extends RefCounted
## G1: DeepSeek SSE stream behavior on offline fixtures. No network, no real credentials.

const Contract = preload("res://application/contracts/model_transport_contract.gd")
const Harness = preload("res://tests/g1/g1_harness.gd")
const Fixture = preload("res://tests/g1/sse_fixture.gd")

const BASIC := "res://tests/g1/fixtures/deepseek_stream_basic.json"
const TRUNCATED := "res://tests/g1/fixtures/deepseek_stream_truncated.json"
const NO_DONE := "res://tests/g1/fixtures/deepseek_stream_no_done.json"
const VENDOR_ERROR := "res://tests/g1/fixtures/deepseek_stream_vendor_error.json"
const HEARTBEAT := "res://tests/g1/fixtures/deepseek_stream_heartbeat_only.json"

const EXPECTED_TEXT := "暴风雨中的公路"
const EXPECTED_USAGE := {
	"prompt_tokens": 12,
	"completion_tokens": 5,
	"total_tokens": 17,
	"prompt_cache_hit_tokens": 4,
	"prompt_cache_miss_tokens": 8,
	"prompt_tokens_details": {"cached_tokens": 4},
}

func run(check: Callable) -> void:
	_happy_path(check)
	_byte_by_byte(check)
	_oversized_response(check)
	_invalid_payload(check)
	_truncated_streams(check)
	_vendor_error_and_heartbeat(check)

func _happy_path(check: Callable) -> void:
	var harness := Harness.new()
	var request := harness.provider.start("req-happy", Harness.context())
	check.call(request.ok, "provider accepts valid request")
	var stream := harness.stream()
	if stream == null:
		check.call(false, "stream created for accepted request")
		harness.release()
		return
	check.call(stream.started, "stream started with fake transport")
	check.call(stream.url == Harness.DEFAULT_ENDPOINT, "configured endpoint used")
	check.call(String(stream.headers.get("Authorization", "")).begins_with("Bearer "),
		"authorization header present for transport only")
	var body := _parse_body(stream.body)
	check.call(body.get("model") == Harness.DEFAULT_MODEL and body.get("stream") == true,
		"request body carries configured model and stream flag")
	check.call(body.get("stream_options", {}).get("include_usage") == true,
		"usage requested as structured stream option")
	check.call(body.get("messages") is Array, "filtered context passed through as body")
	for chunk: Variant in Fixture.load_chunks(BASIC):
		stream.emit_chunk(chunk)
	check.call(harness.text() == EXPECTED_TEXT, "deltas concatenate to expected chinese text")
	check.call(harness.completed.size() == 1 and harness.failed.is_empty(),
		"exactly one completed terminal and no failure")
	var payload: Dictionary = harness.completed[0]["payload"]
	check.call(payload.get("content") == EXPECTED_TEXT, "completed transport aggregate matches")
	check.call(payload.get("usage") == EXPECTED_USAGE, "usage sanitized to whitelisted counters")
	check.call(payload.get("finish_reason") == "stop", "finish reason carried")
	check.call(payload.get("transport_schema_version") == 1, "transport envelope versioned")
	check.call(not harness.text().contains("usage"), "raw deltas never carry usage records")
	stream.emit_chunk("data: [DONE]\r\n\r\n".to_utf8_buffer())
	stream.emit_finished(200)
	check.call(harness.terminal_count() == 1, "late callbacks after completion are ignored")
	harness.release()

func _byte_by_byte(check: Callable) -> void:
	var harness := Harness.new()
	harness.provider.start("req-bytes", Harness.context())
	var stream := harness.stream()
	if stream == null:
		check.call(false, "stream created for byte-split request")
		harness.release()
		return
	var bytes := Fixture.load_bytes(BASIC)
	for index: int in bytes.size():
		stream.emit_chunk(bytes.slice(index, index + 1))
	check.call(harness.text() == EXPECTED_TEXT and harness.completed.size() == 1,
		"byte-split UTF-8 and JSON still complete exactly once")
	check.call(not "\uFFFD" in harness.text(), "no replacement characters in transport text")
	harness.release()

func _oversized_response(check: Callable) -> void:
	var harness := Harness.new({"max_response_bytes": 64})
	harness.provider.start("req-big", Harness.context())
	var stream := harness.stream()
	if stream == null:
		check.call(false, "stream created for oversized request")
		harness.release()
		return
	var bytes := Fixture.load_bytes(BASIC)
	for index: int in bytes.size():
		if harness.failed.is_empty():
			stream.emit_chunk(bytes.slice(index, index + 1))
	check.call(harness.failure_codes() == [Contract.MODEL_RESPONSE_INVALID],
		"response size cap maps to MODEL_RESPONSE_INVALID")
	check.call(harness.terminal_count() == 1, "oversized response produces one terminal")
	stream.emit_finished(200)
	check.call(harness.terminal_count() == 1, "end after size failure is ignored")
	harness.release()

