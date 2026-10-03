extends Control
const Service = preload("res://application/character/character_creation_service.gd")
const NumberRow = preload("res://presentation/character/creation_number_row.gd")
signal route_requested(route_id: String)
var _service: Service
var _revision: int
var _budget: Label
var _status: Label
var _confirm: Button
var _rows: Dictionary = {}
var _text: Dictionary = {}
var _reset_dialog: ConfirmationDialog
var _built := false
const BG := Color(0.075, 0.092, 0.092)
const PANEL := Color(0.15, 0.17, 0.16)
const GOLD := Color(0.83, 0.69, 0.46)
const PAPER := Color(0.92, 0.87, 0.76)

func configure(service: Service) -> void:
	_service = service
	if is_node_ready():
		if not _built:
			_build()
		if not _service.changed.is_connected(_refresh):
			_service.changed.connect(_refresh)
		_refresh()

func _ready() -> void:
	if _service != null:
		_build()
		_service.changed.connect(_refresh)
		_refresh()

func _build() -> void:
	_built = true
	var limits: Dictionary = _service.read_rules()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var background := ColorRect.new()
	add_child(background)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	background.color = BG
	var frame := VBoxContainer.new()
	add_child(frame)
	frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 0)
	var header := PanelContainer.new()
	frame.add_child(header)
	header.add_theme_stylebox_override("panel", _style(PANEL, Color(0.33, 0.30, 0.24), 1, 20))
	var head_row := HBoxContainer.new()
	header.add_child(head_row)
	var title := _label(head_row, tr("creation.title"), 31, PAPER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_budget = _label(head_row, "", 21, GOLD)
	var back := _button(head_row, tr("creation.back"))
	back.pressed.connect(func() -> void: route_requested.emit("story_archive"))
	var scroll := ScrollContainer.new()
	frame.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var centering := CenterContainer.new()
	scroll.add_child(centering)
	centering.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	centering.add_child(content)
	content.custom_minimum_size.x = 1000
	content.add_theme_constant_override("separation", 14)
	_label(content, tr("creation.subtitle"), 18, GOLD)
	var identity := _section(content, tr("creation.identity"))
	for id: String in ["name", "role"]:
		_text[id] = _text_row(identity, id, "creation." + id)
	var stats := HBoxContainer.new()
	content.add_child(stats)
	stats.add_theme_constant_override("separation", 16)
	var attributes := _section(stats, tr("dossier.attributes"))
	attributes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in limits.attribute_ids:
		var row: NumberRow = NumberRow.new()
		attributes.add_child(row)
		row.configure(id, tr("attribute." + id), limits.attribute_min, limits.attribute_max)
		row.requested.connect(_set_value)
		_rows[id] = row
	var skills := _section(stats, tr("dossier.skills"))
	skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in limits.skill_ids:
		var row: NumberRow = NumberRow.new()
		skills.add_child(row)
		row.configure(id, tr("creation.skill." + id), limits.skill_min, limits.skill_max)
		row.requested.connect(_set_value)
		_rows[id] = row
	_label(skills, tr("creation.skill_note"), 16, GOLD).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var background_section := _section(content, tr("dossier.background"))
	var background_input := TextEdit.new()
	background_section.add_child(background_input)
	background_input.custom_minimum_size.y = 105
	background_input.placeholder_text = tr("creation.background_hint")
	background_input.add_theme_font_size_override("font_size", 18)
	background_input.focus_exited.connect(func() -> void: _set_text("background", background_input.text))
	_text["background"] = background_input
	var footer := PanelContainer.new()
	frame.add_child(footer)
	footer.add_theme_stylebox_override("panel", _style(PANEL, Color(0.33, 0.30, 0.24), 1, 14))
	var footer_row := HBoxContainer.new()
	footer.add_child(footer_row)
	_status = _label(footer_row, tr("creation.confirm_hint"), 17, PAPER)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var reset := _button(footer_row, tr("creation.reset"))
	reset.pressed.connect(func() -> void: _reset_dialog.popup_centered())
	_confirm = _button(footer_row, tr("creation.confirm"))
	_confirm.pressed.connect(_confirm_creation)
	_reset_dialog = ConfirmationDialog.new()
	add_child(_reset_dialog)
	_reset_dialog.title = tr("creation.reset_title")
	_reset_dialog.dialog_text = tr("creation.reset_question")
	_reset_dialog.confirmed.connect(_reset)

func _section(parent: Control, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color(0.36, 0.32, 0.25), 1, 18))
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_theme_constant_override("separation", 9)
	_label(column, title, 24, GOLD)
	return column

func _text_row(parent: Control, id: String, label_key: String) -> LineEdit:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, tr(label_key), 19, PAPER).custom_minimum_size.x = 92
	var entry := LineEdit.new()
	row.add_child(entry)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.custom_minimum_size.y = 44
	entry.max_length = 80
	entry.add_theme_font_size_override("font_size", 19)
	entry.text_submitted.connect(func(_value: String) -> void: _set_text(id, entry.text))
	entry.focus_exited.connect(func() -> void: _set_text(id, entry.text))
	return entry

func _button(parent: Control, title: String) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.text = title
	button.custom_minimum_size = Vector2(116, 48)
	button.add_theme_font_size_override("font_size", 19)
	return button

func _label(parent: Control, value: String, size: int, color: Color) -> Label:
	var node := Label.new()
	parent.add_child(node)
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node

func _style(fill: Color, border: Color, width: int, inset: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(inset)
	style.set_corner_radius_all(8)
	return style

func _refresh() -> void:
	if _service == null or _budget == null:
		return
	var view: Dictionary = _service.read_creation()
	var limits: Dictionary = _service.read_rules()
	_revision = view.revision
	_budget.text = tr("creation.budget") % [view.remaining.attributes, view.remaining.skills]
	for id: String in limits.attribute_ids:
		_rows[id].display(view.attributes[id], view.remaining.attributes, view.locked)
	for id: String in limits.skill_ids:
		_rows[id].display(view.skills[id], view.remaining.skills, view.locked)
	for id: String in limits.text_ids:
		if id == "background":
			(_text[id] as TextEdit).text = view[id]
			(_text[id] as TextEdit).editable = not view.locked
		else:
			(_text[id] as LineEdit).text = view[id]
			(_text[id] as LineEdit).editable = not view.locked
	_confirm.disabled = view.locked
	if view.locked:
		_status.text = tr("creation.locked")

func _set_value(id: String, value: int) -> void:
	_show_result(_service.set_value(id, value, _revision))

func _set_text(id: String, value: String) -> void:
	if _service == null or _service.read_creation()[id] == value.strip_edges():
		return
	_show_result(_service.set_text(id, value, _revision))

func _reset() -> void:
	_show_result(_service.reset(_revision))

func _confirm_creation() -> void:
	for id: String in _service.read_rules().text_ids:
		_set_text(id, _text[id].text)
	var result: RefCounted = _service.confirm(_revision)
	if result.ok:
		route_requested.emit("manor")
	else:
		_show_result(result)

func _show_result(result: RefCounted) -> void:
	if result.ok:
		_status.text = tr("creation.saved")
	else:
		_status.text = tr("creation.error." + result.code)
		_refresh()
