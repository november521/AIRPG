extends SceneTree
## Standalone F1 suite entry. The integration owner registers these suites in
## tests/run_tests.gd; F1 does not modify the shared aggregate entry.

const KnowledgeSuite = preload("res://tests/f1/test_f1_knowledge.gd")
const LifecycleSuite = preload("res://tests/f1/test_f1_lifecycle.gd")
const ValidationSuite = preload("res://tests/f1/test_f1_reply_validation.gd")
const UseCaseSuite = preload("res://tests/f1/test_f1_use_case.gd")

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
	KnowledgeSuite.new().run(_check)
	LifecycleSuite.new().run(_check)
	ValidationSuite.new().run(_check)
	UseCaseSuite.new().run(_check)
	print("AIRPG_F1_TESTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
