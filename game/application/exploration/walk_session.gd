extends RefCounted

var _axis := Vector2.ZERO
var _slow: bool = false

func set_movement(axis: Vector2, slow: bool = false) -> void:
	_axis = axis.limit_length(1.0) if axis.is_finite() else Vector2.ZERO
	_slow = slow

func movement() -> Vector2:
	return _axis

func speed() -> float:
	return 1.2 if _slow else 2.6

func stop() -> void:
	_axis = Vector2.ZERO
