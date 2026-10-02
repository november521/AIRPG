extends Node3D

const WalkInput = preload("res://infrastructure/input/walk_input.gd")
const WalkSession = preload("res://application/exploration/walk_session.gd")
const Player = preload("res://presentation/exploration/player.gd")
const WalkHud = preload("res://presentation/shell/walk_hud.gd")
const CharacterPreview = preload("res://bootstrap/character_preview.gd")
const CharacterHud = preload("res://presentation/character/character_hud.gd")
signal route_requested(route_id: String)
const SIDE_SPAWN := Vector3(-8.05, -0.39, -1.64)
const CELLAR_SPAWN := Vector3(-3.4, -2.65, -10.7)
var _controls := WalkInput.new()
var session := WalkSession.new()
var character_service = CharacterPreview.build()
var character_hud: CharacterHud
var _pitch: float = 0.0
@onready var player: Player = $World/Player
@onready var camera: Camera3D = $World/Player/Camera
@onready var _hud: WalkHud = $HUD

func _ready() -> void:
	_controls.configure()
	player.configure(session)
	reset_at_side_entry()
	_controls.capture_pointer()
	character_hud = CharacterHud.new()
	character_hud.configure(character_service)
	character_hud.panel_changed.connect(_on_panel_changed)
	character_hud.return_requested.connect(_return_to_archive)
	_hud.add_child(character_hud)
	print("AIRPG_STRUCTURE_WALK_READY")

func _input(event: InputEvent) -> void:
	if not is_instance_valid(character_hud):
		return
	if _controls.inventory_toggle(event):
		character_hud.set_open(not character_hud.is_open())
		get_viewport().set_input_as_handled()
	elif _controls.return_requested(event):
		get_viewport().set_input_as_handled()
		_return_to_archive()
	elif character_hud.is_open() and _controls.escape_pressed(event):
		character_hud.set_open(false)
		get_viewport().set_input_as_handled()

func _on_panel_changed(open: bool) -> void:
	_controls.set_ui_blocked(open)
	session.stop()

func _return_to_archive() -> void:
	session.stop()
	_controls.release_pointer()
	route_requested.emit("story_archive")

func _unhandled_input(event: InputEvent) -> void:
	if character_hud.is_open():
		return
	apply_look(_controls.look_motion(event))

func apply_look(motion: Vector2) -> void:
	if not motion.is_finite():
		return
	player.rotation.y -= motion.x * 0.0025
	_pitch = clampf(_pitch - motion.y * 0.0025, deg_to_rad(-80), deg_to_rad(80))
	camera.rotation.x = _pitch

func reset_at_side_entry() -> void:
	player.place_at(SIDE_SPAWN, -PI / 2)
	_pitch = 0
	camera.rotation.x = 0

func visit_cellar() -> void:
	player.place_at(CELLAR_SPAWN, PI / 2)
	_pitch = 0
	camera.rotation.x = 0

func _physics_process(_delta: float) -> void:
	session.set_movement(_controls.movement(), _controls.slow())
	if _controls.reset_requested() or player.position.y < -7:
		reset_at_side_entry()
	elif _controls.cellar_requested():
		visit_cellar()
	_hud.show_location(player.position, _controls.active())

func _exit_tree() -> void:
	_controls.release_pointer()
