extends Control
## Investigator creation page (车卡 / 加点), laid out to the approved reference:
## chamfered outer frame, inline header with the live point budget, a
## full-width identity card above a two-column card area, and a footer with the
## reset / confirm pair.
const Service = preload("res://application/character/character_creation_service.gd")
const NumberRow = preload("res://presentation/character/creation_number_row.gd")
const Style = preload("res://presentation/character/creation_style.gd")

signal route_requested(route_id: String)

const FRAME_MARGIN := Vector4(52, 50, 52, 40)
const BODY_MARGIN := Vector4(67, 29, 67, 2)

var _service: Service
var _revision: int
var _budget_attributes: Label
var _budget_skills: Label
var _status: Label
var _confirm: Button
var _rows: Dictionary = {}
var _text: Dictionary = {}
var _reset_dialog: ConfirmationDialog
var _built := false

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
	Style.backdrop(self)
	var frame := Style.plate_box(self, Style.FRAME_FILL, Style.FRAME_LINE, 16.0, Vector4.ZERO)
	frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	frame.offset_left = FRAME_MARGIN.x
	frame.offset_top = FRAME_MARGIN.y
	frame.offset_right = -FRAME_MARGIN.z
	frame.offset_bottom = -FRAME_MARGIN.w
	var shell := VBoxContainer.new()
	frame.add_child(shell)
	shell.add_theme_constant_override("separation", 0)
	_build_header(shell)
	_build_body(shell, limits)
	_build_footer(shell)

func _build_header(shell: Control) -> void:
	var header := PanelContainer.new()
	shell.add_child(header)
	header.add_theme_stylebox_override("panel",
		Style.bar(Style.BAR_FILL, Style.HAIRLINE, false, true, Vector4(34, 16, 34, 16)))
	var row := HBoxContainer.new()
	header.add_child(row)
	row.add_theme_constant_override("separation", 22)
	var brand := HBoxContainer.new()
	row.add_child(brand)
	brand.add_theme_constant_override("separation", 18)
	var title := Style.label(brand, tr("creation.title"), 44, Style.PAPER, Style.heading())
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var divider := ColorRect.new()
	brand.add_child(divider)
	divider.color = Style.HAIRLINE
	divider.custom_minimum_size = Vector2(1, 30)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var subtitle := Style.label(brand, tr("creation.subtitle"), 23, Style.MUTED)
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var spacer := Control.new()
	row.add_child(spacer)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spend := HBoxContainer.new()
	row.add_child(spend)
	spend.add_theme_constant_override("separation", 22)
	_budget_attributes = _spend_group(spend, tr("creation.budget.attributes"))
	var spend_divider := ColorRect.new()
	spend.add_child(spend_divider)
	spend_divider.color = Style.DIVIDER
	spend_divider.custom_minimum_size = Vector2(1, 30)
	spend_divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_budget_skills = _spend_group(spend, tr("creation.budget.skills"))
	var back := Style.ghost_button(row, tr("creation.back"), Vector2(132, 48))
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: route_requested.emit("story_archive"))

func _spend_group(parent: Control, caption: String) -> Label:
	var group := HBoxContainer.new()
	parent.add_child(group)
	group.add_theme_constant_override("separation", 10)
	var text := Style.label(group, caption, 21, Style.PAPER, Style.title_font())
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value := Style.label(group, "", 32, Style.GOLD_BRIGHT, Style.heading())
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return value

