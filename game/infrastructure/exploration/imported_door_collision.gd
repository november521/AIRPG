extends RefCounted
## Removes baked door faces from the imported shared walk mesh.
## The delivered V4 walk mesh bakes all ten closed leaves together with their symmetric inset
## panels, which is why the per-door budgets below are higher than the V2 structure study needed.
## This adapter stays specific to the manor prototype's exported geometry.
const Result = preload("res://shared/result.gd")
const LEAF_PADDING: float = 0.06
const HANDLE_PADDING: float = 0.02
const MIN_FACES_PER_DOOR: int = 200
const MAX_FACES_PER_DOOR: int = 900

static func strip(model: Node3D, leaves: Array[MeshInstance3D], handles: Array[MeshInstance3D]) -> Result:
	if leaves.size() != handles.size() or leaves.is_empty():
		return Result.failure("MANOR_DOOR_BINDING_MISSING")
	var collision: StaticBody3D = model.get_node_or_null("ManorWalkCollision") as StaticBody3D
	if collision == null:
		return Result.failure("MANOR_COLLISION_MISSING")
	var shape_node: CollisionShape3D = collision.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or not shape_node.shape is ConcavePolygonShape3D:
		return Result.failure("MANOR_COLLISION_INVALID")
	var original: PackedVector3Array = (shape_node.shape as ConcavePolygonShape3D).get_faces()
	if original.size() % 3 != 0:
		return Result.failure("MANOR_COLLISION_INVALID")
	var bounds: Array[AABB] = []
	var to_leaf: Array[Transform3D] = []
	var door_indices: Array[int] = []
	for index: int in leaves.size():
		var leaf: MeshInstance3D = leaves[index]
		var handle: MeshInstance3D = handles[index]
		bounds.append(leaf.get_aabb().grow(LEAF_PADDING))
		to_leaf.append(leaf.global_transform.affine_inverse() * shape_node.global_transform)
		door_indices.append(index)
		if handle != null:
			bounds.append(handle.get_aabb().grow(HANDLE_PADDING))
			to_leaf.append(handle.global_transform.affine_inverse() * shape_node.global_transform)
			door_indices.append(index)
	var kept := PackedVector3Array()
	var removed: Array[int] = []
	removed.resize(leaves.size())
	removed.fill(0)
	for triangle: int in original.size() / 3:
		var offset: int = triangle * 3
		var door_index: int = _containing_door(original[offset], original[offset + 1],
			original[offset + 2], bounds, to_leaf, door_indices)
		if door_index >= 0:
			removed[door_index] += 1
		else:
			kept.push_back(original[offset])
			kept.push_back(original[offset + 1])
			kept.push_back(original[offset + 2])
	for count: int in removed:
		if count < MIN_FACES_PER_DOOR or count > MAX_FACES_PER_DOOR:
			return Result.failure("MANOR_DOOR_COLLISION_MISMATCH")
	var corrected: ConcavePolygonShape3D = (shape_node.shape as ConcavePolygonShape3D).duplicate()
	corrected.set_faces(kept)
	shape_node.shape = corrected
	return Result.success(removed)

static func _containing_door(a: Vector3, b: Vector3, c: Vector3,
		bounds: Array[AABB], to_leaf: Array[Transform3D], door_indices: Array[int]) -> int:
	for index: int in bounds.size():
		var transform: Transform3D = to_leaf[index]
		var box: AABB = bounds[index]
		if box.has_point(transform * a) and box.has_point(transform * b) and box.has_point(transform * c):
			return door_indices[index]
	return -1
