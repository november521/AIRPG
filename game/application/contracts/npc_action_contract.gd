extends RefCounted
## Strict, coordinate-free NPC action proposal. Only replies sealed by F1 may create one.

const Result = preload("res://shared/result.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")

const SCHEMA_VERSION: int = 1
const KEYS: Array[String] = ["schema_version", "session_id", "request_id",
	"expected_revision", "speaker_id", "scene_id", "command_id", "parameters"]

static func proposal(session_id: String, request_id: String, expected_revision: int,
		speaker_id: String, scene_id: String, action: Variant) -> RefCounted:
	if not Ids.is_valid_id(session_id) or not Ids.is_valid_request_id(request_id) \
			or expected_revision < 0 or not Ids.is_valid_id(speaker_id) \
			or not Ids.is_valid_id(scene_id):
		return Result.failure("NPC_ACTION_INVALID")
	if not action is Dictionary or action.size() != 2 or not action.has("command_id") \
			or not action.has("parameters"):
		return Result.failure("NPC_ACTION_INVALID")
	if not action.command_id is String or not Ids.is_valid_id(action.command_id) \
			or not action.parameters is Dictionary:
		return Result.failure("NPC_ACTION_INVALID")
	return Result.success({"schema_version": SCHEMA_VERSION, "session_id": session_id,
		"request_id": request_id, "expected_revision": expected_revision,
		"speaker_id": speaker_id, "scene_id": scene_id, "command_id": action.command_id,
		"parameters": action.parameters.duplicate(true)})

static func validate(value: Variant) -> RefCounted:
	if not value is Dictionary or value.size() != KEYS.size():
		return Result.failure("NPC_ACTION_INVALID")
	for key: String in KEYS:
		if not value.has(key):
			return Result.failure("NPC_ACTION_INVALID")
	for key: Variant in value:
		if not key is String or key not in KEYS:
			return Result.failure("NPC_ACTION_INVALID")
	if not value.schema_version is int or value.schema_version != SCHEMA_VERSION \
			or not value.session_id is String or not value.request_id is String \
			or not value.expected_revision is int or not value.speaker_id is String \
			or not value.scene_id is String or not value.command_id is String \
			or not value.parameters is Dictionary:
		return Result.failure("NPC_ACTION_INVALID")
	return proposal(value.session_id, value.request_id, value.expected_revision,
		value.speaker_id, value.scene_id,
		{"command_id": value.command_id, "parameters": value.parameters})
