extends SceneTree
const Foundation = preload("res://tests/test_foundation.gd")
const Router = preload("res://presentation/navigation/scene_router.gd")
const HOME = preload("res://presentation/shell/home.tscn")
const WORKSPACE = preload("res://presentation/shell/workspace.tscn")
const MAIN = preload("res://bootstrap/main.tscn")

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
	Foundation.new().run(_check)
	var main := MAIN.instantiate()
	root.add_child(main)
	await process_frame
	_check(main.boot_ready, "main scene booted")
	var host: Node = main.get_node("SceneHost")
	_check(host.get_child_count() == 1, "one active shell")
	host.get_child(0).route_requested.emit("workspace")
	await process_frame
	_check(host.get_child_count() == 1 and host.get_child(0).workspace, "UI navigation reaches workspace")
	host.get_child(0).route_requested.emit("home")
	await process_frame
	_check(host.get_child_count() == 1 and not host.get_child(0).workspace, "return navigation frees previous view")
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
	print("AIRPG_TESTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)
