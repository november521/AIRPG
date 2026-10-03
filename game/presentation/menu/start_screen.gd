extends Control
## Presentation owns animation only; bootstrap handles navigation and process exit.
const Session = preload("res://application/session_service.gd")
const MenuEntry = preload("res://presentation/menu/menu_entry.gd")
const AiConnectionPanel = preload("res://presentation/menu/ai_connection_panel.gd")
const DESIGN_SIZE := Vector2(1920.0, 1080.0)

signal route_requested(route_id: String)
signal quit_requested()

@onready var _design: Control = %Design
@onready var _art: Control = %Artwork
@onready var _menu: VBoxContainer = %Menu
@onready var _start: MenuEntry = %StartButton
@onready var _settings: MenuEntry = %SettingsButton
@onready var _exit: MenuEntry = %ExitButton
var _reveal: Tween
var _departure: Tween
var _leaving: bool = false
var _ai_connection: Object = null
var _settings_overlay: Control = null

func _ready() -> void:
	resized.connect(_fit_design)
	_fit_design()
	_start.pressed.connect(_start_game)
	_settings.pressed.connect(_open_settings)
	_exit.pressed.connect(_quit_game)
	_link_focus()
	_art.modulate.a = 0.0
	_menu.modulate.a = 0.0
	_start.grab_focus()
	_reveal = create_tween().set_parallel(true)
	_reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reveal.tween_property(_art, "modulate:a", 1.0, 2.4)
	_reveal.tween_property(_menu, "modulate:a", 1.0, 1.2).set_delay(0.5)

func configure(_session: Session, _pack_id: String, _content_version: String,
		_debug_enabled: bool, ai_connection: Object = null) -> void:
	_ai_connection = ai_connection

func _fit_design() -> void:
	var factor: float = minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_design.scale = Vector2.ONE * factor
	_design.position = (size - DESIGN_SIZE * factor) * 0.5

func _link_focus() -> void:
	var entries: Array[MenuEntry] = [_start, _settings, _exit]
	for index: int in entries.size():
		var entry: MenuEntry = entries[index]
		var previous: MenuEntry = entries[(index + entries.size() - 1) % entries.size()]
		var following: MenuEntry = entries[(index + 1) % entries.size()]
		entry.focus_neighbor_top = entry.get_path_to(previous)
		entry.focus_neighbor_bottom = entry.get_path_to(following)
		entry.focus_previous = entry.get_path_to(previous)
		entry.focus_next = entry.get_path_to(following)
		entry.focus_neighbor_left = NodePath(".")
		entry.focus_neighbor_right = NodePath(".")

func _start_game() -> void:
	_depart(route_requested.emit.bind("story_archive"), 0.25)

func resume_from_archive() -> void:
	# Navigation-only change: retain the existing menu composition and artwork.
	if _reveal != null:
		_reveal.kill()
	_art.modulate.a = 1.0
	_menu.modulate.a = 1.0
	_design.modulate.a = 0.0
	_reveal = create_tween()
	_reveal.tween_property(_design, "modulate:a", 1.0, 0.25)

func _quit_game() -> void:
	_depart(quit_requested.emit)

func _open_settings() -> void:
	if _leaving or _ai_connection == null:
		return
	if is_instance_valid(_settings_overlay):
		_settings_overlay.show()
		return
	_settings_overlay = Control.new()
	_settings_overlay.name = "AiConnectionOverlay"
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_design.add_child(_settings_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.007, 0.009, 0.9)
	_settings_overlay.add_child(shade)
	var panel := AiConnectionPanel.new()
	_settings_overlay.add_child(panel)
	panel.configure(_ai_connection)
	panel.closed.connect(_close_settings)

func _close_settings() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.hide()
	_settings.grab_focus()

func _depart(action: Callable, duration: float = 0.3) -> void:
	if _leaving:
		return
	_leaving = true
	if is_instance_valid(_settings_overlay):
		_settings_overlay.hide()
	for entry: MenuEntry in [_start, _settings, _exit]:
		entry.disabled = true
	if _reveal != null:
		_reveal.kill()
	_departure = create_tween()
	_departure.tween_property(_design, "modulate:a", 0.0, duration)
	_departure.tween_callback(action)

func _exit_tree() -> void:
	if _reveal != null:
		_reveal.kill()
	if _departure != null:
		_departure.kill()