func _invalid_payload(check: Callable) -> void:
	var harness := Harness.new()
	harness.provider.start("req-invalid", Harness.context())
	var stream := harness.stream()
	if stream == null:
		check.call(false, "stream created for invalid payload request")
		harness.release()
		return
	stream.emit_chunk_text("data: {oops\r\n\r\n")
	check.call(harness.failure_codes() == [Contract.MODEL_RESPONSE_INVALID],
		"malformed JSON maps to MODEL_RESPONSE_INVALID")
	stream.emit_chunk_text("data: [1,2]\r\n\r\n")
	stream.emit_finished(200)
	check.call(harness.terminal_count() == 1, "duplicate terminals ignored after invalid payload")
	harness.release()
	var second := Harness.new()
	second.provider.start("req-shape", Harness.context())
	var second_stream := second.stream()
	if second_stream != null:
		second_stream.emit_chunk_text("data: {\"id\":\"only-id\"}\r\n\r\n")
	check.call(second.failure_codes() == [Contract.MODEL_RESPONSE_INVALID],
		"unrecognized chunk shape maps to MODEL_RESPONSE_INVALID")
	second.release()
	var third := Harness.new()
	third.provider.start("req-content-type", Harness.context())
	var third_stream := third.stream()
	if third_stream != null:
		third_stream.emit_chunk_text(
			"data: {\"choices\":[{\"delta\":{\"content\":123}}]}\r\n\r\n")
	check.call(third.failure_codes() == [Contract.MODEL_RESPONSE_INVALID],
		"non-string delta content maps to MODEL_RESPONSE_INVALID")
	third.release()

func _truncated_streams(check: Callable) -> void:
	var truncated := Harness.new()
	truncated.provider.start("req-truncated", Harness.context())
	var stream := truncated.stream()
	if stream != null:
		for chunk: Variant in Fixture.load_chunks(TRUNCATED):
			stream.emit_chunk(chunk)
		stream.emit_finished(200)
	check.call(truncated.failure_codes() == [Contract.MODEL_TRANSPORT_ERROR],
		"truncated stream maps to MODEL_TRANSPORT_ERROR")
	check.call(truncated.terminal_count() == 1, "truncated stream has one terminal")
	truncated.release()
	var no_done := Harness.new()
	no_done.provider.start("req-no-done", Harness.context())
	var no_done_stream := no_done.stream()
	if no_done_stream != null:
		for chunk: Variant in Fixture.load_chunks(NO_DONE):
			no_done_stream.emit_chunk(chunk)
		no_done_stream.emit_finished(200)
	check.call(no_done.failure_codes() == [Contract.MODEL_TRANSPORT_ERROR],
		"clean EOF without done marker is a transport error")
	no_done.release()
	var disconnected := Harness.new()
	disconnected.provider.start("req-disconnect", Harness.context())
	var disconnected_stream := disconnected.stream()
	if disconnected_stream != null:
		disconnected_stream.emit_chunk(Fixture.load_bytes(BASIC).slice(0, 40))
		disconnected_stream.emit_failed(Contract.MODEL_TRANSPORT_ERROR)
		disconnected_stream.emit_finished(200)
	check.call(disconnected.failure_codes() == [Contract.MODEL_TRANSPORT_ERROR],
		"server disconnect maps to stable transport error")
	check.call(disconnected.terminal_count() == 1, "disconnect terminal is not duplicated")
	disconnected.release()

func _vendor_error_and_heartbeat(check: Callable) -> void:
	var vendor := Harness.new()
	vendor.provider.start("req-vendor", Harness.context())
	var stream := vendor.stream()
	if stream != null:
		for chunk: Variant in Fixture.load_chunks(VENDOR_ERROR):
			stream.emit_chunk(chunk)
	check.call(vendor.failure_codes() == [Contract.MODEL_TRANSPORT_ERROR],
		"vendor error event maps to stable transport error")
	var exposed := JSON.stringify({
		"deltas": vendor.deltas,
		"completed": vendor.completed,
		"failed": vendor.failed,
	})
	check.call(not exposed.contains("G1_VENDOR_SECRET_MARKER"),
		"vendor error text never reaches transport signals")
	check.call(not str(vendor.provider).contains("G1_VENDOR_SECRET_MARKER"),
		"provider string form carries no vendor text")
	vendor.release()
	var heartbeat := Harness.new()
	heartbeat.provider.start("req-heartbeat", Harness.context())
	var heartbeat_stream := heartbeat.stream()
	if heartbeat_stream != null:
		for chunk: Variant in Fixture.load_chunks(HEARTBEAT):
			heartbeat_stream.emit_chunk(chunk)
		heartbeat_stream.emit_finished(200)
	check.call(heartbeat.failure_codes() == [Contract.MODEL_TRANSPORT_ERROR]
		and heartbeat.deltas.is_empty(), "heartbeat-only stream cannot pretend success")
	heartbeat.release()

func _parse_body(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data
