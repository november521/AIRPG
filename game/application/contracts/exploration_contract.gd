extends RefCounted
## Stable UI-to-application commands for the greybox exploration package.
## These DTOs carry intent only. They never calculate checks or mutate story state.

const Result = preload("res://shared/result.gd")

const SCHEMA_VERSION: int = 1
const ACTION_MOVE: String = "move"
const ACTION_INTERACT: String = "interact"
const ACTION_INVESTIGATE: String = "investigate"

static func move(axis: Vector2) -> RefCounted:
	if not axis.is_finite() or axis.length() > 1.001:
		return Result.failure("EXPLORATION_INVALID_MOVE")
	return Result.success({"schema_version": SCHEMA_VERSION, "kind": ACTION_MOVE, "axis": axis})

static func interact(target_id: String) -> RefCounted:
	if not _valid_id(target_id):
		return Result.failure("EXPLORATION_INVALID_TARGET")
	return Result.success({"schema_version": SCHEMA_VERSION, "kind": ACTION_INTERACT,
		"target_id": target_id})

static func investigate() -> RefCounted:
	return Result.success({"schema_version": SCHEMA_VERSION, "kind": ACTION_INVESTIGATE})

static func candidate(target_id: String, prompt_key: String, distance: float) -> RefCounted:
	if not _valid_id(target_id) or not _valid_id(prompt_key):
		return Result.failure("EXPLORATION_INVALID_CANDIDATE")
	if not is_finite(distance) or distance < 0.0:
		return Result.failure("EXPLORATION_INVALID_CANDIDATE")
	return Result.success({"schema_version": SCHEMA_VERSION, "target_id": target_id,
		"prompt_key": prompt_key, "distance": distance})

static func _valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	var expression := RegEx.new()
	if expression.compile("^[a-z][a-z0-9_.]*$") != OK:
		return false
	return expression.search(value) != null
