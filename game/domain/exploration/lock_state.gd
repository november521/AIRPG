extends RefCounted
## Local locked/unlocked state for a fixed container the player opens with a carried tool. Same
## shape as DeviceState: one stable revision per accepted change and no gameplay effect beyond the
## container itself -- no key is consumed and no story flag is written.
##
## It is deliberately not a toggle: a container that has been opened stays open, so a second press
## can never lock the player out of what is inside it. Refusing to open changes nothing here; the
## refusal is a refusal, not a state.
const Result = preload("res://shared/result.gd")
var _locked: bool
var _revision: int = 0

func _init(initially_locked: bool = true) -> void:
	_locked = initially_locked

func snapshot() -> Dictionary:
	return {"locked": _locked, "revision": _revision}

func accepts(expected_revision: int) -> bool:
	return expected_revision == _revision

func unlock(expected_revision: int) -> Result:
	if not accepts(expected_revision):
		return Result.failure("STALE_STATE")
	if not _locked:
		return Result.failure("ALREADY_UNLOCKED")
	_locked = false
	_revision += 1
	return Result.success(snapshot())
