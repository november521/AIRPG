extends RefCounted
## Synthetic structured model reply DTO. Structural validation only; semantic checks
## (speaker identity, authorized facts, allowed actions) live in reply_validator.gd.
## Unknown fields, unknown versions and malformed values always fail closed.

const Result = preload("res://shared/result.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")

const SCHEMA_VERSION: int = 1
const KEYS: Array[String] = ["schema_version", "speaker_id", "reply_text", "used_fact_ids",
	"options", "actions"]
const MAX_TEXT_LENGTH: int = 12000
const MAX_FACT_IDS: int = 64
const MAX_OPTIONS: int = 6
const MAX_OPTION_TEXT_LENGTH: int = 500
const MAX_ACTIONS: int = 8

## Field-level issues are deliberately content-free: only our own schema key names, counts and
## group names are reported, so a rejection can be classified in the log without echoing the
## model's reply text.
static func validate(data: Variant) -> RefCounted:
	if not data is Dictionary:
		return Result.failure("REPLY_INVALID", ["not_object"])
	if data.size() != KEYS.size():
		return Result.failure("REPLY_INVALID", ["fields:" + str(data.size())])
	for key: String in KEYS:
		if not data.has(key):
			return Result.failure("REPLY_INVALID", ["missing:" + key])
	for key: Variant in data:
		if not key is String:
			return Result.failure("REPLY_INVALID", ["key_type"])
		if key not in KEYS:
			return Result.failure("REPLY_INVALID", ["unknown_field"])
	var version: Variant = _as_int(data.schema_version)
	if version == null or version != SCHEMA_VERSION:
		return Result.failure("REPLY_VERSION_UNSUPPORTED", ["schema_version"])
	if not data.speaker_id is String or not Ids.is_valid_id(data.speaker_id):
		return Result.failure("REPLY_INVALID", ["id:speaker_id"])
	if not data.reply_text is String or data.reply_text.strip_edges().is_empty() \
			or data.reply_text.length() > MAX_TEXT_LENGTH:
		return Result.failure("REPLY_INVALID", ["value:reply_text"])
	var fact_ids := _valid_fact_ids(data.used_fact_ids)
	if not fact_ids.ok:
		return fact_ids
	var options := _valid_options(data.options)
	if not options.ok:
		return options
	var actions := _valid_actions(data.actions)
	if not actions.ok:
		return actions
	return Result.success({"schema_version": SCHEMA_VERSION, "speaker_id": data.speaker_id,
		"reply_text": data.reply_text, "used_fact_ids": fact_ids.value,
		"options": options.value, "actions": actions.value})

static func _as_int(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	return null

static func parse(content: String) -> RefCounted:
	if content.is_empty() or content.length() > MAX_TEXT_LENGTH * 4:
		return Result.failure("REPLY_INVALID")
	var json := JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		return Result.failure("REPLY_INVALID")
	return validate(json.data)

static func _valid_fact_ids(value: Variant) -> RefCounted:
	if not value is Array or value.size() > MAX_FACT_IDS:
		return Result.failure("REPLY_INVALID", ["group:used_fact_ids"])
	var copied: Array[String] = []
	for item: Variant in value:
		if not item is String or not Ids.is_valid_id(item) or item in copied:
			return Result.failure("REPLY_INVALID")
		copied.append(item)
	return Result.success(copied)

static func _valid_options(value: Variant) -> RefCounted:
	if not value is Array or value.size() > MAX_OPTIONS:
		return Result.failure("REPLY_INVALID", ["group:options"])
	var copied: Array[Dictionary] = []
	var seen: Dictionary = {}
	for item: Variant in value:
		if not item is Dictionary or item.size() != 2 or not item.has("option_id") \
				or not item.has("text"):
			return Result.failure("REPLY_INVALID")
		if not item.option_id is String or not Ids.is_valid_id(item.option_id) \
				or not item.text is String or item.text.strip_edges().is_empty() \
				or item.text.length() > MAX_OPTION_TEXT_LENGTH:
			return Result.failure("REPLY_INVALID")
		if seen.has(item.option_id):
			return Result.failure("REPLY_DUPLICATE_OPTION", [item.option_id])
		seen[item.option_id] = true
		copied.append({"option_id": item.option_id, "text": item.text})
	return Result.success(copied)

static func _valid_actions(value: Variant) -> RefCounted:
	if not value is Array or value.size() > MAX_ACTIONS:
		return Result.failure("REPLY_INVALID", ["group:actions"])
	var copied: Array[Dictionary] = []
	var seen: Dictionary = {}
	for item: Variant in value:
		if not item is Dictionary or item.size() != 2 or not item.has("command_id") \
				or not item.has("parameters"):
			return Result.failure("REPLY_INVALID")
		if not item.command_id is String or not Ids.is_valid_id(item.command_id) \
				or not item.parameters is Dictionary:
			return Result.failure("REPLY_INVALID")
		if seen.has(item.command_id):
			return Result.failure("REPLY_DUPLICATE_ACTION", [item.command_id])
		seen[item.command_id] = true
		copied.append({"command_id": item.command_id, "parameters": item.parameters.duplicate(true)})
	return Result.success(copied)
