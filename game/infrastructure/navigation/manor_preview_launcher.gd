extends "res://application/ports/story_launcher.gd"
## Injected local prototype route; it does not start an authored story.
var _launch: Callable

func _init(launch: Callable) -> void:
	_launch = launch

func start_story(story_id: String) -> RefCounted:
	if story_id != "deadlight" or not _launch.is_valid():
		return Result.failure("STORY_START_UNAVAILABLE")
	return _launch.call()
