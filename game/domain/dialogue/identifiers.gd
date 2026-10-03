extends RefCounted
## Stable identifier rules for F1 dialogue DTOs. Pure string checks; no I/O, no state.

static func is_valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	if not _is_lower_letter(value.unicode_at(0)):
		return false
	for index: int in range(1, value.length()):
		var code := value.unicode_at(index)
		if _is_lower_letter(code) or _is_digit(code) or code == 95 or code == 46:
			continue
		return false
	return true

static func is_valid_request_id(value: String) -> bool:
	return not value.is_empty() and value.length() <= 128

static func _is_lower_letter(code: int) -> bool:
	return code >= 97 and code <= 122

static func _is_digit(code: int) -> bool:
	return code >= 48 and code <= 57
