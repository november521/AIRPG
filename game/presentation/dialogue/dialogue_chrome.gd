extends RefCounted
## Presentation chrome: maps view state to controls and localized labels.
## Owns no request tracking, application references or model access.

enum State { IDLE, WAITING, PRESENTING, FAILED, PAUSED, CANCELLED }

var _portrait: TextureRect
var _portrait_fallback: Label
var _name_label: Label
var _status_label: Label
var _input_edit: LineEdit
var _submit_button: Button
var _history_button: Button
var _skip_button: Button
var _retry_button: Button
var _back_button: Button

func bind(nodes: Dictionary) -> void:
	_portrait = nodes.get("portrait")
	_portrait_fallback = nodes.get("portrait_fallback")
	_name_label = nodes.get("name_label")
	_status_label = nodes.get("status_label")
	_input_edit = nodes.get("input_edit")
	_submit_button = nodes.get("submit_button")
	_history_button = nodes.get("history_button")
	_skip_button = nodes.get("skip_button")
	_retry_button = nodes.get("retry_button")
	_back_button = nodes.get("back_button")

func localize() -> void:
	_input_edit.placeholder_text = tr("dialogue.free_text.placeholder")
	_submit_button.text = tr("dialogue.free_text.send")
	_history_button.text = tr("dialogue.history.toggle")
	_skip_button.text = tr("dialogue.skip")
	_retry_button.text = tr("dialogue.retry")
	_back_button.text = tr("dialogue.back")
	_portrait_fallback.text = tr("dialogue.portrait.missing")

func render(state: int, error_code: String, can_retry: bool, notice: String) -> void:
	var idle: bool = state == State.IDLE
	_input_edit.editable = idle
	_submit_button.disabled = not idle
	_skip_button.visible = state == State.PRESENTING
	_retry_button.visible = can_retry
	_back_button.visible = state in [State.FAILED, State.PAUSED, State.CANCELLED]
	var text := ""
	var show := true
	if state == State.WAITING or state == State.PRESENTING:
		text = tr("dialogue.waiting")
	elif state == State.FAILED:
		text = _error_text(error_code)
	elif state == State.PAUSED:
		text = "%s (%s)" % [tr("dialogue.paused"), error_code]
	elif state == State.CANCELLED:
		text = tr("dialogue.cancelled")
	elif not notice.is_empty():
		text = notice
	else:
		show = false
	_status_label.visible = show
	_status_label.text = text

func set_speaker(name_text: String) -> void:
	_name_label.text = name_text

func set_portrait(texture: Texture2D) -> void:
	_portrait.texture = texture
	_portrait.visible = texture != null
	_portrait_fallback.visible = texture == null

func _error_text(error_code: String) -> String:
	var key := "dialogue.error." + error_code
	var localized := tr(key)
	if localized != key:
		return localized
	return "%s (%s)" % [tr("dialogue.failed.generic"), error_code]
