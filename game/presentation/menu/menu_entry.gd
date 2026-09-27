extends Button
## Mouse and native keyboard/controller focus share one 250 ms visual transition.
@export var text_key: String = ""
@export var quiet_color: Color = Color(0.77, 0.70, 0.58, 1.0)
@export var selected_color: Color = Color(1.0, 0.91, 0.73, 1.0)

@onready var _halo: ColorRect = $Halo
var _highlight: float = 0.0
var _transition: Tween

func _ready() -> void:
	text = tr(text_key)
	_halo.material = _halo.material.duplicate()
	mouse_entered.connect(_hover)
	focus_entered.connect(_select.bind(true))
	focus_exited.connect(_select.bind(false))
	_set_highlight(0.0)

func _hover() -> void:
	if not disabled:
		grab_focus()

func _select(selected: bool) -> void:
	if _transition != null:
		_transition.kill()
	_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_transition.tween_method(_set_highlight, _highlight, 1.0 if selected else 0.0, 0.25)

func _set_highlight(value: float) -> void:
	_highlight = value
	var ink: Color = quiet_color.lerp(selected_color, value)
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		add_theme_color_override(state, ink)
	(_halo.material as ShaderMaterial).set_shader_parameter("intensity", value)

func _exit_tree() -> void:
	if _transition != null:
		_transition.kill()
