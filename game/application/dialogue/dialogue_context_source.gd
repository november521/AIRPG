extends RefCounted
## Application port: gathers the perceptible, memory and non-authoritative inputs for one
## dialogue request. Implementations return a Result whose value contains only the context
## keys the projector accepts; the use case validates and isolates the result before any
## model call. This base implementation fails closed.

const Result = preload("res://shared/result.gd")

func gather(_speaker_id: String, _scene_id: String, _topic_id: String) -> RefCounted:
	return Result.failure("DIALOGUE_CONTEXT_NOT_CONFIGURED")
