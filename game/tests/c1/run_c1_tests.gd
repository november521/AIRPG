extends SceneTree
## Standalone C1 suite entry. The integration owner registers these suites in
## tests/run_tests.gd; C1 does not modify the shared aggregate entry.

const WorldSuite = preload("res://tests/c1/test_c1_world.gd")
const UseCaseSuite = preload("res://tests/c1/test_c1_use_case.gd")
const ViewSuite = preload("res://tests/c1/test_c1_view.gd")
const Composition = preload("res://bootstrap/composition.gd")
const Keyboard = preload("res://infrastructure/input/keyboard_input.gd")

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
	WorldSuite.new().run(_check)
	UseCaseSuite.new().run(_check)
	var boot := Composition.build()
	if boot.ok:
		Keyboard.configure(boot.value.config.input_bindings)
	await ViewSuite.new().run(_check, self)
	print("AIRPG_C1_TESTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
