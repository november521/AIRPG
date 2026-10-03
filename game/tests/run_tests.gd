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
const CreationTests = preload("res://tests/manor/creation_tests.gd")
const InteractionTests = preload("res://tests/interactions/test_interactions.gd")
const InteractionSceneTests = preload("res://tests/interactions/test_scene_interactions.gd")
const AudioTests = preload("res://tests/audio/test_audio.gd")

var _checks: int = 0
var _failures: Array[String] = []
## Optional development filter, e.g. `--script tests/run_tests.gd -- interaction` (prefix it with
## the engine's res scheme when actually running it; the scheme is left out here because the
## architecture gate scans comments for dependency paths too, and a literal one would read as a
## self-reference).
## Empty means the full aggregate below runs exactly as before, markers and counts unchanged.
var _filter: String = ""

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_filter = args[0].strip_edges().to_lower()
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
	if not _filter.is_empty():
		await _run_filtered()
		return
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
	await StoryArchive.new().run(_check, self)
	print("AIRPG_ARCHIVE_TESTS: %d checks" % (_checks - before))
	before = _checks
	await ManorTests.new().run(_check, self)
	print("AIRPG_MANOR_TESTS: %d checks" % (_checks - before))
	before = _checks
	await NpcRigTests.new().run(_check, self)
	print("AIRPG_NPC_RIG_TESTS: %d checks" % (_checks - before))
	CharacterTests.new().run(_check)
	before = _checks
	CreationTests.new().run(_check, self)
	print("AIRPG_CREATION_TESTS: %d checks" % (_checks - before))
	before = _checks
	InteractionTests.new().run(_check)
	await InteractionSceneTests.new().run(_check, self)
	print("AIRPG_INTERACTION_TESTS: %d checks" % (_checks - before))
	before = _checks
	await AudioTests.new().run(_check, self)
	print("AIRPG_AUDIO_TESTS: %d checks" % (_checks - before))
	print("AIRPG_TESTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

## Development-only path: run just the suites whose label contains `_filter`, in the same order and
## with the same per-suite markers as the full aggregate. It never runs unless a filter argument was
## passed, so the gate's numbers above stay untouched.
func _wanted(label: String) -> bool:
	return _filter.is_empty() or label.contains(_filter)

func _run_filtered() -> void:
	# Boot the real app once. That is what installs localization and the composition root which the
	# scene suites below assume; without it every HUD string formats a raw key and the run is buried
	# in formatting errors that would hide a real one. The contract suites run only in the full
	# aggregate, so this path never prints a base marker with a partial count.
	var main := MAIN.instantiate()
	root.add_child(main)
	await process_frame
	main.queue_free()
	await process_frame

	var before: int = 0
	if _wanted("archive"):
		before = _checks
		await StoryArchive.new().run(_check, self)
		print("AIRPG_ARCHIVE_TESTS: %d checks" % (_checks - before))
	if _wanted("manor"):
		before = _checks
		await ManorTests.new().run(_check, self)
		print("AIRPG_MANOR_TESTS: %d checks" % (_checks - before))
	if _wanted("npc"):
		before = _checks
		await NpcRigTests.new().run(_check, self)
		print("AIRPG_NPC_RIG_TESTS: %d checks" % (_checks - before))
	if _wanted("character"):
		CharacterTests.new().run(_check)
	if _wanted("creation"):
		before = _checks
		CreationTests.new().run(_check, self)
		print("AIRPG_CREATION_TESTS: %d checks" % (_checks - before))
	if _wanted("interaction"):
		before = _checks
		InteractionTests.new().run(_check)
		await InteractionSceneTests.new().run(_check, self)
		print("AIRPG_INTERACTION_TESTS: %d checks" % (_checks - before))
	# The audio suite runs with the interaction suite as well as on its own: the acceptance command
	# for this round is the interaction filter, and it must exercise the new wiring.
	if _wanted("interaction") or _wanted("audio"):
		before = _checks
		await AudioTests.new().run(_check, self)
		print("AIRPG_AUDIO_TESTS: %d checks" % (_checks - before))
	print("AIRPG_FILTER: %s" % _filter)
	print("AIRPG_TESTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
