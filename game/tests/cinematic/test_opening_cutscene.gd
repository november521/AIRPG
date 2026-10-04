extends RefCounted
## Opening-cutscene suite: the video gate that runs before the Dead Light instance is built.
##
## A headless run cannot display a stream, so the suite drives the same paths the player does --
## the skip button, the keyboard shortcut, a stream that cannot play at all -- and checks that the
## entry flow is released exactly once, because a gate that never opens would cost the instance.
const OpeningCutscene = preload("res://presentation/cinematic/opening_cutscene.gd")
const VIEW = preload("res://presentation/cinematic/opening_cutscene.tscn")

func run(check: Callable, tree: SceneTree) -> void:
	await _scene_shape(check, tree)
	await _begin_without_playback_finishes(check, tree)
	await _skip_is_idempotent(check, tree)
	await _input_shortcut(check, tree)
	await _movement_keys_do_not_skip(check, tree)

func _make(tree: SceneTree) -> Dictionary:
	var holder := Control.new()
	holder.name = "CutsceneHolder"
	holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	holder.size = Vector2(1280, 720)
	tree.root.add_child(holder)
	var view := VIEW.instantiate() as OpeningCutscene
	holder.add_child(view)
	await tree.process_frame
	return {"holder": holder, "view": view}

func _free(holder: Control, tree: SceneTree) -> void:
	holder.queue_free()
	await tree.process_frame

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event

func _scene_shape(check: Callable, tree: SceneTree) -> void:
	var built := await _make(tree)
	var view: OpeningCutscene = built.view
	var video := view.get_node("Video") as VideoStreamPlayer
	check.call(video != null and video.stream != null,
		"CUTSCENE: the opening video is imported and bound to the player")
	check.call(view.get_node_or_null("SkipButton") is Button,
		"CUTSCENE: the opening offers a skip control")
	check.call(view.get_node_or_null("Guard") is Timer,
		"CUTSCENE: the opening arms a guard for a stream that never ends")
	check.call(tr("cutscene.skip") != "cutscene.skip",
		"CUTSCENE: the skip control carries a translation, not a key")
	check.call(tr("cutscene.hint") != "cutscene.hint",
		"CUTSCENE: the hint line is translated")
	await _free(built.holder, tree)

func _begin_without_playback_finishes(check: Callable, tree: SceneTree) -> void:
	var built := await _make(tree)
	var view: OpeningCutscene = built.view
	var done: Array = []
	view.finished.connect(func() -> void: done.append(1))
	view.configure(false)
	view.begin()
	var video := view.get_node("Video") as VideoStreamPlayer
	check.call(done.size() == 1,
		"CUTSCENE: a run without playback releases the entry flow immediately")
	check.call(not video.is_playing(),
		"CUTSCENE: nothing is left playing after the opening is released")
	await _free(built.holder, tree)

func _skip_is_idempotent(check: Callable, tree: SceneTree) -> void:
	var built := await _make(tree)
	var view: OpeningCutscene = built.view
	var done: Array = []
	view.finished.connect(func() -> void: done.append(1))
	view.skip()
	view.skip()
	check.call(done.size() == 1,
		"CUTSCENE: a second skip does not enter the instance twice")
	view.begin()
	view.skip()
	check.call(done.size() == 1,
		"CUTSCENE: releasing an already finished opening stays final")
	await _free(built.holder, tree)

func _input_shortcut(check: Callable, tree: SceneTree) -> void:
	var built := await _make(tree)
	var view: OpeningCutscene = built.view
	var done: Array = []
	view.finished.connect(func() -> void: done.append(1))
	view._input(_key(KEY_ESCAPE))
	check.call(done.size() == 1, "CUTSCENE: escape skips the opening")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	view._input(mouse)
	check.call(done.size() == 1, "CUTSCENE: a click after a skip changes nothing")
	await _free(built.holder, tree)

func _movement_keys_do_not_skip(check: Callable, tree: SceneTree) -> void:
	var built := await _make(tree)
	var view: OpeningCutscene = built.view
	var done: Array = []
	view.finished.connect(func() -> void: done.append(1))
	view._input(_key(KEY_W))
	check.call(done.is_empty(), "CUTSCENE: walking keys do not cut the opening short")
	view._input(_key(KEY_SPACE))
	check.call(done.size() == 1, "CUTSCENE: space skips the opening")
	await _free(built.holder, tree)
