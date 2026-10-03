extends "res://application/ports/model_provider.gd"
## DeepSeek chat-completions SSE transport adapter.
## Scope: request lifecycle, raw SSE transport, stable failure codes and sanitized usage only.
## It does NOT choose NPC knowledge, approve facts, judge semantics, settle rules or commit state.
## raw_delta and the completed.content aggregate are unverified transport data and must never be
## connected to player-facing UI before the caller has validated the full cached response.
## The API key lives only inside the injected credentials object and is never returned, logged
## or included in completed/failed payloads. Vendor error text is discarded at this boundary.
##
## Construction (composition owns wiring; no globals, no bootstrap edits):
##   var provider := DeepSeekProvider.new(config, credentials, stream_factory, clock)
##   stream_factory: Callable returning a fresh stream (GodotHttpStream.new(host) in production,
##                   a fake extending http_stream_port.gd in tests)
##   clock: required ClockPort for overall/idle timeouts; a missing clock fails closed because
##          it could otherwise accept a request that never receives a terminal signal
##   Completion requires both a 2xx response_started and the [DONE] sentinel. A body containing
##   [DONE] on a non-2xx response, or before the status is confirmed, always fails.

const Contract = preload("res://application/contracts/model_transport_contract.gd")
const Config = preload("res://infrastructure/ai/deepseek_config.gd")
const Credentials = preload("res://infrastructure/ai/deepseek_credentials.gd")
const ClockPort = preload("res://infrastructure/ai/clock_port.gd")
const SseParser = preload("res://infrastructure/ai/sse_parser.gd")
const Usage = preload("res://infrastructure/ai/deepseek_usage.gd")
const TerminatedLog = preload("res://infrastructure/ai/terminated_request_log.gd")

const DONE_MARKER: String = "[DONE]"
const SYNC_REQUEST_INVALID: String = "MODEL_REQUEST_INVALID"
const FINISH_REASONS: PackedStringArray = [
	"stop", "length", "tool_calls", "content_filter", "insufficient_system_resource",
]

var _config: Config
var _credentials: Credentials
var _stream_factory: Callable
var _clock: ClockPort
var _requests: Dictionary = {}
var _active_count: int = 0
var _terminated: TerminatedLog = TerminatedLog.new()

func _init(config: Config, credentials: Credentials, stream_factory: Callable,
		clock: ClockPort) -> void:
	_config = config
	_credentials = credentials
	_stream_factory = stream_factory
	_clock = clock

func _to_string() -> String:
	return "<deepseek transport provider>"

func start(request_id: String, filtered_context: Dictionary) -> RefCounted:
	var request := Contract.request(request_id, filtered_context)
	if not request.ok or _requests.has(request_id) or _terminated.has(request_id):
		return Result.failure(SYNC_REQUEST_INVALID)
	if _config == null or _credentials == null or not _credentials.configured():
		return Result.failure(Contract.AI_NOT_CONFIGURED)
	if _clock == null:
		# Without a clock the adapter cannot guarantee a terminal signal; fail before accepting.
		return Result.failure(Contract.AI_NOT_CONFIGURED)
	if _active_count >= _config.max_concurrent_requests:
		return Result.failure(SYNC_REQUEST_INVALID)
	if not Config.is_json_safe(request.value.filtered_context):
		return Result.failure(SYNC_REQUEST_INVALID)
	var body := _build_body(request.value.filtered_context)
	if not body.ok:
		return body
	var stream: Variant = _stream_factory.call()
	if stream == null or not stream.has_signal("response_started") \
			or not stream.has_signal("body_chunk") \
			or not stream.has_signal("response_finished") or not stream.has_signal("transport_failed"):
		return Result.failure(Contract.MODEL_TRANSPORT_ERROR)
	var state := {
		"stream": stream,
		"parser": SseParser.new(),
		"text": "",
		"usage": {},
		"finish_reason": "",
		"status_code": 0,
		"terminated": false,
		"received_bytes": 0,
		"request_token": null,
		"idle_token": null,
	}
	stream.connect("response_started", _on_response_started.bind(request_id))
	stream.connect("body_chunk", _on_body_chunk.bind(request_id))
	stream.connect("response_finished", _on_response_finished.bind(request_id))
	stream.connect("transport_failed", _on_transport_failed.bind(request_id))
	_requests[request_id] = state
	_active_count += 1
	if not _arm_timer(request_id, "request_token", _config.request_timeout_seconds) \
			or not _arm_timer(request_id, "idle_token", _config.idle_timeout_seconds):
		state.terminated = true
		_release_request(request_id, state, false)
		return Result.failure(Contract.MODEL_TRANSPORT_ERROR)
	# Register lifecycle state before start(): injected transports are allowed to signal
	# synchronously, and those callbacks must see the accepted request.
	var started: RefCounted = stream.start(_config.endpoint_url, _credentials.request_headers(), body.value)
	if not started.ok:
		var active: Variant = _active(request_id)
		if active != null:
			active.terminated = true
			_release_request(request_id, active, false)
		return Result.failure(Contract.MODEL_TRANSPORT_ERROR)
	return Result.success()

