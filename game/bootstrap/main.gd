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
const Manor = preload("res://bootstrap/manor_play.gd")
const MANOR = preload("res://bootstrap/manor_play.tscn")
const ManorLauncher = preload("res://infrastructure/navigation/manor_preview_launcher.gd")
const CreationService = preload("res://application/character/character_creation_service.gd")
const CreationView = preload("res://presentation/character/creation_view.gd")
const CREATION = preload("res://presentation/character/creation_view.tscn")
const Result = preload("res://shared/result.gd")
const Audio = preload("res://application/ports/audio_port.gd")
const GodotAudio = preload("res://infrastructure/audio/godot_audio.gd")
const GodotRandomSource = preload("res://infrastructure/random/godot_random_source.gd")

var _services: Dictionary = {}
var _router: Router
var _active_view: Node
var boot_ready: bool = false
var _creation_service: CreationService
## The shell's audio runtime: menu banks only, for the menus and the archive. The manor assembles its
## own when it is entered, so a session's music and machine loops belong to the view that started
## them and leave with it.
var _audio: Audio

func _ready() -> void:
	var messages := JsonFile.read("res://data/localization/zh_CN.json")
	if not messages.ok:
		_fail(messages.code)
		return
	var localized := Localization.install(messages.value, "zh_CN")
	if not localized.ok:
		_fail(localized.code)
		return
	var boot := Composition.build("res://data/config/app.json", ManorLauncher.new(_launch_creation))
	if not boot.ok:
		_fail(boot.code)
		return
	_services = boot.value
	# Players for the shell are parented here, so they live exactly as long as the application does.
	_audio = GodotAudio.new(self, GodotRandomSource.new())
	var input_ready := Keyboard.configure(_services.config.input_bindings)
	if not input_ready.ok:
		_fail(input_ready.code)
		return
	_router = Router.new()
	add_child(_router)
	_router.configure($SceneHost, {"home": HOME, "workspace": WORKSPACE,
		"story_archive": STORY_ARCHIVE, "creation": CREATION, "manor": MANOR})
	_navigate("home")
	boot_ready = true
	print("AIRPG_BOOT_READY")

func _navigate(route_id: String) -> RefCounted:
	if route_id == "manor" and (_creation_service == null or not _creation_service.read_creation().locked):
		return Result.failure("CREATION_REQUIRED")
	# Returning from the archive only needs a short fade; the menu look must not replay.
	var resume_menu: bool = route_id == "home" and is_instance_valid(_active_view) \
		and (_active_view is StoryArchive or _active_view is Manor or _active_view is CreationView)
	var routed := _router.navigate(route_id)
	if not routed.ok:
		_fail(routed.code)
		return routed
	var view: Node = routed.value
	# A full-screen Control host must not swallow first-person mouse events.
	$SceneHost.mouse_filter = Control.MOUSE_FILTER_IGNORE if view is Manor else Control.MOUSE_FILTER_STOP
	# Disconnect immediately, including the interval before queue_free is processed.
	if is_instance_valid(_active_view) and _active_view is StartScreen:
		if _active_view.quit_requested.is_connected(_quit_from_menu):
			_active_view.quit_requested.disconnect(_quit_from_menu)
	_active_view = view
	if view is StoryArchive:
		view.configure(_services.story_archive, _services.story_art)
	elif view is CreationView:
		view.configure(_creation_service)
	elif view is Manor:
		view.configure_ai(_services.ai_runtime)
		if _creation_service != null and _creation_service.read_creation().locked:
			view.character_service.apply_created_profile(_creation_service.read_creation())
	elif view is StartScreen:
		view.configure(_services.session, _services.pack_id, _services.content_version,
			_services.config.debug_panel and OS.is_debug_build(), _services.ai_connection)
	else:
		view.configure(_services.session, _services.pack_id, _services.content_version,
			_services.config.debug_panel and OS.is_debug_build())
	view.route_requested.connect(_navigate)
	if view is StartScreen or view is StoryArchive:
		view.attach_audio(_audio)
	if view is StartScreen:
		view.quit_requested.connect(_quit_from_menu)
		if resume_menu:
			view.resume_from_archive()
	return routed

func _launch_creation() -> RefCounted:
	_creation_service = CreationService.new()
	return _navigate("creation")

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
