extends RefCounted
## F1 request binding: one dialogue attempt tied to a session, speaker, scene, topic
## and the authoritative state revision it was built from. Pure value object.

const Result = preload("res://shared/result.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")

const SCHEMA_VERSION: int = 1
const KEYS: Array[String] = ["schema_version", "session_id", "request_id", "expected_revision",
	"speaker_id", "scene_id", "topic_id"]

static func create(session_id: String, request_id: String, expected_revision: int,
		speaker_id: String, scene_id: String, topic_id: String) -> RefCounted:
	if not Ids.is_valid_id(session_id) or not Ids.is_valid_request_id(request_id):
		return Result.failure("DIALOGUE_REQUEST_INVALID")
	if expected_revision < 0:
		return Result.failure("DIALOGUE_REQUEST_INVALID")
	if not Ids.is_valid_id(speaker_id) or not Ids.is_valid_id(scene_id) \
			or not Ids.is_valid_id(topic_id):
		return Result.failure("DIALOGUE_REQUEST_INVALID")
	return Result.success({"schema_version": SCHEMA_VERSION, "session_id": session_id,
		"request_id": request_id, "expected_revision": expected_revision,
		"speaker_id": speaker_id, "scene_id": scene_id, "topic_id": topic_id})

static func validate(data: Variant) -> RefCounted:
	if not data is Dictionary or data.size() != KEYS.size():
		return Result.failure("DIALOGUE_REQUEST_INVALID")
	for key: String in KEYS:
		if not data.has(key):
			return Result.failure("DIALOGUE_REQUEST_INVALID")
	for key: Variant in data:
		if not key is String or key not in KEYS:
			return Result.failure("DIALOGUE_REQUEST_INVALID")
	if data.schema_version != SCHEMA_VERSION:
		return Result.failure("DIALOGUE_REQUEST_INVALID")
	if not data.expected_revision is int:
		return Result.failure("DIALOGUE_REQUEST_INVALID")
	if not data.session_id is String or not data.request_id is String \
			or not data.speaker_id is String or not data.scene_id is String \
			or not data.topic_id is String:
		return Result.failure("DIALOGUE_REQUEST_INVALID")
	return create(data.session_id, data.request_id, data.expected_revision, data.speaker_id,
		data.scene_id, data.topic_id)
