extends "res://application/exploration/interactions/interaction_handler.gd"
const State = preload("res://domain/exploration/door_state.gd")
const Clearance = preload("res://application/ports/door_clearance.gd")
var _state: State
var _clearance: Clearance
var _name_key: String
var _open_yaw: float
var _open_yaw_provider: Callable
var _moving: bool = false

func _init(state: State, clearance: Clearance, name_key: String, open_yaw: float, open_yaw_provider: Callable = Callable()) -> void:
	_state = state
	_clearance = clearance
	_name_key = name_key
	_open_yaw = open_yaw
	_open_yaw_provider = open_yaw_provider

func read() -> Dictionary:
	var view: Dictionary = _state.snapshot()
	view.merge({"available": not _moving, "name_key": _name_key, "open_yaw": _open_yaw,
		"action_key": "interaction.close" if view.open else "interaction.open"})
	return view

func execute(expected_revision: int) -> Outcome:
	var before: Dictionary = _state.snapshot()
	if before.revision != expected_revision:
		return Outcome.failure("STALE_STATE")
	if _moving:
		return Outcome.failure("DOOR_MOVING")
	var target_open: bool = not before.open
	var target_yaw: float = _open_yaw
	if target_open and _open_yaw_provider.is_valid():
		var provided: Variant = _open_yaw_provider.call()
		if not provided is float and not provided is int:
			return Outcome.failure("INVALID_DOOR_POSE")
		target_yaw = provided
	if not _clearance.is_clear_pose(before.open, target_open, _open_yaw if before.open else target_yaw, target_yaw if target_open else 0.0):
		return Outcome.failure("DOOR_BLOCKED")
	var result: Outcome = _state.toggle(expected_revision)
	if result.ok:
		if target_open:
			_open_yaw = target_yaw
		_moving = true
		changed.emit()
	return result

func finish_motion() -> void:
	if _moving:
		_moving = false
		changed.emit()
