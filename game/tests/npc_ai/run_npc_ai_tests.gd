extends SceneTree
## Standalone NPC-AI runner. A script error inside _run would otherwise leave the process
## hanging forever, so the same budget the aggregate uses is armed here too.

const Suite = preload("res://tests/npc_ai/test_npc_ai_pipeline.gd")
const ContentSuite = preload("res://tests/npc_ai/test_npc_content.gd")

var _checks: int = 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_arm_watchdog")

func _arm_watchdog() -> void:
	var watchdog := create_timer(300.0)
	watchdog.timeout.connect(_on_watchdog)

func _on_watchdog() -> void:
	printerr("FAIL: NPC-AI run exceeded its 300 second budget")
	print("AIRPG_NPC_AI_TESTS: %d checks, %d failures" % [_checks, _failures.size() + 1])
	quit(1)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		printerr("FAIL: " + description)

func _run() -> void:
	Suite.new().run(_check)
	ContentSuite.new().run(_check)
	print("AIRPG_NPC_AI_TESTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
