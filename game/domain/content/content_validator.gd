extends RefCounted
## Structural validation precedes semantic checks. Errors contain IDs, never raw content.
const Schema = preload("res://shared/schema_validator.gd")
const Result = preload("res://shared/result.gd")

static func validate(pack: Variant, schema: Dictionary) -> RefCounted:
	var issues := Schema.validate(pack, schema)
	if not issues.is_empty():
		return Result.failure("CONTENT_INVALID", issues)
	var ids: Dictionary = {}
	for definition: Dictionary in pack.definitions:
		if ids.has(definition.id):
			issues.append("duplicate_id:" + definition.id)
		ids[definition.id] = true
		if not pack.localization.has(definition.text_key):
			issues.append("missing_localization:" + definition.id)
	for definition: Dictionary in pack.definitions:
		for reference: String in definition.references:
			if not ids.has(reference):
				issues.append("missing_reference:" + definition.id + ":" + reference)
		for condition: Dictionary in definition.conditions:
			if not pack.flags.has(condition.flag):
				issues.append("unknown_flag:" + definition.id + ":" + condition.flag)
	if not issues.is_empty():
		return Result.failure("CONTENT_INVALID", issues)
	return Result.success(pack.duplicate(true))
