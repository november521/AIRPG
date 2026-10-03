extends SceneTree
const Foundation = preload("res://tests/test_foundation.gd")
const A1Contracts = preload("res://tests/suites/test_a1_contracts.gd")
const Router = preload("res://presentation/navigation/scene_router.gd")
const HOME = preload("res://presentation/shell/home.tscn")
const WORKSPACE = preload("res://presentation/shell/workspace.tscn")
const MAIN = preload("res://bootstrap/main.tscn")
## Start-screen detection by script file keeps this harness free of the view's public surface.
const START_SCRIPT = "start_screen.gd"
const StoryArchive = preload("res://tests/story_archive/test_story_archive.gd")
const ManorTests = preload("res://tests/manor/test_manor.gd")
const NpcRigTests = preload("res://tests/manor/npc_animation_tests.gd")
const CharacterTests = preload("res://tests/manor/character_tests.gd")
const InteractionTests = preload("res://tests/interactions/test_interactions.gd")
const InteractionSceneTests = preload("res://tests/interactions/test_scene_interactions.gd")
const G1Tests = preload("res://tests/g1/test_g1_suite.gd")
const F1KnowledgeTests = preload("res://tests/f1/test_f1_knowledge.gd")
const F1LifecycleTests = preload("res://tests/f1/test_f1_lifecycle.gd")
const F1ValidationTests = preload("res://tests/f1/test_f1_reply_validation.gd")
const F1UseCaseTests = preload("res://tests/f1/test_f1_use_case.gd")
const I1BehaviorTests = preload("res://tests/i1/test_dialogue_view_behavior.gd")
const I1LifecycleTests = preload("res://tests/i1/test_dialogue_view_lifecycle.gd")
const NpcAiTests = preload("res://tests/npc_ai/test_npc_ai_pipeline.gd")

var _checks: int = 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_arm_watchdog")

## A script error inside _run aborts it forever; without this the process would hang instead of failing.
func _arm_watchdog() -> void:
	var watchdog := create_timer(300.0)
	watchdog.timeout.connect(_on_watchdog)

func _on_watchdog() -> void:
	printerr("FAIL: test run exceeded its 300 second budget")
	print("AIRPG_TESTS: %d checks, %d failures" % [_checks, _failures.size() + 1])
	quit(1)

func _is_start_view(view: Node) -> bool:
	var script: Script = view.get_script()
	return script != null and script.resource_path.get_file() == START_SCRIPT

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		printerr("FAIL: " + description)

func _run() -> void:
	# Feature branches add isolated suites. The integration owner registers suites here once.
	for suite: Variant in [Foundation, A1Contracts]:
		suite.new().run(_check)
	var main := MAIN.instantiate()
	root.add_child(main)
	await process_frame
	_check(main.boot_ready, "main scene booted")
	var host: Node = main.get_node("SceneHost")
	_check(host.get_child_count() == 1, "one active shell")
	_check(_is_start_view(host.get_child(0)), "boot route shows the start screen")
	# Navigation itself is asserted here; the start screen's own fade timing is left to
	# presentation tests because a --script run does not advance process frames reliably.
	host.get_child(0).route_requested.emit("workspace")
	await process_frame
	_check(host.get_child_count() == 1 and host.get_child(0).workspace,
		"navigation from the start screen reaches workspace")
	host.get_child(0).route_requested.emit("home")
	await process_frame
	_check(host.get_child_count() == 1 and _is_start_view(host.get_child(0)),
		"return navigation shows the start screen again")
	var router := Router.new()
	root.add_child(router)
	var isolated_host := Node.new()
	root.add_child(isolated_host)
	router.configure(isolated_host, {"home": HOME, "workspace": WORKSPACE})
	_check(router.navigate("home").ok, "valid route accepted")
	var prior: Node = isolated_host.get_child(0)
	_check(not router.navigate("unknown").ok, "unknown route rejected")
	_check(isolated_host.get_child(0) == prior, "unknown route preserves previous view")
	router.queue_free()
	isolated_host.queue_free()
	main.queue_free()
	await process_frame
	print("AIRPG_BASE_TESTS: %d checks" % _checks)
	var before: int = _checks
	G1Tests.new().run(_check)
	print("AIRPG_G1_TESTS: %d checks" % (_checks - before))
	before = _checks
	for suite: Variant in [F1KnowledgeTests, F1LifecycleTests, F1ValidationTests, F1UseCaseTests]:
		suite.new().run(_check)
	print("AIRPG_F1_TESTS: %d checks" % (_checks - before))
	before = _checks
	NpcAiTests.new().run(_check)
	print("AIRPG_NPC_AI_TESTS: %d checks" % (_checks - before))
	before = _checks
	var i1_host := Control.new()
	i1_host.name = "I1TestHost"
	root.add_child(i1_host)
	await I1BehaviorTests.new().run(_check, i1_host)
	await I1LifecycleTests.new().run(_check, i1_host)
	i1_host.queue_free()
	await process_frame
	print("AIRPG_I1_TESTS: %d checks" % (_checks - before))
	before = _checks
	await StoryArchive.new().run(_check, self)
	print("AIRPG_ARCHIVE_TESTS: %d checks" % (_checks - before))
	before = _checks
	await ManorTests.new().run(_check, self)
	print("AIRPG_MANOR_TESTS: %d checks" % (_checks - before))
	before = _checks
	await NpcRigTests.new().run(_check, self)
	print("AIRPG_NPC_RIG_TESTS: %d checks" % (_checks - before))
	before = _checks
	CharacterTests.new().run(_check)
	print("AIRPG_CHARACTER_TESTS: %d checks" % (_checks - before))
	before = _checks
	InteractionTests.new().run(_check)
	await InteractionSceneTests.new().run(_check, self)
	print("AIRPG_INTERACTION_TESTS: %d checks" % (_checks - before))
	print("AIRPG_TESTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
