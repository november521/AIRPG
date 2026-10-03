extends RefCounted
const Rules = preload("res://domain/character/creation_rules.gd")
const Result = preload("res://shared/result.gd")
var _state: Dictionary = Rules.initial()

func snapshot() -> Dictionary:
	return _state.duplicate(true)

func commit(expected_revision: int, candidate: Dictionary) -> RefCounted:
	if expected_revision != _state.revision:
		return Result.failure("STALE_STATE")
	if _state.locked:
		return Result.failure("ALREADY_CONFIRMED")
	if candidate.get("revision") != expected_revision:
		return Result.failure("INVALID_VALUE")
	var validation := Rules.validate(candidate)
	if not validation.ok:
		return validation
	if candidate == _state:
		return Result.failure("NO_CHANGE")
	var next: Dictionary = candidate.duplicate(true)
	next.revision += 1
	_state = next
	return Result.success(snapshot())
