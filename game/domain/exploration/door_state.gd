extends RefCounted
const Result = preload("res://shared/result.gd")
var _open: bool
var _revision: int = 0

func _init(initially_open: bool = false) -> void:
	_open = initially_open

func snapshot() -> Dictionary:
	return {"open": _open, "revision": _revision}

func toggle(expected_revision: int) -> Result:
	if expected_revision != _revision:
		return Result.failure("STALE_STATE")
	_open = not _open
	_revision += 1
	return Result.success(snapshot())
