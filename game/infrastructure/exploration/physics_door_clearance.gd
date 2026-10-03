extends "res://application/ports/door_clearance.gd"
var _body: AnimatableBody3D
var _shape: CollisionShape3D
var _closed_yaw: float
var _open_yaw: float

func _init(body: AnimatableBody3D, shape: CollisionShape3D, closed_yaw: float, open_yaw: float) -> void:
	_body = body
	_shape = shape
	_closed_yaw = closed_yaw
	_open_yaw = open_yaw

func is_clear(from_open: bool, to_open: bool) -> bool:
	var start: float = _open_yaw if from_open else _closed_yaw
	var finish: float = _open_yaw if to_open else _closed_yaw
	return _is_clear_sweep(start, finish)

func is_clear_pose(from_open: bool, to_open: bool, from_yaw: float, to_yaw: float) -> bool:
	var start: float = from_yaw if from_open else _closed_yaw
	var finish: float = to_yaw if to_open else _closed_yaw
	return _is_clear_sweep(start, finish)

func _is_clear_sweep(start: float, finish: float) -> bool:
	if not is_instance_valid(_body) or not _body.is_inside_tree():
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape.shape
	query.collision_mask = 6 # Existing NPC bodies on bit2 and player bodies on bit3.
	query.margin = 0.045
	var parent: Node3D = _body.get_parent()
	for step: int in 17:
		var yaw: float = lerp_angle(start, finish, float(step) / 16.0)
		query.transform = parent.global_transform * Transform3D(Basis(Vector3.UP, yaw), _body.position) * _shape.transform
		if not _body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return false
	return true
