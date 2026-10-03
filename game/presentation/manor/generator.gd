extends Node3D
## Manor generator view. It reads the handler and shows the running state; the
## authoritative on/off flag lives in the use case, never here. It also draws the handler's own
## first-look line: the layer ignores the mouse and never touches the walk session, so the pointer
## stays captured and F keeps working while the inspection text is on screen.
##
## The machine's voice belongs here for the same reason its lamp does: the loop has to come out of
## this casing and move with it, so the view is the host the audio port hangs the source on, and the
## running flag is what switches it. Starting also gets the one-shot pair -- the crank, and a pour of
## kerosene only when the device actually asked for fuel, which is exactly the run that consumed a
## gated start.
const Handler = preload("res://application/exploration/interactions/interaction_handler.gd")
const Audio = preload("res://application/ports/audio_port.gd")
const Caption = preload("res://presentation/manor/inspect_caption.gd")
const SHUDDER := Vector3(0.006, 0.0, 0.005)
var _handler: Handler
var _model: Node3D
var _model_rest: Vector3
var _running: bool = false
var _caption: Caption
var _phase: float = 0.0
## Silent until bootstrap attaches the port, and silent on the first refresh either way: a device
## that starts its life stopped must not sound like it was just switched off.
var _audio: Audio = Audio.new()
var _seen: bool = false

func configure(handler: Handler) -> void:
	_handler = handler
	# Only the visual shakes; the solid body and the placement stay authoritative.
	_model = $Model
	_model_rest = _model.position
	var layer := CanvasLayer.new()
	layer.name = "Caption"
	add_child(layer)
	_caption = Caption.new()
	layer.add_child(_caption)
	_handler.changed.connect(_refresh)
	_refresh()

## Injected by bootstrap before `configure`. The loop is bound to this node, so it is heard from the
## machine and stops being heard when the machine leaves the scene.
func attach_audio(port: Audio) -> void:
	if port == null:
		return
	_audio = port
	_audio.attach_loop(Audio.GENERATOR_LOOP, self)

func is_running() -> bool:
	return _running

## The localization key currently on screen, so a test can assert the first look without a window.
func caption_key() -> String:
	return _caption.shown_key() if _caption != null else ""

func _refresh() -> void:
	var view: Dictionary = _handler.read()
	var running: bool = bool(view.get("running", false))
	if _seen and running != _running:
		if running:
			_audio.play_sfx(Audio.GENERATOR_CRANK, global_position)
			if not String(view.get("requires", "")).is_empty():
				_audio.play_sfx(Audio.POUR_KEROSENE, global_position)
		_audio.set_ambience(Audio.GENERATOR_LOOP, running)
	_running = running
	_seen = true
	$Running.visible = _running
	if _caption != null:
		_caption.show_key(String(view.get("caption_key", "")))
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
