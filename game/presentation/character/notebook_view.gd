extends RefCounted
## Builds the investigator notebook and exploration HUD nodes for character_hud.gd.

const NotebookIcon = preload("res://presentation/character/notebook_icon.gd")
const ItemSketch = preload("res://presentation/character/notebook_item_sketch.gd")
const PaperShader = preload("res://presentation/character/notebook_paper.gdshader")
const SketchPaper = preload("res://presentation/character/notebook_sketch_paper.gdshader")

const INK := Color(0.15, 0.12, 0.09)
const MUTED := Color(0.30, 0.24, 0.17)
const GOLD := Color(0.82, 0.68, 0.47)

static func _t(key: String) -> String:
	# Node.tr() is not callable from a static builder; the server call is equivalent.
	return TranslationServer.translate(key)

static func style(fill: Color, border: Color, width: int, inset: int, radius: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(inset)
	box.set_corner_radius_all(radius)
	return box

static func label(parent: Control, value: String, size: int, color: Color, font: Font = null) -> Label:
	var node := Label.new()
	parent.add_child(node)
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if font != null:
		node.add_theme_font_override("font", font)
	return node

static func bar(parent: Control, fill: Color) -> ProgressBar:
	var node := ProgressBar.new()
	parent.add_child(node)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.custom_minimum_size = Vector2(110, 9)
	node.show_percentage = false
	node.add_theme_stylebox_override("background", style(Color(0.35, 0.36, 0.35), Color.TRANSPARENT, 0, 0))
	node.add_theme_stylebox_override("fill", style(fill, Color.TRANSPARENT, 0, 0))
	return node

static func button(parent: Control, title: String, callback: Callable, font: Font) -> Button:
	var node := Button.new()
	parent.add_child(node)
	node.text = title
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", INK)
	node.add_theme_font_size_override("font_size", 25)
	node.custom_minimum_size.y = 45
	node.add_theme_font_override("font", font)
	node.add_theme_stylebox_override("normal", style(Color(0.87, 0.80, 0.65), Color(0.55, 0.44, 0.31), 1, 8))
	node.add_theme_stylebox_override("hover", style(Color(0.94, 0.86, 0.69), Color(0.40, 0.30, 0.20), 1, 8))
	node.pressed.connect(callback)
	return node

static func page(parent: Control, left_margin: int, right_margin: int, font: Font) -> VBoxContainer:
	var paper := PanelContainer.new()
	parent.add_child(paper)
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margins := style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 28)
	margins.content_margin_left = left_margin
	margins.content_margin_right = right_margin
	margins.content_margin_top = 78
	margins.content_margin_bottom = 82
	paper.add_theme_stylebox_override("panel", margins)
	paper.add_theme_font_override("font", font)
	var column := VBoxContainer.new()
	paper.add_child(column)
	column.add_theme_constant_override("separation", 16)
	return column

static func build_meter(parent: Control) -> Dictionary:
	var meter := PanelContainer.new()
	parent.add_child(meter)
	meter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	meter.offset_left = -330
	meter.offset_right = -28
	meter.offset_top = 24
	meter.add_theme_stylebox_override("panel", style(Color(0.035, 0.043, 0.043, 0.59), Color.TRANSPARENT, 0, 14, 12))
	var column := VBoxContainer.new()
	meter.add_child(column)
	column.add_theme_constant_override("separation", 7)
	label(column, _t("ui.investigator_status"), 14, GOLD)
	var hp_row := HBoxContainer.new()
	column.add_child(hp_row)
	label(hp_row, _t("dossier.hp"), 20, Color.WHITE).custom_minimum_size.x = 54
	var hp := bar(hp_row, GOLD)
	var hp_number := label(hp_row, "", 19, Color.WHITE)
	var sanity_row := HBoxContainer.new()
	column.add_child(sanity_row)
	label(sanity_row, _t("dossier.sanity"), 20, Color.WHITE).custom_minimum_size.x = 54
	var sanity := bar(sanity_row, Color(0.65, 0.77, 0.77))
	var sanity_number := label(sanity_row, "", 19, Color.WHITE)
	return {"meter": meter, "hp": hp, "hp_number": hp_number, "sanity": sanity, "sanity_number": sanity_number}

static func build_bag(parent: Control, on_open: Callable) -> Button:
	var bag := Button.new()
	parent.add_child(bag)
	bag.text = _t("ui.bag_hint")
	bag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	bag.offset_left = -245
	bag.offset_right = -28
	bag.offset_top = -69
	bag.offset_bottom = -23
	bag.add_theme_color_override("font_color", GOLD)
	bag.add_theme_font_size_override("font_size", 21)
	bag.add_theme_stylebox_override("normal", style(Color(0.04, 0.055, 0.055, 0.78), GOLD, 1, 8, 6))
	var book_icon: Control = NotebookIcon.new()
	bag.add_child(book_icon)
	book_icon.position = Vector2(14, 11)
	book_icon.size = Vector2(24, 24)
	book_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag.pressed.connect(on_open)
	return bag

