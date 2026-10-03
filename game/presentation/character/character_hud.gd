extends Control
## Read-only presentation of the character use case; item actions delegate to the service.
const Service = preload("res://application/character/character_service.gd")
const Result = preload("res://shared/result.gd")
const ItemRow = preload("res://presentation/character/notebook_item_row.gd")
const View = preload("res://presentation/character/notebook_view.gd")
signal panel_changed(open: bool)
signal return_requested()
signal item_dropped(item_id: String)
var _service: Service
var _revision: int
var _selected := ""
var _ids: Array[String] = []
var _meter: PanelContainer
var _bag: Button
var _dimmer: ColorRect
var _panel: PanelContainer
var _hp: ProgressBar
var _sanity: ProgressBar
var _hp_number: Label
var _sanity_number: Label
var _list: VBoxContainer
var _item_page: Control
var _other_pages: Array[Control] = []
var _tabs: Array[Button] = []
var _name: Label
var _count: Label
var _description: Label
var _status: Label
var _hold: Button
var _use_held: Button
var _use: Button
var _discard: Button
var _sketch: Control
var _book_font: SystemFont
func configure(service: Service) -> void:
	_service = service
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()
	_build_notebook()
	_service.changed.connect(_refresh)
	_refresh()
	set_open(false)
func is_open() -> bool:
	return _panel.visible
func set_open(open: bool) -> void:
	_panel.visible = open
	_dimmer.visible = open
	_meter.visible = not open
	_bag.visible = not open
	if open:
		_select_tab(0)
		_refresh()
	else:
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus != null and is_ancestor_of(focus):
			focus.release_focus()
	panel_changed.emit(open)
func _build_hud() -> void:
	var nodes: Dictionary = View.build_meter(self)
	_meter = nodes.meter
	_hp = nodes.hp
	_hp_number = nodes.hp_number
	_sanity = nodes.sanity
	_sanity_number = nodes.sanity_number
	_bag = View.build_bag(self, func() -> void: set_open(true))
func _build_notebook() -> void:
	var nodes: Dictionary = View.build_notebook(self, {
		"close": set_open.bind(false),
		"select_tab": _select_tab,
		"hold": _toggle_held,
		"use_held": _use_held_item,
		"use": _use_selected,
		"discard": _discard_selected,
	})
	_panel = nodes.panel
	_dimmer = nodes.dimmer
	_book_font = nodes.font
	_list = nodes.list
	_item_page = nodes.item_page
	_other_pages = nodes.other_pages
	_tabs = nodes.tabs
	_name = nodes.name
	_count = nodes.count
	_description = nodes.description
	_status = nodes.status
	_sketch = nodes.sketch
	_hold = nodes.hold
	_use_held = nodes.use_held
	_use = nodes.use
	_discard = nodes.discard
func _select_tab(index: int) -> void:
	_item_page.visible = index == 0
	for i: int in _other_pages.size():
		_other_pages[i].visible = index == i + 1
	for i: int in _tabs.size():
		_tabs[i].modulate = Color.WHITE if i == index else Color(0.66, 0.60, 0.50)
func _refresh() -> void:
	var view: Dictionary = _service.read_character()
	_revision = view.revision
	_hp.max_value = view.hp_max
	_hp.value = view.hp
	_sanity.max_value = view.sanity_max
	_sanity.value = view.sanity
	_hp_number.text = str(view.hp)
	_sanity_number.text = str(view.sanity)
	for child: Node in _list.get_children():
		child.queue_free()
	_ids.clear()
	for id: String in view.inventory:
		_ids.append(id)
		var row: Button = ItemRow.new()
		_list.add_child(row)
		row.configure(id, tr(view.definitions[id].name_key), tr("ui.kind." + view.definitions[id].kind), view.inventory[id], _book_font)
		row.pressed.connect(_choose_item.bind(id))
	if not _selected in _ids:
		_selected = _ids[0] if not _ids.is_empty() else ""
	_update_selection(view)
func _choose_item(id: String) -> void:
	_selected = id
	_update_selection(_service.read_character())
func _update_selection(view: Dictionary) -> void:
	if _selected.is_empty():
		_name.text = tr("hud.empty")
		_count.text = ""
		_description.text = ""
		_hold.disabled = true
		_use_held.disabled = true
		_use.disabled = true
		_discard.disabled = true
		return
	var item: Dictionary = view.definitions[_selected]
	var held: bool = view.held_item == _selected
	_sketch.set("item_id", _selected)
	_name.text = tr(item.name_key)
	_count.text = tr("ui.item_count") % view.inventory[_selected] + (" · " + tr("hud.held_item") if held else "")
	_description.text = tr(item.description_key)
	_hold.text = tr("hud.unequip") if held else tr("hud.equip")
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
func _show_result(result: Result) -> void:
	_status.text = tr("hud.success") if result.ok else tr("error." + result.code)
	_refresh()
