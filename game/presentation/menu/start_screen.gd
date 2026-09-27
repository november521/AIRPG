extends Control
## Presentation owns animation only; bootstrap handles navigation and process exit.
const Session = preload("res://application/session_service.gd")
const MenuEntry = preload("res://presentation/menu/menu_entry.gd")
const DESIGN_SIZE := Vector2(1920.0, 1080.0)

signal route_requested(route_id: String)
signal quit_requested()

@onready var _design: Control = %Design
@onready var _art: Control = %Artwork
@onready var _smoke: TextureRect = %Smoke
@onready var _menu: VBoxContainer = %Menu
@onready var _start: MenuEntry = %StartButton
@onready var _settings: MenuEntry = %SettingsButton
@onready var _exit: MenuEntry = %ExitButton
var _reveal: Tween
var _departure: Tween
var _leaving: bool = false

func _ready() -> void:
	resized.connect(_fit_design)
	_fit_design()
	_start.pressed.connect(_start_game)
	_exit.pressed.connect(_quit_game)
	# Settings intentionally has no pressed handler until its scope is defined.
	_link_focus()
	_art.modulate.a = 0.0
	_smoke.modulate.a = 0.0
	_menu.modulate.a = 0.0
	_start.grab_focus()
	_reveal = create_tween().set_parallel(true)
	_reveal.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_reveal.tween_property(_art, "modulate:a", 1.0, 2.4)
	_reveal.tween_property(_smoke, "modulate:a", 1.0, 3.2)
	_reveal.tween_property(_menu, "modulate:a", 1.0, 1.2).set_delay(0.5)

func configure(_session: Session, _pack_id: String, _content_version: String,
		_debug_enabled: bool) -> void:
	pass

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
	_depart(route_requested.emit.bind("workspace"))

func _quit_game() -> void:
	_depart(quit_requested.emit)

func _depart(action: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	for entry: MenuEntry in [_start, _settings, _exit]:
		entry.disabled = true
	if _reveal != null:
		_reveal.kill()
	_departure = create_tween()
	_departure.tween_property(_design, "modulate:a", 0.0, 0.3)
	_departure.tween_callback(action)

func _exit_tree() -> void:
	if _reveal != null:
		_reveal.kill()
	if _departure != null:
		_departure.kill()
