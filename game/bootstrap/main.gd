extends Node
const Composition = preload("res://bootstrap/composition.gd")
const JsonFile = preload("res://infrastructure/content/json_file.gd")
const Localization = preload("res://infrastructure/localization/json_localization.gd")
const Keyboard = preload("res://infrastructure/input/keyboard_input.gd")
const Router = preload("res://presentation/navigation/scene_router.gd")
const HOME = preload("res://presentation/menu/start_screen.tscn")
const WORKSPACE = preload("res://presentation/shell/workspace.tscn")
const StartScreen = preload("res://presentation/menu/start_screen.gd")
const StoryArchive = preload("res://presentation/story_archive/story_archive.gd")
const STORY_ARCHIVE = preload("res://presentation/story_archive/story_archive.tscn")

var _services: Dictionary = {}
var _router: Router
var _active_view: Control
var boot_ready: bool = false

func _ready() -> void:
	var messages := JsonFile.read("res://data/localization/zh_CN.json")
	if not messages.ok:
		_fail(messages.code)
		return
	var localized := Localization.install(messages.value, "zh_CN")
	if not localized.ok:
		_fail(localized.code)
		return
	var boot := Composition.build()
	if not boot.ok:
		_fail(boot.code)
		return
	_services = boot.value
	var input_ready := Keyboard.configure(_services.config.input_bindings)
	if not input_ready.ok:
		_fail(input_ready.code)
		return
	_router = Router.new()
	add_child(_router)
	_router.configure($SceneHost, {"home": HOME, "workspace": WORKSPACE,
		"story_archive": STORY_ARCHIVE})
	_navigate("home")
	boot_ready = true
	print("AIRPG_BOOT_READY")

func _navigate(route_id: String) -> void:
	# Returning from the archive only needs a short fade; the menu look must not replay.
	var resume_menu: bool = route_id == "home" and is_instance_valid(_active_view) \
		and _active_view is StoryArchive
	var routed := _router.navigate(route_id)
	if not routed.ok:
		_fail(routed.code)
		return
	var view: Control = routed.value
	# Disconnect immediately, including the interval before queue_free is processed.
	if is_instance_valid(_active_view) and _active_view is StartScreen:
		if _active_view.quit_requested.is_connected(_quit_from_menu):
			_active_view.quit_requested.disconnect(_quit_from_menu)
	_active_view = view
	if view is StoryArchive:
		view.configure(_services.story_archive, _services.story_art)
	else:
		view.configure(_services.session, _services.pack_id, _services.content_version,
			_services.config.debug_panel and OS.is_debug_build())
	view.route_requested.connect(_navigate)
	if view is StartScreen:
		view.quit_requested.connect(_quit_from_menu)
		if resume_menu:
			view.resume_from_archive()

func _quit_from_menu() -> void:
	if is_instance_valid(_active_view) and _active_view is StartScreen:
		get_tree().quit()

func _fail(code: String) -> void:
	push_error("AIRPG_BOOT_FAILED:" + code)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	var label := Label.new()
	label.text = tr("boot.failed")
	$SceneHost.add_child(label)