func cancel(request_id: String) -> void:
	var state: Variant = _active(request_id)
	if state == null:
		return
	_fail_request(request_id, Contract.REQUEST_CANCELLED)

func _build_body(filtered_context: Dictionary) -> RefCounted:
	var body: Dictionary = filtered_context.duplicate(true)
	body["model"] = _config.model
	body["stream"] = true
	if _config.include_usage:
		var options: Dictionary = {}
		if typeof(body.get("stream_options")) == TYPE_DICTIONARY:
			options = body["stream_options"].duplicate(true)
		options["include_usage"] = true
		body["stream_options"] = options
	for key: Variant in _config.parameters:
		body[key] = _config.parameters[key]
	var encoded := JSON.stringify(body)
	if encoded.is_empty():
		return Result.failure(SYNC_REQUEST_INVALID)
	var bytes := encoded.to_utf8_buffer()
	if bytes.size() > _config.max_request_bytes:
		return Result.failure(SYNC_REQUEST_INVALID)
	return Result.success(bytes)

func _on_response_started(status_code: int, request_id: String) -> void:
	var state: Variant = _active(request_id)
	if state == null:
		return
	state.status_code = status_code
	if status_code < 200 or status_code > 299:
		_fail_request(request_id, Contract.MODEL_TRANSPORT_ERROR)

func _on_body_chunk(bytes: PackedByteArray, request_id: String) -> void:
	var state: Variant = _active(request_id)
	if state == null or bytes.is_empty():
		return
	state.received_bytes += bytes.size()
	if state.received_bytes > _config.max_response_bytes:
		_fail_request(request_id, Contract.MODEL_RESPONSE_INVALID)
		return
	if not _arm_timer(request_id, "idle_token", _config.idle_timeout_seconds):
		_fail_request(request_id, Contract.MODEL_TRANSPORT_ERROR)
		return
	var events: Array = state.parser.feed_bytes(bytes)
	for event: Variant in events:
		if state.terminated:
			return
		_handle_event(request_id, state, event)
	if not state.terminated and state.parser.has_failed():
		_fail_request(request_id, Contract.MODEL_RESPONSE_INVALID)

func _handle_event(request_id: String, state: Dictionary, event: Dictionary) -> void:
	var data: String = String(event.get("data", ""))
	if data == DONE_MARKER:
		if state.status_code >= 200 and state.status_code <= 299:
			_complete_request(request_id, state)
		else:
			_fail_request(request_id, Contract.MODEL_TRANSPORT_ERROR)
		return
	if data.is_empty():
		return
	var json := JSON.new()
	if json.parse(data) != OK or typeof(json.data) != TYPE_DICTIONARY:
		_fail_request(request_id, Contract.MODEL_RESPONSE_INVALID)
		return
	var payload: Dictionary = json.data
	if payload.has("error"):
		_fail_request(request_id, Contract.MODEL_TRANSPORT_ERROR)
		return
	if not payload.has("choices") and not payload.has("usage"):
		_fail_request(request_id, Contract.MODEL_RESPONSE_INVALID)
		return
	if payload.has("usage"):
		var sanitized := Usage.sanitize(payload["usage"])
		if not sanitized.is_empty():
			state.usage = sanitized
	if not payload.has("choices"):
		return
	if typeof(payload["choices"]) != TYPE_ARRAY:
		_fail_request(request_id, Contract.MODEL_RESPONSE_INVALID)
		return
	for choice: Variant in payload["choices"]:
		if state.terminated:
			return
		if typeof(choice) != TYPE_DICTIONARY:
			_fail_request(request_id, Contract.MODEL_RESPONSE_INVALID)
			return
		_consume_choice(request_id, state, choice)

