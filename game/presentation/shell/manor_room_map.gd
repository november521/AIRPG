extends RefCounted
## Coordinates follow the imported manor.glb floor meshes. Player position is in World space.

static func room_id(point: Vector3) -> String:
	var x: float = point.x
	var z: float = point.z
	if point.y < -1.05:
		return "cellar"
	if _inside(x, z, -2.12, 0.76, -12.80, -9.24):
		return "bathroom"
	if _inside(x, z, 0.76, 6.16, -12.80, -5.84):
		return "doctor_bedroom"
	if _inside(x, z, 0.76, 8.44, -5.84, 0.0):
		return "doctor_study"
	if _inside(x, z, -8.40, -2.12, -8.28, -3.20):
		return "emilia_bedroom"
	if _inside(x, z, -6.84, -2.12, -12.80, -8.28):
		if x <= -5.80 or x >= -4.60 or z >= -9.08 or z <= -12.48:
			return "emilia_study"
		return "cellar_stairs"
	if _inside(x, z, -8.40, -2.12, 0.0, 7.80):
		return "reception"
	if _inside(x, z, -2.12, 3.32, 0.0, 7.80):
		return "kitchen"
	if _inside(x, z, 3.32, 7.88, 0.0, 7.80):
		return "porch"
	if _inside(x, z, -6.28, -2.12, -3.20, 0.0) or _inside(x, z, -2.12, 0.76, -9.24, 0.0):
		return "hall"
	return "outside"

static func _inside(x: float, z: float, left: float, right: float, north: float, south: float) -> bool:
	return x >= left and x < right and z >= north and z < south
