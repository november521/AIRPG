extends RefCounted
## G1: incremental SSE parser tests. Pure offline buffers, no network.

const Parser = preload("res://infrastructure/ai/sse_parser.gd")
const Fixture = preload("res://tests/g1/sse_fixture.gd")

const BASIC := "res://tests/g1/fixtures/deepseek_stream_basic.json"
const TRUNCATED := "res://tests/g1/fixtures/deepseek_stream_truncated.json"
const HEARTBEAT := "res://tests/g1/fixtures/deepseek_stream_heartbeat_only.json"

func run(check: Callable) -> void:
	_basic_fixture(check)
	_byte_by_byte(check)
	_field_edges(check)
	_invalid_bytes(check)
	_caps(check)
	_finish_states(check)

func _basic_fixture(check: Callable) -> void:
	var chunks := Fixture.load_chunks(BASIC)
	check.call(chunks.size() > 4, "basic fixture loaded as multiple chunks")
	var parser := Parser.new()
	var events: Array = []
	for chunk: Variant in chunks:
		events.append_array(parser.feed_bytes(chunk))
	var data: Array = []
	for event: Variant in events:
		data.append(String(event["data"]))
	check.call(events.size() == 6, "basic fixture dispatches six events")
	check.call(parser.finish().clean, "basic fixture ends at a clean boundary")
	check.call(String(data[1]).contains("暴风雨"), "utf-8 payload decoded across chunk boundaries")
	check.call(not "\uFFFD" in "\n".join(data), "no replacement characters from split utf-8")
	check.call(String(data[2]).contains("\n") and String(data[2]).contains("choices"),
		"multi-line data reassembled into one json document")
	check.call(String(events[3].get("event")) == "message", "explicit event name carried")
	check.call(data[data.size() - 1] == "[DONE]", "done marker dispatched verbatim")

func _byte_by_byte(check: Callable) -> void:
	var bytes := Fixture.load_bytes(BASIC)
	var parser := Parser.new()
	var events: Array = []
	for index: int in bytes.size():
		events.append_array(parser.feed_bytes(bytes.slice(index, index + 1)))
	var joined := ""
	for event: Variant in events:
		if String(event["data"]) != "[DONE]":
			joined += String(event["data"])
	check.call(events.size() == 6, "byte-by-byte feed still dispatches six events")
	check.call(joined.contains("暴风雨") and joined.contains("中的") and joined.contains("公路"),
		"chinese characters survive every byte split")
	check.call(not "\uFFFD" in joined, "byte-by-byte decode has no replacement characters")
	check.call(parser.finish().clean, "byte-by-byte stream ends cleanly")

func _field_edges(check: Callable) -> void:
	var parser := Parser.new()
	var events := parser.feed_bytes(
		": heartbeat\r\n\r\ndata: one\r\ndata: two\r\n\r\ndata\r\n\r\n".to_utf8_buffer())
	check.call(events.size() == 2, "comments ignored and data-only line accepted")
	check.call(String(events[0]["data"]) == "one\ntwo", "consecutive data lines joined")
	check.call(String(events[1]["data"]) == "", "data line without colon yields empty data event")
	check.call(parser.finish().clean, "edge stream ends cleanly")
	var second := Parser.new()
	var second_events := second.feed_bytes(
		"retry: 100\nfoo: bar\ndata: x\nid: 7\n\nevent: ping\n\n".to_utf8_buffer())
	check.call(second_events.size() == 1 and String(second_events[0]["id"]) == "7",
		"unknown fields ignored, last event id retained")

func _invalid_bytes(check: Callable) -> void:
	var invalid_utf8 := Parser.new()
	var bytes := "data: ".to_utf8_buffer()
	bytes.append(0xFF)
	bytes.append(0x0A)
	bytes.append(0x0A)
	invalid_utf8.feed_bytes(bytes)
	check.call(invalid_utf8.has_failed() and not invalid_utf8.finish().clean,
		"invalid utf-8 line fails the parser")
	var nul := Parser.new()
	var nul_bytes := "data: ok".to_utf8_buffer()
	nul_bytes.append(0x00)
	nul_bytes.append(0x0A)
	nul_bytes.append(0x0A)
	nul.feed_bytes(nul_bytes)
	check.call(nul.has_failed(), "NUL byte in a line fails the parser")
	var overlong := Parser.new()
	var overlong_bytes := "data: ".to_utf8_buffer()
	overlong_bytes.append(0xC0)
	overlong_bytes.append(0xAF)
	overlong_bytes.append(0x0A)
	overlong_bytes.append(0x0A)
	overlong.feed_bytes(overlong_bytes)
	check.call(overlong.has_failed(), "overlong UTF-8 fails the parser")
	var surrogate := Parser.new()
	var surrogate_bytes := "data: ".to_utf8_buffer()
	surrogate_bytes.append(0xED)
	surrogate_bytes.append(0xA0)
	surrogate_bytes.append(0x80)
	surrogate_bytes.append(0x0A)
	surrogate_bytes.append(0x0A)
	surrogate.feed_bytes(surrogate_bytes)
	check.call(surrogate.has_failed(), "UTF-8 surrogate fails the parser")
	var truncated := Parser.new()
	var truncated_bytes := "data: ".to_utf8_buffer()
	truncated_bytes.append(0xE4)
	truncated_bytes.append(0xB8)
	truncated_bytes.append(0x0A)
	truncated_bytes.append(0x0A)
	truncated.feed_bytes(truncated_bytes)
	check.call(truncated.has_failed(), "truncated multi-byte character fails the parser")
	var valid := Parser.new()
	var valid_bytes := "data: 中文".to_utf8_buffer()
	valid_bytes.append(0x0A)
	valid_bytes.append(0x0A)
	var valid_events := valid.feed_bytes(valid_bytes)
	check.call(valid_events.size() == 1 and not valid.has_failed(),
		"valid multi-byte utf-8 still parses")

func _caps(check: Callable) -> void:
	var long_line := Parser.new()
	var oversized := PackedByteArray()
	oversized.resize(Parser.MAX_LINE_BYTES + 1)
	oversized.fill(120)
	var events := long_line.feed_bytes(oversized)
	check.call(events.is_empty() and long_line.has_failed() and not long_line.finish().clean,
		"oversized line fails the parser")
	var long_event := Parser.new()
	var block := "data: " + "y".repeat(60000) + "\n"
	for _index: int in 5:
		long_event.feed_bytes(block.to_utf8_buffer())
	check.call(long_event.has_failed(), "oversized event fails the parser")

func _finish_states(check: Callable) -> void:
	var clean := Parser.new()
	clean.feed_bytes("data: [DONE]\n\n".to_utf8_buffer())
	check.call(clean.finish().clean, "clean finish after complete event")
	var pending_line := Parser.new()
	pending_line.feed_bytes("data: abc".to_utf8_buffer())
	check.call(not pending_line.finish().clean and pending_line.finish().pending_bytes == 9,
		"pending partial line is not clean")
	var pending_event := Parser.new()
	pending_event.feed_bytes("data: abc\n".to_utf8_buffer())
	check.call(not pending_event.finish().clean and pending_event.finish().pending_event,
		"pending un-dispatched event is not clean")
	var truncated := Parser.new()
	truncated.feed_bytes(Fixture.load_bytes(TRUNCATED))
	check.call(not truncated.finish().clean, "truncated fixture has no clean boundary")
	var heartbeat := Parser.new()
	heartbeat.feed_bytes(Fixture.load_bytes(HEARTBEAT))
	check.call(heartbeat.finish().clean, "heartbeat-only fixture is clean but eventless")
