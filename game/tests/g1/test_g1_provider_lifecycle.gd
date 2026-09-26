extends RefCounted
## G1: request lifecycle tests: one terminal per accepted request, idempotent cancel,
## timeouts, duplicate/unknown IDs, HTTP status mapping and stable error boundary. Offline only.

const Contract = preload("res://application/contracts/model_transport_contract.gd")
const Config = preload("res://infrastructure/ai/deepseek_config.gd")
const Credentials = preload("res://infrastructure/ai/deepseek_credentials.gd")
const Provider = preload("res://infrastructure/ai/deepseek_provider.gd")
const TerminatedLog = preload("res://infrastructure/ai/terminated_request_log.gd")
const Harness = preload("res://tests/g1/g1_harness.gd")
const ManualClock = preload("res://tests/g1/manual_clock.gd")
const Fixture = preload("res://tests/g1/sse_fixture.gd")

const BASIC := "res://tests/g1/fixtures/deepseek_stream_basic.json"

func run(check: Callable) -> void:
	_not_configured(check)
	_missing_clock(check)
	_request_validation(check)
	_cancel_is_idempotent(check)
	_timeouts(check)
	_concurrency(check)
	_http_status(check)
	_stable_error_boundary(check)
	_sanitized_finish_reason(check)
	_bounded_terminated_ids(check)

func _not_configured(check: Callable) -> void:
	var config: Config = Config.from_dictionary(Harness.base_config()).value
	var provider := Provider.new(config, Credentials.new(""), func() -> Object: return null, ManualClock.new())
	var terminals: Array = []
	provider.failed.connect(func(_id: String, code: String) -> void: terminals.append(code))
	var request := provider.start("req-nc", Harness.context())
	check.call(not request.ok and request.code == Contract.AI_NOT_CONFIGURED,
		"unconfigured provider fails synchronously with AI_NOT_CONFIGURED")
	check.call(terminals.is_empty(), "synchronous failure emits no terminal")

func _missing_clock(check: Callable) -> void:
	var config: Config = Config.from_dictionary(Harness.base_config()).value
	var credentials := Credentials.from_key("test-key-synthetic")
	var provider := Provider.new(config, credentials.value, func() -> Object: return null, null)
	var result := provider.start("req-no-clock", Harness.context())
	check.call(not result.ok and result.code == Contract.AI_NOT_CONFIGURED,
		"missing clock fails closed before accepting the request")

func _request_validation(check: Callable) -> void:
	var harness := Harness.new()
	check.call(not harness.provider.start("", Harness.context()).ok, "empty request id rejected")
	check.call(not harness.provider.start("bad".repeat(100), Harness.context()).ok,
		"oversized request id rejected")
	check.call(not harness.provider.start("req-empty", {}).ok, "empty context rejected")
	check.call(harness.provider.start("req-dup", Harness.context()).ok, "first valid request accepted")
	check.call(not harness.provider.start("req-dup", Harness.context()).ok,
		"duplicate request id rejected")
	check.call(harness.streams.size() == 1, "rejected requests never start a stream")
	check.call(harness.terminal_count() == 0, "no terminal before completion")
	harness.provider.cancel("unknown-id")
	check.call(harness.terminal_count() == 0, "cancel for unknown request id is a no-op")
	harness.provider.call("_on_response_started", 200, "ghost-id")
	harness.provider.call("_on_body_chunk", Fixture.load_bytes(BASIC), "ghost-id")
	harness.provider.call("_on_response_finished", 200, "ghost-id")
	harness.provider.call("_on_transport_failed", Contract.MODEL_TRANSPORT_ERROR, "ghost-id")
	check.call(harness.terminal_count() == 0 and harness.deltas.is_empty(),
		"callbacks for unknown request ids are ignored")
	harness.stream().emit_started(200)
	harness.stream().emit_chunk(Fixture.load_bytes(BASIC))
	check.call(harness.completed.size() == 1, "accepted request completes once")
	check.call(harness.terminal_count() == 1, "completed request ends without duplicate terminal")
	check.call(not harness.provider.start("req-dup", Harness.context()).ok,
		"terminated request id is not reusable")
	harness.release()

