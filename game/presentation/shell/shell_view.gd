extends Control
## UI receives read-only application facade and safe diagnostics; no adapters or domain objects.
const Session = preload("res://application/session_service.gd")
signal route_requested(route_id: String)

@export var workspace: bool = false
var _debug_label: Label
var _debug_button: Button
var _session: Session
var _pack_id: String
var _content_version: String

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	var title := Label.new()
	title.text = tr("workspace.title" if workspace else "shell.title")
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)
	var description := Label.new()
	description.text = tr("workspace.description" if workspace else "shell.description")
	column.add_child(description)
	var route_button := Button.new()
	route_button.text = tr("workspace.back" if workspace else "shell.open")
	route_button.pressed.connect(func() -> void: route_requested.emit("home" if workspace else "workspace"))
	column.add_child(route_button)
	_debug_button = Button.new()
	_debug_button.text = tr("debug.toggle")
	_debug_button.pressed.connect(_toggle_debug)
	column.add_child(_debug_button)
	_debug_label = Label.new()
	_debug_label.visible = false
	column.add_child(_debug_label)

func configure(session: Session, pack_id: String, content_version: String, debug_enabled: bool) -> void:
	_session = session
	_pack_id = pack_id
	_content_version = content_version
	_debug_button.visible = debug_enabled
	_refresh_debug()

func _unhandled_input(event: InputEvent) -> void:
	if _debug_button.visible and event.is_action_pressed("debug_toggle"):
		_toggle_debug()
		get_viewport().set_input_as_handled()

func _toggle_debug() -> void:
	_refresh_debug()
	_debug_label.visible = not _debug_label.visible

func _refresh_debug() -> void:
	if _session == null:
		return
	_debug_label.text = tr("debug.summary").format({"pack": _pack_id,
		"version": _content_version, "revision": _session.diagnostics().revision})
