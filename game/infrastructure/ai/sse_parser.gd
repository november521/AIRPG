extends RefCounted
## Incremental SSE parser. Pure buffer logic: no network, no logging, no vendor knowledge.
## Only complete lines are decoded, so multi-byte UTF-8 sequences split across transport
## chunks reassemble before decoding and are never replaced with U+FFFD.
## Standard SSE behavior: CRLF/LF lines, comment/heartbeat lines (":" prefix), empty events,
## multi-line data joined with "\n", explicit event names, last-event-id, unknown fields ignored.

const MAX_LINE_BYTES: int = 65536
const MAX_EVENT_BYTES: int = 262144
const NEWLINE_BYTE: int = 10
const CARRIAGE_RETURN: String = "\r"

var _buffer: PackedByteArray = PackedByteArray()
var _scan_from: int = 0
var _data_lines: PackedStringArray = PackedStringArray()
var _data_bytes: int = 0
var _event_name: String = ""
var _last_id: String = ""
var _failed: bool = false

## Feeds raw bytes and returns the complete events decoded by this call.
## Each event is {"event": String, "data": String, "id": String}; no event is emitted
## for comments, heartbeats or empty data.
func feed_bytes(bytes: PackedByteArray) -> Array:
	var events: Array = []
	if _failed or bytes.is_empty():
		return events
	_buffer.append_array(bytes)
	while not _failed:
		var newline_index := _buffer.find(NEWLINE_BYTE, _scan_from)
		if newline_index < 0:
			if _buffer.size() - _scan_from > MAX_LINE_BYTES:
				_failed = true
			break
		if newline_index - _scan_from > MAX_LINE_BYTES:
			_failed = true
			break
		var line := _buffer.slice(_scan_from, newline_index).get_string_from_utf8()
		_scan_from = newline_index + 1
		if line.ends_with(CARRIAGE_RETURN):
			line = line.substr(0, line.length() - 1)
		var event := _consume_line(line)
		if not event.is_empty():
			events.append(event)
	_compact()
	return events

## True when the parser rejected the stream (for example a line or event over the cap).
func has_failed() -> bool:
	return _failed

## Reports whether the byte stream ended at a clean SSE boundary.
## "clean" requires no parser failure, no pending bytes and no pending data event.
func finish() -> Dictionary:
	return {
		"clean": not _failed and _scan_from >= _buffer.size() and _data_lines.is_empty(),
		"failed": _failed,
		"pending_bytes": _buffer.size() - _scan_from,
		"pending_event": not _data_lines.is_empty(),
	}

func _consume_line(line: String) -> Dictionary:
	if line.is_empty():
		return _dispatch()
	if line.begins_with(":"):
		return {}
	var colon := line.find(":")
	var field := line if colon < 0 else line.substr(0, colon)
	var value := "" if colon < 0 else line.substr(colon + 1)
	if value.begins_with(" "):
		value = value.substr(1)
	match field:
		"data":
			_data_lines.append(value)
			_data_bytes += value.length()
			if _data_bytes > MAX_EVENT_BYTES:
				_failed = true
		"event":
			_event_name = value
		"id":
			if not value.contains("\u0000"):
				_last_id = value
		_:
			pass
	return {}

func _dispatch() -> Dictionary:
	if _data_lines.is_empty():
		_event_name = ""
		return {}
	var event := {
		"event": "message" if _event_name.is_empty() else _event_name,
		"data": "\n".join(_data_lines),
		"id": _last_id,
	}
	_data_lines = PackedStringArray()
	_data_bytes = 0
	_event_name = ""
	return event

func _compact() -> void:
	if _scan_from <= 0:
		return
	if _scan_from >= _buffer.size():
		_buffer = PackedByteArray()
	else:
		_buffer = _buffer.slice(_scan_from)
	_scan_from = 0
