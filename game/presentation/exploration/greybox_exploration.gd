extends Node2D
## Greybox exploration view. It owns no game rules: movement, collision, interaction
## range and cooldown live in application/exploration. This script maps configured
## action names to use-case calls and renders the synthetic layout only.

const Actions = preload("res://application/exploration/exploration_actions.gd")
const UseCase = preload("res://application/exploration/exploration_use_case.gd")

const WALL_COLOR := Color(0.25, 0.28, 0.33)
const OBJECT_COLOR := Color(0.58, 0.47, 0.3)
const PLAYER_COLOR := Color(0.85, 0.85, 0.7)
const RANGE_COLOR := Color(0.5, 0.75, 0.9, 0.12)
const RANGE_SEGMENTS: int = 32

var _use_case: UseCase
var _wired: bool = false
var _held: Dictionary = {}
var _interact_latched: bool = false
var _investigate_latched: bool = false
var _viewport: Viewport
var _world_node: Node2D
var _camera: Camera2D
var _player: ColorRect
var _player_half: Vector2 = Vector2(16.0, 16.0)
var _title_label: Label
var _prompt_label: Label
var _cooldown_label: Label
var _status_label: Label

func configure(use_case: UseCase) -> void:
	if _wired:
		_unwire()
	_use_case = use_case
	if is_node_ready():
		_wire()

func _ready() -> void:
	_build_nodes()
	_wire()

func is_wired() -> bool:
	return _wired

func _build_nodes() -> void:
	_world_node = Node2D.new()
	_world_node.name = "World"
	add_child(_world_node)
	_camera = Camera2D.new()
	_camera.enabled = true
	add_child(_camera)
	_player = ColorRect.new()
	_player.name = "Player"
	_player.color = PLAYER_COLOR
	_player.size = _player_half * 2.0
	_world_node.add_child(_player)
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui_root := Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui_root)
	_title_label = _make_label(ui_root, 26, Vector4(0, 0, 0, 0), Vector4(24, 16, 824, 52))
	_prompt_label = _make_label(ui_root, 24, Vector4(0.5, 1, 0.5, 1),
		Vector4(-300, -140, 300, -104))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cooldown_label = _make_label(ui_root, 18, Vector4(0, 1, 0, 1),
		Vector4(24, -56, 424, -30))
	_status_label = _make_label(ui_root, 18, Vector4(1, 1, 1, 1),
		Vector4(-624, -56, -24, -30))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _make_label(parent: Control, font_size: int, anchors: Vector4,
		offsets: Vector4) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.anchor_left = anchors.x
	label.anchor_top = anchors.y
	label.anchor_right = anchors.z
	label.anchor_bottom = anchors.w
	label.offset_left = offsets.x
	label.offset_top = offsets.y
	label.offset_right = offsets.z
	label.offset_bottom = offsets.w
	parent.add_child(label)
	return label

func _wire() -> void:
	if not is_node_ready():
		return
	if _wired:
		_unwire()
	if _use_case == null:
		_title_label.text = tr("exploration.greybox.not_configured")
		return
	_use_case.proximity_changed.connect(_on_proximity_changed)
	_use_case.cooldown_changed.connect(_on_cooldown_changed)
	_viewport = get_viewport()
	if _viewport != null and not _viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		_viewport.gui_focus_changed.connect(_on_gui_focus_changed)
	_wired = true
	_title_label.text = tr("exploration.greybox.title")
	_status_label.text = ""
	_render_world()
	_refresh_player()
	_refresh_cooldown()
	var initial := _use_case.nearest_candidate()
	_on_proximity_changed(initial.value.duplicate(true) if initial.ok else {})

func _unwire() -> void:
	if _use_case != null:
		if _use_case.proximity_changed.is_connected(_on_proximity_changed):
			_use_case.proximity_changed.disconnect(_on_proximity_changed)
		if _use_case.cooldown_changed.is_connected(_on_cooldown_changed):
			_use_case.cooldown_changed.disconnect(_on_cooldown_changed)
	if _viewport != null and is_instance_valid(_viewport):
		if _viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
			_viewport.gui_focus_changed.disconnect(_on_gui_focus_changed)
	_wired = false

func _exit_tree() -> void:
	_unwire()
	_clear_transient_input()
	_use_case = null
	_viewport = null
	_world_node = null
	_camera = null
	_player = null
	_title_label = null
	_prompt_label = null
	_cooldown_label = null
	_status_label = null

func _physics_process(delta: float) -> void:
	if not _wired or _use_case == null:
		return
	var focused := _text_input_focused()
	if focused:
		_clear_transient_input()
	_use_case.move(Vector2.ZERO if focused else _movement_axis())
	_use_case.advance(delta)
	_refresh_player()

