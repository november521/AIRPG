extends RefCounted
## Synthetic knowledge fact DTO for F1. This module defines the fact boundary only;
## real story facts must come from reviewed content data, never from this file.
##
## Access rules:
## - speaker_ids explicitly grants NPCs; public_on_scene grants every speaker present
##   in the listed scenes.
## - scene_ids/topic_ids restrict where a fact may be used; empty means unrestricted.
## - disclosure_conditions are boolean flag conjunctions evaluated through the story
##   Conditions contract. A fact whose condition is not met must not reach the model.

const Result = preload("res://shared/result.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")
const Conditions = preload("res://domain/story/conditions.gd")

const SCHEMA_VERSION: int = 1
const SOURCE_AUTHORITATIVE: String = "authoritative"
const SOURCE_PLAYER_STATEMENT: String = "player_statement"
const SOURCE_RUMOR: String = "rumor"
const SOURCES: Array[String] = [SOURCE_AUTHORITATIVE, SOURCE_PLAYER_STATEMENT, SOURCE_RUMOR]
const KEYS: Array[String] = ["schema_version", "fact_id", "text_key", "source", "speaker_ids",
	"public_on_scene", "scene_ids", "topic_ids", "disclosure_conditions"]
const MAX_FACTS: int = 256
const MAX_IDS: int = 32
const MAX_CONDITIONS: int = 8

static func validate(data: Variant) -> RefCounted:
	if not data is Dictionary or data.size() != KEYS.size():
		return Result.failure("KNOWLEDGE_FACT_INVALID")
	for key: String in KEYS:
		if not data.has(key):
			return Result.failure("KNOWLEDGE_FACT_INVALID")
	for key: Variant in data:
		if not key is String or key not in KEYS:
			return Result.failure("KNOWLEDGE_FACT_INVALID")
	if data.schema_version != SCHEMA_VERSION:
		return Result.failure("KNOWLEDGE_FACT_VERSION")
	if not data.fact_id is String or not Ids.is_valid_id(data.fact_id):
		return Result.failure("KNOWLEDGE_FACT_INVALID")
	if not data.text_key is String or not Ids.is_valid_id(data.text_key):
		return Result.failure("KNOWLEDGE_FACT_INVALID")
	if not data.source is String or data.source not in SOURCES:
		return Result.failure("KNOWLEDGE_FACT_INVALID")
	if not data.public_on_scene is bool:
		return Result.failure("KNOWLEDGE_FACT_INVALID")
	var speaker_ids := _valid_ids(data.speaker_ids)
	if not speaker_ids.ok:
		return speaker_ids
	var scene_ids := _valid_ids(data.scene_ids)
	if not scene_ids.ok:
		return scene_ids
	var topic_ids := _valid_ids(data.topic_ids)
	if not topic_ids.ok:
		return topic_ids
	var conditions := _valid_conditions(data.disclosure_conditions)
	if not conditions.ok:
		return conditions
	if speaker_ids.value.is_empty() and not data.public_on_scene:
		return Result.failure("KNOWLEDGE_FACT_INVALID")
	if data.public_on_scene and scene_ids.value.is_empty():
		return Result.failure("KNOWLEDGE_FACT_INVALID")
	return Result.success({"schema_version": SCHEMA_VERSION, "fact_id": data.fact_id,
		"text_key": data.text_key, "source": data.source, "speaker_ids": speaker_ids.value,
		"public_on_scene": data.public_on_scene, "scene_ids": scene_ids.value,
		"topic_ids": topic_ids.value, "disclosure_conditions": conditions.value})

static func is_authoritative(fact: Dictionary) -> bool:
	return fact.source == SOURCE_AUTHORITATIVE

static func allows_speaker(fact: Dictionary, speaker_id: String) -> bool:
	return fact.speaker_ids.has(speaker_id) or fact.public_on_scene

static func allows_scene(fact: Dictionary, scene_id: String) -> bool:
	return fact.scene_ids.is_empty() or fact.scene_ids.has(scene_id)

static func allows_topic(fact: Dictionary, topic_id: String) -> bool:
	return fact.topic_ids.is_empty() or fact.topic_ids.has(topic_id)

static func disclosure_allowed(fact: Dictionary, flags: Dictionary) -> bool:
	return Conditions.matches(fact.disclosure_conditions, flags)

static func _valid_ids(value: Variant) -> RefCounted:
	if not value is Array or value.size() > MAX_IDS:
		return Result.failure("KNOWLEDGE_FACT_INVALID")
	var copied: Array[String] = []
	for item: Variant in value:
		if not item is String or not Ids.is_valid_id(item) or item in copied:
			return Result.failure("KNOWLEDGE_FACT_INVALID")
		copied.append(item)
	return Result.success(copied)

static func _valid_conditions(value: Variant) -> RefCounted:
	if not value is Array or value.size() > MAX_CONDITIONS:
		return Result.failure("KNOWLEDGE_FACT_INVALID")
	var copied: Array[Dictionary] = []
	var seen: Dictionary = {}
	for item: Variant in value:
		if not item is Dictionary or item.size() != 2 or not item.has("flag") or not item.has("equals"):
			return Result.failure("KNOWLEDGE_FACT_INVALID")
		if not item.flag is String or not Ids.is_valid_id(item.flag) or not item.equals is bool:
			return Result.failure("KNOWLEDGE_FACT_INVALID")
		if seen.has(item.flag):
			return Result.failure("KNOWLEDGE_FACT_INVALID")
		seen[item.flag] = true
		copied.append({"flag": item.flag, "equals": item.equals})
	return Result.success(copied)
