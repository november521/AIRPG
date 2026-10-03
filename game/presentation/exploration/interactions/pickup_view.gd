extends Node3D
const Handler = preload("res://application/exploration/interactions/interaction_handler.gd")
const Audio = preload("res://application/ports/audio_port.gd")
var _handler: Handler
## Silent until bootstrap hands the scene's port over: a view built in a test, in a still-life capture
## or in a scene nobody wired simply has no sound, rather than a missing dependency.
var _audio: Audio = Audio.new()
## The receipt has been observed. The first refresh only records where the object started, so an
## object that is already claimed when it is placed cannot sound like it was just picked up.
var _seen: bool = false
var _claimed: bool = false

func configure(handler: Handler, name_key: String, quantity: int) -> void:
	_handler = handler
	$Name.text = tr(name_key) + " × " + str(quantity)
	_handler.changed.connect(_refresh)
	_refresh()

func configure_item(handler: Handler, name_key: String, quantity: int) -> void:
	configure(handler, name_key, quantity)

## Injected by bootstrap. This view owns one event: the receipt that takes the object out of the
## world. The first command on a pickup with a line only reads that line out, and the receipt is what
## changes, so the sound and the disappearance are the same fact.
func attach_audio(port: Audio) -> void:
	if port != null:
		_audio = port

func _refresh() -> void:
	var available: bool = _handler.read().available
	if not available and _seen and not _claimed:
		_claimed = true
		_audio.play_sfx(Audio.PICKUP, global_position)
	_seen = true
	visible = available
	$Target.collision_layer = 8 if available else 0

func _exit_tree() -> void:
	if _handler != null and _handler.changed.is_connected(_refresh):
		_handler.changed.disconnect(_refresh)
