extends RefCounted
## Local on/off state for a world device. Same shape as DoorState: one stable
## revision per accepted change and no gameplay effect beyond the device itself.
const Result = preload("res://shared/result.gd")
var _running: bool
var _revision: int = 0

func _init(initially_running: bool = false) -> void:
	_running = initially_running

func snapshot() -> Dictionary:
	return {"running": _running, "revision": _revision}

func toggle(expected_revision: int) -> Result:
	if expected_revision != _revision:
		return Result.failure("STALE_STATE")
	_running = not _running
	_revision += 1
	return Result.success(snapshot())
