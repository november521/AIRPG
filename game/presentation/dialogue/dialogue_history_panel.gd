extends PanelContainer
## Read-only transcript panel. Player text is inserted raw and never parsed as markup.

signal close_requested()

const PANEL_MARGIN: int = 48
const CAPTION_SIZE: int = 16
const BODY_SIZE: int = 18

var _scroll: ScrollContainer
var _entries: VBoxContainer
var _close_button: Button
var _title_label: Label

func _init() -> void:
	name = "HistoryPanel"
	visible = false
	var frame := MarginContainer.new()
	frame.name = "HistoryFrame"
	for side: String in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, PANEL_MARGIN)
	add_child(frame)
	var column := VBoxContainer.new()
	column.name = "HistoryColumn"
	column.add_theme_constant_override("separation", 12)
	frame.add_child(column)
	_title_label = Label.new()
	_title_label.name = "HistoryTitle"
	_title_label.add_theme_font_size_override("font_size", 28)
	column.add_child(_title_label)
	_scroll = ScrollContainer.new()
	_scroll.name = "HistoryScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_entries = VBoxContainer.new()
	_entries.name = "HistoryEntries"
	_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_theme_constant_override("separation", 16)
	_scroll.add_child(_entries)
	_close_button = Button.new()
	_close_button.name = "HistoryCloseButton"
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	column.add_child(_close_button)
	_close_button.pressed.connect(func() -> void: close_requested.emit())

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_label.text = tr("dialogue.history.title")
	_close_button.text = tr("dialogue.history.close")

func append_entry(speaker: String, text: String) -> void:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 2)
	var caption := Label.new()
	caption.add_theme_font_size_override("font_size", CAPTION_SIZE)
	caption.text = speaker
	entry.add_child(caption)
	var body := RichTextLabel.new()
	body.bbcode_enabled = false
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("normal_font_size", BODY_SIZE)
	body.text = text
	entry.add_child(body)
	_entries.add_child(entry)
	_follow_tail()

func clear_entries() -> void:
	for child: Node in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()
	_follow_tail()

func entry_count() -> int:
	return _entries.get_child_count()

func get_entry_text(index: int) -> String:
	if index < 0 or index >= _entries.get_child_count():
		return ""
	for child: Node in _entries.get_child(index).get_children():
		if child is RichTextLabel:
			return (child as RichTextLabel).text
	return ""

func _follow_tail() -> void:
	if not is_inside_tree():
		return
	var bar := _scroll.get_v_scroll_bar()
	if bar != null:
		_scroll.scroll_vertical = int(bar.max_value)
