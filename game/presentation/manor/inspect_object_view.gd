extends Node3D
## Manor observation view: reads the object's stage from the handler and only moves visuals between
## their floor slot and the player's hand socket. The authoritative stage lives in the use case,
## never here. The ray target never moves, so the object can always be aimed at and put back
## exactly where it was authored.
##
## An observed object need not travel as a whole, so the travelling node is named rather than
## assumed:
##   metal box -- nothing is named, so its own `Model` does.
##   wallet    -- `Model/Reveal` travels, so only the drawn photo is held while the wallet's own
##                `Model` stays exactly where the scene authored it.
##   diary     -- the opened book (`Book`) travels while the closed cover (`Model`) steps aside.
## Whichever node travels is always restored to its authored local Transform3D. The whole transform
## is kept, not just position and scale: an imported mesh may carry a rotation and an origin far
## from its visible geometry, and clearing either teleports it out of the room.
##
## `hidden_unless_held` is for travelling nodes that are a reveal rather than the object itself, and
## `stowed_node` names what the reveal replaces. Both are driven by the handler's own `held` flag,
## never by comparing stage numbers here: an object with several stages is in the hand for more than
## one of them.
const Handler = preload("res://application/exploration/interactions/interaction_handler.gd")
const Audio = preload("res://application/ports/audio_port.gd")
const Caption = preload("res://presentation/manor/inspect_caption.gd")
const Photo = preload("res://presentation/manor/photo_center_view.gd")
const HELD_STAGE: int = 2
const POSE_WHOLE_OBJECT := "whole"
const POSE_PHOTO_CARD := "photo"
const POSE_OPEN_BOOK := "book"
## Hand pose for a whole object (the metal box), local to `Camera/HandSocket`. That socket is a child
## of `Camera` at the camera origin with an identity basis, so these are camera-space metres.
const BOX_HAND_POSITION := Vector3(0.02, -0.12, -0.45)
## Hand pose for the photograph drawn out of the wallet, local to the same socket. The imported card
## is measured, not assumed: its visible card is a 7.2 x 8.8 x 0.4 unit plate whose centre sits
## 6.4 units from the photo node's own origin, and one unit is a centimetre. So the pose is built
## from the measured card frame -- short edge, long edge, front normal -- instead of from the node:
## the long edge is turned up and the front turned toward the eye, which puts a 9 x 11 cm card
## 0.30 m in front of the eye and 6 cm below it, upright and readable at the scale of a print.
const PHOTO_CARD_SHORT := Vector3(0.616, 0.235, 0.752)
const PHOTO_CARD_LONG := Vector3(-0.57, -0.526, 0.631)
const PHOTO_CARD_FRONT := Vector3(-0.5439, 0.8174, 0.1901)
const PHOTO_HAND_SCALE: float = 0.0125
const PHOTO_HAND_POSITION := Vector3(0.022659, -0.01569, -0.362818)
## Hand pose for the opened diary, local to the same socket. The imported book is measured too: its
## visible mesh is 2.0 x 1.558 x 0.2525 model units with the page side facing its own +Z and the
## spine running along its x axis, and the model carries no metric scale of its own. The measured
## diary cover is 0.253 x 0.329 m, so an opened copy measures about 0.44 x 0.34 m at this scale --
## roughly the two pages of that cover -- and the pose raises the far edge toward the eye.
const BOOK_HAND_SCALE: float = 0.2
const BOOK_HAND_POSITION := Vector3(0.0, -0.15, -0.48)
## -30 degrees.
const BOOK_HAND_TILT: float = -0.5235988
var _handler: Handler
var _holder: Node3D
var _caption: Caption
var _photo: Photo
var _photo_face: Texture2D
var _travelling: Node3D
var _travelling_rest: Transform3D
## The authored parent of the travelling node, captured on the first configure. A reveal sits inside
## the object's own model subtree, so `self` is not where it belongs once it comes back from the hand.
var _travelling_home: Node3D
var _stowed: Node3D
var _travelling_hidden_unless_held: bool = false
var _hand_pose: Transform3D = Transform3D(Basis(), BOX_HAND_POSITION)
## Sound is off until bootstrap attaches the scene's port. Two events belong to this view, and both
## are the state crossing a line rather than the command: the photograph being drawn out of the
## wallet (`pose == POSE_PHOTO_CARD`), and an appliance that is running while its stage is past a
## threshold -- the radio's static, which the switch that turns it on announces with an interface
## click because the click is the switch, not the speaker.
var _audio: Audio = Audio.new()
var _pose: String = POSE_WHOLE_OBJECT
var _appliance_kind: String = ""
var _appliance_from_stage: int = -1
var _appliance_on: bool = false
var _first_look: bool = true
var _held_before: bool = false

