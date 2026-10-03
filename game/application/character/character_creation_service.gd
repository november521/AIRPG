extends RefCounted
const Rules = preload("res://domain/character/creation_rules.gd")
const State = preload("res://domain/character/creation_state.gd")
const Result = preload("res://shared/result.gd")
signal changed()
var _state := State.new()

func read_rules() -> Dictionary:
	return {"attribute_ids": Rules.ATTRIBUTE_IDS.duplicate(), "skill_ids": Rules.SKILL_IDS.duplicate(),
		"text_ids": Rules.TEXT_IDS.duplicate(), "attribute_min": Rules.ATTRIBUTE_MIN,
		"attribute_max": Rules.ATTRIBUTE_MAX, "skill_min": Rules.SKILL_MIN,
		"skill_max": Rules.SKILL_MAX}

func read_creation() -> Dictionary:
	var view: Dictionary = _state.snapshot()
	view["remaining"] = Rules.remaining(view)
	return view

func set_value(field_id: String, value: int, expected_revision: int) -> RefCounted:
	var candidate: Dictionary = _state.snapshot()
	if expected_revision != candidate.revision:
		return Result.failure("STALE_STATE")
	if candidate.locked:
		return Result.failure("ALREADY_CONFIRMED")
	if Rules.ATTRIBUTE_IDS.has(field_id):
		candidate.attributes[field_id] = value
	elif Rules.SKILL_IDS.has(field_id):
		candidate.skills[field_id] = value
	else:
		return Result.failure("UNKNOWN_FIELD")
	return _submit(expected_revision, candidate)

func allocate(field_id: String, delta: int, expected_revision: int) -> RefCounted:
	var view: Dictionary = _state.snapshot()
	if expected_revision != view.revision:
		return Result.failure("STALE_STATE")
	if view.locked:
		return Result.failure("ALREADY_CONFIRMED")
	if Rules.ATTRIBUTE_IDS.has(field_id):
		return set_value(field_id, view.attributes[field_id] + delta, expected_revision)
	if Rules.SKILL_IDS.has(field_id):
		return set_value(field_id, view.skills[field_id] + delta, expected_revision)
	return Result.failure("UNKNOWN_FIELD")

func set_text(field_id: String, value: String, expected_revision: int) -> RefCounted:
	var candidate: Dictionary = _state.snapshot()
	if expected_revision != candidate.revision:
		return Result.failure("STALE_STATE")
	if candidate.locked:
		return Result.failure("ALREADY_CONFIRMED")
	if not Rules.TEXT_IDS.has(field_id):
		return Result.failure("UNKNOWN_FIELD")
	candidate[field_id] = value.strip_edges()
	return _submit(expected_revision, candidate)

func reset(expected_revision: int) -> RefCounted:
	var candidate: Dictionary = Rules.initial()
	candidate.revision = expected_revision
	return _submit(expected_revision, candidate)

func confirm(expected_revision: int) -> RefCounted:
	var candidate: Dictionary = _state.snapshot()
	if expected_revision != candidate.revision:
		return Result.failure("STALE_STATE")
	if candidate.locked:
		return Result.failure("ALREADY_CONFIRMED")
	if candidate.name.is_empty() or candidate.role.is_empty():
		return Result.failure("REQUIRED_FIELD")
	var remaining: Dictionary = Rules.remaining(candidate)
	if remaining.attributes != 0 or remaining.skills != 0:
		return Result.failure("UNSPENT_POINTS")
	candidate.locked = true
	return _submit(expected_revision, candidate)

func _submit(expected_revision: int, candidate: Dictionary) -> RefCounted:
	var result: RefCounted = _state.commit(expected_revision, candidate)
	if result.ok:
		changed.emit()
	return result
