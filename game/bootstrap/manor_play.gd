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
const HeldItem = preload("res://bootstrap/manor_held_item.gd")
const ManorGreeting = preload("res://bootstrap/manor_npc_greeting.gd")
const Audio = preload("res://application/ports/audio_port.gd")
const Soundscape = preload("res://bootstrap/manor_soundscape.gd")
var npc_presence = NpcPreview.build()
var npc_actors: Array[NpcActor] = []
var npc_hud: NpcHud
var npc_ai: ManorNpcAi
var dialogue_view: Control
var ai_error: String = "AI_NOT_CONFIGURED"
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
var _held_item: HeldItem
var _greeting: ManorGreeting
## The session's audio runtime. Left unset, this node assembles the real one in `_ready`; a test that
## records instead of plays hands its own over before the node enters the tree.
var _audio: Audio
var _sound := Soundscape.new()
@onready var player: Player = $World/Player
@onready var camera: Camera3D = $World/Player/Camera
@onready var _hud: WalkHud = $HUD

## Injected by bootstrap, and by a test that wants to record the events instead of hearing them. Must
## be called before this node is added to the tree, because `_ready` is what builds the session.
func attach_audio(port: Audio) -> void:
	if port != null:
		_audio = port

func _ready() -> void:
	# The manor assembles its own audio runtime. The port is a contract, not a singleton: a session's
	# music, its machine loops and their fades must belong to the view that started them, and leaving
	# the manor has to take all of it with it.
	_audio = _sound.begin(self, _audio)
	_controls.configure()
	player.configure(session)
	reset_at_side_entry()
	_sound.watch(player)
	character_hud = CharacterHud.new()
	character_hud.configure(character_service)
	character_hud.panel_changed.connect(_on_panel_changed)
	character_hud.return_requested.connect(_return_to_archive)
	_held_item = HeldItem.new()
	character_hud.item_dropped.connect(_held_item.drop)
	character_service.changed.connect(_held_item.sync)
	_hud.add_child(character_hud)
	# After the HUD is in the tree: the notebook closes itself on the way in, and that closing call is
	# not the player opening anything.
	character_hud.attach_audio(_audio)
	var interactions: RefCounted = Interactions.build($World, camera, player, character_service, _audio)
	if not interactions.ok:
		_controls.set_ui_blocked(true)
		set_physics_process(false)
		push_error(interactions.code)
		return
	interaction_service = interactions.value
	_held_item.configure(character_service, player, $World, interaction_service, _sound)
	_held_item.sync()
	_interaction_hud = InteractionHud.new()
	_interaction_hud.configure(interaction_service)
	_hud.add_child(_interaction_hud)
	npc_hud = NpcHud.new()
	_hud.add_child(npc_hud)
	_greeting = ManorGreeting.new()
	_greeting.configure(npc_presence, npc_actors, player, camera, npc_hud)
	npc_hud.closed.connect(_end_greeting)
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
	_greeting.attach_dialogue(npc_ai, dialogue_view)
	dialogue_view.back_requested.connect(_end_greeting)
	ai_error = ""
	return true

func _input(event: InputEvent) -> void:
	if not is_instance_valid(character_hud):
		return
	if _conversation_open() and _dialogue_text_focused():
		if _controls.escape_pressed(event):
			_end_greeting()
			get_viewport().set_input_as_handled()
		return
	if interaction_service == null:
		if _controls.return_requested(event):
			_return_to_archive()
			get_viewport().set_input_as_handled()
		return
	if _controls.inventory_toggle(event):
		if _conversation_open():
			_end_greeting()
		character_hud.set_open(not character_hud.is_open())
		get_viewport().set_input_as_handled()
	elif _controls.return_requested(event):
		get_viewport().set_input_as_handled()
		_return_to_archive()
	elif character_hud.is_open() and _controls.escape_pressed(event):
		character_hud.set_open(false)
		get_viewport().set_input_as_handled()
	elif _conversation_open() and (_controls.escape_pressed(event) or _controls.talk_pressed(event)):
		_end_greeting()
		get_viewport().set_input_as_handled()
	elif not character_hud.is_open() and _controls.active() and (
			_controls.interact_pressed(event) or (not _observing() and _controls.talk_pressed(event))):
		# Defer selection to the physics tick: ray hits take priority over legacy NPC talk.
		# While an observed object is held up the interact key is the only way out, so talk is off.
		_pending_interaction = true
		get_viewport().set_input_as_handled()

## True while an observed object owns the player's action: frozen in place, but free to look around,
## and the interact key always means "put it back".
func _observing() -> bool:
	return interaction_service != null and not interaction_service.read_exclusive().is_empty()

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
	var observing: bool = _observing()
	# Held up for inspection: pinned in place so the object cannot be carried off, but the view
	# still turns (apply_look never depends on the session) and the shortcut teleports are off.
	if observing:
		session.set_movement(Vector2.ZERO, false)
	else:
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
		_sound.focus_changed(String(focus.get("target_id", "")))
		var exclusive: Dictionary = interaction_service.read_exclusive()
		if requested and enabled:
			if not exclusive.is_empty():
				var outcome: RefCounted = interaction_service.interact_exclusive(exclusive.revision)
				_interaction_hud.show_result("OK" if outcome.ok else outcome.code)
			elif not focus.is_empty():
				var result: RefCounted = interaction_service.interact(focus.target_id, focus.revision)
				_interaction_hud.show_result("OK" if result.ok else result.code)
			else:
				_open_greeting()
		_greeting.refresh_candidate(enabled and not observing and focus.is_empty())
		_interaction_hud.refresh(_controls.active() and not npc_hud.is_open() \
			and not _conversation_open())
	_sound.walked(player)

## Starts the exchange and freezes the manor around it. The greeting controller owns the candidate,
## the presence handshake and the view switch; what follows is the manor's own state.
func _open_greeting() -> void:
	if not _greeting.open():
		return
	_controls.set_ui_blocked(true)
	session.stop()
	_pending_interaction = false
	interaction_service.set_enabled(false)
	_interaction_hud.refresh(false)

## The greeting HUD dismissing itself and the dialogue view asking to leave both land here, because
## leaving a conversation also restores the manor's own UI and session state.
func _end_greeting() -> void:
	_greeting.close()
	_controls.set_ui_blocked(character_hud.is_open() or interaction_service == null)
	_pending_interaction = false
	session.stop()


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