func _unhandled_input(event: InputEvent) -> void:
	if not _wired or _use_case == null:
		return
	if _text_input_focused():
		_clear_transient_input()
		return
	for action: String in Actions.MOVEMENT:
		if event.is_action_pressed(action):
			_held[action] = true
		elif event.is_action_released(action):
			_held[action] = false
	if event.is_action_released(Actions.INTERACT):
		_interact_latched = false
	if event.is_action_released(Actions.INVESTIGATE):
		_investigate_latched = false
	if event.is_action_pressed(Actions.INTERACT) and not _interact_latched:
		_interact_latched = true
		_try_interact()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed(Actions.INVESTIGATE) and not _investigate_latched:
		_investigate_latched = true
		_try_investigate()
		get_viewport().set_input_as_handled()

func _movement_axis() -> Vector2:
	var x := _pressed_amount(Actions.MOVE_RIGHT) - _pressed_amount(Actions.MOVE_LEFT)
	var y := _pressed_amount(Actions.MOVE_DOWN) - _pressed_amount(Actions.MOVE_UP)
	return Vector2(x, y)

func _pressed_amount(action: String) -> float:
	return 1.0 if _held.get(action, false) else 0.0

func _text_input_focused() -> bool:
	if _viewport == null or not is_instance_valid(_viewport):
		return false
	var focused: Control = _viewport.gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

func _clear_transient_input() -> void:
	_held.clear()
	_interact_latched = false
	_investigate_latched = false

func _try_interact() -> void:
	var candidate := _use_case.nearest_candidate()
	if not candidate.ok:
		_set_status(tr("exploration.status.unavailable"))
		return
	_set_status(tr("exploration.status.interact_submitted") if
		_use_case.interact(candidate.value.target_id).ok else
		tr("exploration.status.unavailable"))

func _try_investigate() -> void:
	var requested := _use_case.investigate()
	if requested.ok:
		_set_status(tr("exploration.status.investigate_submitted"))
	elif requested.code == UseCase.CODE_COOLDOWN_ACTIVE:
		_set_status(tr("exploration.status.cooldown").format(
			{"seconds": "%.1f" % _use_case.cooldown_remaining()}))
	else:
		_set_status(tr("exploration.status.unavailable"))

func _on_proximity_changed(candidate: Dictionary) -> void:
	if candidate.is_empty():
		_prompt_label.text = ""
		return
	_prompt_label.text = tr("exploration.prompt.hint").format({
		"target": tr(candidate.prompt_key), "action": tr("exploration.action.interact")})

func _on_cooldown_changed(_remaining: float, _ready: bool) -> void:
	_refresh_cooldown()

func _on_gui_focus_changed(node: Control) -> void:
	if node is LineEdit or node is TextEdit:
		_clear_transient_input()

func _refresh_cooldown() -> void:
	if _use_case == null or _cooldown_label == null:
		return
	if _use_case.investigate_ready():
		_cooldown_label.text = tr("exploration.ui.investigate_ready")
	else:
		_cooldown_label.text = tr("exploration.ui.investigate_cooldown").format(
			{"seconds": "%.1f" % _use_case.cooldown_remaining()})

func _set_status(text: String) -> void:
	_status_label.text = text

func _render_world() -> void:
	for child in _world_node.get_children():
		if child != _player:
			child.queue_free()
	var layout: Dictionary = _use_case.layout()
	_player_half = layout.player.half_extents
	_player.size = _player_half * 2.0
	var bounds := Rect2()
	var has_bounds := false
	for wall: Rect2 in layout.walls:
		_add_rect(wall, WALL_COLOR)
		bounds = wall if not has_bounds else bounds.merge(wall)
		has_bounds = true
	for item: Dictionary in layout.interactables:
		_add_range(item.position, item.radius)
		var half: Vector2 = item.solid_half_extents
		_add_rect(Rect2(item.position - half, half * 2.0), OBJECT_COLOR)
	if has_bounds:
		_camera.position = bounds.get_center()

func _add_rect(rect: Rect2, color: Color) -> void:
	var view := ColorRect.new()
	view.position = rect.position
	view.size = rect.size
	view.color = color
	_world_node.add_child(view)

func _add_range(center: Vector2, radius: float) -> void:
	var polygon := Polygon2D.new()
	var points := PackedVector2Array()
	for index: int in RANGE_SEGMENTS:
		var angle := TAU * float(index) / float(RANGE_SEGMENTS)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	polygon.polygon = points
	polygon.color = RANGE_COLOR
	_world_node.add_child(polygon)

func _refresh_player() -> void:
	if _player == null or _use_case == null:
		return
	_player.position = _use_case.player_position() - _player_half

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_transient_input()
