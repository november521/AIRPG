extends RefCounted
## Pre-declared action catalog for model replies. A reply may only propose commands from
## this catalog with parameters matching the declared schema. The catalog describes intent
## only; it cannot carry StateStore patches and this module never commits state.

const Result = preload("res://shared/result.gd")
const Schema = preload("res://shared/schema_validator.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")

const MAX_ACTIONS: int = 32

var _catalog: Dictionary = {}

static func create(entries: Variant) -> RefCounted:
	if not entries is Array or entries.is_empty() or entries.size() > MAX_ACTIONS:
		return Result.failure("ACTION_CATALOG_INVALID")
	var instance := new()
	for item: Variant in entries:
		if not item is Dictionary or item.size() != 2 or not item.has("command_id") \
				or not item.has("parameter_schema"):
			return Result.failure("ACTION_CATALOG_INVALID")
		if not item.command_id is String or not Ids.is_valid_id(item.command_id):
			return Result.failure("ACTION_CATALOG_INVALID")
		if not item.parameter_schema is Dictionary or _schema_unsupported(item.parameter_schema):
			return Result.failure("ACTION_CATALOG_INVALID", [item.command_id])
		if instance._catalog.has(item.command_id):
			return Result.failure("ACTION_CATALOG_DUPLICATE", [item.command_id])
		instance._catalog[item.command_id] = item.parameter_schema.duplicate(true)
	return Result.success(instance)

func has(command_id: String) -> bool:
	return _catalog.has(command_id)

func describe() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var command_ids: Array = _catalog.keys()
	command_ids.sort()
	for command_id: String in command_ids:
		entries.append({"command_id": command_id,
			"parameter_schema": _catalog[command_id].duplicate(true)})
	return entries

func validate(command_id: String, parameters: Variant) -> RefCounted:
	if not _catalog.has(command_id):
		return Result.failure("ACTION_NOT_ALLOWED", [command_id])
	var issues := Schema.validate(parameters, _catalog[command_id])
	if not issues.is_empty():
		return Result.failure("ACTION_PARAMETERS_INVALID", issues)
	return Result.success(parameters.duplicate(true) if parameters is Dictionary else parameters)

static func _schema_unsupported(schema: Dictionary) -> bool:
	# Reject catalogs whose schema uses keywords the runtime validator cannot enforce.
	for issue: String in Schema.validate({}, schema):
		if issue.contains("unsupported_schema_keyword") or issue.contains("schema_depth_limit"):
			return true
	return false
