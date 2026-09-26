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