func _cancel_is_idempotent(check: Callable) -> void:
	var harness := Harness.new()
	harness.provider.start("req-cancel", Harness.context())
	var stream := harness.stream()
	stream.emit_started(200)
	stream.emit_chunk(Fixture.load_bytes(BASIC).slice(0, 30))
	harness.provider.cancel("req-cancel")
	harness.provider.cancel("req-cancel")
	check.call(harness.failure_codes() == [Contract.REQUEST_CANCELLED],
		"cancellation emits REQUEST_CANCELLED exactly once")
	check.call(stream.cancelled, "stream told to cancel")
	stream.emit_chunk(Fixture.load_bytes(BASIC))
	stream.emit_finished(200)
	stream.emit_failed(Contract.MODEL_TRANSPORT_ERROR)
	check.call(harness.terminal_count() == 1, "late callbacks after cancel are ignored")
	check.call(harness.completed.is_empty(), "cancelled request cannot complete later")
	harness.release()

func _timeouts(check: Callable) -> void:
	var request_timeout := Harness.new(
		{"request_timeout_seconds": 5.0, "idle_timeout_seconds": 30.0})
	request_timeout.provider.start("req-timeout", Harness.context())
	check.call(request_timeout.clock.fire_delay(5.0), "request timeout scheduled")
	check.call(request_timeout.failure_codes() == [Contract.MODEL_TIMEOUT],
		"request timeout maps to MODEL_TIMEOUT")
	check.call(request_timeout.clock.active_count() == 0, "timers disarmed after terminal")
	request_timeout.stream().emit_started(200)
	request_timeout.stream().emit_chunk(Fixture.load_bytes(BASIC))
	check.call(request_timeout.terminal_count() == 1, "late data after timeout is ignored")
	request_timeout.release()
	var idle_timeout := Harness.new(
		{"request_timeout_seconds": 60.0, "idle_timeout_seconds": 30.0})
	idle_timeout.provider.start("req-idle", Harness.context())
	idle_timeout.stream().emit_started(200)
	idle_timeout.stream().emit_chunk(Fixture.load_bytes(BASIC).slice(0, 10))
	check.call(idle_timeout.clock.active_count() == 2, "idle timeout rescheduled while active")
	check.call(idle_timeout.clock.fire_delay(30.0), "idle timeout scheduled")
	check.call(idle_timeout.failure_codes() == [Contract.MODEL_TIMEOUT],
		"idle timeout maps to MODEL_TIMEOUT")
	idle_timeout.release()

func _concurrency(check: Callable) -> void:
	var capped := Harness.new({"max_concurrent_requests": 1})
	capped.provider.start("req-a", Harness.context())
	var extra := capped.provider.start("req-b", Harness.context())
	check.call(not extra.ok and capped.streams.size() == 1,
		"concurrency cap rejects extra request synchronously")
	capped.release()
	var harness := Harness.new({"max_concurrent_requests": 2})
	harness.provider.start("req-a", Harness.context())
	harness.provider.start("req-b", Harness.context())
	check.call(harness.streams.size() == 2, "two concurrent streams created")
	harness.provider.cancel("req-a")
	check.call(harness.failure_codes() == [Contract.REQUEST_CANCELLED],
		"only the cancelled request emits a terminal")
	harness.streams[1].emit_started(200)
	harness.streams[1].emit_chunk(Fixture.load_bytes(BASIC))
	check.call(harness.completed.size() == 1 and harness.completed[0]["request_id"] == "req-b",
		"other request still completes")
	check.call(harness.terminal_count() == 2, "each accepted request kept one terminal")
	harness.release()

