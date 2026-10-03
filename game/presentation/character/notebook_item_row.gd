extends Button
## A compact handwritten inventory entry with a sketch and ruled-paper alignment.
const ItemSketch = preload("res://presentation/character/notebook_item_sketch.gd")
const INK := Color(0.17, 0.13, 0.09)
const MUTED := Color(0.36, 0.28, 0.19)

func configure(id: String, title: String, category: String, amount: int, book_font: Font) -> void:
	custom_minimum_size.y = 94
	add_theme_stylebox_override("normal", _paper_style(Color.TRANSPARENT))
	add_theme_stylebox_override("hover", _paper_style(Color(0.38, 0.27, 0.14, 0.13)))
	add_theme_stylebox_override("pressed", _paper_style(Color(0.38, 0.27, 0.14, 0.20)))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var contents := HBoxContainer.new()
	add_child(contents)
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contents.offset_left = 8
	contents.offset_right = -8
	contents.add_theme_constant_override("separation", 10)
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sketch: Control = ItemSketch.new()
	contents.add_child(sketch)
	sketch.custom_minimum_size = Vector2(58, 58)
	sketch.set("item_id", id)
	sketch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var labels := VBoxContainer.new()
	contents.add_child(labels)
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.add_theme_constant_override("separation", 0)
	_make_label(labels, title, 29, INK, book_font)
	_make_label(labels, category, 21, MUTED, book_font)
	var amount_label := _make_label(contents, "%02d" % amount, 24, MUTED, book_font)
	amount_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _make_label(parent: Control, value: String, font_size: int, color: Color, book_font: Font) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.text = value
	label.add_theme_font_override("font", book_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _paper_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Color(0.45, 0.36, 0.25, 0.36)
	style.border_width_bottom = 1
	style.set_corner_radius_all(4)
	return style
