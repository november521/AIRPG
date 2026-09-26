extends RefCounted
## Presentation contract. Only verified replies may be created as player-visible messages.

const Result = preload("res://shared/result.gd")
const TransportContract = preload("res://application/contracts/model_transport_contract.gd")

const SCHEMA_VERSION: int = 1
const STATUS_IDLE: String = "idle"
const STATUS_WAITING: String = "waiting"
const STATUS_PRESENTING: String = "presenting"
const STATUS_FAILED: String = "failed"
const STATUS_CANCELLED: String = "cancelled"
const MAX_OPTIONS: int = 6
const MAX_OPTION_TEXT_LENGTH: int = 500
const _STATUSES: Array[String] = [STATUS_IDLE, STATUS_WAITING, STATUS_PRESENTING,
	STATUS_FAILED, STATUS_CANCELLED]

static func status(request_id: String, value: String, error_code: String = "",
		retryable: bool = false) -> RefCounted:
	if not _valid_request_id(request_id) or value not in _STATUSES:
		return Result.failure("DIALOGUE_VIEW_INVALID_STATUS")
	if value == STATUS_FAILED and not TransportContract.is_stable_error(error_code):
		return Result.failure("DIALOGUE_VIEW_INVALID_STATUS")
	if value != STATUS_FAILED and (not error_code.is_empty() or retryable):
		return Result.failure("DIALOGUE_VIEW_INVALID_STATUS")
	return Result.success({"schema_version": SCHEMA_VERSION, "kind": "status",
		"request_id": request_id, "status": value, "error_code": error_code,
		"retryable": retryable})

static func verified_reply(request_id: String, speaker_id: String, name_key: String,
		portrait_id: String, text: String, options: Array) -> RefCounted:
	if not _valid_request_id(request_id) or not _valid_id(speaker_id):
		return Result.failure("DIALOGUE_VIEW_INVALID_REPLY")
	if not _valid_id(name_key) or (not portrait_id.is_empty() and not _valid_id(portrait_id)):
		return Result.failure("DIALOGUE_VIEW_INVALID_REPLY")
	if text.strip_edges().is_empty() or text.length() > 12000:
		return Result.failure("DIALOGUE_VIEW_INVALID_REPLY")
	if options.size() > MAX_OPTIONS:
		return Result.failure("DIALOGUE_VIEW_INVALID_REPLY")
	var copied_options: Array[Dictionary] = []
	var option_ids: Dictionary = {}
	for item: Variant in options:
		if not item is Dictionary or item.keys().any(func(key: Variant) -> bool:
			return key not in ["option_id", "text"]):
			return Result.failure("DIALOGUE_VIEW_INVALID_REPLY")
		if not item.has("option_id") or not item.has("text"):
			return Result.failure("DIALOGUE_VIEW_INVALID_REPLY")
		if not item.option_id is String or not item.text is String:
			return Result.failure("DIALOGUE_VIEW_INVALID_REPLY")
		if not _valid_id(item.option_id) or item.text.strip_edges().is_empty():
			return Result.failure("DIALOGUE_VIEW_INVALID_REPLY")
		if option_ids.has(item.option_id):
			return Result.failure("DIALOGUE_VIEW_INVALID_REPLY")
		if item.text.length() > MAX_OPTION_TEXT_LENGTH:
			return Result.failure("DIALOGUE_VIEW_INVALID_REPLY")
		option_ids[item.option_id] = true
		copied_options.append(item.duplicate(true))
	return Result.success({"schema_version": SCHEMA_VERSION, "kind": "verified_reply",
		"request_id": request_id, "speaker_id": speaker_id, "name_key": name_key,
		"portrait_id": portrait_id, "text": text, "options": copied_options})

static func player_text(request_id: String, text: String) -> RefCounted:
	if not _valid_request_id(request_id) or text.strip_edges().is_empty() or text.length() > 4000:
		return Result.failure("DIALOGUE_INPUT_INVALID")
	return Result.success({"schema_version": SCHEMA_VERSION, "kind": "player_text",
		"request_id": request_id, "text": text})

static func option_selection(request_id: String, option_id: String) -> RefCounted:
	if not _valid_request_id(request_id) or not _valid_id(option_id):
		return Result.failure("DIALOGUE_INPUT_INVALID")
	return Result.success({"schema_version": SCHEMA_VERSION, "kind": "option_selection",
		"request_id": request_id, "option_id": option_id})

static func validate_view_event(value: Variant) -> RefCounted:
	if not value is Dictionary or not value.has("schema_version") or value.schema_version != SCHEMA_VERSION:
		return Result.failure("DIALOGUE_VIEW_INVALID_EVENT")
	if not value.has("kind") or not value.kind is String:
		return Result.failure("DIALOGUE_VIEW_INVALID_EVENT")
	if value.kind == "status":
		if not _exact_keys(value, ["schema_version", "kind", "request_id", "status",
				"error_code", "retryable"]):
			return Result.failure("DIALOGUE_VIEW_INVALID_EVENT")
		if not value.request_id is String or not value.status is String:
			return Result.failure("DIALOGUE_VIEW_INVALID_EVENT")
		if not value.error_code is String or not value.retryable is bool:
			return Result.failure("DIALOGUE_VIEW_INVALID_EVENT")
		return status(value.request_id, value.status, value.error_code, value.retryable)
	if value.kind == "verified_reply":
		if not _exact_keys(value, ["schema_version", "kind", "request_id", "speaker_id",
				"name_key", "portrait_id", "text", "options"]):
			return Result.failure("DIALOGUE_VIEW_INVALID_EVENT")
		for key: String in ["request_id", "speaker_id", "name_key", "portrait_id", "text"]:
			if not value[key] is String:
				return Result.failure("DIALOGUE_VIEW_INVALID_EVENT")
		if not value.options is Array:
			return Result.failure("DIALOGUE_VIEW_INVALID_EVENT")
		return verified_reply(value.request_id, value.speaker_id, value.name_key,
			value.portrait_id, value.text, value.options)
	return Result.failure("DIALOGUE_VIEW_INVALID_EVENT")

static func _valid_request_id(value: String) -> bool:
	return not value.is_empty() and value.length() <= 128

static func _valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	var expression := RegEx.new()
	if expression.compile("^[a-z][a-z0-9_.]*$") != OK:
		return false
	return expression.search(value) != null

static func _exact_keys(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true
