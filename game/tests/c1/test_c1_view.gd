extends RefCounted
## C1 view suite: action-name input, text-focus guard, repeat triggers, cleanup.

const Fixtures = preload("res://tests/c1/c1_fixtures.gd")
const GreyboxScene = preload("res://presentation/exploration/greybox_exploration.tscn")

func run(check: Callable, tree: SceneTree) -> void:
	await _movement_and_focus(check, tree)
	await _repeat_triggers(check, tree)
	await _reconfigure(check, tree)
	await _cleanup(check, tree)
	await _unconfigured(check, tree)

func _spawn(tree: SceneTree, layout: Dictionary) -> Dictionary:
	var sink = Fixtures.recording_sink()
	var built := Fixtures.build(layout, sink)
	var view = GreyboxScene.instantiate()
	tree.root.add_child(view)
	view.configure(built.value)
	return {"view": view, "use_case": built.value, "sink": sink}

func _dispose(tree: SceneTree, view: Node) -> void:
	view.queue_free()
	await tree.process_frame

func _event(action: String, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event

func _key(action: String, pressed: bool, echo: bool) -> InputEventKey:
	var event := InputEventKey.new()
	var events := InputMap.action_get_events(action)
	event.physical_keycode = events[0].physical_keycode if not events.is_empty() else KEY_NONE
	event.pressed = pressed
	event.echo = echo
	return event

func _movement_and_focus(check: Callable, tree: SceneTree) -> void:
	var spawned := _spawn(tree, Fixtures.view_layout())
	var view = spawned.view
	var use_case = spawned.use_case
	var sink = spawned.sink
	await tree.process_frame
	check.call(view.is_wired(), "configured scene wires the use case")
	var player_node: Control = view.get_node("World/Player")
	check.call(player_node.position == use_case.spawn() - use_case.player_half_extents(),
		"player marker starts at the use-case position")
	var start: Vector2 = use_case.player_position()
	tree.root.push_input(_event("move_right", true))
	await tree.physics_frame
	await tree.physics_frame
	check.call(use_case.player_position().x > start.x, "held movement action moves the player")
	check.call(player_node.position == use_case.player_position()
		- use_case.player_half_extents(), "player marker follows movement")
	tree.root.push_input(_event("move_right", false))
	var stopped: Vector2 = use_case.player_position()
	await tree.physics_frame
	await tree.physics_frame
	check.call(use_case.player_position() == stopped, "released movement action stops the player")
	check.call(sink.commands.is_empty(), "movement never submits interaction commands")

	var line_edit := LineEdit.new()
	line_edit.size = Vector2(200, 40)
	tree.root.add_child(line_edit)
	tree.root.push_input(_event("move_right", true))
	await tree.physics_frame
	await tree.physics_frame
	var moving: Vector2 = use_case.player_position()
	check.call(moving.x > stopped.x, "new press moves the player again")
	line_edit.grab_focus()
	await tree.physics_frame
	await tree.physics_frame
	check.call(use_case.player_position() == moving, "focus grab clears held movement")
	await tree.process_frame
	check.call(line_edit.has_focus(), "text input holds focus for the guard test")
	var frozen: Vector2 = use_case.player_position()
	tree.root.push_input(_event("move_right", true))
	await tree.physics_frame
	await tree.physics_frame
	check.call(use_case.player_position() == frozen, "movement ignored while text input focused")
	tree.root.push_input(_event("interact", true))
	tree.root.push_input(_event("interact", false))
	tree.root.push_input(_event("investigate", true))
	tree.root.push_input(_event("investigate", false))
	check.call(sink.commands.is_empty(), "commands ignored while text input focused")
	line_edit.release_focus()
	await tree.process_frame
	tree.root.push_input(_event("move_right", true))
	await tree.physics_frame
	await tree.physics_frame
	check.call(use_case.player_position().x > frozen.x, "movement resumes after focus release")
	tree.root.push_input(_event("move_right", false))
	line_edit.queue_free()
	await _dispose(tree, view)

func _repeat_triggers(check: Callable, tree: SceneTree) -> void:
	var spawned := _spawn(tree, Fixtures.view_layout())
	var view = spawned.view
	var sink = spawned.sink
	await tree.process_frame
	tree.root.push_input(_event("interact", true))
	check.call(sink.commands.size() == 1, "interact press submits exactly one command")
	tree.root.push_input(_event("interact", true))
	check.call(sink.commands.size() == 1, "duplicate press without release does not retrigger")
	tree.root.push_input(_event("interact", false))
	tree.root.push_input(_event("interact", true))
	check.call(sink.commands.size() == 2, "press after release submits again")
	tree.root.push_input(_event("interact", false))
	tree.root.push_input(_key("investigate", true, true))
	check.call(sink.commands.size() == 2, "key echo does not trigger investigate")
	tree.root.push_input(_key("investigate", true, false))
	check.call(sink.commands.size() == 3, "real key press submits investigate")
	tree.root.push_input(_key("investigate", false, false))
	tree.root.push_input(_key("investigate", true, true))
	check.call(sink.commands.size() == 3, "echo after release still does not trigger")
	await _dispose(tree, view)

func _reconfigure(check: Callable, tree: SceneTree) -> void:
	var spawned := _spawn(tree, Fixtures.view_layout())
	var view = spawned.view
	var first = spawned.use_case
	var first_sink = spawned.sink
	await tree.process_frame
	var second_sink = Fixtures.recording_sink()
	var second_built := Fixtures.build(Fixtures.view_layout(), second_sink)
	check.call(second_built.ok, "second use case builds")
	view.configure(second_built.value)
	await tree.process_frame
	check.call(first.proximity_changed.get_connections().is_empty(),
		"reconfigure detaches the old proximity callback")
	check.call(first.cooldown_changed.get_connections().is_empty(),
		"reconfigure detaches the old cooldown callback")
	check.call(second_built.value.proximity_changed.get_connections().size() == 1
		and second_built.value.cooldown_changed.get_connections().size() == 1,
		"reconfigure attaches only the new use case")
	first.advance(10.0)
	tree.root.push_input(_event("interact", true))
	tree.root.push_input(_event("interact", false))
	check.call(first_sink.commands.is_empty(), "old use case receives no commands after reconfigure")
	check.call(second_sink.commands.size() == 1, "new use case receives commands after reconfigure")
	await _dispose(tree, view)

func _cleanup(check: Callable, tree: SceneTree) -> void:
	var baseline := tree.root.gui_focus_changed.get_connections().size()
	var spawned := _spawn(tree, Fixtures.view_layout())
	var view = spawned.view
	var use_case = spawned.use_case
	await tree.process_frame
	check.call(use_case.proximity_changed.get_connections().size() == 1,
		"proximity callback registered while wired")
	check.call(use_case.cooldown_changed.get_connections().size() == 1,
		"cooldown callback registered while wired")
	view.queue_free()
	await tree.process_frame
	check.call(not is_instance_valid(view), "scene node released on exit")
	check.call(use_case.proximity_changed.get_connections().is_empty(),
		"proximity callback removed on scene exit")
	check.call(use_case.cooldown_changed.get_connections().is_empty(),
		"cooldown callback removed on scene exit")
	check.call(tree.root.gui_focus_changed.get_connections().size() == baseline,
		"viewport focus callback removed on scene exit")
	use_case.advance(1.0)
	use_case.move(Vector2(0, 0))
	check.call(true, "use case keeps running after the scene exits")
	var second = GreyboxScene.instantiate()
	tree.root.add_child(second)
	second.configure(use_case)
	await tree.process_frame
	check.call(second.is_wired(), "scene can rewire an existing use case")
	second.queue_free()
	await tree.process_frame
	check.call(use_case.proximity_changed.get_connections().is_empty(),
		"second scene exit also cleans callbacks")

func _unconfigured(check: Callable, tree: SceneTree) -> void:
	var view = GreyboxScene.instantiate()
	tree.root.add_child(view)
	await tree.process_frame
	check.call(not view.is_wired(), "scene without a use case stays inert")
	view.queue_free()
	await tree.process_frame
	check.call(not is_instance_valid(view), "unconfigured scene releases cleanly")
	var sink = Fixtures.recording_sink()
	var built := Fixtures.build(Fixtures.view_layout(), sink)
	var early = GreyboxScene.instantiate()
	early.configure(built.value)
	tree.root.add_child(early)
	await tree.process_frame
	check.call(early.is_wired(), "configure before entering tree wires on ready")
	tree.root.push_input(_event("interact", true))
	check.call(sink.commands.size() == 1, "early-configured scene still handles actions")
	tree.root.push_input(_event("interact", false))
	early.queue_free()
	await tree.process_frame
