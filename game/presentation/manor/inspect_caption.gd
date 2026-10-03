extends Control
## Non-interactive caption for an observed object. Every node here ignores the mouse and the
## view never touches the walk session, so the pointer stays captured and F keeps working while
## the text is on screen. The text itself is a localization key supplied by the use case.
var _label: Label
var _key: String = ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_left = 200
	_label.offset_right = -200
	_label.offset_top = 118
	_label.offset_bottom = 330
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(0.96, 0.91, 0.81))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("outline_size", 8)
	_label.text = ""

func show_key(text_key: String) -> void:
	if text_key == _key:
		return
	_key = text_key
	_label.text = "" if text_key.is_empty() else tr(text_key)
	if _label.text.is_empty() or not is_inside_tree():
		_label.modulate.a = 1.0
		return
	_label.modulate.a = 0.0
	create_tween().tween_property(_label, "modulate:a", 1.0, 0.35)

func shown_key() -> String:
	return _key
