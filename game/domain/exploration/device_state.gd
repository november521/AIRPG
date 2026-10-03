extends RefCounted
## Local on/off state for a world device. Same shape as DoorState: one stable
## revision per accepted change and no gameplay effect beyond the device itself.
##
## A device may be `gated`: it then offers one inspection before it can be operated, and the gate is
## its own accepted change so a stale command cannot half-commit it. The default is ungated, which
## reproduces the original start/stop shape exactly.
const Result = preload("res://shared/result.gd")
var _running: bool
var _revision: int = 0
var _gated: bool = false
var _inspected: bool = false
var _operated: bool = false

func _init(initially_running: bool = false, gated: bool = false) -> void:
	_running = initially_running
	_gated = gated

func snapshot() -> Dictionary:
	return {"running": _running, "revision": _revision, "gated": _gated,
		"inspected": _inspected, "operated": _operated}

func gated() -> bool:
	return _gated

## True once the first look has been committed. An ungated device is always considered inspected.
func inspected() -> bool:
	return _inspected or not _gated

## True once the device has actually been started or stopped, so its first-look text can step aside.
func operated() -> bool:
	return _operated

## True when the caller holds the revision this state is currently at.
func accepts(expected_revision: int) -> bool:
	return expected_revision == _revision

## The single first look a gated device offers. It commits nothing but the gate.
func inspect(expected_revision: int) -> Result:
	if not accepts(expected_revision):
		return Result.failure("STALE_STATE")
	if not _gated or _inspected:
		return Result.failure("ALREADY_INSPECTED")
	_inspected = true
	_revision += 1
	return Result.success(snapshot())

func toggle(expected_revision: int) -> Result:
	if not accepts(expected_revision):
		return Result.failure("STALE_STATE")
	if _gated and not _inspected:
		return Result.failure("NOT_INSPECTED")
	_running = not _running
	_inspected = true
	_operated = true
	_revision += 1
	return Result.success(snapshot())