func _http_status(check: Callable) -> void:
	var unauthorized := Harness.new()
	unauthorized.provider.start("req-401", Harness.context())
	var unauthorized_stream := unauthorized.stream()
	unauthorized_stream.emit_started(401)
	check.call(unauthorized.failure_codes() == [Contract.MODEL_TRANSPORT_ERROR],
		"non-2xx response start maps to stable transport error")
	unauthorized_stream.emit_chunk_text("data: [DONE]\r\n\r\n")
	unauthorized_stream.emit_finished(401)
	check.call(unauthorized.terminal_count() == 1 and unauthorized.completed.is_empty(),
		"non-2xx body can never complete and emits one terminal")
	unauthorized.release()
	var premature := Harness.new()
	premature.provider.start("req-done-first", Harness.context())
	var premature_stream := premature.stream()
	premature_stream.emit_chunk_text("data: [DONE]\r\n\r\n")
	check.call(premature.failure_codes() == [Contract.MODEL_TRANSPORT_ERROR]
		and premature.completed.is_empty(),
		"done marker before status confirmation fails closed")
	premature_stream.emit_started(401)
	premature_stream.emit_finished(401)
	check.call(premature.terminal_count() == 1,
		"late status after a premature done marker is ignored")
	premature.release()
	var late := Harness.new()
	late.provider.start("req-late-status", Harness.context())
	var late_stream := late.stream()
	late_stream.emit_started(200)
	late_stream.emit_chunk(Fixture.load_bytes(BASIC).slice(0, 30))
	late_stream.emit_finished(401)
	check.call(late.failure_codes() == [Contract.MODEL_TRANSPORT_ERROR]
		and late.completed.is_empty(), "http error status maps to stable transport error")
	late_stream.emit_chunk(Fixture.load_bytes(BASIC))
	check.call(late.terminal_count() == 1, "data after http error is ignored")
	late.release()
	var failed_start := Harness.new()
	failed_start.next_start_failure = "vendor raw text"
	var start_result := failed_start.provider.start("req-start-fail", Harness.context())
	check.call(not start_result.ok and start_result.code == Contract.MODEL_TRANSPORT_ERROR,
		"stream start failure returns synchronous transport error")
	check.call(failed_start.terminal_count() == 0, "unaccepted request emits no terminal")
	check.call(failed_start.provider.start("req-start-fail", Harness.context()).ok,
		"request id can be retried after synchronous start failure")
	failed_start.release()

func _stable_error_boundary(check: Callable) -> void:
	var harness := Harness.new()
	harness.provider.start("req-code", Harness.context())
	harness.stream().emit_failed("vendor stack trace")
	check.call(harness.failure_codes() == [Contract.MODEL_TRANSPORT_ERROR],
		"unknown transport failure code coerced to stable code")
	check.call(not JSON.stringify(harness.failed).contains("stack trace"),
		"vendor failure text never forwarded")
	harness.release()

func _sanitized_finish_reason(check: Callable) -> void:
	var harness := Harness.new()
	harness.provider.start("req-finish", Harness.context())
	var stream := harness.stream()
	stream.emit_started(200)
	stream.emit_chunk_text(
		"data: {\"choices\":[{\"delta\":{\"content\":\"x\"},\"finish_reason\":\"stack trace secret\"}]}\r\n\r\n")
	stream.emit_chunk_text("data: [DONE]\r\n\r\n")
	check.call(harness.completed.size() == 1
		and String(harness.completed[0]["payload"].get("finish_reason")) == "unknown",
		"unexpected finish reason is replaced with a stable token")
	harness.release()

func _bounded_terminated_ids(check: Callable) -> void:
	var harness := Harness.new()
	var total := TerminatedLog.MAX_ENTRIES + 5
	var bytes := Fixture.load_bytes(BASIC)
	for index: int in total:
		var request_id := "req-mem-%d" % index
		harness.provider.start(request_id, Harness.context())
		harness.streams[index].emit_started(200)
		harness.streams[index].emit_chunk(bytes)
	check.call(harness.completed.size() == total, "many sequential requests complete")
	check.call(harness.provider._requests.is_empty(),
		"terminated requests leave the active map")
	check.call(harness.provider._terminated.size() <= TerminatedLog.MAX_ENTRIES,
		"terminated request id memory is bounded")
	check.call(not harness.provider.start("req-mem-%d" % (total - 1), Harness.context()).ok,
		"recent terminated id is still deduplicated")
	check.call(harness.provider.start("req-mem-0", Harness.context()).ok,
		"evicted tombstone allows bounded id reuse")
	harness.release()
