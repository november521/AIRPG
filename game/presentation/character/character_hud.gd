extends Control
const Service = preload("res://application/character/character_service.gd")
const Result = preload("res://shared/result.gd")
const Widgets = preload("res://presentation/character/archive_widgets.gd")
const Overview = preload("res://presentation/character/archive_overview.gd")
signal panel_changed(open: bool)
signal return_requested()
signal item_dropped(item_id: String)
var _service: Service
var _revision: int = 0
var _selected: String = ""
var _ids: Array[String] = []
var _panel: PanelContainer
var _meter: PanelContainer
var _vitals: Label
var _hp: ProgressBar
var _sanity: ProgressBar
var _items: ItemList
var _description: Label
var _status: Label
var _use: Button
var _hold: Button
var _use_held: Button
var _discard: Button
var _tabs: TabContainer
var _overview := Overview.new()

func configure(service: Service) -> void:
	_service = service

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_service.changed.connect(_refresh)
	_refresh()
	set_open(false)

func is_open() -> bool:
	return _panel.visible

func set_open(open: bool) -> void:
	_panel.visible = open
	_meter.visible = not open
	if open:
		_tabs.current_tab = 0
		_refresh()
	else:
		if get_viewport().gui_get_focus_owner() != null and is_ancestor_of(get_viewport().gui_get_focus_owner()):
			get_viewport().gui_get_focus_owner().release_focus()
	panel_changed.emit(open)

func _build() -> void:
	_meter = PanelContainer.new()
	add_child(_meter)
	_meter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_meter.offset_left = -330
	_meter.offset_right = -24
	_meter.offset_top = 24
	var meters := VBoxContainer.new()
	_meter.add_child(meters)
	_vitals = Widgets.label(meters, "")
	_hp = Widgets.bar(meters)
	_sanity = Widgets.bar(meters)
	Widgets.label(meters, tr("hud.open_hint"))
	_panel = PanelContainer.new()
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.065, 0.075, 1)
	background.content_margin_left = 28
	background.content_margin_right = 28
	background.content_margin_top = 22
	background.content_margin_bottom = 22
	_panel.add_theme_stylebox_override("panel", background)
	var content := VBoxContainer.new()
	_panel.add_child(content)
	content.add_theme_constant_override("separation", 14)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Widgets.label(header, tr("dossier.title"), 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Widgets.label(header, tr("dossier.demo"), 18)
	Widgets.button(header, tr("hud.close"), set_open.bind(false))
	_tabs = TabContainer.new()
	content.add_child(_tabs)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 21)
	var overview := Widgets.page(_tabs, tr("dossier.tab.overview"))
	_overview.build(overview)
	var skills := Widgets.page(_tabs, tr("dossier.tab.skills"))
	var skill_panel := Widgets.panel(skills)
	Widgets.label(skill_panel, tr("dossier.skills"), 25)
	_overview.build_skills(skill_panel)
	Widgets.text(skill_panel, tr("dossier.rules_pending"))
	var inventory := Widgets.page(_tabs, tr("dossier.tab.items"))
	_build_inventory(inventory)
	var history := Widgets.page(_tabs, tr("dossier.tab.background"))
	var history_panel := Widgets.panel(history, true)
	Widgets.label(history_panel, tr("dossier.background"), 25)
	_overview.build_background(history_panel)
	for text_node: Node in history_panel.find_children("*", "Label", true, false):
		text_node.add_theme_color_override("font_color", Color(0.10, 0.12, 0.13))
	var footer := HBoxContainer.new()
	content.add_child(footer)
	Widgets.label(footer, tr("hud.preview_controls"), 16)
	Widgets.button(footer, tr("hud.damage"), _preview.bind("damage"))
	Widgets.button(footer, tr("hud.stress"), _preview.bind("stress"))
	Widgets.button(footer, tr("hud.supply"), _preview.bind("supply"))
	Widgets.button(footer, tr("hud.reset"), _preview.bind("reset"))
	Widgets.button(footer, tr("dossier.return"), func() -> void: return_requested.emit())
	_status = Widgets.text(content, tr("hud.ready"))

