extends Node3D

const WalkInput = preload("res://infrastructure/input/walk_input.gd")
const WalkSession = preload("res://application/exploration/walk_session.gd")
const Player = preload("res://presentation/exploration/player.gd")
const WalkHud = preload("res://presentation/shell/walk_hud.gd")
const CharacterPreview = preload("res://bootstrap/character_preview.gd")
const CharacterHud = preload("res://presentation/character/character_hud.gd")
const Interactions = preload("res://bootstrap/manor_interactions.gd")
const InteractionService = preload("res://application/exploration/interaction_service.gd")
const InteractionHud = preload("res://presentation/exploration/interactions/interaction_hud.gd")
const NpcPreview = preload("res://bootstrap/npc_preview.gd")
const NpcActor = preload("res://presentation/manor/npc_actor.gd")
const NpcHud = preload("res://presentation/manor/npc_greeting_hud.gd")
const ManorNpcAi = preload("res://bootstrap/manor_npc_ai.gd")
const DIALOGUE_VIEW = preload("res://presentation/dialogue/dialogue_view.tscn")
const WorldItemInteraction = preload("res://application/exploration/interactions/world_item_interaction.gd")
const WorldItem = preload("res://items/world/world_item.gd")
var npc_presence = NpcPreview.build()
var npc_actors: Array[NpcActor] = []
var npc_hud: NpcHud
var npc_ai: ManorNpcAi
var dialogue_view: Control
var ai_error: String = "AI_NOT_CONFIGURED"
var _candidate: NpcActor
signal route_requested(route_id: String)
const SIDE_SPAWN := Vector3(-8.05, -0.39, -1.64)
const CELLAR_SPAWN := Vector3(-3.6, -3.19, -7.4)
var _controls := WalkInput.new()
var session := WalkSession.new()
var character_service = CharacterPreview.build()
var character_hud: CharacterHud
var interaction_service: InteractionService
var _interaction_hud: InteractionHud
var _pending_interaction: bool = false
var _pitch: float = 0.0
var _held_visual: Node3D
var _drop_serial: int = 0
@onready var player: Player = $World/Player
@onready var camera: Camera3D = $World/Player/Camera
@onready var _hud: WalkHud = $HUD

func _ready() -> void:
	_controls.configure()
	player.configure(session)
	reset_at_side_entry()
	character_hud = CharacterHud.new()
	character_hud.configure(character_service)
	character_hud.panel_changed.connect(_on_panel_changed)
	character_hud.return_requested.connect(_return_to_archive)
	character_hud.item_dropped.connect(_drop_item_in_world)
	character_service.changed.connect(_sync_held_visual)
	_hud.add_child(character_hud)
	var interactions: RefCounted = Interactions.build($World, camera, player, character_service)
	if not interactions.ok:
		_controls.set_ui_blocked(true)
		set_physics_process(false)
		push_error(interactions.code)
		return
	interaction_service = interactions.value
	_sync_held_visual()
	_interaction_hud = InteractionHud.new()
	_interaction_hud.configure(interaction_service)
	_hud.add_child(_interaction_hud)
	npc_hud = NpcHud.new()
	_hud.add_child(npc_hud)
	npc_hud.closed.connect(_close_greeting)
	for entry: Dictionary in npc_presence.roster():
		var actor := NpcActor.new()
		if not actor.configure(npc_presence, entry):
			push_error("NPC_VISUAL_INVALID")
			_controls.set_ui_blocked(true)
			set_physics_process(false)
			return
		$World.add_child(actor)
		npc_actors.append(actor)
	player.collision_mask = 3
	_controls.set_ui_blocked(false)
	print("AIRPG_STRUCTURE_WALK_READY")

func configure_ai(runtime: Object) -> bool:
	if npc_ai != null:
		npc_ai.release()
		npc_ai = null
	if is_instance_valid(dialogue_view):
		dialogue_view.queue_free()
		dialogue_view = null
	var built := ManorNpcAi.build(self, runtime, npc_presence.roster(), npc_actors, player,
		NpcPreview.action_anchors())
	if not built.ok:
		ai_error = built.code
		return false
	npc_ai = built.value
	dialogue_view = DIALOGUE_VIEW.instantiate()
	_hud.add_child(dialogue_view)
	dialogue_view.hide()
	dialogue_view.configure(npc_ai.use_case())
	dialogue_view.back_requested.connect(_close_greeting)
	ai_error = ""
	return true

func _input(event: InputEvent) -> void:
	if not is_instance_valid(character_hud):
		return
	if _conversation_open() and _dialogue_text_focused():
		if _controls.escape_pressed(event):
			_close_greeting()
			get_viewport().set_input_as_handled()
		return
	if interaction_service == null:
		if _controls.return_requested(event):
			_return_to_archive()
			get_viewport().set_input_as_handled()
		return
	if _controls.inventory_toggle(event):
		if _conversation_open():
			_close_greeting()
		character_hud.set_open(not character_hud.is_open())
		get_viewport().set_input_as_handled()
	elif _controls.return_requested(event):
		get_viewport().set_input_as_handled()
		_return_to_archive()
	elif character_hud.is_open() and _controls.escape_pressed(event):
		character_hud.set_open(false)
		get_viewport().set_input_as_handled()
	elif _conversation_open() and (_controls.escape_pressed(event) or _controls.talk_pressed(event)):
		_close_greeting()
		get_viewport().set_input_as_handled()
	elif not character_hud.is_open() and _controls.active() and (_controls.interact_pressed(event) or _controls.talk_pressed(event)):
		# Defer selection to the physics tick: ray hits take priority over legacy NPC talk.
		_pending_interaction = true
		get_viewport().set_input_as_handled()

