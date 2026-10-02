extends CharacterBody3D

const WalkSession = preload("res://application/exploration/walk_session.gd")
var _session: WalkSession

func configure(session: WalkSession) -> void:
	_session = session

func _physics_process(delta: float) -> void:
	if _session == null:
		return
	var axis: Vector2 = _session.movement()
	var direction: Vector3 = basis * Vector3(axis.x, 0, axis.y)
	velocity.x = direction.x * _session.speed()
	velocity.z = direction.z * _session.speed()
	if is_on_floor() and velocity.y < 0:
		velocity.y = 0
	velocity.y -= 16.0 * delta
	move_and_slide()

func place_at(point: Vector3, yaw: float) -> void:
	position = point
	rotation.y = yaw
	velocity = Vector3.ZERO
	if _session != null:
		_session.stop()
