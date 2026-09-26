extends RefCounted
## Single in-memory authority. Call only from application use cases on the main thread.
## Snapshots are defensive copies; no UI or provider holds writable state.
const Result = preload("res://shared/result.gd")

var _flags: Dictionary = {}
var _revision: int = 0
var _configured: bool = false

func configure(default_flags: Dictionary) -> RefCounted:
	if _configured:
		return Result.failure("ALREADY_CONFIGURED")
	for flag: Variant in default_flags:
		if not flag is String or not default_flags[flag] is bool:
			return Result.failure("INVALID_FLAGS")
	_flags = default_flags.duplicate(true)
	_configured = true
	return Result.success()

func snapshot() -> Dictionary:
	return {"revision": _revision, "flags": _flags.duplicate(true)}

func commit(expected_revision: int, changes: Dictionary) -> RefCounted:
	if not _configured:
		return Result.failure("NOT_CONFIGURED")
	if expected_revision != _revision:
		return Result.failure("STALE_REVISION")
	if changes.is_empty():
		return Result.failure("EMPTY_CHANGE")
	for flag: Variant in changes:
		if not _flags.has(flag) or not changes[flag] is bool:
			return Result.failure("INVALID_FLAGS")
	# Validate the whole change before replacing authoritative state.
	var candidate := _flags.duplicate(true)
	candidate.merge(changes, true)
	_flags = candidate
	_revision += 1
	return Result.success(snapshot())
