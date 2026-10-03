extends RefCounted
## Prototype point-buy rules. No check modifier is derived here.
const Result = preload("res://shared/result.gd")
const ATTRIBUTE_IDS: Array[String] = ["strength", "dexterity", "constitution", "intelligence", "perception", "charisma"]
const SKILL_IDS: Array[String] = ["awareness", "insight", "negotiation"]
const TEXT_IDS: Array[String] = ["name", "role", "background"]
const ATTRIBUTE_BASE := 50
const ATTRIBUTE_BUDGET := 60
const ATTRIBUTE_MIN := 30
const ATTRIBUTE_MAX := 80
const SKILL_BUDGET := 6
const SKILL_MIN := 0
const SKILL_MAX := 3

static func initial() -> Dictionary:
	var attributes := {}
	for id: String in ATTRIBUTE_IDS:
		attributes[id] = ATTRIBUTE_BASE
	var skills := {}
	for id: String in SKILL_IDS:
		skills[id] = 0
	return {"revision": 0, "locked": false, "name": "", "role": "", "background": "",
		"attributes": attributes, "skills": skills}

static func validate(value: Dictionary) -> RefCounted:
	if not _keys(value, ["revision", "locked", "name", "role", "background", "attributes", "skills"]):
		return Result.failure("INVALID_VALUE")
	if not value.revision is int or value.revision < 0 or not value.locked is bool:
		return Result.failure("INVALID_VALUE")
	for id: String in TEXT_IDS:
		if not value[id] is String or value[id].length() > 280:
			return Result.failure("INVALID_VALUE")
	if not value.attributes is Dictionary or not _keys(value.attributes, ATTRIBUTE_IDS):
		return Result.failure("UNKNOWN_FIELD")
	if not value.skills is Dictionary or not _keys(value.skills, SKILL_IDS):
		return Result.failure("UNKNOWN_FIELD")
	var attribute_cost := 0
	for id: String in ATTRIBUTE_IDS:
		var score: Variant = value.attributes[id]
		if not score is int:
			return Result.failure("INVALID_VALUE")
		if score < ATTRIBUTE_MIN:
			return Result.failure("ATTRIBUTE_BELOW_FLOOR")
		if score > ATTRIBUTE_MAX:
			return Result.failure("ATTRIBUTE_ABOVE_CAP")
		attribute_cost += score - ATTRIBUTE_BASE
	if attribute_cost > ATTRIBUTE_BUDGET:
		return Result.failure("POINT_BUDGET_EXCEEDED")
	var skill_cost := 0
	for id: String in SKILL_IDS:
		var score: Variant = value.skills[id]
		if not score is int or score < SKILL_MIN or score > SKILL_MAX:
			return Result.failure("INVALID_VALUE")
		skill_cost += score
	if skill_cost > SKILL_BUDGET:
		return Result.failure("SKILL_POINTS_EXCEEDED")
	return Result.success()

static func remaining(value: Dictionary) -> Dictionary:
	var attribute_cost := 0
	for id: String in ATTRIBUTE_IDS:
		attribute_cost += value.attributes[id] - ATTRIBUTE_BASE
	var skill_cost := 0
	for id: String in SKILL_IDS:
		skill_cost += value.skills[id]
	return {"attributes": ATTRIBUTE_BUDGET - attribute_cost, "skills": SKILL_BUDGET - skill_cost}

static func _keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true
