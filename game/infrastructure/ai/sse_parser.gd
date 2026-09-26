extends RefCounted
## Incremental SSE parser. Pure buffer logic: no network, no logging, no vendor knowledge.
## Only complete lines are decoded, so multi-byte UTF-8 sequences split across transport
## chunks reassemble before decoding and are never replaced with U+FFFD.
## Each line is validated strictly: invalid UTF-8, NUL bytes, oversized lines/events fail
## the parser instead of silently continuing with replacement characters.
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
		var raw := _buffer.slice(_scan_from, newline_index)
		_scan_from = newline_index + 1
		if raw.find(0) >= 0 or not _is_valid_utf8(raw):
			_failed = true
			break
		var line := raw.get_string_from_utf8()
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
			_last_id = value
		_:
			pass
	return {}

## Strict byte-level UTF-8 validation (no engine decode, so invalid input never produces
## replacement characters or engine warnings). Rejects overlong forms, surrogates and >U+10FFFF.
static func _is_valid_utf8(bytes: PackedByteArray) -> bool:
	var index := 0
	while index < bytes.size():
		var first := bytes[index]
		if first < 0x80:
			index += 1
			continue
		var length := 0
		var code := 0
		if (first & 0xE0) == 0xC0:
			length = 2
			code = first & 0x1F
		elif (first & 0xF0) == 0xE0:
			length = 3
			code = first & 0x0F
		elif (first & 0xF8) == 0xF0:
			length = 4
			code = first & 0x07
		else:
			return false
		if index + length > bytes.size():
			return false
		for offset: int in range(1, length):
			var continuation: int = bytes[index + offset]
			if (continuation & 0xC0) != 0x80:
				return false
			code = (code << 6) | (continuation & 0x3F)
		if code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF):
			return false
		if length == 2 and code < 0x80:
			return false
		if length == 3 and code < 0x800:
			return false
		if length == 4 and code < 0x10000:
			return false
		index += length
	return true

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
