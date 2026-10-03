extends RefCounted
## Palette, styleboxes and widget factories for the investigator creation page.
##
## Presentation only: no state, no service access, no player-visible strings.

const Plate = preload("res://presentation/character/creation_plate.gd")
const BackdropShader = preload("res://presentation/character/creation_backdrop.gdshader")

# Surface colours sampled from the approved reference layout.
const FRAME_FILL := Color(0.051, 0.063, 0.071, 0.92)
const FRAME_LINE := Color(0.78, 0.69, 0.60)
# The header and footer bands sit noticeably lighter than the body in the
# reference layout, which is what separates them from the card area.
const BAR_FILL := Color(0.094, 0.110, 0.114, 0.94)
const PANEL_FILL := Color(0.067, 0.082, 0.086, 0.93)
const PANEL_LINE := Color(0.22, 0.20, 0.176)
const HAIRLINE := Color(0.196, 0.176, 0.145)
const DIVIDER := Color(0.36, 0.32, 0.26)
const ROW_RULE := Color(0.153, 0.137, 0.114)
const INPUT_FILL := Color(0.075, 0.088, 0.092)
const INPUT_LINE := Color(0.27, 0.24, 0.20)
const BUTTON_FILL := Color(0.125, 0.137, 0.14)
const BUTTON_HOVER := Color(0.18, 0.196, 0.20)
const BUTTON_LINE := Color(0.30, 0.27, 0.23)
const BUTTON_OFF := Color(0.075, 0.082, 0.084)
const BUTTON_OFF_LINE := Color(0.16, 0.15, 0.13)
const CONFIRM_FILL := Color(0.761, 0.627, 0.459)
const CONFIRM_HOVER := Color(0.851, 0.722, 0.541)
const CONFIRM_LINE := Color(0.91, 0.816, 0.635)
const CONFIRM_TEXT := Color(0.141, 0.11, 0.071)

# Type colours.
const GOLD := Color(0.890, 0.812, 0.624)
const GOLD_BRIGHT := Color(0.941, 0.816, 0.541)
const PAPER := Color(0.941, 0.925, 0.886)
const MUTED := Color(0.663, 0.620, 0.553)
const DIM := Color(0.702, 0.604, 0.490)
const DISABLED_TEXT := Color(0.42, 0.40, 0.36)

static var _fonts: Dictionary = {}

static func sans(weight: int) -> Font:
	var key := str(weight)
	if not _fonts.has(key):
		var font := SystemFont.new()
		font.font_names = PackedStringArray(
			["Microsoft YaHei", "Noto Sans SC", "Source Han Sans SC", "PingFang SC", "sans-serif"])
		font.font_weight = weight
		_fonts[key] = font
	return _fonts[key]

static func heading() -> Font:
	## The reference layout's display type is a semibold: the system's full
	## Bold reads too heavy, so the regular face is emboldened a little.
	if not _fonts.has("heading"):
		var variation := FontVariation.new()
		variation.base_font = sans(400)
		variation.variation_embolden = 0.38
		_fonts["heading"] = variation
	return _fonts["heading"]

static func title_font() -> Font:
	## Section captions sit a weight lighter than the page title in the
	## reference layout.
	return sans(400)

static func plate(fill: Color, line: Color, cut: float, line_width: float = 1.0) -> StyleBox:
	var style: StyleBox = Plate.new()
	style.set("fill", fill)
	style.set("line", line)
	style.set("cut", cut)
	style.set("line_width", line_width)
	return style

static func pad(style: StyleBox, values: Vector4) -> StyleBox:
	style.content_margin_left = values.x
	style.content_margin_top = values.y
	style.content_margin_right = values.z
	style.content_margin_bottom = values.w
	return style

static func backdrop(parent: Control) -> ColorRect:
	var rect := ColorRect.new()
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = BackdropShader
	rect.material = material
	return rect

static func plate_box(parent: Control, fill: Color, line: Color, cut: float,
		insets: Vector4) -> PanelContainer:
	var host := PanelContainer.new()
	parent.add_child(host)
	host.add_theme_stylebox_override("panel", pad(plate(fill, line, cut), insets))
	return host

