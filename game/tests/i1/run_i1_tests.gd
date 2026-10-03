extends SceneTree
## Standalone I1 suite runner. The integration owner registers these suites in tests/run_tests.gd.

const Behavior = preload("res://tests/i1/test_dialogue_view_behavior.gd")
const Lifecycle = preload("res://tests/i1/test_dialogue_view_lifecycle.gd")

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
	var host := Control.new()
	host.name = "I1TestHost"
	root.add_child(host)
	await Behavior.new().run(_check, host)
	await Lifecycle.new().run(_check, host)
	host.queue_free()
	await process_frame
	print("AIRPG_I1_TESTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
