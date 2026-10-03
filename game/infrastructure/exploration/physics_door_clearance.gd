extends "res://application/ports/door_clearance.gd"
## Sweeps the leaf through its motion and reports whether the path is free.
## A body already touching the leaf does not veto an opening move: leaning on a closed door is the
## pose players open it from, and the leaf swings away from them. It still blocks when the leaf
## would come to rest against it, and whenever the leaf closes.
const STEPS: int = 17
const MAX_CONTACTS: int = 8
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
	return _is_clear_sweep(start, finish, to_open)

func is_clear_pose(from_open: bool, to_open: bool, from_yaw: float, to_yaw: float) -> bool:
	var start: float = from_yaw if from_open else _closed_yaw
	var finish: float = to_yaw if to_open else _closed_yaw
	return _is_clear_sweep(start, finish, to_open)

func _is_clear_sweep(start: float, finish: float, opening: bool) -> bool:
	if not is_instance_valid(_body) or not _body.is_inside_tree():
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape.shape
	query.collision_mask = 6 # Existing NPC bodies on bit2 and player bodies on bit3.
	query.margin = 0.045
	var parent: Node3D = _body.get_parent()
	var resting: Dictionary = _contacts(query, parent, start) if opening else {}
	for step: int in range(1, STEPS):
		query.transform = _pose(parent, lerp_angle(start, finish, float(step) / float(STEPS - 1)))
		if _blocked(query, resting):
			return false
	if resting.is_empty():
		return true
	# Whoever was leaning on the leaf must be clear of it once the leaf stops moving.
	query.transform = _pose(parent, finish)
	return not _blocked(query, {})

func _blocked(query: PhysicsShapeQueryParameters3D, tolerated: Dictionary) -> bool:
	for contact: Dictionary in _body.get_world_3d().direct_space_state.intersect_shape(query, MAX_CONTACTS):
		if not tolerated.has(contact.rid):
			return true
	return false

func _contacts(query: PhysicsShapeQueryParameters3D, parent: Node3D, yaw: float) -> Dictionary:
	query.transform = _pose(parent, yaw)
	var found: Dictionary = {}
	for contact: Dictionary in _body.get_world_3d().direct_space_state.intersect_shape(query, MAX_CONTACTS):
		found[contact.rid] = true
	return found

func _pose(parent: Node3D, yaw: float) -> Transform3D:
	return parent.global_transform * Transform3D(Basis(Vector3.UP, yaw), _body.position) * _shape.transform