static func label(parent: Control, value: String, size: int, color: Color,
		font: Font = null) -> Label:
	var node := Label.new()
	parent.add_child(node)
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if font != null:
		node.add_theme_font_override("font", font)
	return node

static func fade_rule(parent: Control) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.62, 0.52, 0.38, 0.55))
	gradient.set_color(1, Color(0.62, 0.52, 0.38, 0.06))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(1.0, 0.0)
	texture.width = 256
	texture.height = 1
	var node := TextureRect.new()
	parent.add_child(node)
	node.texture = texture
	node.custom_minimum_size.y = 1
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

static func section(parent: Control, title: String, expand: bool = false) -> VBoxContainer:
	## Builds a chamfered section card and returns the container for its rows.
	var host := plate_box(parent, PANEL_FILL, PANEL_LINE, 14.0, Vector4(44, 24, 44, 26))
	if expand:
		host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	host.add_child(column)
	column.add_theme_constant_override("separation", 14)
	if expand:
		column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(section_head(title))
	var body := VBoxContainer.new()
	column.add_child(body)
	body.add_theme_constant_override("separation", 14)
	if expand:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return body

static func bar(fill: Color, line: Color, top: bool, bottom: bool, insets: Vector4) -> StyleBoxFlat:
	## Straight-edged band for the header and footer strips, which are square
	## (only the outer frame is chamfered).
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = line
	style.border_width_top = 1 if top else 0
	style.border_width_bottom = 1 if bottom else 0
	return pad(style, insets) as StyleBoxFlat

static func section_head(title: String) -> VBoxContainer:
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	var row := HBoxContainer.new()
	head.add_child(row)
	row.add_theme_constant_override("separation", 10)
	var caption := label(row, title, 30, GOLD, title_font())
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot := Panel.new()
	row.add_child(dot)
	dot.add_theme_stylebox_override("panel", plate(GOLD, GOLD, 5.0, 0.0))
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rule(row)
	var brush := Panel.new()
	head.add_child(brush)
	brush.add_theme_stylebox_override("panel",
		plate(Color(GOLD.r, GOLD.g, GOLD.b, 0.62), Color.TRANSPARENT, 1.0, 0.0))
	brush.custom_minimum_size = Vector2(58, 2)
	brush.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	brush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return head

static func step_button(parent: Control, glyph: String) -> Button:
	var button := button_base(parent, glyph, 30, PAPER)
	button.custom_minimum_size = Vector2(72, 52)
	button.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	button.add_theme_stylebox_override("normal", plate(BUTTON_FILL, BUTTON_LINE, 8.0))
	button.add_theme_stylebox_override("hover", plate(BUTTON_HOVER, GOLD, 8.0))
	button.add_theme_stylebox_override("pressed", plate(BUTTON_HOVER, GOLD_BRIGHT, 8.0))
	button.add_theme_stylebox_override("disabled", plate(BUTTON_OFF, BUTTON_OFF_LINE, 8.0))
	return button

static func value_field(parent: Control) -> LineEdit:
	var entry := LineEdit.new()
	parent.add_child(entry)
	entry.custom_minimum_size = Vector2(143, 52)
	entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry.max_length = 3
	entry.add_theme_font_size_override("font_size", 28)
	entry.add_theme_color_override("font_color", Color.WHITE)
	entry.add_theme_color_override("font_uneditable_color", MUTED)
	entry.add_theme_color_override("caret_color", GOLD_BRIGHT)
	entry.add_theme_color_override("selection_color", Color(0.72, 0.60, 0.38, 0.45))
	entry.add_theme_stylebox_override("normal", field_plate(INPUT_LINE))
	entry.add_theme_stylebox_override("focus", field_plate(GOLD_BRIGHT))
	entry.add_theme_stylebox_override("read_only", field_plate(INPUT_LINE))
	return entry

static func field_plate(line: Color) -> StyleBox:
	return pad(plate(INPUT_FILL, line, 8.0), Vector4(10, 6, 10, 6))

