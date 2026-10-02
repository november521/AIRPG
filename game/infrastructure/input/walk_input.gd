extends RefCounted
var _ui_blocked: bool = false

func configure() -> void:
	var bindings: Dictionary = {
		"walk_left": KEY_A, "walk_right": KEY_D,
		"walk_forward": KEY_W, "walk_back": KEY_S,
		"walk_reset": KEY_R, "walk_cellar": KEY_B, "walk_slow": KEY_SHIFT,
	}
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = bindings[action]
			InputMap.action_add_event(action, event)

func active() -> bool:
	return not _ui_blocked and DisplayServer.window_is_focused() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func movement() -> Vector2:
	if not DisplayServer.window_is_focused():
		release_pointer()
	return Input.get_vector("walk_left", "walk_right", "walk_forward", "walk_back") if active() else Vector2.ZERO

func slow() -> bool:
	return active() and Input.is_action_pressed("walk_slow")

func reset_requested() -> bool:
	return active() and Input.is_action_just_pressed("walk_reset")

func cellar_requested() -> bool:
	return active() and Input.is_action_just_pressed("walk_cellar")

func capture_pointer() -> void:
	if not _ui_blocked and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func release_pointer() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func look_motion(event: InputEvent) -> Vector2:
	if _ui_blocked:
		return Vector2.ZERO
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		release_pointer()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		capture_pointer()
	if event is InputEventMouseMotion and active():
		return event.relative
	return Vector2.ZERO

func set_ui_blocked(blocked: bool) -> void:
	_ui_blocked = blocked
	if blocked:
		release_pointer()
	else:
		capture_pointer()

func inventory_toggle(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E

func escape_pressed(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE

func return_requested(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1
