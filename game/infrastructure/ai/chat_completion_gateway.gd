extends "res://application/ports/model_provider.gd"
## Bridges AIRPG's filtered NPC context to a Chat Completions transport and decodes
## its cached completion. Raw deltas deliberately stop here and never reach F1 or UI.

const Contract = preload("res://application/contracts/model_transport_contract.gd")
const ModelReply = preload("res://domain/dialogue/model_reply.gd")

var _transport: Object = null
var _builder: Object = null
var _active: Dictionary = {}
var _attempts: Dictionary = {}
var _released: bool = false

const MAX_RECOVERY_RETRIES: int = 1
## Transient answer defects worth one silent resample: the answer was empty, cut short, or did
## not follow the reply protocol. Anything else (timeouts, HTTP errors, credentials) is final.
const RECOVERABLE_CODES: Array[String] = [Contract.MODEL_RESPONSE_INVALID,
	Contract.MODEL_EMPTY_CONTENT, Contract.MODEL_FINISH_INCOMPLETE, Contract.MODEL_REPLY_INVALID]

func _init(transport: Object = null, builder: Object = null) -> void:
	_transport = transport
	_builder = builder
	if _transport != null:
		_transport.completed.connect(_on_transport_completed)
		_transport.failed.connect(_on_transport_failed)

func start(request_id: String, filtered_context: Dictionary) -> RefCounted:
	if _released or _transport == null or _builder == null or _active.has(request_id):
		return Result.failure("MODEL_REQUEST_INVALID")
	var body: RefCounted = _builder.build(filtered_context)
	if not body.ok:
		return Result.failure(Contract.MODEL_RESPONSE_INVALID, body.issues)
	_active[request_id] = {"body": body.value.duplicate(true), "attempt_id": request_id,
		"retry_count": 0}
	_attempts[request_id] = request_id
	var started: RefCounted = _transport.start(request_id, body.value)
	if not started.ok:
		_forget(request_id, request_id)
		return started
	return Result.success()

func cancel(request_id: String) -> void:
	if _released or not _active.has(request_id):
		return
	var attempt_id: String = _active[request_id].attempt_id
	_transport.cancel(attempt_id)

func release() -> void:
	if _released:
		return
	_released = true
	var attempt_ids: Array[String] = []
	for request_id: String in _active:
		attempt_ids.append(_active[request_id].attempt_id)
	_active.clear()
	_attempts.clear()
	for attempt_id: String in attempt_ids:
		_transport.cancel(attempt_id)
	if _transport != null and is_instance_valid(_transport):
		if _transport.completed.is_connected(_on_transport_completed):
			_transport.completed.disconnect(_on_transport_completed)
		if _transport.failed.is_connected(_on_transport_failed):
			_transport.failed.disconnect(_on_transport_failed)
	_transport = null
	_builder = null

func _on_transport_completed(attempt_id: String, response: Dictionary) -> void:
	var request_id := _claim_attempt(attempt_id)
	if request_id.is_empty():
		return
	var envelope := Contract.validate_completed_response(response)
	if not envelope.ok:
		# The contract already separates an empty message from a cut-short answer.
		var classified: String = envelope.code if envelope.code in RECOVERABLE_CODES \
			else Contract.MODEL_RESPONSE_INVALID
		_recover_or_fail(request_id, classified, "envelope:" + envelope.code)
		return
	if envelope.value.finish_reason != "stop":
		_recover_or_fail(request_id, Contract.MODEL_FINISH_INCOMPLETE,
			"finish:" + envelope.value.finish_reason)
		return
	var parsed := ModelReply.parse(envelope.value.content)
	if not parsed.ok:
		# Field-level detail only: reply text and model content never reach the log.
		_recover_or_fail(request_id, Contract.MODEL_REPLY_INVALID,
			"reply:" + parsed.code + ":" + _detail(parsed.issues))
		return
	_active.erase(request_id)
	completed.emit(request_id, parsed.value)

func _on_transport_failed(attempt_id: String, code: String) -> void:
	var request_id := _claim_attempt(attempt_id)
	if request_id.is_empty():
		return
	if code in RECOVERABLE_CODES:
		_recover_or_fail(request_id, code, "transport")
		return
	_active.erase(request_id)
	failed.emit(request_id, code if Contract.is_stable_error(code) else Contract.MODEL_TRANSPORT_ERROR)

## One automatic resample for transient answer defects, then the classified code reaches the
## dialogue layer so the player sees which kind of failure it was instead of a generic error.
func _recover_or_fail(request_id: String, code: String, detail: String) -> void:
	if not _active.has(request_id):
		return
	var state: Dictionary = _active[request_id]
	if state.retry_count >= MAX_RECOVERY_RETRIES:
		_active.erase(request_id)
		print("AIRPG_MODEL_REPLY_REJECTED: ", code, " ", detail, " (retry exhausted)")
		failed.emit(request_id, code)
		return
	state.retry_count += 1
	var attempt_id := "recovery." + request_id.sha256_text().substr(0, 32) + "." \
		+ str(state.retry_count)
	state.attempt_id = attempt_id
	_attempts[attempt_id] = request_id
	print("AIRPG_AI_RECOVERY: retry ", code, " ", detail)
	var started: RefCounted = _transport.start(attempt_id, state.body)
	if not started.ok and _attempts.has(attempt_id):
		_forget(request_id, attempt_id)
		failed.emit(request_id, started.code if Contract.is_stable_error(started.code) \
			else Contract.MODEL_TRANSPORT_ERROR)

static func _detail(issues: Array) -> String:
	for issue: Variant in issues:
		if issue is String and not issue.is_empty():
			return issue
	return "none"

func _claim_attempt(attempt_id: String) -> String:
	if _released or not _attempts.has(attempt_id):
		return ""
	var request_id: String = _attempts[attempt_id]
	_attempts.erase(attempt_id)
	if not _active.has(request_id) or _active[request_id].attempt_id != attempt_id:
		return ""
	return request_id

func _forget(request_id: String, attempt_id: String) -> void:
	_attempts.erase(attempt_id)
	_active.erase(request_id)
