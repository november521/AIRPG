extends SceneTree
const Suite = preload("res://tests/story_archive/test_story_archive.gd")
var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	await Suite.new().run(_check, self)
	print("AIRPG_ARCHIVE_TESTS: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)
