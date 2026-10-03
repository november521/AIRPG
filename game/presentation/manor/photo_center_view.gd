extends Control
## Centred full-size view of the photograph drawn out of an observed object. Like the caption it is
## a mouse-ignoring overlay: it never releases the pointer and never freezes the walk session, so
## looking around and the interact key keep working while it is up. The texture is injected by
## bootstrap, so this layer knows no asset location of its own.
var _frame: TextureRect
var _shown: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = TextureRect.new()
	add_child(_frame)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The middle half of the screen height, width free: the card is centred and keeps its own aspect
	# ratio, so the whole face stays visible whatever the window shape is.
	_frame.anchor_top = 0.25
	_frame.anchor_bottom = 0.75
	_frame.offset_left = 0.0
	_frame.offset_right = 0.0
	_frame.offset_top = 0.0
	_frame.offset_bottom = 0.0
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = false

func show_face(texture: Texture2D) -> void:
	if texture == null or _frame == null:
		hide_face()
		return
	_frame.texture = texture
	_frame.visible = true
	_shown = true

func hide_face() -> void:
	_shown = false
	if _frame != null:
		_frame.visible = false

func shown() -> bool:
	return _shown and _frame != null and _frame.visible
