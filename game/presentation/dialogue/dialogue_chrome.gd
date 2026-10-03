extends RefCounted
## Presentation chrome: maps view state to controls and localized labels, and owns the
## speaker name/portrait registry. Owns no request tracking, application references or
## model access.

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
var _portraits: Dictionary = {}
var _logged_state: int = -1

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
	# A failed, paused or cancelled reply must not lock the conversation: the player can keep
	# talking or rephrase while retry stays next to them. Locking free text here made a rejected
	# or timed-out answer look like a frozen dialogue.
	var editable: bool = state in [State.IDLE, State.FAILED, State.PAUSED, State.CANCELLED]
	_input_edit.editable = editable
	_submit_button.disabled = not editable
	_skip_button.visible = state == State.PRESENTING
	_retry_button.visible = can_retry
	# Leaving the conversation must always be one visible click away: while a request waits or a
	# reply plays there is otherwise no on-screen exit and the view reads as frozen.
	_back_button.visible = true
	var text := ""
	var show := true
	if state == State.WAITING or state == State.PRESENTING:
		text = tr("dialogue.waiting")
	elif state == State.FAILED:
		# Localized explanation plus the stable code, so a failed answer names its own class.
		text = "%s (%s)" % [_error_text(error_code), error_code]
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
	if state != _logged_state:
		_logged_state = state
		# Secret-free trace: a conversation that never leaves "waiting" is visible in the log.
		print("AIRPG_DIALOGUE_STATE: ", _state_name(state), " ", error_code)

func set_speaker(name_text: String) -> void:
	_name_label.text = name_text

func set_portrait(texture: Texture2D) -> void:
	_portrait.texture = texture
	_portrait.visible = texture != null
	_portrait_fallback.visible = texture == null

func show_portrait(portrait_id: String) -> void:
	set_portrait(_portraits.get(portrait_id))

func register_portrait(portrait_id: String, texture: Texture2D) -> void:
	if portrait_id.is_empty():
		return
	if texture == null:
		_portraits.erase(portrait_id)
		return
	_portraits[portrait_id] = texture

## Localized speaker name for a localization key; falls back to the key when unlocalized.
func resolve_name(name_key: String) -> String:
	var localized := tr(name_key)
	if not localized.is_empty() and localized != name_key:
		return localized
	var fallback := tr("dialogue.name.unknown")
	return fallback if fallback != "dialogue.name.unknown" else name_key

func _state_name(value: int) -> String:
	match value:
		State.IDLE: return "idle"
		State.WAITING: return "waiting"
		State.PRESENTING: return "presenting"
		State.FAILED: return "failed"
		State.PAUSED: return "paused"
		State.CANCELLED: return "cancelled"
		_: return "unknown"

func _error_text(error_code: String) -> String:
	var key := "dialogue.error." + error_code
	var localized := tr(key)
	if localized != key:
		return localized
	return "%s (%s)" % [tr("dialogue.failed.generic"), error_code]
