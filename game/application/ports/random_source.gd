extends RefCounted
const Result = preload("res://shared/result.gd")

func roll(_sides: int) -> RefCounted:
	return Result.failure("NOT_IMPLEMENTED")

func capture() -> Dictionary:
	return {}

func restore(_checkpoint: Dictionary) -> RefCounted:
	return Result.failure("NOT_IMPLEMENTED")