func _consume_choice(request_id: String, state: Dictionary, choice: Dictionary) -> void:
	var delta: Variant = choice.get("delta")
	if choice.has("delta") and typeof(delta) != TYPE_DICTIONARY:
		_fail_request(request_id, Contract.MODEL_RESPONSE_INVALID)
		return
	if typeof(delta) == TYPE_DICTIONARY:
		if delta.has("content"):
			var content: Variant = delta["content"]
			if typeof(content) == TYPE_STRING:
				if not content.is_empty():
					state.text += content
					raw_delta.emit(request_id, content)
			elif typeof(content) != TYPE_NIL:
				_fail_request(request_id, Contract.MODEL_RESPONSE_INVALID)
				return
	var finish: Variant = choice.get("finish_reason")
	if typeof(finish) == TYPE_STRING and not finish.is_empty():
		state.finish_reason = finish if finish in FINISH_REASONS else "unknown"

func _on_response_finished(status_code: int, request_id: String) -> void:
	var state: Variant = _active(request_id)
	if state == null:
		return
	if status_code < 200 or status_code > 299:
		_fail_request(request_id, Contract.MODEL_TRANSPORT_ERROR)
		return
	var finished: Dictionary = state.parser.finish()
	if not finished.clean:
		_fail_request(request_id, Contract.MODEL_TRANSPORT_ERROR)
		return
	# A clean EOF without the [DONE] sentinel is still an incomplete stream; success is only
	# signalled by [DONE], so reaching this line always means the stream ended prematurely.
	_fail_request(request_id, Contract.MODEL_TRANSPORT_ERROR)

func _on_transport_failed(code: String, request_id: String) -> void:
	if _active(request_id) == null:
		return
	_fail_request(request_id, code)

func _complete_request(request_id: String, state: Dictionary) -> void:
	if state.terminated:
		return
	var response := Contract.completed_response(state.text, state.finish_reason, state.usage)
	if not response.ok:
		_fail_request(request_id, Contract.MODEL_RESPONSE_INVALID)
		return
	var payload: Dictionary = response.value
	state.terminated = true
	_release_request(request_id, state)
	completed.emit(request_id, payload)

func _fail_request(request_id: String, code: String) -> void:
	var state: Variant = _active(request_id)
	if state == null:
		return
	state.terminated = true
	_release_request(request_id, state)
	var stable := code if Contract.is_stable_error(code) else Contract.MODEL_TRANSPORT_ERROR
	failed.emit(request_id, stable)

func _release_request(request_id: String, state: Dictionary, remember: bool = true) -> void:
	_disarm_timer(state, "request_token")
	_disarm_timer(state, "idle_token")
	var stream: Variant = state.stream
	if stream != null and is_instance_valid(stream) and stream.has_method("cancel"):
		stream.cancel()
	# Drop references to response text, parser and stream so terminated requests do not
	# accumulate memory; the request ID stays deduplicated through a bounded tombstone ring.
	state.text = ""
	state.usage = {}
	state.parser = null
	state.stream = null
	_active_count = maxi(_active_count - 1, 0)
	_requests.erase(request_id)
	if remember:
		_terminated.remember(request_id)

func _active(request_id: String) -> Variant:
	var state: Variant = _requests.get(request_id)
	if state == null or state.terminated:
		return null
	return state

func _arm_timer(request_id: String, key: String, seconds: float) -> bool:
	if _clock == null:
		return false
	var state: Variant = _requests.get(request_id)
	if state == null:
		return false
	_disarm_timer(state, key)
	state[key] = _clock.schedule(seconds, _on_timeout.bind(request_id))
	return state[key] != null

func _disarm_timer(state: Dictionary, key: String) -> void:
	var token: Variant = state.get(key)
	if token == null:
		return
	if _clock != null:
		_clock.unschedule(token)
	state[key] = null

func _on_timeout(request_id: String) -> void:
	_fail_request(request_id, Contract.MODEL_TIMEOUT)
