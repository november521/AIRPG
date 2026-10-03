extends Node3D
## Presentation for the concealed cellar entrance: the boards that cover the stairwell, and the one
## collision body that keeps the player out of it. It holds no state of its own -- it asks the handler
## whether the entrance has been pried up, and then stops drawing the boards and takes that body off
## every layer, which is all that uncovers the stairwell the walk mesh already leaves open underneath.
##
## The body is also the aim ray target: bootstrap binds it directly, so the one event that opens the
## hole is the same event that stops the entrance from claiming the crosshair. Nothing here makes the
## descent possible; it only stops hiding it, and the shipped .glb is never touched.
##
## When the entrance gives way it tells one line, on the scene's narrative layer rather than one of
## its own: the handler publishes that line only after a successful opening, so a refusal shows the
## refusal's wording and nothing else, and a second command -- which the handler refuses, because an
## open entrance has no way back -- cannot repeat it.
const Handler = preload("res://application/exploration/interactions/interaction_handler.gd")
const Audio = preload("res://application/ports/audio_port.gd")
const Caption = preload("res://presentation/manor/narrative_caption.gd")
var _handler: Handler
var _boards: Node3D
var _blocker: CollisionObject3D
var _blocker_layer: int = 1
var _captions: Caption
## Two sounds and one moment: the boards are timber nailed over a stone lip, so coming up is a wood
## give followed by the metal of the bar. The entrance has no way back, so this fires exactly once.
var _audio: Audio = Audio.new()
var _seen: bool = false
var _was_open: bool = false

func configure(handler: Handler, boards: Node3D, blocker: CollisionObject3D,
		captions: Caption = null) -> void:
	_handler = handler
	_boards = boards
	_blocker = blocker
	_captions = captions
	if _blocker != null:
		_blocker_layer = _blocker.collision_layer
	_handler.changed.connect(_refresh)
	_refresh()

## Injected by bootstrap.
func attach_audio(port: Audio) -> void:
	if port != null:
		_audio = port

func is_open() -> bool:
	return _handler != null and not bool(_handler.read().get("locked", true))

## Read-only view of what is drawn, so a test can assert a refused pry left the boards alone.
func boards_visible() -> bool:
	return _boards != null and is_instance_valid(_boards) and _boards.visible

## The collision layer the boards' body sits on while the entrance is shut.
func blocker_layer() -> int:
	return _blocker.collision_layer if _blocker != null and is_instance_valid(_blocker) else -1

func _refresh() -> void:
	var open: bool = is_open()
	if open and _seen and not _was_open:
		_audio.play_sfx(Audio.PRY_WOOD, global_position)
		_audio.play_sfx(Audio.PRY_METAL, global_position)
	_was_open = open
	_seen = true
	if _boards != null and is_instance_valid(_boards):
		_boards.visible = not open
	if _blocker != null and is_instance_valid(_blocker):
		_blocker.collision_layer = 0 if open else _blocker_layer
	if _captions != null:
		_captions.show_key(String(_handler.read().get("caption_key", "")))

func _exit_tree() -> void:
	if _handler != null and _handler.changed.is_connected(_refresh):
		_handler.changed.disconnect(_refresh)