func _build_body(shell: Control, limits: Dictionary) -> void:
	var margin := MarginContainer.new()
	shell.add_child(margin)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", int(BODY_MARGIN.x))
	margin.add_theme_constant_override("margin_top", int(BODY_MARGIN.y))
	margin.add_theme_constant_override("margin_right", int(BODY_MARGIN.z))
	margin.add_theme_constant_override("margin_bottom", int(BODY_MARGIN.w))
	# Identity spans the full frame; the two cards below it split the width.
	var outer := VBoxContainer.new()
	margin.add_child(outer)
	outer.add_theme_constant_override("separation", 17)
	_build_identity(outer)
	var columns := HBoxContainer.new()
	outer.add_child(columns)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 17)
	var left := VBoxContainer.new()
	columns.add_child(left)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := VBoxContainer.new()
	columns.add_child(right)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.07
	right.add_theme_constant_override("separation", 17)
	var attributes := Style.section(left, tr("dossier.attributes"), true)
	for id: String in limits.attribute_ids:
		_add_row(attributes, id, tr("attribute." + id), limits.attribute_min,
			limits.attribute_max, true)
	var skills := Style.section(right, tr("dossier.skills"))
	for id: String in limits.skill_ids:
		_add_row(skills, id, tr("creation.skill." + id), limits.skill_min,
			limits.skill_max, false)
	var note := Style.label(skills, tr("creation.skill_note"), 21, Style.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_background(right)

func _build_identity(parent: Control) -> void:
	var body := Style.section(parent, tr("creation.identity"))
	var row := HBoxContainer.new()
	body.add_child(row)
	row.add_theme_constant_override("separation", 18)
	_text["name"] = _identity_row(row, "name")
	var gap := Control.new()
	row.add_child(gap)
	gap.custom_minimum_size.x = 45
	_text["role"] = _identity_row(row, "role")

func _identity_row(row: Control, id: String) -> LineEdit:
	var caption := Style.label(row, tr("creation." + id), 22, Style.PAPER)
	caption.custom_minimum_size.x = 68
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var entry := Style.line_field(row)
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.text_submitted.connect(func(_value: String) -> void: _set_text(id, entry.text))
	entry.focus_exited.connect(func() -> void: _set_text(id, entry.text))
	return entry

func _build_background(parent: Control) -> void:
	var body := Style.section(parent, tr("dossier.background"), true)
	var area := Style.text_area(body)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.placeholder_text = tr("creation.background_hint")
	area.focus_exited.connect(func() -> void: _set_text("background", area.text))
	_text["background"] = area

func _add_row(body: VBoxContainer, id: String, title: String, minimum: int,
		maximum: int, expand: bool) -> void:
	if body.get_child_count() > 0:
		var rule := ColorRect.new()
		body.add_child(rule)
		rule.color = Style.ROW_RULE
		rule.custom_minimum_size.y = 1
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: NumberRow = NumberRow.new()
	body.add_child(row)
	row.configure(id, title, minimum, maximum)
	# Attributes stretch to share the tall left card; skills keep their natural
	# height so the background card absorbs the remainder of the right column.
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_BEGIN
	row.requested.connect(_set_value)
	_rows[id] = row

func _build_footer(shell: Control) -> void:
	var footer := PanelContainer.new()
	shell.add_child(footer)
	footer.add_theme_stylebox_override("panel",
		Style.bar(Style.BAR_FILL, Style.HAIRLINE, true, false, Vector4(30, 15, 30, 15)))
	var row := HBoxContainer.new()
	footer.add_child(row)
	row.add_theme_constant_override("separation", 34)
	_status = Style.label(row, tr("creation.confirm_hint"), 21, Style.MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var reset := Style.ghost_button(row, tr("creation.reset"), Vector2(192, 68))
	reset.pressed.connect(func() -> void: _reset_dialog.popup_centered())
	_confirm = Style.confirm_button(row, tr("creation.confirm"), Vector2(240, 68))
	_confirm.pressed.connect(_confirm_creation)
	_reset_dialog = ConfirmationDialog.new()
	add_child(_reset_dialog)
	_reset_dialog.title = tr("creation.reset_title")
	_reset_dialog.dialog_text = tr("creation.reset_question")
	_reset_dialog.confirmed.connect(_reset)

func _refresh() -> void:
	if _service == null or _budget_attributes == null:
		return
	var view: Dictionary = _service.read_creation()
	var limits: Dictionary = _service.read_rules()
	_revision = view.revision
	_budget_attributes.text = str(view.remaining.attributes)
	_budget_skills.text = str(view.remaining.skills)
	for id: String in limits.attribute_ids:
		_rows[id].display(view.attributes[id], view.remaining.attributes, view.locked)
	for id: String in limits.skill_ids:
		_rows[id].display(view.skills[id], view.remaining.skills, view.locked)
	for id: String in limits.text_ids:
		if id == "background":
			var area: TextEdit = _text[id]
			area.text = view[id]
			area.editable = not view.locked
		else:
			var entry: LineEdit = _text[id]
			entry.text = view[id]
			entry.editable = not view.locked
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
