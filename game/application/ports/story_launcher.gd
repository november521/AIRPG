extends RefCounted
## Synchronous acceptance boundary. A future implementation owns the actual flow.
## Success transfers ownership; failure must leave gameplay state unchanged.
const Result = preload("res://shared/result.gd")

func start_story(_story_id: String) -> RefCounted:
	return Result.failure("STORY_START_UNAVAILABLE")
