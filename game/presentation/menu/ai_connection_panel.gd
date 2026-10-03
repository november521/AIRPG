extends PanelContainer
## Runtime-only direct API entry. The key field is secret and is cleared immediately after
## every submission. This view receives only the application facade, never a model client.

signal closed()

var _service: Object = null
var _endpoint: LineEdit
var _model: LineEdit
var _key: LineEdit
var _status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(720, 520)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	var title := Label.new()
	title.text = tr("ai.settings.title")
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	var note := Label.new()
	note.text = tr("ai.settings.notice")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	_endpoint = _field(column, "ai.settings.endpoint", "ai.settings.endpoint_hint")
	_model = _field(column, "ai.settings.model", "ai.settings.model_hint")
	_key = _field(column, "ai.settings.key", "ai.settings.key_hint")
	_key.secret = true
	_key.secret_character = "•"
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var disconnect := Button.new()
	disconnect.text = tr("ai.settings.disconnect")
	disconnect.pressed.connect(_disconnect)
	row.add_child(disconnect)
	var close := Button.new()
	close.text = tr("ai.settings.close")
	close.pressed.connect(func() -> void: closed.emit())
	row.add_child(close)
	var connect_button := Button.new()
	connect_button.text = tr("ai.settings.connect")
	connect_button.pressed.connect(_submit)
	row.add_child(connect_button)
	_key.text_submitted.connect(func(_value: String) -> void: _submit())

func configure(service: Object) -> bool:
	if service == null or not service.has_method("configure") \
			or not service.has_method("diagnostics") or not service.has_method("clear"):
		return false
	_service = service
	_refresh_status()
	return true

func _field(parent: VBoxContainer, label_key: String, hint_key: String) -> LineEdit:
	var label := Label.new()
	label.text = tr(label_key)
	parent.add_child(label)
	var edit := LineEdit.new()
	edit.placeholder_text = tr(hint_key)
	parent.add_child(edit)
	return edit

func _submit() -> void:
	if _service == null:
		return
	var result: RefCounted = _service.configure(_endpoint.text, _model.text, _key.text)
	_key.clear()
	if result.ok:
		_refresh_status()
	else:
		_status.text = tr("ai.settings.invalid") + " (" + result.code + ")"

func _disconnect() -> void:
	if _service == null:
		return
	_service.clear()
	_key.clear()
	_refresh_status()

func _refresh_status() -> void:
	if _service == null:
		_status.text = tr("ai.settings.unavailable")
		return
	var summary: Dictionary = _service.diagnostics()
	if summary.get("configured", false):
		_status.text = tr("ai.settings.connected").format({"host": summary.endpoint_host,
			"model": summary.model})
	else:
		_status.text = tr("ai.settings.disconnected")
