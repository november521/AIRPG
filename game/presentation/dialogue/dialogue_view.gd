extends Control
## Traditional RPG dialogue view. Consumes only DialogueViewContract-validated events
## from an injected dialogue use case. Holds no state store, model provider, network
## client or save handle, and never renders raw model output.

const Contract = preload("res://application/contracts/dialogue_view_contract.gd")
const Chrome = preload("res://presentation/dialogue/dialogue_chrome.gd")
const Layout = preload("res://presentation/dialogue/dialogue_layout.gd")
const Options = preload("res://presentation/dialogue/dialogue_options.gd")
const Playback = preload("res://presentation/dialogue/dialogue_playback.gd")
const HistoryPanel = preload("res://presentation/dialogue/dialogue_history_panel.gd")

signal reply_presented(request_id: String)
signal submission_accepted(kind: String, request_id: String)
signal state_changed(state: int)
signal back_requested()

var _use_case: Variant = null
var _released: bool = false
var _state: int = Chrome.State.IDLE
var _active_request_id: String = ""
var _closed_requests: Dictionary = {}
var _last_submission: Dictionary = {}
var _last_error_code: String = ""
var _last_retryable: bool = false
var _notice_text: String = ""
var _rejected_events: int = 0
var _request_counter: int = 0
var _portraits: Dictionary = {}
var _pending_options: Array = []
var _playback_request_id: String = ""

var _chrome: Chrome
var _options: Options
var _playback: Playback
var _history_panel: HistoryPanel
var _input_edit: LineEdit

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var nodes := Layout.build(self)
	_chrome = Chrome.new()
	_chrome.bind(nodes)
	_options = Options.new()
	_options.bind(nodes["options_box"])
	_playback = Playback.new()
	_playback.attach(nodes["reply_text"], self)
	_playback.finished.connect(_on_playback_finished)
	_history_panel = nodes["history_panel"]
	_input_edit = nodes["input_edit"]
	nodes["submit_button"].pressed.connect(_on_submit_pressed)
	_input_edit.text_submitted.connect(func(_text: String) -> void: _on_submit_pressed())
	nodes["history_button"].pressed.connect(_toggle_history)
	nodes["skip_button"].pressed.connect(skip_playback)
	nodes["retry_button"].pressed.connect(_on_retry_pressed)
	nodes["back_button"].pressed.connect(_on_back_pressed)
	_history_panel.close_requested.connect(_toggle_history)
	_chrome.localize()
	_render()

func _exit_tree() -> void:
	release()

func configure(dialogue_use_case: Object) -> bool:
	if dialogue_use_case == null or not dialogue_use_case.has_signal("view_event"):
		return false
	_disconnect_use_case()
	_use_case = dialogue_use_case
	_use_case.connect("view_event", _on_view_event)
	_released = false
	_active_request_id = ""
	_closed_requests.clear()
	_last_submission.clear()
	_last_error_code = ""
	_last_retryable = false
	_notice_text = ""
	_pending_options = []
	_set_state(Chrome.State.IDLE)
	_render()
	return true

func release() -> void:
	if _released:
		return
	_released = true
	if _playback != null:
		_playback.stop()
	_disconnect_use_case()

func get_state() -> int:
	return _state

func get_active_request_id() -> String:
	return _active_request_id

func get_last_error_code() -> String:
	return _last_error_code

func get_rejected_event_count() -> int:
	return _rejected_events

func get_reply_text() -> String:
	if _playback == null:
		return ""
	return _playback.full_text()

func get_visible_reply_length() -> int:
	if _playback == null:
		return 0
	return _playback.visible_length()

func is_playback_active() -> bool:
	if _playback == null:
		return false
	return _playback.is_active()

func register_portrait(portrait_id: String, texture: Texture2D) -> void:
	if portrait_id.is_empty():
		return
	if texture == null:
		_portraits.erase(portrait_id)
	else:
		_portraits[portrait_id] = texture

func skip_playback() -> void:
	if _playback != null:
		_playback.skip()

func _on_view_event(event: Dictionary) -> void:
	if _released or not is_inside_tree():
		return
	var validated := Contract.validate_view_event(event)
	if not validated.ok:
		_rejected_events += 1
		return
	var value: Dictionary = validated.value
	if value.kind == "status":
		_apply_status(value)
	elif value.kind == "verified_reply":
		_apply_reply(value)

func _apply_status(value: Dictionary) -> void:
	var request_id: String = value.request_id
	if request_id.is_empty() or request_id != _active_request_id:
		return
	var status: String = value.status
	if status == Contract.STATUS_IDLE:
		_close_request(request_id)
		_set_state(Chrome.State.IDLE)
	elif status == Contract.STATUS_WAITING:
		_set_state(Chrome.State.WAITING)
	elif status == Contract.STATUS_PRESENTING:
		_set_state(Chrome.State.PRESENTING)
	elif status == Contract.STATUS_FAILED:
		_last_error_code = value.error_code
		_last_retryable = value.retryable
		_close_request(request_id)
		_set_state(Chrome.State.FAILED if value.retryable else Chrome.State.PAUSED)
	elif status == Contract.STATUS_CANCELLED:
		_close_request(request_id)
		_set_state(Chrome.State.CANCELLED)
	_render()

