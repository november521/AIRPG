extends Control
const Service = preload("res://application/exploration/interaction_service.gd")
var _service: Service
var _prompt: Label
var _feedback: Label
var _crosshair: Label
var _remaining: float = 0.0
var _feedback_key: String = ""

func configure(service: Service) -> void:
	_service = service

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair = _label(0.48, 0.52)
	_crosshair.text = "+"
	_prompt = _label(0.57, 0.64)
	_feedback = _label(0.77, 0.84)

func _label(top: float, bottom: float) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.anchor_top = top
	label.anchor_bottom = bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	return label

func refresh(enabled: bool) -> void:
	visible = enabled
	if _service == null:
		return
	# A held-up observed object always advertises the way out, whatever the aim ray happens to hit.
	var exclusive: Dictionary = _service.read_exclusive()
	if not exclusive.is_empty():
		_prompt.text = tr("interaction.prompt") % [tr(String(exclusive.action_key)),
			tr(String(exclusive.name_key))]
		return
	var focus: Dictionary = _service.read_focus()
	_prompt.text = "" if focus.is_empty() else tr("interaction.prompt") % [tr(focus.action_key), tr(focus.name_key)]

func show_result(code: String) -> void:
	var key: String = "interaction.done" if code == "OK" else "interaction.failed"
	if code == "DOOR_BLOCKED":
		key = "interaction.door_blocked"
	elif code == "CABINET_LOCKED":
		key = "interaction.cabinet_locked"
	elif code == "PRY_NEEDS_CROWBAR":
		key = "interaction.need_crowbar"
	elif code == "GENERATOR_NEEDS_KEROSENE":
		key = "interaction.need_kerosene"
	elif code == "STACK_LIMIT":
		key = "interaction.stack_limit"
	elif code == "STALE_STATE":
		key = "interaction.stale"
	_feedback_key = key
	_feedback.text = tr(key)
	_remaining = 2.5

## Read-only view of the line currently shown, so a test can assert the wording a refused command
## puts on screen without a rendered window.
func feedback_key() -> String:
	return _feedback_key

func _process(delta: float) -> void:
	_remaining = maxf(0, _remaining - delta)
	if _remaining == 0:
		_feedback.text = ""
		_feedback_key = ""
