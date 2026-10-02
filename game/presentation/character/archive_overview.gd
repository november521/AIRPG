extends RefCounted
const Widgets = preload("res://presentation/character/archive_widgets.gd")
const ATTRIBUTE_IDS: Array[String] = ["strength", "dexterity", "constitution", "intelligence", "perception", "charisma"]
const SKILL_IDS: Array[String] = ["spot", "listen", "psychology", "persuade", "first_aid"]
var _name: Label
var _role: Label
var _age: Label
var _hp_text: Label
var _sanity_text: Label
var _condition: Label
var _hp: ProgressBar
var _sanity: ProgressBar
var _attributes: Dictionary = {}
var _skills: Dictionary = {}
var _backgrounds: Dictionary = {}
var _item_summary: Label

func build(parent: Control) -> void:
	var columns := HBoxContainer.new()
	parent.add_child(columns)
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := Widgets.panel(columns, true)
	Widgets.label(left, tr("dossier.investigator"), 24)
	var portrait := ColorRect.new()
	left.add_child(portrait)
	portrait.custom_minimum_size.y = 190
	portrait.color = Color(0.20, 0.24, 0.25)
	var avatar := Widgets.label(portrait, tr("hud.portrait"), 22)
	avatar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	avatar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_theme_color_override("font_color", Color.WHITE)
	_name = Widgets.row(left, tr("dossier.name"), "")
	_role = Widgets.row(left, tr("dossier.role"), "")
	_age = Widgets.row(left, tr("dossier.age"), "")
	left.add_child(HSeparator.new())
	Widgets.label(left, tr("dossier.state"), 23)
	_hp_text = Widgets.row(left, tr("dossier.hp"), "")
	_hp = Widgets.bar(left)
	_sanity_text = Widgets.row(left, tr("dossier.sanity"), "")
	_sanity = Widgets.bar(left)
	_condition = Widgets.row(left, tr("dossier.condition"), "")
	for text_node: Node in left.find_children("*", "Label", true, false):
		if text_node != avatar:
			text_node.add_theme_color_override("font_color", Color(0.10, 0.12, 0.13))
	var middle := Widgets.panel(columns)
	Widgets.label(middle, tr("dossier.attributes"), 24)
	var grid := GridContainer.new()
	middle.add_child(grid)
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for id: String in ATTRIBUTE_IDS:
		var card := Widgets.panel(grid)
		var number := Widgets.row(card, tr("attribute." + id), "")
		_attributes[id] = {"value": number, "bar": Widgets.bar(card)}
	Widgets.label(middle, tr("dossier.background"), 24)
	build_background(middle, false)
	var right := Widgets.panel(columns)
	Widgets.label(right, tr("dossier.skills"), 24)
	build_skills(right)
	Widgets.label(right, tr("dossier.items"), 24)
	_item_summary = Widgets.text(right, "")

func build_skills(parent: Control) -> void:
	for id: String in SKILL_IDS:
		var number := Widgets.row(parent, tr("skill." + id), "")
		var progress := Widgets.bar(parent)
		if not _skills.has(id):
			_skills[id] = []
		_skills[id].append({"value": number, "bar": progress})

func build_background(parent: Control, include_experience: bool = true) -> void:
	var ids: Array[String] = ["beliefs", "people", "possessions"]
	if include_experience:
		ids.append("experience")
	for id: String in ids:
		Widgets.label(parent, tr("background." + id), 19)
		var value := Widgets.text(parent, "")
		if not _backgrounds.has(id):
			_backgrounds[id] = []
		_backgrounds[id].append(value)

func refresh(view: Dictionary) -> void:
	var profile: Dictionary = view.profile
	_name.text = tr(profile.name_key)
	_role.text = tr(profile.role_key)
	_age.text = str(profile.age) if profile.age != null else tr("dossier.pending")
	_condition.text = tr(profile.condition_key)
	_hp_text.text = "%d / %d" % [view.hp, view.hp_max]
	_sanity_text.text = "%d / %d" % [view.sanity, view.sanity_max]
	_hp.max_value = view.hp_max
	_hp.value = view.hp
	_sanity.max_value = view.sanity_max
	_sanity.value = view.sanity
	for id: String in ATTRIBUTE_IDS:
		_set_number(_attributes[id], profile.attributes.get(id))
	for id: String in _skills:
		for widgets: Dictionary in _skills[id]:
			_set_number(widgets, profile.skills.get(id))
	for id: String in _backgrounds:
		for value: Label in _backgrounds[id]:
			var key: String = profile.background.get(id, "dossier.pending")
			value.text = tr(key)
	var lines: PackedStringArray = []
	for id: String in view.inventory:
		lines.append(tr("hud.item_row") % [tr(view.definitions[id].name_key), view.inventory[id]])
	_item_summary.text = "\n".join(lines) if not lines.is_empty() else tr("hud.empty")

func _set_number(widgets: Dictionary, value: Variant) -> void:
	widgets.value.text = str(value) if value != null else tr("dossier.pending")
	widgets.bar.visible = value != null
	widgets.bar.value = float(value) if value != null else 0.0

