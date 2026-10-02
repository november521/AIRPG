extends RefCounted
## Small native controls shared only by the archive presentation.
static func label(parent: Control, value: String, font_size: int = 18) -> Label:
	var node := Label.new()
	parent.add_child(node)
	node.text = value
	node.add_theme_font_size_override("font_size", font_size)
	return node

static func panel(parent: Control, light: bool = false) -> VBoxContainer:
	var box := PanelContainer.new()
	parent.add_child(box)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.76, 0.72, 0.62) if light else Color(0.075, 0.12, 0.14)
	style.border_color = Color(0.40, 0.40, 0.32)
	style.set_border_width_all(1)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	box.add_theme_stylebox_override("panel", style)
	if light:
		box.add_theme_color_override("font_color", Color(0.10, 0.12, 0.13))
	var column := VBoxContainer.new()
	box.add_child(column)
	column.add_theme_constant_override("separation", 12)
	return column

static func text(parent: Control, value: String) -> Label:
	var node := label(parent, value)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

static func bar(parent: Control, maximum: float = 100.0) -> ProgressBar:
	var node := ProgressBar.new()
	parent.add_child(node)
	node.max_value = maximum
	node.show_percentage = false
	node.custom_minimum_size.y = 14
	return node

static func row(parent: Control, title: String, value: String) -> Label:
	var line := HBoxContainer.new()
	parent.add_child(line)
	var name := label(line, title)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label(line, value)

static func button(parent: Control, title: String, callback: Callable) -> Button:
	var node := Button.new()
	parent.add_child(node)
	node.text = title
	node.pressed.connect(callback)
	return node

static func page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, title)
	var column := VBoxContainer.new()
	scroll.add_child(column)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	return column
