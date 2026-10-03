extends "res://application/exploration/interactions/interaction_handler.gd"
## Start/stop handler for a placed device. It commits the device's own state and
## nothing else: no power grid, no fuel, no check, no story flag.
const State = preload("res://domain/exploration/device_state.gd")
var _state: State
var _name_key: String

func _init(state: State, name_key: String) -> void:
	_state = state
	_name_key = name_key

func read() -> Dictionary:
	var view: Dictionary = _state.snapshot()
	view.merge({"available": true, "name_key": _name_key,
		"action_key": "interaction.device.stop" if view.running else "interaction.device.start"})
	return view

func execute(expected_revision: int) -> Outcome:
	var result: Outcome = _state.toggle(expected_revision)
	if result.ok:
		changed.emit()
	return result
