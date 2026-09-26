extends RefCounted
## Catalog helpers over validated synthetic facts. Every return value is a deep copy;
## callers can never reach the caller-owned arrays through this module.

const Result = preload("res://shared/result.gd")
const Fact = preload("res://domain/dialogue/knowledge_fact.gd")

static func validate_all(facts: Variant) -> RefCounted:
	if not facts is Array or facts.size() > Fact.MAX_FACTS:
		return Result.failure("KNOWLEDGE_FACTS_INVALID")
	var copied: Array[Dictionary] = []
	var seen: Dictionary = {}
	for item: Variant in facts:
		var validated := Fact.validate(item)
		if not validated.ok:
			return validated
		var fact: Dictionary = validated.value
		if seen.has(fact.fact_id):
			return Result.failure("KNOWLEDGE_FACTS_DUPLICATE", [fact.fact_id])
		seen[fact.fact_id] = true
		copied.append(fact)
	return Result.success(copied)

static func trusted(facts: Array, speaker_id: String, scene_id: String, topic_id: String,
		flags: Dictionary) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for fact: Dictionary in facts:
		if not Fact.is_authoritative(fact):
			continue
		if not Fact.allows_speaker(fact, speaker_id):
			continue
		if not Fact.allows_scene(fact, scene_id):
			continue
		if not Fact.allows_topic(fact, topic_id):
			continue
		if not Fact.disclosure_allowed(fact, flags):
			continue
		available.append(_view(fact))
	return available

static func untrusted(facts: Array) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for fact: Dictionary in facts:
		if Fact.is_authoritative(fact):
			continue
		available.append(_view(fact))
	return available

static func known_ids(facts: Array) -> Array[String]:
	var ids: Array[String] = []
	for fact: Dictionary in facts:
		ids.append(fact.fact_id)
	return ids

static func _view(fact: Dictionary) -> Dictionary:
	return {"fact_id": fact.fact_id, "text_key": fact.text_key, "source": fact.source}
