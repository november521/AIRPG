extends RefCounted
## Archive metadata only: not a playable content pack or an authorization to start it.
const Schema = preload("res://shared/schema_validator.gd")
const Result = preload("res://shared/result.gd")

static func validate(raw: Variant, schema: Dictionary, messages: Dictionary) -> RefCounted:
	var issues := Schema.validate(raw, schema)
	if not issues.is_empty():
		return Result.failure("STORY_CATALOG_INVALID", issues)
	var ids: Dictionary = {}
	for entry: Dictionary in raw.stories:
		if ids.has(entry.id) or entry.accent.size() != 3 or entry.tag_keys.is_empty():
			return Result.failure("STORY_CATALOG_INVALID")
		ids[entry.id] = true
		var keys: Array = [entry.title_key, entry.description_key] + entry.tag_keys
		for key: String in keys:
			if not messages.get(key) is String or messages[key].strip_edges().is_empty():
				return Result.failure("STORY_LOCALIZATION_MISSING")
	return Result.success(raw.stories.duplicate(true))