func _build_inventory(parent: Control) -> void:
	var columns := HBoxContainer.new()
	parent.add_child(columns)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	var list := Widgets.panel(columns)
	Widgets.label(list, tr("dossier.items"), 25)
	_items = ItemList.new()
	list.add_child(_items)
	_items.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items.custom_minimum_size = Vector2(280, 280)
	_items.add_theme_font_size_override("font_size", 21)
	_items.item_selected.connect(_on_selected)
	var detail := Widgets.panel(columns)
	Widgets.label(detail, tr("dossier.item_detail"), 25)
	var icon := ColorRect.new()
	detail.add_child(icon)
	icon.custom_minimum_size.y = 120
	icon.color = Color(0.16, 0.21, 0.24)
	var icon_text := Widgets.label(icon, tr("dossier.item_icon"))
	icon_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description = Widgets.text(detail, "")
	var actions := HBoxContainer.new()
	detail.add_child(actions)
	_hold = Widgets.button(actions, tr("hud.hold"), _toggle_held)
	_use_held = Widgets.button(actions, tr("hud.use_held"), _use_held_item)
	_use = Widgets.button(actions, tr("hud.use"), _use_selected)
	_discard = Widgets.button(actions, tr("hud.discard"), _discard_selected)

func _refresh() -> void:
	var view: Dictionary = _service.read_character()
	_revision = view.revision
	_vitals.text = tr("hud.vitals") % [view.hp, view.hp_max, view.sanity, view.sanity_max]
	_hp.max_value = view.hp_max
	_hp.value = view.hp
	_sanity.max_value = view.sanity_max
	_sanity.value = view.sanity
	_overview.refresh(view)
	_items.clear()
	_ids.clear()
	for id: String in view.inventory:
		_ids.append(id)
		_items.add_item(tr("hud.item_row") % [tr(view.definitions[id].name_key), view.inventory[id]])
	if not _selected in _ids:
		_selected = _ids[0] if not _ids.is_empty() else ""
	if not _selected.is_empty():
		_items.select(_ids.find(_selected))
	_update_selection(view)

func _on_selected(index: int) -> void:
	_selected = _ids[index]
	_update_selection(_service.read_character())

func _update_selection(view: Dictionary) -> void:
	_use.disabled = _selected.is_empty()
	_discard.disabled = _selected.is_empty()
	if _selected.is_empty():
		_description.text = tr("hud.empty")
		_hold.disabled = true
		_use_held.disabled = true
		_use.disabled = true
		_discard.disabled = true
		return
	var item: Dictionary = view.definitions[_selected]
	var held_suffix: String = "\n" + tr("hud.held_item") if view.held_item == _selected else ""
	_description.text = tr("dossier.item_description") % [tr(item.name_key), view.inventory[_selected], tr(item.description_key)] + held_suffix
	_hold.text = tr("hud.unequip") if view.held_item == _selected else tr("hud.equip")
	_hold.disabled = not item.equippable
	_use_held.disabled = view.held_item.is_empty()
	_use.disabled = item.kind != "consumable"
	_discard.disabled = not item.droppable

func _use_selected() -> void:
	_show_result(_service.use_item(_selected, _revision))

func _toggle_held() -> void:
	var view: Dictionary = _service.read_character()
	if view.held_item == _selected:
		_show_result(_service.unequip_item())
	else:
		_show_result(_service.equip_item(_selected))

func _use_held_item() -> void:
	_show_result(_service.use_held_item(_revision))

func _discard_selected() -> void:
	var dropped_item_id: String = _selected
	var result: Result = _service.drop_item(dropped_item_id, _revision)
	_show_result(result)
	if result.ok:
		item_dropped.emit(dropped_item_id)

func _preview(action: String) -> void:
	_show_result(_service.preview_action(action, _revision))

func _show_result(result: Result) -> void:
	_status.text = tr("hud.success") if result.ok else tr("error." + result.code)
	_refresh()

