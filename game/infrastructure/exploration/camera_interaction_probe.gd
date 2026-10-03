extends "res://application/ports/interaction_probe.gd"
var _camera: Camera3D
var _player: CollisionObject3D
var _bindings: Dictionary
var _reach: float

func _init(camera: Camera3D, player: CollisionObject3D, bindings: Dictionary, reach: float) -> void:
	_camera = camera
	_player = player
	_bindings = bindings.duplicate()
	_reach = reach

func observe() -> Outcome:
	if not is_instance_valid(_camera) or not _camera.is_inside_tree():
		return Outcome.failure("NO_TARGET")
	var origin: Vector3 = _camera.global_position
	var end: Vector3 = origin - _camera.global_basis.z * _reach
	# World + existing NPC actor layer + pickup layer. A nearer NPC also occludes objects.
	var query := PhysicsRayQueryParameters3D.create(origin, end, 11, [_player.get_rid()])
	query.collide_with_areas = true
	var hit: Dictionary = _camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not _bindings.has(hit.collider):
		return Outcome.failure("NO_TARGET")
	return Outcome.success({"target_id": _bindings[hit.collider], "distance": origin.distance_to(hit.position)})

func bind_target(collider: CollisionObject3D, target_id: String) -> Outcome:
	if collider == null or target_id.is_empty() or _bindings.has(collider):
		return Outcome.failure("INVALID_TARGET_BINDING")
	_bindings[collider] = target_id
	return Outcome.success()
