extends "res://application/ports/save_repository.gd"
## Test adapter only. Production composition must not present this as disk persistence.
var _slots: Dictionary = {}

func write_snapshot(slot: String, snapshot: Dictionary) -> RefCounted:
	if slot.is_empty():
		return Result.failure("INVALID_SLOT")
	_slots[slot] = snapshot.duplicate(true)
	return Result.success()

func read_snapshot(slot: String) -> RefCounted:
	if not _slots.has(slot):
		return Result.failure("SAVE_NOT_FOUND")
	return Result.success(_slots[slot].duplicate(true))
