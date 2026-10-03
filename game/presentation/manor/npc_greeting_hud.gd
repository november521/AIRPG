extends Control
signal closed()
var _prompt: Label
var _panel: PanelContainer
var _speaker: Label
var _line: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt = Label.new()
	add_child(_prompt)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -350
	_prompt.offset_right = 350
	_prompt.offset_top = -170
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 100
	_panel.offset_right = -100
	_panel.offset_top = -230
	_panel.offset_bottom = -24
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.065, 0.97)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	_speaker = Label.new()
	column.add_child(_speaker)
	_speaker.add_theme_font_size_override("font_size", 26)
	_line = Label.new()
	column.add_child(_line)
	_line.add_theme_font_size_override("font_size", 24)
	_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	column.add_child(close)
	close.text = tr("npc.close")
	close.pressed.connect(func() -> void: closed.emit())
	_panel.hide()

func show_candidate(name_key: String) -> void:
	_prompt.text = tr("npc.talk_hint") % tr(name_key) if not name_key.is_empty() else ""
	_prompt.visible = not _panel.visible

func show_greeting(reply: Dictionary) -> void:
	_speaker.text = tr(reply.name_key)
	_line.text = tr(reply.text_key)
	_panel.show()
	_prompt.hide()

func dismiss() -> void:
	_panel.hide()

func is_open() -> bool:
	return _panel.visible
