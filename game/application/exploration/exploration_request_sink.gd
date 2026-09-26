extends RefCounted
## Integration seam for validated exploration intent DTOs.
## C1 only produces ExplorationContract commands; it never mutates story state.
## The integration owner supplies the real sink (dialogue / rules / story).

const Result = preload("res://shared/result.gd")

func submit(_command: Dictionary) -> RefCounted:
	return Result.failure("EXPLORATION_SINK_NOT_IMPLEMENTED")