func _apply_reply(value: Dictionary) -> void:
	var request_id: String = value.request_id
	var is_active := not _active_request_id.is_empty() and request_id == _active_request_id
	var is_push := _active_request_id.is_empty() and _state == Chrome.State.IDLE and not _closed_requests.has(request_id)
	if not is_active and not is_push:
		return
	_active_request_id = request_id
	var speaker := _resolve_name(value.name_key)
	_chrome.set_speaker(speaker)
	_chrome.set_portrait(_portraits.get(value.portrait_id))
	_history_panel.append_entry(speaker, value.text)
	_options.clear()
	_pending_options = value.options.duplicate(true)
	_playback_request_id = request_id
	_playback.start(value.text)
	_set_state(Chrome.State.PRESENTING)
	_render()

func _resolve_name(name_key: String) -> String:
	var localized := tr(name_key)
	if not localized.is_empty() and localized != name_key:
		return localized
	var fallback := tr("dialogue.name.unknown")
	return fallback if fallback != "dialogue.name.unknown" else name_key

func _on_playback_finished() -> void:
	var request_id := _playback_request_id
	_playback_request_id = ""
	_close_request(request_id)
	_options.show_options(_pending_options, _on_option_pressed)
	_pending_options = []
	_set_state(Chrome.State.IDLE)
	_render()
	reply_presented.emit(request_id)

func _close_request(request_id: String) -> void:
	if not request_id.is_empty():
		_closed_requests[request_id] = true
	if _active_request_id == request_id:
		_active_request_id = ""

func _on_submit_pressed() -> void:
	if _released or _state != Chrome.State.IDLE:
		return
	_send_text(_input_edit.text, true)

func _on_option_pressed(option_id: String, display_text: String) -> void:
	if _released or _state != Chrome.State.IDLE:
		return
	_send_option(option_id, display_text, true)

func _on_retry_pressed() -> void:
	if _released or _last_submission.is_empty():
		return
	if _state != Chrome.State.FAILED and _state != Chrome.State.CANCELLED:
		return
	if _last_submission.kind == "option":
		_send_option(_last_submission.option_id, _last_submission.text, false)
	else:
		_send_text(_last_submission.text, false)

func _on_back_pressed() -> void:
	back_requested.emit()

func _send_text(text: String, echo: bool) -> bool:
	if text.strip_edges().is_empty() or _use_case == null:
		return false
	var request_id := _next_request_id()
	var result: Variant = _use_case.call("submit_text", request_id, text)
	if result == null or not result.ok:
		_show_local_rejection()
		return false
	_accept_submission("text", text, "", request_id, echo)
	return true

func _send_option(option_id: String, display_text: String, echo: bool) -> bool:
	if _use_case == null:
		return false
	var request_id := _next_request_id()
	var result: Variant = _use_case.call("select_option", request_id, option_id)
	if result == null or not result.ok:
		_show_local_rejection()
		return false
	_accept_submission("option", display_text, option_id, request_id, echo)
	return true

func _accept_submission(kind: String, text: String, option_id: String,
		request_id: String, echo: bool) -> void:
	_last_submission = {"kind": kind, "text": text, "option_id": option_id}
	_active_request_id = request_id
	_last_error_code = ""
	_last_retryable = false
	_notice_text = ""
	_options.clear()
	if echo:
		_history_panel.append_entry(tr("dialogue.you"), text)
		_input_edit.text = ""
	_set_state(Chrome.State.WAITING)
	_render()
	submission_accepted.emit(kind, request_id)

func _show_local_rejection() -> void:
	_notice_text = tr("dialogue.free_text.rejected")
	_render()

func _toggle_history() -> void:
	_history_panel.visible = not _history_panel.visible

func _next_request_id() -> String:
	_request_counter += 1
	return "ui.%d.%d" % [get_instance_id(), _request_counter]

func _retry_enabled() -> bool:
	if _last_submission.is_empty():
		return false
	if _state == Chrome.State.CANCELLED:
		return true
	return _state == Chrome.State.FAILED and _last_retryable

func _set_state(next: int) -> void:
	if _state == next:
		return
	_state = next
	state_changed.emit(_state)

func _render() -> void:
	if is_node_ready():
		_chrome.render(_state, _last_error_code, _retry_enabled(), _notice_text)

func _disconnect_use_case() -> void:
	if _use_case != null and _use_case.has_signal("view_event") \
			and _use_case.is_connected("view_event", _on_view_event):
		_use_case.disconnect("view_event", _on_view_event)
	_use_case = null
