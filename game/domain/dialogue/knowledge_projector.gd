extends RefCounted
## Pure domain projection: builds the isolated per-NPC context handed to the model.
## Authoritative facts are filtered by speaker, scene, topic and disclosure flags.
## Player text, notes, rumors and non-speaker dialogue only ever appear under the
## explicit `untrusted` field; the full content pack is never accepted or returned.

const Result = preload("res://shared/result.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")
const Fact = preload("res://domain/dialogue/knowledge_fact.gd")
const Facts = preload("res://domain/dialogue/knowledge_facts.gd")

const SCHEMA_VERSION: int = 1
const MAX_PERCEPTIBLE: int = 64
const MAX_DIALOGUE: int = 32
const MAX_MEMORIES: int = 32
const MAX_NOTES: int = 32
const MAX_RUMORS: int = 32
const MAX_TEXT_LENGTH: int = 4000
const MAX_MEMORY_LENGTH: int = 2000
const MEMORY_SOURCES: Array[String] = ["witnessed", "player_statement", "rumor", "inference"]
const REQUIRED_KEYS: Array[String] = ["speaker_id", "scene_id", "topic_id", "facts", "flags"]
const OPTIONAL_KEYS: Array[String] = ["perceptible", "recent_dialogue", "key_memories",
	"player_text", "player_notes", "rumors"]

static func project(context_input: Variant) -> RefCounted:
	if not context_input is Dictionary:
		return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	for key: Variant in context_input:
		if not key is String:
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
		if key not in REQUIRED_KEYS and key not in OPTIONAL_KEYS:
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	for key: String in REQUIRED_KEYS:
		if not context_input.has(key):
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	if not context_input.speaker_id is String or not Ids.is_valid_id(context_input.speaker_id):
		return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	if not context_input.scene_id is String or not Ids.is_valid_id(context_input.scene_id):
		return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	if not context_input.topic_id is String or not Ids.is_valid_id(context_input.topic_id):
		return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	if not _valid_flags(context_input.flags):
		return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	var catalog := Facts.validate_all(context_input.facts)
	if not catalog.ok:
		return catalog
	var perceptible := _valid_observations(context_input.get("perceptible", []))
	if not perceptible.ok:
		return perceptible
	var memories := _valid_memories(context_input.get("key_memories", []))
	if not memories.ok:
		return memories
	var dialogue := _valid_dialogue(context_input.get("recent_dialogue", []))
	if not dialogue.ok:
		return dialogue
	var notes := _valid_texts(context_input.get("player_notes", []), MAX_NOTES, MAX_MEMORY_LENGTH)
	if not notes.ok:
		return notes
	var rumors := _valid_texts(context_input.get("rumors", []), MAX_RUMORS, MAX_MEMORY_LENGTH)
	if not rumors.ok:
		return rumors
	if not context_input.get("player_text", "") is String or context_input.get("player_text", "").length() > MAX_TEXT_LENGTH:
		return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	var recent_dialogue: Array[Dictionary] = []
	var other_dialogue: Array[Dictionary] = []
	for entry: Dictionary in dialogue.value:
		var copy: Dictionary = {"speaker_id": entry.speaker_id, "text": entry.text}
		if entry.speaker_id == context_input.speaker_id:
			recent_dialogue.append(copy)
		else:
			other_dialogue.append(copy)
	var player_statements: Array[Dictionary] = []
	var rumor_facts: Array[Dictionary] = []
	for fact: Dictionary in Facts.untrusted(catalog.value):
		if fact.source == Fact.SOURCE_PLAYER_STATEMENT:
			player_statements.append(fact)
		else:
			rumor_facts.append(fact)
	return Result.success({"schema_version": SCHEMA_VERSION, "speaker_id": context_input.speaker_id,
		"scene_id": context_input.scene_id, "topic_id": context_input.topic_id,
		"trusted_facts": Facts.trusted(catalog.value, context_input.speaker_id, context_input.scene_id,
			context_input.topic_id, context_input.flags),
		"perceptible": perceptible.value, "recent_dialogue": recent_dialogue,
		"key_memories": memories.value,
		"untrusted": {"player_text": context_input.get("player_text", ""), "player_notes": notes.value,
			"rumors": rumors.value, "player_statements": player_statements,
			"rumor_facts": rumor_facts, "other_dialogue": other_dialogue}})

static func _valid_flags(flags: Variant) -> bool:
	if not flags is Dictionary or flags.size() > 128:
		return false
	for key: Variant in flags:
		if not key is String or not flags[key] is bool:
			return false
	return true

static func _valid_observations(value: Variant) -> RefCounted:
	if not value is Array or value.size() > MAX_PERCEPTIBLE:
		return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	var copied: Array[Dictionary] = []
	for item: Variant in value:
		if not item is Dictionary or item.size() != 2 or not item.has("observation_id") \
				or not item.has("text"):
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
		if not item.observation_id is String or not Ids.is_valid_id(item.observation_id):
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
		if not _valid_text(item.text):
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
		copied.append({"observation_id": item.observation_id, "text": item.text})
	return Result.success(copied)

static func _valid_memories(value: Variant) -> RefCounted:
	if not value is Array or value.size() > MAX_MEMORIES:
		return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	var copied: Array[Dictionary] = []
	for item: Variant in value:
		if not item is Dictionary or item.size() != 2 or not item.has("source") or not item.has("text"):
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
		if not item.source is String or item.source not in MEMORY_SOURCES:
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
		if not _valid_text(item.text):
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
		copied.append({"source": item.source, "text": item.text})
	return Result.success(copied)

static func _valid_dialogue(value: Variant) -> RefCounted:
	if not value is Array or value.size() > MAX_DIALOGUE:
		return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	var copied: Array[Dictionary] = []
	for item: Variant in value:
		if not item is Dictionary or item.size() != 2 or not item.has("speaker_id") \
				or not item.has("text"):
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
		if not item.speaker_id is String or not Ids.is_valid_id(item.speaker_id):
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
		if not _valid_text(item.text) or item.text.length() > MAX_TEXT_LENGTH:
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
		copied.append({"speaker_id": item.speaker_id, "text": item.text})
	return Result.success(copied)

static func _valid_texts(value: Variant, maximum: int, length: int) -> RefCounted:
	if not value is Array or value.size() > maximum:
		return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
	var copied: Array[String] = []
	for item: Variant in value:
		if not item is String or not _valid_text(item) or item.length() > length:
			return Result.failure("KNOWLEDGE_CONTEXT_INVALID")
		copied.append(item)
	return Result.success(copied)

static func _valid_text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= MAX_MEMORY_LENGTH
