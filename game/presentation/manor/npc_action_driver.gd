extends "res://application/ports/npc_action_sink.gd"
## Executes only already-validated semantic actions against synthetic scene actors.
## The model sees anchor IDs; only this scene adapter resolves them to Vector3 values.

const Contract = preload("res://application/contracts/npc_action_contract.gd")

var _actors: Dictionary = {}
var _player: Node3D = null
var _anchors: Dictionary = {}
var _session_id: String = ""
var _scene_id: String = ""
var _revision_source: Object = null

func _init(actors: Array = [], player: Node3D = null, anchors: Dictionary = {},
		session_id: String = "", scene_id: String = "", revision_source: Object = null) -> void:
	_player = player
	_anchors = anchors.duplicate(true)
	_session_id = session_id
	_scene_id = scene_id
	_revision_source = revision_source
	for actor: Variant in actors:
		if actor != null and actor.get("npc_id") is String \
				and actor.has_method("apply_stay") and actor.has_method("apply_face_target") \
				and actor.has_method("apply_directed_destination"):
			_actors[actor.npc_id] = actor

func accept(proposal: Dictionary) -> RefCounted:
	var checked := Contract.validate(proposal)
	if not checked.ok:
		return checked
	var value: Dictionary = checked.value
	if _session_id.is_empty() or _scene_id.is_empty() or _revision_source == null \
			or not _revision_source.has_method("snapshot"):
		return Result.failure("NPC_ACTION_NOT_CONFIGURED")
	var snapshot: Variant = _revision_source.snapshot()
	if not snapshot is Dictionary or not snapshot.has("revision") \
			or not snapshot.revision is int:
		return Result.failure("NPC_ACTION_NOT_CONFIGURED")
	if value.session_id != _session_id or value.scene_id != _scene_id \
			or value.expected_revision != snapshot.revision:
		return Result.failure("NPC_ACTION_CONTEXT_MISMATCH")
	if not _actors.has(value.speaker_id) or _player == null:
		return Result.failure("NPC_ACTION_TARGET_UNAVAILABLE")
	var actor: Object = _actors[value.speaker_id]
	match value.command_id:
		"npc.stay":
			return Result.success() if value.parameters.is_empty() and actor.apply_stay() \
				else Result.failure("NPC_ACTION_REJECTED")
		"npc.face_player":
			return Result.success() if value.parameters.is_empty() \
				and actor.apply_face_target(_player.global_position) \
				else Result.failure("NPC_ACTION_REJECTED")
		"npc.move_to_anchor":
			if value.parameters.size() != 1 or not value.parameters.has("anchor_id") \
					or not value.parameters.anchor_id is String:
				return Result.failure("NPC_ACTION_REJECTED")
			var allowed: Dictionary = _anchors.get(value.speaker_id, {})
			if not allowed.has(value.parameters.anchor_id):
				return Result.failure("NPC_ACTION_ANCHOR_NOT_ALLOWED")
			var target: Variant = allowed[value.parameters.anchor_id]
			if not target is Vector3 or not target.is_finite():
				return Result.failure("NPC_ACTION_ANCHOR_INVALID")
			return Result.success() if actor.apply_directed_destination(target) \
				else Result.failure("NPC_ACTION_REJECTED")
		_:
			return Result.failure("NPC_ACTION_NOT_ALLOWED")