func _on_panel_changed(open: bool) -> void:
	_controls.set_ui_blocked(open or interaction_service == null or _conversation_open())
	session.stop()
	_pending_interaction = false
	if interaction_service != null:
		interaction_service.set_enabled(false)
		_interaction_hud.refresh(false)

func _return_to_archive() -> void:
	if npc_ai != null:
		npc_ai.end()
	npc_presence.end_greeting()
	session.stop()
	_controls.release_pointer()
	_pending_interaction = false
	if interaction_service != null:
		interaction_service.set_enabled(false)
	route_requested.emit("story_archive")

func _unhandled_input(event: InputEvent) -> void:
	if character_hud.is_open() or interaction_service == null or _conversation_open():
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
	if _conversation_open():
		_hud.show_ui_state("walk.talking")
	elif character_hud.is_open():
		_hud.show_ui_state("walk.dossier")
	var requested: bool = _pending_interaction
	_pending_interaction = false
	if interaction_service != null:
		var enabled: bool = _controls.active() and not character_hud.is_open() and not _conversation_open()
		interaction_service.set_enabled(enabled)
		interaction_service.refresh_focus()
		var focus: Dictionary = interaction_service.read_focus()
		if requested and enabled:
			if not focus.is_empty():
				var result: RefCounted = interaction_service.interact(focus.target_id, focus.revision)
				_interaction_hud.show_result("OK" if result.ok else result.code)
			else:
				_open_greeting()
		_candidate = _find_candidate() if enabled and focus.is_empty() else null
		npc_hud.show_candidate(_candidate.name_key if _candidate != null else "")
		_interaction_hud.refresh(_controls.active() and not _conversation_open())

func _find_candidate() -> NpcActor:
	var nearest: NpcActor
	var distance: float = npc_presence.TALK_RANGE
	for actor: NpcActor in npc_actors:
		var next: float = player.position.distance_to(actor.position)
		if next <= distance and _can_see(actor):
			nearest = actor
			distance = next
	return nearest

func _can_see(actor: NpcActor) -> bool:
	var point := actor.global_position + Vector3(0, 1.2, 0)
	var direction := point - camera.global_position
	if direction.normalized().dot(-camera.global_basis.z) < 0.65:
		return false
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, point, 3, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.get("collider") == actor

func _open_greeting() -> void:
	_candidate = _find_candidate()
	if _candidate == null:
		return
	var reply = npc_presence.begin_greeting(_candidate.npc_id,
		player.position.distance_to(_candidate.position), _can_see(_candidate))
	if reply.ok:
		_candidate.set_greeting_target(player.global_position)
		if npc_ai != null and is_instance_valid(dialogue_view) \
				and npc_ai.begin(_candidate.npc_id, player, dialogue_view).ok:
			npc_hud.dismiss()
			dialogue_view.show()
		else:
			npc_hud.show_greeting(reply.value)
		_controls.set_ui_blocked(true)
		session.stop()
		_pending_interaction = false
		interaction_service.set_enabled(false)
		_interaction_hud.refresh(false)

func _close_greeting() -> void:
	if _candidate != null:
		_candidate.clear_greeting_target()
	npc_presence.end_greeting()
	if npc_ai != null:
		npc_ai.end()
	if is_instance_valid(dialogue_view):
		dialogue_view.hide()
	npc_hud.dismiss()
	_controls.set_ui_blocked(character_hud.is_open() or interaction_service == null)
	_pending_interaction = false
	session.stop()

func _drop_item_in_world(item_id: String) -> void:
	var definition: Dictionary = character_service.read_character().definitions[item_id]
	var dropped: WorldItem = definition.world_scene.instantiate()
	var source_id: String = "manor.drop.%d" % _drop_serial
	_drop_serial += 1
	var handler := WorldItemInteraction.new(character_service, source_id, item_id, 1, definition.name_key)
	dropped.name = source_id.replace(".", "_")
	$World.add_child(dropped)
	dropped.position = player.position - player.global_basis.z * 0.8
	dropped.position.y = player.position.y + 0.24
	dropped.configure_runtime(item_id, handler, definition.name_key, 1)
	interaction_service.register_runtime_target(source_id, handler, dropped.get_node("Target"))

func _sync_held_visual() -> void:
	if not is_instance_valid(player):
		return
	if is_instance_valid(_held_visual):
		_held_visual.queue_free()
		_held_visual = null
	var item_id: String = character_service.read_character().held_item
	if item_id.is_empty():
		return
	var definition: Dictionary = character_service.read_character().definitions[item_id]
	if definition.held_scene == null:
		return
	_held_visual = definition.held_scene.instantiate()
	player.get_node("Camera/HandSocket").add_child(_held_visual)

func _exit_tree() -> void:
	if npc_ai != null:
		npc_ai.release()
		npc_ai = null
	_controls.release_pointer()
	if interaction_service != null:
		interaction_service.close()

func _conversation_open() -> bool:
	return (npc_hud != null and npc_hud.is_open()) \
		or (is_instance_valid(dialogue_view) and dialogue_view.visible)

func _dialogue_text_focused() -> bool:
	if not is_instance_valid(dialogue_view):
		return false
	var focused: Control = get_viewport().gui_get_focus_owner()
	return focused is LineEdit and dialogue_view.is_ancestor_of(focused)
