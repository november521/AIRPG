extends Node3D
## Manor generator view. It reads the handler and shows the running state; the
## authoritative on/off flag lives in the use case, never here.
const Handler = preload("res://application/exploration/interactions/interaction_handler.gd")
const SHUDDER := Vector3(0.006, 0.0, 0.005)
var _handler: Handler
var _model: Node3D
var _model_rest: Vector3
var _running: bool = false
var _phase: float = 0.0

func configure(handler: Handler) -> void:
	_handler = handler
	# Only the visual shakes; the solid body and the placement stay authoritative.
	_model = $Model
	_model_rest = _model.position
	_handler.changed.connect(_refresh)
	_refresh()

func is_running() -> bool:
	return _running

func _refresh() -> void:
	_running = bool(_handler.read().get("running", false))
	$Running.visible = _running
	_phase = 0.0
	_model.position = _model_rest

func _process(delta: float) -> void:
	if not _running:
		return
	_phase += delta * 44.0
	_model.position = _model_rest + Vector3(sin(_phase) * SHUDDER.x, 0.0, cos(_phase * 1.31) * SHUDDER.z)

func _exit_tree() -> void:
	if _handler != null and _handler.changed.is_connected(_refresh):
		_handler.changed.disconnect(_refresh)
