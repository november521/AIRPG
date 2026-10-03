extends RefCounted
## I1 lifecycle and isolation suite: release, scene free, reconfigure and source guards.

const Contract = preload("res://application/contracts/dialogue_view_contract.gd")
const Transport = preload("res://application/contracts/model_transport_contract.gd")
const Chrome = preload("res://presentation/dialogue/dialogue_chrome.gd")
const HistoryPanel = preload("res://presentation/dialogue/dialogue_history_panel.gd")
const VIEW = preload("res://presentation/dialogue/dialogue_view.tscn")
const DialogueView = preload("res://presentation/dialogue/dialogue_view.gd")
const FakeDialogue = preload("res://tests/doubles/fake_dialogue_use_case.gd")

const PRODUCTION_SCRIPTS: Array[String] = [
	"res://presentation/dialogue/dialogue_view.gd",
	"res://presentation/dialogue/dialogue_chrome.gd",
	"res://presentation/dialogue/dialogue_layout.gd",
	"res://presentation/dialogue/dialogue_options.gd",
	"res://presentation/dialogue/dialogue_playback.gd",
	"res://presentation/dialogue/dialogue_history_panel.gd",
]

func run(check: Callable, host: Node) -> void:
	await _released_view_ignores_events(check, host)
	await _freed_view_ignores_late_events(check, host)
	await _reconfigure_switches_source(check, host)
	await _reconfigure_stops_playback(check, host)
	await _release_then_configure_resumes(check, host)
	_production_sources_stay_isolated(check)

func _make(host: Node) -> Dictionary:
	var holder := Control.new()
	holder.name = "Holder"
	holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	holder.size = Vector2(1920, 1080)
	host.add_child(holder)
	var view := VIEW.instantiate() as DialogueView
	holder.add_child(view)
	await host.get_tree().process_frame
	var fake := FakeDialogue.new()
	view.configure(fake)
	return {"holder": holder, "view": view, "fake": fake}

func _free(ctx: Dictionary) -> void:
	var holder: Node = ctx.holder
	var tree := holder.get_tree()
	holder.queue_free()
	await tree.process_frame

func _reply(request_id: String, text: String) -> RefCounted:
	return Contract.verified_reply(request_id, "test.npc", "npc.test.name", "", text, [])

func _button(view: Node, node_name: String) -> Button:
	return view.find_child(node_name, true, false) as Button

func _line_edit(view: Node, node_name: String) -> LineEdit:
	return view.find_child(node_name, true, false) as LineEdit

func _history(view: Node) -> HistoryPanel:
	return view.find_child("HistoryPanel", true, false) as HistoryPanel

