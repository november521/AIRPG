extends RefCounted
const Result = preload("res://shared/result.gd")

static func configure(bindings: Dictionary) -> RefCounted:
	var events: Dictionary = {}
	for action: String in bindings:
		if not bindings[action] is String:
			return Result.failure("INPUT_INVALID")
		var key: int = OS.find_keycode_from_string(bindings[action])
		if key == KEY_NONE:
			return Result.failure("INPUT_INVALID")
		var event := InputEventKey.new()
		event.physical_keycode = key
		events[action] = event
	for action: String in events:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, events[action])
	return Result.success()

static func movement() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