func configure(handler: Handler, holder: Node3D, travelling_node: String = "Model",
		pose: String = POSE_WHOLE_OBJECT, hidden_unless_held: bool = false,
		stowed_node: String = "", photo_face: Texture2D = null) -> void:
	_handler = handler
	_holder = holder
	_pose = pose
	_travelling_hidden_unless_held = hidden_unless_held
	_travelling = get_node_or_null(travelling_node) as Node3D
	if _travelling != null:
		if _travelling_home == null:
			_travelling_home = _travelling.get_parent() as Node3D
		_travelling_rest = _travelling.transform
	else:
		push_error("INSPECT_TRAVELLING_NODE_MISSING")
	_stowed = get_node_or_null(stowed_node) as Node3D
	_hand_pose = _hand_pose_for(pose)
	var layer := CanvasLayer.new()
	layer.name = "Caption"
	add_child(layer)
	_caption = Caption.new()
	layer.add_child(_caption)
	if photo_face != null:
		_photo_face = photo_face
		var photo_layer := CanvasLayer.new()
		photo_layer.name = "Photo"
		# Under the HUD and the caption: the photograph covers the middle of the screen, and the
		# prompt that says how to put it away has to stay readable on top of it.
		photo_layer.layer = 0
		add_child(photo_layer)
		_photo = Photo.new()
		photo_layer.add_child(_photo)
	_handler.changed.connect(_refresh)
	_refresh()

func caption_key() -> String:
	return _caption.shown_key() if _caption != null else ""

## Injected by bootstrap. This is the one-shot side: an object whose pose is the photograph card is
## heard being drawn out of its wallet.
func attach_audio(port: Audio) -> void:
	if port != null:
		_audio = port

## Injected by bootstrap for an observed object that is a running appliance: it plays `kind` from its
## own node while its stage is at or past `on_from_stage`. The view is the host because the source
## has to come out of this case, and the loop stops the moment the stage drops back below the line.
func attach_appliance(port: Audio, kind: String, on_from_stage: int) -> void:
	if port == null or kind.is_empty():
		return
	_audio = port
	_appliance_kind = kind
	_appliance_from_stage = on_from_stage
	_audio.attach_loop(kind, self)

## The use case this view draws. Bootstrap reads it for the one object that is also wired to the
## notebook port, so the wiring stays in the composition root and not in presentation.
func handler() -> Handler:
	return _handler

## True while the centred photograph is on screen. Presentation only: the stage still decides.
func photo_shown() -> bool:
	return _photo != null and _photo.shown()

## Resolves a named pose to the measured transform it stands for. An unknown name falls back to the
## whole-object pose rather than leaving the object at the camera origin.
func _hand_pose_for(pose: String) -> Transform3D:
	if pose == POSE_PHOTO_CARD:
		return _photo_hand_pose()
	if pose == POSE_OPEN_BOOK:
		return _book_hand_pose()
	return Transform3D(Basis(), BOX_HAND_POSITION)

## Resolved from the measured card frame: rows are the card axes that must land on the socket's
## right, up and forward axes, in that order.
func _photo_hand_pose() -> Transform3D:
	var frame := Basis(-PHOTO_CARD_SHORT, PHOTO_CARD_LONG, PHOTO_CARD_FRONT).transposed()
	return Transform3D(frame.scaled(Vector3.ONE * PHOTO_HAND_SCALE), PHOTO_HAND_POSITION)

## The book's own frame already has the page side on +Z and the spine along x, so the pose is the
## measured scale, a tilt about x, and a spot below the eyeline. Because the mesh origin sits at the
## middle of the open pages, the origin offset used here is the visible centre.
func _book_hand_pose() -> Transform3D:
	var tilt := Basis(Vector3.RIGHT, BOOK_HAND_TILT)
	return Transform3D(tilt.scaled(Vector3.ONE * BOOK_HAND_SCALE), BOOK_HAND_POSITION)

func _refresh() -> void:
	var view: Dictionary = _handler.read()
	var stage: int = int(view.get("stage", 0))
	var held: bool = bool(view.get("held", stage == HELD_STAGE))
	if _pose == POSE_PHOTO_CARD and not _first_look and held and not _held_before:
		_audio.play_sfx(Audio.PICKUP, global_position)
	_held_before = held
	if not _appliance_kind.is_empty():
		var want: bool = stage >= _appliance_from_stage
		if want != _appliance_on:
			if want and not _first_look:
				_audio.play_ui(Audio.UI_SWITCH)
			_appliance_on = want
			_audio.set_ambience(_appliance_kind, want)
	_first_look = false
	$Name.text = tr(String(view.get("name_key", "")))
	$Name.visible = not held
	if _caption != null:
		_caption.show_key(String(view.get("caption_key", "")))
	if _photo != null:
		if held:
			_photo.show_face(_photo_face)
		else:
			_photo.hide_face()
	if _travelling != null and _travelling_hidden_unless_held:
		_travelling.visible = held
	if _stowed != null:
		_stowed.visible = not held
	_attach(_travelling, _travelling_home, _hand_pose, _travelling_rest, held)

## The rest branch restores the node's authored transform under its authored parent; the held branch
## moves it under the socket and applies the hand pose. position/rotation/scale are written
## separately so a non-uniform basis survives the round trip unchanged.
func _attach(node: Node3D, home: Node3D, hand: Transform3D, rest: Transform3D, held: bool) -> void:
	if node == null or not is_inside_tree() or _holder == null or not is_instance_valid(_holder):
		return
	var target: Transform3D = hand if held else rest
	var parent: Node3D = _holder if held else home
	if parent == null or not is_instance_valid(parent):
		return
	if node.get_parent() != parent:
		node.reparent(parent)
	node.position = target.origin
	node.rotation = target.basis.get_euler()
	node.scale = target.basis.get_scale()

func _exit_tree() -> void:
	if _handler != null and _handler.changed.is_connected(_refresh):
		_handler.changed.disconnect(_refresh)
