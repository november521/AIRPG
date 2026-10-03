extends RefCounted
## Builds the dialogue layout tree. Presentation only; no business state or rules.

const HistoryPanel = preload("res://presentation/dialogue/dialogue_history_panel.gd")

const MARGIN: int = 24
const BOX_HEIGHT: int = 300
const PORTRAIT_WIDTH: int = 320
const PORTRAIT_MIN_HEIGHT: int = 240

static func build(root: Control) -> Dictionary:
	var portrait_frame := PanelContainer.new()
	portrait_frame.name = "PortraitFrame"
	portrait_frame.anchor_bottom = 1.0
	portrait_frame.offset_left = MARGIN
	portrait_frame.offset_right = MARGIN + PORTRAIT_WIDTH
	portrait_frame.offset_top = MARGIN
	portrait_frame.offset_bottom = -(BOX_HEIGHT + 2 * MARGIN)
	portrait_frame.custom_minimum_size = Vector2(PORTRAIT_WIDTH, PORTRAIT_MIN_HEIGHT)
	root.add_child(portrait_frame)
	var portrait := TextureRect.new()
	portrait.name = "PortraitTexture"
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.visible = false
	portrait_frame.add_child(portrait)
	var fallback := Label.new()
	fallback.name = "PortraitFallback"
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback.clip_text = true
	portrait_frame.add_child(fallback)
	var box := PanelContainer.new()
	box.name = "DialogueBox"
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = MARGIN
	box.offset_right = -MARGIN
	box.offset_top = -(BOX_HEIGHT + MARGIN)
	box.offset_bottom = -MARGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(box)
	var margin := MarginContainer.new()
	margin.name = "BoxMargin"
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	box.add_child(margin)
	var column := VBoxContainer.new()
	column.name = "BoxColumn"
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var name_label := Label.new()
	name_label.name = "SpeakerName"
	name_label.add_theme_font_size_override("font_size", 24)
	column.add_child(name_label)
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.visible = false
	column.add_child(status_label)
	var scroll := ScrollContainer.new()
	scroll.name = "TranscriptScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var transcript := VBoxContainer.new()
	transcript.name = "TranscriptBox"
	transcript.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(transcript)
	var reply_text := RichTextLabel.new()
	reply_text.name = "ReplyText"
	reply_text.bbcode_enabled = false
	reply_text.fit_content = true
	reply_text.scroll_active = false
	reply_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reply_text.add_theme_font_size_override("normal_font_size", 20)
	transcript.add_child(reply_text)
	var options_box := VBoxContainer.new()
	options_box.name = "OptionsBox"
	options_box.add_theme_constant_override("separation", 4)
	transcript.add_child(options_box)
	var input_row := HBoxContainer.new()
	input_row.name = "InputRow"
	input_row.add_theme_constant_override("separation", 8)
	column.add_child(input_row)
	var input_edit := LineEdit.new()
	input_edit.name = "InputEdit"
	input_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_edit.custom_minimum_size = Vector2(240, 0)
	input_row.add_child(input_edit)
	var submit_button := Button.new()
	submit_button.name = "SubmitButton"
	input_row.add_child(submit_button)
	var history_button := Button.new()
	history_button.name = "HistoryButton"
	input_row.add_child(history_button)
	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.alignment = BoxContainer.ALIGNMENT_END
	action_row.add_theme_constant_override("separation", 8)
	column.add_child(action_row)
	var skip_button := Button.new()
	skip_button.name = "SkipButton"
	skip_button.visible = false
	action_row.add_child(skip_button)
	var retry_button := Button.new()
	retry_button.name = "RetryButton"
	retry_button.visible = false
	action_row.add_child(retry_button)
	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.visible = false
	action_row.add_child(back_button)
	var history := HistoryPanel.new()
	root.add_child(history)
	return {"portrait": portrait, "portrait_fallback": fallback, "name_label": name_label,
		"status_label": status_label, "reply_text": reply_text, "options_box": options_box,
		"input_edit": input_edit, "submit_button": submit_button,
		"history_button": history_button, "skip_button": skip_button,
		"retry_button": retry_button, "back_button": back_button,
		"history_panel": history, "dialogue_box": box, "portrait_frame": portrait_frame}
