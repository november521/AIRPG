extends RefCounted
## Scene-side semantic NPC action executor. Coordinates never cross this port.

const Result = preload("res://shared/result.gd")

func accept(_proposal: Dictionary) -> RefCounted:
	return Result.failure("NPC_ACTION_NOT_CONFIGURED")
