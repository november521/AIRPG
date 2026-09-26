extends RefCounted
## Storage only. Save eligibility, schema migration and snapshot capture belong to use cases.
const Result = preload("res://shared/result.gd")

func write_snapshot(_slot: String, _snapshot: Dictionary) -> RefCounted:
	return Result.failure("NOT_IMPLEMENTED")

func read_snapshot(_slot: String) -> RefCounted:
	return Result.failure("NOT_IMPLEMENTED")