func _released_view_ignores_events(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var fake: FakeDialogue = ctx.fake
	_line_edit(view, "InputEdit").text = "释放前"
	_button(view, "SubmitButton").pressed.emit()
	var active := view.get_active_request_id()
	var presented: Array[int] = []
	view.reply_presented.connect(func(_id: String) -> void: presented.append(1))
	view.release()
	fake.publish(_reply(active, "迟到回复"))
	view.skip_playback()
	check.call(presented.is_empty(), "released view presents nothing")
	check.call(view.get_state() == Chrome.State.WAITING, "released view keeps frozen state")
	check.call(view.get_reply_text() == "", "released view does not accept reply text")
	check.call(view.get_rejected_event_count() == 0, "released view does not process events")
	await _free(ctx)

func _freed_view_ignores_late_events(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var fake: FakeDialogue = ctx.fake
	var presented: Array[int] = []
	view.reply_presented.connect(func(_id: String) -> void: presented.append(1))
	_line_edit(view, "InputEdit").text = "场景切换"
	_button(view, "SubmitButton").pressed.emit()
	var active := view.get_active_request_id()
	await _free(ctx)
	check.call(not is_instance_valid(view), "view freed on scene switch")
	fake.publish(_reply(active, "切场景后迟到"))
	fake.publish(Contract.status(active, Contract.STATUS_FAILED, Transport.MODEL_TIMEOUT, true))
	check.call(presented.is_empty(), "late events after scene free never present")

func _reconfigure_switches_source(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var first: FakeDialogue = ctx.fake
	_line_edit(view, "InputEdit").text = "第一会话"
	_button(view, "SubmitButton").pressed.emit()
	var stale := view.get_active_request_id()
	check.call(view.register_push("scene.old_push"), "old session push registered")
	var second := FakeDialogue.new()
	check.call(view.configure(second), "second use case configures")
	first.publish(_reply(stale, "旧源回复"))
	check.call(view.get_state() == Chrome.State.IDLE, "old source events are disconnected")
	check.call(view.get_reply_text() == "", "old source cannot change the view")
	second.publish(_reply("scene.old_push", "旧推送回复"))
	check.call(view.get_reply_text() == "", "reconfigure clears registered pushes")
	_line_edit(view, "InputEdit").text = "第二会话"
	_button(view, "SubmitButton").pressed.emit()
	check.call(second.submissions.size() == 1, "new source receives submissions")
	check.call(first.submissions.size() == 1, "old source receives nothing further")
	await _free(ctx)

func _reconfigure_stops_playback(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var first: FakeDialogue = ctx.fake
	check.call(view.register_push("scene.long"), "long opening registered as push")
	first.publish(_reply("scene.long", "未完成的旧开场"))
	check.call(view.is_playback_active(), "playback active before reconfigure")
	var presented: Array[int] = []
	view.reply_presented.connect(func(_id: String) -> void: presented.append(1))
	var second := FakeDialogue.new()
	check.call(view.configure(second), "reconfigure accepts a new use case")
	check.call(not view.is_playback_active(), "reconfigure stops old playback")
	check.call(view.get_reply_text() == "", "reconfigure clears displayed reply")
	check.call(_history(view).entry_count() == 0, "reconfigure clears old history")
	check.call(view.get_state() == Chrome.State.IDLE, "reconfigure resets to idle")
	_line_edit(view, "InputEdit").text = "新会话"
	_button(view, "SubmitButton").pressed.emit()
	check.call(view.get_state() == Chrome.State.WAITING, "new session request waits")
	view._on_playback_finished()
	check.call(view.get_state() == Chrome.State.WAITING, "stale playback callback cannot reset new session")
	check.call(presented.is_empty(), "stale playback callback presents nothing")
	check.call(second.submissions.size() == 1, "new session submission intact")
	await _free(ctx)

func _release_then_configure_resumes(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var fake: FakeDialogue = ctx.fake
	view.release()
	check.call(view.configure(fake), "view reconfigures after release")
	_line_edit(view, "InputEdit").text = "恢复"
	_button(view, "SubmitButton").pressed.emit()
	check.call(fake.submissions.size() == 1, "reconfigured view submits again")
	check.call(view.get_state() == Chrome.State.WAITING, "reconfigured view waits again")
	await _free(ctx)

func _production_sources_stay_isolated(check: Callable) -> void:
	var forbidden: Array[String] = ["raw_delta", "ModelProvider", "StateStore", "infrastructure",
		"domain/", "save_repository", "FileAccess", "ResourceLoader", "HTTPClient", "HTTPRequest",
		"class_name", "SceneTree", "RandomNumberGenerator"]
	var loader_pattern := RegEx.new()
	loader_pattern.compile("\\bload\\s*\\(")
	var input_pattern := RegEx.new()
	input_pattern.compile("(?i)\\binput\\b")
	for path: String in PRODUCTION_SCRIPTS:
		var file := FileAccess.open(path, FileAccess.READ)
		check.call(file != null, "source readable: " + path)
		if file == null:
			continue
		var source := file.get_as_text()
		file.close()
		for token: String in forbidden:
			check.call(not source.contains(token), "%s free of %s" % [path, token])
		check.call(loader_pattern.search(source) == null, path + " uses explicit preload only")
		check.call(input_pattern.search(source) == null, path + " avoids direct input polling")
