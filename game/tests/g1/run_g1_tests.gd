extends SceneTree
## Standalone G1 runner launched with the project's Godot binary, --headless, --script.
## Fully offline; no real API key or network request is used.

const Suite = preload("res://tests/g1/test_g1_suite.gd")

var _checks: int = 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		printerr("FAIL: " + description)

func _run() -> void:
	Suite.new().run(_check)
	print("AIRPG_G1_TESTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
