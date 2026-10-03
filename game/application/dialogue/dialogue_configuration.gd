extends RefCounted
## Construction validation extracted from DialogueUseCase to keep orchestration bounded.

const Result = preload("res://shared/result.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")

const CODE_INVALID: String = "DIALOGUE_CONFIG_INVALID"
const REQUIRED: Array[String] = ["session_id", "state_store", "provider", "context_source",
	"facts", "action_catalog", "speakers"]
const OPTIONAL: Array[String] = ["action_sink", "reply_policies"]

static func validate(config: Variant) -> RefCounted:
	if not config is Dictionary or config.size() < REQUIRED.size() \
			or config.size() > REQUIRED.size() + OPTIONAL.size():
		return Result.failure(CODE_INVALID)
	for key: String in REQUIRED:
		if not config.has(key):
			return Result.failure(CODE_INVALID)
	for key: Variant in config:
		if not key is String or (key not in REQUIRED and key not in OPTIONAL):
			return Result.failure(CODE_INVALID)
	if not config.session_id is String or not Ids.is_valid_id(config.session_id):
		return Result.failure(CODE_INVALID)
	if not config.state_store is Object or not config.state_store.has_method("snapshot"):
		return Result.failure(CODE_INVALID)
	if not config.provider is Object or not config.provider.has_signal("completed") \
			or not config.provider.has_signal("failed") or not config.provider.has_method("start") \
			or not config.provider.has_method("cancel"):
		return Result.failure(CODE_INVALID)
	if not config.context_source is Object or not config.context_source.has_method("gather"):
		return Result.failure(CODE_INVALID)
	if not config.action_catalog is Object or not config.action_catalog.has_method("validate") \
			or not config.action_catalog.has_method("describe"):
		return Result.failure(CODE_INVALID)
	if config.has("action_sink") and (not config.action_sink is Object \
			or not config.action_sink.has_method("accept")):
		return Result.failure(CODE_INVALID)
	if config.has("reply_policies"):
		var policies := _policies(config.reply_policies)
		if not policies.ok:
			return policies
	return _speakers(config.speakers)

## Reviewed per-character output policies, keyed by speaker. Each entry is the card's policy
## dictionary; the reply policy module interprets it, this only checks the envelope.
static func _policies(value: Variant) -> RefCounted:
	if not value is Dictionary or value.size() > 64:
		return Result.failure(CODE_INVALID)
	for speaker: Variant in value:
		if not speaker is String or not Ids.is_valid_id(speaker) or not value[speaker] is Dictionary:
			return Result.failure(CODE_INVALID)
	return Result.success(value)

static func _speakers(value: Variant) -> RefCounted:
	if not value is Dictionary or value.is_empty() or value.size() > 64:
		return Result.failure(CODE_INVALID)
	var copied: Dictionary = {}
	for speaker_id: Variant in value:
		if not speaker_id is String or not Ids.is_valid_id(speaker_id):
			return Result.failure(CODE_INVALID)
		var profile: Variant = value[speaker_id]
		if not profile is Dictionary or profile.size() != 2 or not profile.has("name_key") \
				or not profile.has("portrait_id"):
			return Result.failure(CODE_INVALID)
		if not profile.name_key is String or not Ids.is_valid_id(profile.name_key):
			return Result.failure(CODE_INVALID)
		if not profile.portrait_id is String or (not profile.portrait_id.is_empty() \
				and not Ids.is_valid_id(profile.portrait_id)):
			return Result.failure(CODE_INVALID)
		copied[speaker_id] = {"name_key": profile.name_key, "portrait_id": profile.portrait_id}
	return Result.success(copied)
