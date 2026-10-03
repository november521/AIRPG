extends Node
const Door = preload("res://application/exploration/interactions/door_interaction.gd")
const DURATION: float = 0.42
var _handler: Door
var _body: AnimatableBody3D
var _closed_yaw: float
var _start_yaw: float
var _target_yaw: float
var _elapsed: float = 0.0
var _animating: bool = false

func configure(handler: Door, body: AnimatableBody3D, closed_yaw: float) -> void:
	_handler = handler
	_body = body
	_closed_yaw = closed_yaw
	_body.rotation.y = _closed_yaw
	set_physics_process(false)
	_handler.changed.connect(_refresh)

func _refresh() -> void:
	var view: Dictionary = _handler.read()
	var target: float = view.open_yaw if view.open else _closed_yaw
	if is_equal_approx(_body.rotation.y, target):
		return
	_start_yaw = _body.rotation.y
	_target_yaw = target
	_elapsed = 0.0
	_animating = true
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if not _animating:
		return
	_elapsed = minf(_elapsed + delta, DURATION)
	var t: float = _elapsed / DURATION
	var eased: float = t * t * (3.0 - 2.0 * t)
	_body.rotation.y = lerp_angle(_start_yaw, _target_yaw, eased)
	if _elapsed >= DURATION:
		_body.rotation.y = _target_yaw
		_animating = false
		set_physics_process(false)
		_handler.finish_motion()

func _exit_tree() -> void:
	if _handler != null and _handler.changed.is_connected(_refresh):
		_handler.changed.disconnect(_refresh)
