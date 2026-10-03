extends CharacterBody3D
## Session-scoped NPC body and presentation. Story knowledge stays in the application service.
const Presence = preload("res://application/exploration/npc_presence.gd")
const VISUAL = preload("res://presentation/manor/npc_preview_public.glb")
const WALK_SPEED: float = 0.65
const TURN_SPEED: float = 5.0
var _presence: Presence
var npc_id: String
var name_key: String
var _spawn: Vector3
var _target: Vector3
var _wait: float = 0.0
var _stuck: float = 0.0
var _visual: Node3D
var _animation: AnimationPlayer
var _clip: String = ""
var _greeting_target: Vector3 = Vector3.ZERO
var _has_greeting_target: bool = false
var _directive_active: bool = false
var _directive_command: String = ""
signal directive_completed(npc_id: String, command_id: String)
signal directive_failed(npc_id: String, command_id: String)

func configure(presence: Presence, entry: Dictionary) -> bool:
	_presence = presence
	npc_id = entry.id
	name_key = entry.name_key
	_spawn = entry.spawn
	position = _spawn
	_target = _spawn
	floor_snap_length = 0.3
	collision_layer = 2
	collision_mask = 7
	var shape := CapsuleShape3D.new()
	shape.radius = 0.22
	shape.height = 1.65
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.825
	add_child(collider)
	_visual = VISUAL.instantiate() as Node3D
	if _visual == null:
		return false
	_visual.name = "NpcVisual"
	add_child(_visual)
	_animation = _visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var skeleton := _visual.get_node_or_null("PreviewHumanoid/Skeleton3D") as Skeleton3D
	var body := _visual.get_node_or_null("PreviewHumanoid/Skeleton3D/PreviewBody") as MeshInstance3D
	if _animation == null or skeleton == null or skeleton.get_bone_count() != 17 or body == null or body.skin == null:
		return false
	for clip: String in ["idle", "walk", "talk"]:
		if not _animation.has_animation(clip):
			return false
		_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_tint_coat(body, entry.color)
	_play_clip("idle")
	var label := Label3D.new()
	label.text = tr(name_key)
	label.position.y = 1.98
	label.font_size = 32
	label.pixel_size = 0.0015
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	return true

func _tint_coat(body: MeshInstance3D, color: Color) -> void:
	for index: int in body.mesh.get_surface_count():
		var source := body.mesh.surface_get_material(index) as StandardMaterial3D
		if source != null and source.resource_name == "PreviewCoat":
			var material := source.duplicate() as StandardMaterial3D
			material.albedo_color = color
			body.set_surface_override_material(index, material)

func set_greeting_target(point: Vector3) -> void:
	_greeting_target = point
	_has_greeting_target = point.is_finite()

func clear_greeting_target() -> void:
	_has_greeting_target = false

func apply_stay() -> bool:
	_cancel_directive(false)
	_target = position
	return true

func apply_face_target(point: Vector3) -> bool:
	if not point.is_finite():
		return false
	_cancel_directive(false)
	_target = position
	set_greeting_target(point)
	return true

func apply_directed_destination(point: Vector3) -> bool:
	if not point.is_finite():
		return false
	_target = point
	_wait = 0.0
	_stuck = 0.0
	_directive_active = true
	_directive_command = "npc.move_to_anchor"
	return true

func visual_ready() -> bool:
	return _animation != null and _animation.has_animation("idle") and _animation.has_animation("walk") and _animation.has_animation("talk")

func current_clip() -> String:
	return _clip

func _play_clip(name: String) -> void:
	if name == _clip:
		return
	_clip = name
	_animation.play(name, 0.18)

func _physics_process(delta: float) -> void:
	if _presence == null or not visual_ready():
		return
	var previous := position
	var speaking: bool = _presence.paused(npc_id)
	var direction := Vector3(_target.x - position.x, 0, _target.z - position.z)
	if _directive_active and direction.length() < 0.18:
		var completed_command := _directive_command
		_cancel_directive(false)
		direction = Vector3.ZERO
		directive_completed.emit(npc_id, completed_command)
	elif speaking and not _directive_active:
		direction = Vector3.ZERO
	elif _wait > 0 and not _directive_active:
		_wait = maxf(0, _wait - delta)
		direction = Vector3.ZERO
	elif _directive_active and _stuck > 0.8:
		var failed_command := _directive_command
		_cancel_directive(false)
		direction = Vector3.ZERO
		directive_failed.emit(npc_id, failed_command)
	elif direction.length() < 0.18 or _stuck > 0.8:
		var next := _presence.destination(npc_id)
		if next.ok:
			_target = next.value
		_wait = 0.8
		_stuck = 0
		direction = Vector3.ZERO
	velocity.x = direction.normalized().x * WALK_SPEED
	velocity.z = direction.normalized().z * WALK_SPEED
	velocity.y = -1.0 if is_on_floor() else velocity.y - 16.0 * delta
	move_and_slide()
	var displacement := Vector3(position.x - previous.x, 0, position.z - previous.z)
	var moving: bool = (not speaking or _directive_active) and displacement.length() > 0.002
	var facing := Vector3.ZERO
	if speaking and _has_greeting_target:
		facing = _greeting_target - global_position
	elif moving:
		facing = displacement
	facing.y = 0
	if facing.length_squared() > 0.000001:
		var desired_yaw := atan2(facing.x, facing.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, minf(1.0, TURN_SPEED * delta))
	_play_clip("talk" if speaking else "walk" if moving else "idle")
	if direction.length() > 0.1 and not moving:
		_stuck += delta
	else:
		_stuck = 0
	if position.y < -7:
		if _directive_active:
			var failed_command := _directive_command
			_cancel_directive(false)
			directive_failed.emit(npc_id, failed_command)
		position = _spawn
		velocity = Vector3.ZERO
		_target = _spawn
		_play_clip("idle")

func _cancel_directive(emit_failure: bool) -> void:
	if emit_failure and _directive_active:
		directive_failed.emit(npc_id, _directive_command)
	_target = position
	_directive_active = false
	_directive_command = ""
	_stuck = 0.0