static func line_field(parent: Control) -> LineEdit:
	var entry := LineEdit.new()
	parent.add_child(entry)
	entry.custom_minimum_size.y = 56
	entry.max_length = 80
	entry.add_theme_font_size_override("font_size", 22)
	entry.add_theme_color_override("font_color", PAPER)
	entry.add_theme_color_override("font_placeholder_color", Color(0.55, 0.52, 0.47))
	entry.add_theme_color_override("font_uneditable_color", MUTED)
	entry.add_theme_color_override("caret_color", GOLD_BRIGHT)
	entry.add_theme_color_override("selection_color", Color(0.72, 0.60, 0.38, 0.45))
	entry.add_theme_stylebox_override("normal", pad(plate(INPUT_FILL, INPUT_LINE, 8.0), Vector4(14, 8, 14, 8)))
	entry.add_theme_stylebox_override("focus", pad(plate(INPUT_FILL, GOLD_BRIGHT, 8.0), Vector4(14, 8, 14, 8)))
	entry.add_theme_stylebox_override("read_only", pad(plate(INPUT_FILL, INPUT_LINE, 8.0), Vector4(14, 8, 14, 8)))
	return entry

static func text_area(parent: Control) -> TextEdit:
	var area := TextEdit.new()
	parent.add_child(area)
	area.add_theme_font_size_override("font_size", 21)
	area.add_theme_color_override("font_color", PAPER)
	area.add_theme_color_override("font_placeholder_color", Color(0.55, 0.52, 0.47))
	area.add_theme_color_override("font_readonly_color", MUTED)
	area.add_theme_color_override("caret_color", GOLD_BRIGHT)
	area.add_theme_color_override("selection_color", Color(0.72, 0.60, 0.38, 0.45))
	area.add_theme_stylebox_override("normal", pad(plate(INPUT_FILL, INPUT_LINE, 8.0), Vector4(14, 12, 14, 12)))
	area.add_theme_stylebox_override("focus", pad(plate(INPUT_FILL, GOLD_BRIGHT, 8.0), Vector4(14, 12, 14, 12)))
	area.add_theme_stylebox_override("read_only", pad(plate(INPUT_FILL, INPUT_LINE, 8.0), Vector4(14, 12, 14, 12)))
	area.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	return area

static func ghost_button(parent: Control, title: String, size: Vector2) -> Button:
	var button := button_base(parent, title, 22, PAPER)
	button.custom_minimum_size = size
	button.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	button.add_theme_stylebox_override("normal", plate(BUTTON_FILL, BUTTON_LINE, 8.0))
	button.add_theme_stylebox_override("hover", plate(BUTTON_HOVER, GOLD, 8.0))
	button.add_theme_stylebox_override("pressed", plate(BUTTON_HOVER, GOLD_BRIGHT, 8.0))
	button.add_theme_stylebox_override("disabled", plate(BUTTON_OFF, BUTTON_OFF_LINE, 8.0))
	return button

static func confirm_button(parent: Control, title: String, size: Vector2) -> Button:
	var button := button_base(parent, title, 25, CONFIRM_TEXT)
	button.custom_minimum_size = size
	button.add_theme_color_override("font_hover_color", Color(0.09, 0.07, 0.04))
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	button.add_theme_stylebox_override("normal", plate(CONFIRM_FILL, CONFIRM_LINE, 8.0))
	button.add_theme_stylebox_override("hover", plate(CONFIRM_HOVER, CONFIRM_LINE, 8.0))
	button.add_theme_stylebox_override("pressed", plate(CONFIRM_FILL, CONFIRM_LINE, 8.0))
	button.add_theme_stylebox_override("disabled", plate(BUTTON_OFF, BUTTON_OFF_LINE, 8.0))
	return button

static func button_base(parent: Control, title: String, size: int, color: Color) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.text = title
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_font_override("font", heading())
	button.add_theme_color_override("font_color", color)
	button.add_theme_stylebox_override("focus", plate(Color.TRANSPARENT, Color.TRANSPARENT, 8.0, 0.0))
	return button
