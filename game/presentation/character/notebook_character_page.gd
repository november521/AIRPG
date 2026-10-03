extends VBoxContainer
## Read-only investigator values for the in-play notebook.

const ATTRIBUTE_IDS: Array[String] = ["strength", "dexterity", "constitution", "intelligence", "perception", "charisma"]
const SKILL_IDS: Array[String] = ["awareness", "insight", "negotiation"]
const INK := Color(0.15, 0.12, 0.09)
const MUTED := Color(0.30, 0.24, 0.17)
const RULE := Color(0.55, 0.44, 0.31)

var _font: Font
var _identity: Label
var _attributes: Dictionary = {}
var _skills: Dictionary = {}
var _background: Label

func configure(font: Font) -> void:
	_font = font
	_build()

func refresh(view: Dictionary) -> void:
	var profile: Dictionary = view.profile
	var name: String = profile.get("name", tr(profile.name_key))
	var role: String = profile.get("role", tr(profile.role_key))
	_identity.text = "%s  ·  %s" % [name, role]
	for id: String in ATTRIBUTE_IDS:
		_set_value(_attributes[id], profile.attributes.get(id))
	for id: String in SKILL_IDS:
		_set_value(_skills[id], profile.skills.get(id))
	var background_text: String = profile.get("background_text", "")
	_background.text = background_text if not background_text.is_empty() else tr("dossier.pending")

func _build() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := HBoxContainer.new()
	add_child(heading)
	_identity = _label(heading, "", 29, INK)
	_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge := _label(heading, tr("creation.read_only"), 17, MUTED)
	badge.add_theme_stylebox_override("normal", _style(Color(0.83, 0.76, 0.62, 0.55), RULE, 1, 8, 8))
	_label(self, tr("creation.read_only_hint"), 18, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var body := HBoxContainer.new()
	add_child(body)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	var attributes := _section(body, tr("dossier.attributes"))
	var grid := GridContainer.new()
	attributes.add_child(grid)
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id: String in ATTRIBUTE_IDS:
		_attributes[id] = _value_card(grid, tr("attribute." + id))
	var skills := _section(body, tr("dossier.skills"))
	for id: String in SKILL_IDS:
		_skills[id] = _value_row(skills, tr("creation.skill." + id))
	var background_section := _section(self, tr("dossier.background"))
	_background = _label(background_section, "", 18, MUTED)
	_background.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var pending := PanelContainer.new()
	add_child(pending)
	pending.add_theme_stylebox_override("panel", _style(Color(0.88, 0.82, 0.69, 0.42), RULE, 1, 10, 8))
	var pending_text := _label(pending, tr("creation.pending_notice"), 17, MUTED)
	pending_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _section(parent: Control, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(Color(0.90, 0.84, 0.71, 0.36), RULE, 1, 14, 8))
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_theme_constant_override("separation", 9)
	_label(column, title, 24, INK)
	return column

func _value_card(parent: Control, title: String) -> Label:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.custom_minimum_size = Vector2(150, 74)
	panel.add_theme_stylebox_override("panel", _style(Color(0.96, 0.90, 0.77, 0.64), RULE, 1, 8, 6))
	var row := HBoxContainer.new()
	panel.add_child(row)
	_label(row, title, 18, MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _label(row, "", 28, INK)

func _value_row(parent: Control, title: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_label(row, title, 19, MUTED).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value := _label(row, "", 23, INK)
	var rule := HSeparator.new()
	parent.add_child(rule)
	return value

func _set_value(node: Label, value: Variant) -> void:
	node.text = str(value) if value != null else tr("dossier.pending")
	node.modulate = Color.WHITE if value != null else Color(0.72, 0.68, 0.60)

func _label(parent: Control, value: String, size: int, color: Color) -> Label:
	var node := Label.new()
	parent.add_child(node)
	node.text = value
	node.add_theme_font_override("font", _font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node

func _style(fill: Color, border: Color, width: int, inset: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(inset)
	style.set_corner_radius_all(radius)
	return style
