extends RefCounted
const Launcher = preload("res://application/ports/story_launcher.gd")
const Result = preload("res://shared/result.gd")
var _stories: Array = []
var _launcher: Launcher
var _error: String

func _init(stories: Array, launcher: Launcher, error: String = "") -> void:
	_stories = stories.duplicate(true)
	_launcher = launcher
	_error = error

func list_stories() -> Array:
	return _stories.duplicate(true)

func catalog_error() -> String:
	return _error

func request_start(story_id: String) -> RefCounted:
	for story: Dictionary in _stories:
		if story.id == story_id:
			if story.get("preview_only", false):
				return Result.failure("STORY_PREVIEW_ONLY")
			return _launcher.start_story(story_id)
	return Result.failure("STORY_UNKNOWN")
