extends RefCounted
## Who the player is standing in front of, and the greeting exchange around them: the candidate
## search, the presence handshake and the switch between the greeting HUD and the dialogue view.
## `open()` answers whether a greeting actually started, so the orchestrator keeps its own UI
## blocking, session and interaction state where they belong.
const NpcActor = preload("res://presentation/manor/npc_actor.gd")
var _presence: Object
var _actors: Array[NpcActor]
var _player: Node3D
var _camera: Camera3D
var _hud: Object
var _ai: Object
var _view: Control
var _candidate: NpcActor

func configure(presence: Object, actors: Array[NpcActor], player: Node3D, camera: Camera3D,
		hud: Object) -> void:
	_presence = presence
	_actors = actors
	_player = player
	_camera = camera
	_hud = hud

## The AI session and its dialogue view only exist once the runtime is configured, so they arrive
## later than everything else; until then a greeting falls back to the plain greeting HUD.
func attach_dialogue(ai: Object, view: Control) -> void:
	_ai = ai
	_view = view

## Recomputes who could be talked to. `eligible` carries the orchestrator's own gates -- controls
## active, nothing observed, no interaction focus -- because those are not this controller's business.
func refresh_candidate(eligible: bool) -> void:
	_candidate = find_candidate() if eligible else null
	_hud.show_candidate(_candidate.name_key if _candidate != null else "")

func find_candidate() -> NpcActor:
	var nearest: NpcActor
	var distance: float = _presence.TALK_RANGE
	for actor: NpcActor in _actors:
		var next: float = _player.position.distance_to(actor.position)
		if next <= distance and can_see(actor):
			nearest = actor
			distance = next
	return nearest

## Line of sight, not just proximity: the actor has to be in the view cone and unblocked, so a
## conversation cannot start through a wall the ray reaches first.
func can_see(actor: NpcActor) -> bool:
	var point := actor.global_position + Vector3(0, 1.2, 0)
	var direction := point - _camera.global_position
	if direction.normalized().dot(-_camera.global_basis.z) < 0.65:
		return false
	var ray := PhysicsRayQueryParameters3D.create(_camera.global_position, point, 3,
		[_player.get_rid()])
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.get("collider") == actor

## True when a greeting started: the orchestrator blocks its UI and stops walking only in that case.
func open() -> bool:
	_candidate = find_candidate()
	if _candidate == null:
		return false
	var reply = _presence.begin_greeting(_candidate.npc_id,
		_player.position.distance_to(_candidate.position), can_see(_candidate))
	if not reply.ok:
		return false
	_candidate.set_greeting_target(_player.global_position)
	if _ai != null and is_instance_valid(_view) and _ai.begin(_candidate.npc_id, _player, _view).ok:
		_hud.dismiss()
		_view.show()
	else:
		_hud.show_greeting(reply.value)
	return true

func close() -> void:
	if _candidate != null:
		_candidate.clear_greeting_target()
	_presence.end_greeting()
	if _ai != null:
		_ai.end()
	if is_instance_valid(_view):
		_view.hide()
	_hud.dismiss()