static func build_notebook(parent: Control, callbacks: Dictionary) -> Dictionary:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["KaiTi", "STKaiti", "FangSong"])
	var dimmer := ColorRect.new()
	parent.add_child(dimmer)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.015, 0.018, 0.019, 0.83)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.anchor_left = 0.055
	panel.anchor_top = 0.075
	panel.anchor_right = 0.945
	panel.anchor_bottom = 0.925
	panel.add_theme_stylebox_override("panel", style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	var book_texture := ColorRect.new()
	panel.add_child(book_texture)
	book_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_material := ShaderMaterial.new()
	paper_material.shader = PaperShader
	book_texture.material = paper_material
	var pages := HBoxContainer.new()
	panel.add_child(pages)
	pages.add_theme_constant_override("separation", 0)
	var left := page(pages, 120, 75, font)
	var header := HBoxContainer.new()
	left.add_child(header)
	var title := VBoxContainer.new()
	header.add_child(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label(title, _t("ui.notebook_number"), 18, MUTED, font)
	label(title, _t("ui.notebook_title"), 46, INK, font)
	var close := button(header, "×", callbacks.close, font)
	close.custom_minimum_size = Vector2(42, 42)
	var rule := ColorRect.new()
	left.add_child(rule)
	rule.color = Color(0.44, 0.36, 0.26, 0.6)
	rule.custom_minimum_size.y = 1
	var tab_row := HBoxContainer.new()
	left.add_child(tab_row)
	var tabs: Array[Button] = []
	for index: int in 3:
		var key: String = ["dossier.tab.items", "ui.notebook.clues", "ui.notebook.people"][index]
		tabs.append(button(tab_row, _t(key), callbacks.select_tab.bind(index), font))
	var item_page := Control.new()
	left.add_child(item_page)
	item_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	item_page.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var other_pages: Array[Control] = []
	for key: String in ["ui.notebook.clues_pending", "ui.notebook.people_pending"]:
		var empty := label(left, _t(key), 30, MUTED, font)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		other_pages.append(empty)
	var spine := ColorRect.new()
	pages.add_child(spine)
	spine.color = Color(0.44, 0.34, 0.23)
	spine.custom_minimum_size.x = 9
	var right := page(pages, 60, 120, font)
	label(right, _t("ui.object_study"), 18, MUTED, font)
	var picture := PanelContainer.new()
	right.add_child(picture)
	picture.custom_minimum_size = Vector2(620, 240)
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picture.add_theme_stylebox_override("panel", style(Color(0.88, 0.82, 0.69), Color(0.64, 0.55, 0.40), 1, 10))
	var card_texture := ColorRect.new()
	picture.add_child(card_texture)
	card_texture.material = ShaderMaterial.new()
	card_texture.material.shader = SketchPaper
	card_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sketch: Control = ItemSketch.new()
	picture.add_child(sketch)
	sketch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := label(right, "", 42, INK, font)
	var count := label(right, "", 25, MUTED, font)
	var description := label(right, "", 30, MUTED, font)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var actions := HFlowContainer.new()
	right.add_child(actions)
	actions.add_theme_constant_override("h_separation", 10)
	actions.add_theme_constant_override("v_separation", 8)
	var hold := button(actions, _t("hud.hold"), callbacks.hold, font)
	var use_held := button(actions, _t("hud.use_held"), callbacks.use_held, font)
	var use := button(actions, _t("hud.use"), callbacks.use, font)
	var discard := button(actions, _t("hud.discard"), callbacks.discard, font)
	for action: Button in [hold, use_held, use, discard]:
		action.add_theme_stylebox_override("normal", style(Color(0.25, 0.15, 0.10), Color(0.38, 0.25, 0.15), 1, 10, 4))
		action.add_theme_stylebox_override("hover", style(Color(0.34, 0.21, 0.14), Color(0.50, 0.34, 0.22), 1, 10, 4))
		action.add_theme_color_override("font_color", Color(0.94, 0.85, 0.71))
		action.add_theme_color_override("font_hover_color", Color(0.98, 0.92, 0.82))
	var status := label(right, _t("ui.notebook_hint"), 20, MUTED, font)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return {
		"panel": panel, "dimmer": dimmer, "font": font, "list": list, "item_page": item_page,
		"other_pages": other_pages, "tabs": tabs, "name": name, "count": count,
		"description": description, "status": status, "sketch": sketch,
		"hold": hold, "use_held": use_held, "use": use, "discard": discard,
	}
