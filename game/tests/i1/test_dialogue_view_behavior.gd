extends RefCounted
## I1 behavior suite: normal flow, options, free input, waiting, failure, cancel,
## retry, event hygiene, portrait/long text, missing localization and layout sizes.

const Contract = preload("res://application/contracts/dialogue_view_contract.gd")
const Transport = preload("res://application/contracts/model_transport_contract.gd")
const Chrome = preload("res://presentation/dialogue/dialogue_chrome.gd")
const HistoryPanel = preload("res://presentation/dialogue/dialogue_history_panel.gd")
const VIEW = preload("res://presentation/dialogue/dialogue_view.tscn")
const DialogueView = preload("res://presentation/dialogue/dialogue_view.gd")
const FakeDialogue = preload("res://tests/doubles/fake_dialogue_use_case.gd")

func run(check: Callable, host: Node) -> void:
	await _normal_flow(check, host)
	await _option_flow(check, host)
	await _input_guards(check, host)
	await _failure_and_retry(check, host)
	await _paused_and_cancelled(check, host)
	await _event_hygiene(check, host)
	await _portraits_and_long_text(check, host)
	await _conversation_boundary(check, host)
	await _localization_and_history(check, host)
	await _layout_sizes(check, host)

func _make(host: Node, fake: FakeDialogue = null, size: Vector2 = Vector2(1920, 1080)) -> Dictionary:
	var holder := Control.new()
	holder.name = "Holder"
	holder.set_anchors_preset(Control.PRESET_TOP_LEFT)
	holder.size = size
	holder.custom_minimum_size = size
	host.add_child(holder)
	var view := VIEW.instantiate() as DialogueView
	holder.add_child(view)
	await host.get_tree().process_frame
	if fake == null:
		fake = FakeDialogue.new()
	var configured: bool = view.configure(fake)
	return {"holder": holder, "view": view, "fake": fake, "configured": configured}

func _free(ctx: Dictionary) -> void:
	var holder: Node = ctx.holder
	var tree := holder.get_tree()
	holder.queue_free()
	await tree.process_frame

func _reply(request_id: String, text: String, options: Array = [],
		name_key: String = "npc.test.name", portrait_id: String = "") -> RefCounted:
	return Contract.verified_reply(request_id, "test.npc", name_key, portrait_id, text, options)

func _button(view: Node, node_name: String) -> Button:
	return view.find_child(node_name, true, false) as Button

func _line_edit(view: Node, node_name: String) -> LineEdit:
	return view.find_child(node_name, true, false) as LineEdit

func _options(view: Node) -> VBoxContainer:
	return view.find_child("OptionsBox", true, false) as VBoxContainer

func _history(view: Node) -> HistoryPanel:
	return view.find_child("HistoryPanel", true, false) as HistoryPanel

func _on_screen(bounds: Control, control: Control) -> bool:
	if not control.is_visible_in_tree() or control.size.x <= 0.0 or control.size.y <= 0.0:
		return false
	var rect := control.get_global_rect()
	return rect.position.y >= -1.0 and rect.end.y <= bounds.global_position.y + bounds.size.y + 1.0

func _normal_flow(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var fake: FakeDialogue = ctx.fake
	check.call(ctx.configured, "view accepts a dialogue use case")
	check.call(view.get_state() == Chrome.State.IDLE, "dialogue view starts idle")
	var submit := _button(view, "SubmitButton")
	var input := _line_edit(view, "InputEdit")
	check.call(not submit.disabled and input.editable, "idle view accepts free input")
	var states: Array[int] = []
	view.state_changed.connect(func(state: int) -> void: states.append(state))
	input.text = "  你好，原样输入  "
	submit.pressed.emit()
	check.call(fake.submissions.size() == 1, "free input submits once")
	check.call(fake.submissions[0].kind == "player_text", "free input classified as player text")
	check.call(fake.submissions[0].text == "  你好，原样输入  ", "player text submitted verbatim")
	check.call(view.get_state() == Chrome.State.WAITING, "submit enters waiting")
	check.call(submit.disabled and not input.editable, "waiting locks input")
	check.call(states.has(Chrome.State.WAITING), "state change signal reports waiting")
	var request_id := view.get_active_request_id()
	check.call(not request_id.is_empty(), "submit creates a request id")
	check.call(fake.publish(_reply(request_id, "第一句回答", [
		{"option_id": "test.ask", "text": "推荐问题"},
		{"option_id": "test.leave", "text": "告别"}])), "verified reply published")
	check.call(view.is_playback_active(), "verified reply starts progressive playback")
	check.call(view.get_visible_reply_length() == 0, "playback does not reveal full text at once")
	fake.publish(_reply(request_id, "重复第一句回答"))
	view.skip_playback()
	check.call(view.get_reply_text() == "第一句回答", "duplicate reply during playback ignored")
	check.call(not view.is_playback_active(), "skip finishes playback")
	check.call(view.get_reply_text() == "第一句回答", "full validated reply shown after playback")
	check.call(view.get_state() == Chrome.State.IDLE, "playback completion returns to idle")
	check.call(not _button(view, "SkipButton").visible, "skip control hidden after playback")
	check.call(states.has(Chrome.State.IDLE), "state change signal reports idle")
	var history := _history(view)
	check.call(history.entry_count() == 2, "history records player line and reply")
	check.call(history.get_entry_text(0) == "  你好，原样输入  ", "history keeps player text verbatim")
	check.call(history.get_entry_text(1) == "第一句回答", "history stores validated reply text")
	await _free(ctx)

func _option_flow(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var fake: FakeDialogue = ctx.fake
	var input := _line_edit(view, "InputEdit")
	input.text = "你好"
	_button(view, "SubmitButton").pressed.emit()
	var request_id := view.get_active_request_id()
	fake.publish(_reply(request_id, "请选择", [
		{"option_id": "test.ask", "text": "询问"},
		{"option_id": "test.leave", "text": "离开"}]))
	check.call(_options(view).get_child_count() == 0, "options stay hidden during playback")
	view.skip_playback()
	check.call(_options(view).get_child_count() == 2, "recommended options appear after playback")
	var first := _options(view).get_child(0) as Button
	check.call(first.text == "询问", "option text rendered")
	first.pressed.emit()
	check.call(fake.submissions.size() == 2, "option click submits a selection")
	check.call(fake.submissions[1].kind == "option_selection", "selection classified as option")
	check.call(fake.submissions[1].option_id == "test.ask", "selected option id preserved")
	check.call(view.get_state() == Chrome.State.WAITING, "option selection enters waiting")
	check.call(_options(view).get_child_count() == 0, "options cleared after selection")
	check.call(_history(view).get_entry_text(2) == "询问", "player option echoed verbatim")
	var next_id := view.get_active_request_id()
	fake.publish(_reply(next_id, "第二轮回答"))
	view.skip_playback()
	check.call(view.get_state() == Chrome.State.IDLE, "second reply completes without options")
	check.call(_options(view).get_child_count() == 0, "no options for optionless reply")
	await _free(ctx)

func _input_guards(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var fake: FakeDialogue = ctx.fake
	var input := _line_edit(view, "InputEdit")
	var submit := _button(view, "SubmitButton")
	input.text = "   "
	submit.pressed.emit()
	check.call(fake.submissions.is_empty(), "blank input is not submitted")
	check.call(view.get_state() == Chrome.State.IDLE, "blank input keeps view idle")
	input.text = "重复提交"
	submit.pressed.emit()
	submit.pressed.emit()
	check.call(fake.submissions.size() == 1, "consecutive submit clicks are de-duplicated")
	check.call(view.get_state() == Chrome.State.WAITING, "first click wins the wait state")
	submit.pressed.emit()
	check.call(fake.submissions.size() == 1, "submit during waiting is ignored")
	fake.publish(_reply(view.get_active_request_id(), "重复提交已收到"))
	view.skip_playback()
	check.call(view.get_state() == Chrome.State.IDLE, "reply returns view to idle")
	input.text = "字".repeat(4001)
	input.text_submitted.emit(input.text)
	check.call(fake.submissions.size() == 1, "contract-rejected input is not submitted")
	check.call(view.get_state() == Chrome.State.IDLE, "rejected input keeps view idle")
	var status := view.find_child("StatusLabel", true, false) as Label
	check.call(status.visible and status.text == "dialogue.free_text.rejected",
		"local rejection notice is localized-key safe")
	await _free(ctx)

func _failure_and_retry(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var fake: FakeDialogue = ctx.fake
	var input := _line_edit(view, "InputEdit")
	input.text = "重试测试"
	_button(view, "SubmitButton").pressed.emit()
	var first_request := view.get_active_request_id()
	var history := _history(view)
	var history_before := history.entry_count()
	fake.publish(Contract.status(first_request, Contract.STATUS_FAILED, Transport.MODEL_TIMEOUT, true))
	check.call(view.get_state() == Chrome.State.FAILED, "retryable failure enters failed state")
	check.call(view.get_last_error_code() == Transport.MODEL_TIMEOUT, "stable error code retained")
	var retry := _button(view, "RetryButton")
	check.call(retry.visible, "retry control appears for retryable failure")
	check.call(_button(view, "BackButton").visible, "back control appears on failure")
	var status := view.find_child("StatusLabel", true, false) as Label
	check.call(status.text.contains(Transport.MODEL_TIMEOUT), "failure text exposes stable code")
	retry.pressed.emit()
	check.call(fake.submissions.size() == 2, "retry resubmits once")
	check.call(fake.submissions[1].text == "重试测试", "retry reuses original player text")
	check.call(view.get_state() == Chrome.State.WAITING, "retry returns to waiting")
	var second_request := view.get_active_request_id()
	check.call(second_request != first_request, "retry uses a new request id")
	fake.publish(_reply(first_request, "过期回复"))
	check.call(view.get_state() == Chrome.State.WAITING, "late reply for the old request is ignored")
	check.call(history.entry_count() == history_before, "late reply does not touch history")
	fake.publish(_reply(second_request, "重试成功"))
	view.skip_playback()
	check.call(view.get_state() == Chrome.State.IDLE, "retried request completes")
	check.call(history.get_entry_text(history.entry_count() - 1) == "重试成功",
		"retried reply enters history")
	await _free(ctx)

func _paused_and_cancelled(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var fake: FakeDialogue = ctx.fake
	_line_edit(view, "InputEdit").text = "暂停"
	_button(view, "SubmitButton").pressed.emit()
	fake.publish(Contract.status(view.get_active_request_id(), Contract.STATUS_FAILED,
		Transport.MODEL_RESPONSE_INVALID, false))
	check.call(view.get_state() == Chrome.State.PAUSED, "non-retryable failure pauses dialogue")
	check.call(not _button(view, "RetryButton").visible, "pause hides retry")
	check.call(_button(view, "BackButton").visible, "pause offers back")
	var backs: Array[int] = []
	view.back_requested.connect(func() -> void: backs.append(1))
	_button(view, "BackButton").pressed.emit()
	check.call(backs.size() == 1, "back control emits a presentation request")
	var status := view.find_child("StatusLabel", true, false) as Label
	check.call(status.text.contains("dialogue.paused"), "pause status visible without localization")
	await _free(ctx)
	var second := await _make(host)
	var cancel_view: DialogueView = second.view
	var cancel_fake: FakeDialogue = second.fake
	_line_edit(cancel_view, "InputEdit").text = "取消测试"
	_button(cancel_view, "SubmitButton").pressed.emit()
	check.call(cancel_fake.publish(Contract.status(cancel_view.get_active_request_id(),
		Contract.STATUS_CANCELLED)), "cancelled status published")
	check.call(cancel_view.get_state() == Chrome.State.CANCELLED, "cancelled status reaches view")
	check.call(_button(cancel_view, "RetryButton").visible, "cancelled dialogue can be retried")
	_button(cancel_view, "RetryButton").pressed.emit()
	check.call(cancel_fake.submissions.size() == 2, "cancel retry resubmits")
	check.call(cancel_view.get_state() == Chrome.State.WAITING, "cancel retry waits again")
	cancel_fake.publish(Contract.status(cancel_view.get_active_request_id(), Contract.STATUS_IDLE))
	check.call(cancel_view.get_state() == Chrome.State.IDLE, "idle status returns view to idle")
	check.call(_line_edit(cancel_view, "InputEdit").editable, "idle status unlocks input")
	await _free(second)

func _event_hygiene(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var fake: FakeDialogue = ctx.fake
	var history := _history(view)
	var history_before := history.entry_count()
	var rejected_before := view.get_rejected_event_count()
	fake.view_event.emit({"text": "未验证文本"})
	check.call(view.get_rejected_event_count() == rejected_before + 1, "uncontracted event rejected")
	check.call(history.entry_count() == history_before, "rejected event does not reach history")
	var forged := {"schema_version": 1, "kind": "verified_reply", "request_id": "forged.request",
		"speaker_id": "test.npc", "name_key": "npc.test.name", "portrait_id": "",
		"text": "夹带原始流", "options": [], "raw_delta": "secret"}
	fake.view_event.emit(forged)
	check.call(view.get_rejected_event_count() == rejected_before + 2, "forged reply with raw field rejected")
	check.call(history.entry_count() == history_before, "forged reply never displayed")
	fake.view_event.emit({"schema_version": 1, "kind": "status", "request_id": "forged.request",
		"status": "failed", "error_code": "provider stack trace with bearer token", "retryable": true})
	check.call(view.get_rejected_event_count() == rejected_before + 3,
		"provider error text rejected as unstable code")
	_line_edit(view, "InputEdit").text = "保持等待"
	_button(view, "SubmitButton").pressed.emit()
	var active := view.get_active_request_id()
	fake.publish(Contract.status("stale.request", Contract.STATUS_FAILED, Transport.MODEL_TIMEOUT, true))
	check.call(view.get_state() == Chrome.State.WAITING, "unknown-request status ignored")
	fake.publish(Contract.status(active, Contract.STATUS_FAILED, Transport.MODEL_TIMEOUT, true))
	check.call(view.get_state() == Chrome.State.FAILED, "active-request status applied")
	await _free(ctx)
	var push := await _make(host)
	var push_view: DialogueView = push.view
	var push_fake: FakeDialogue = push.fake
	var push_history := _history(push_view)
	push_fake.publish(_reply("scene.greeting", "未登记问候"))
	push_view.skip_playback()
	check.call(push_history.entry_count() == 0, "unregistered push reply rejected")
	check.call(push_view.get_state() == Chrome.State.IDLE, "unregistered push keeps view idle")
	check.call(not push_view.register_push(""), "empty push id rejected")
	check.call(push_view.register_push("scene.greeting"), "opening push id registered")
	check.call(push_fake.publish(_reply("scene.greeting", "欢迎抵达")), "registered push accepted")
	push_view.skip_playback()
	check.call(push_history.entry_count() == 1, "registered push enters history without player line")
	check.call(not push_view.register_push("scene.greeting"), "closed push id cannot be re-registered")
	push_fake.publish(_reply("scene.greeting", "重复欢迎"))
	push_view.skip_playback()
	check.call(push_history.entry_count() == 1, "closed request cannot be replayed")
	check.call(push_view.get_reply_text() == "欢迎抵达", "replayed reply does not replace shown text")
	_line_edit(push_view, "InputEdit").text = "活动请求"
	_button(push_view, "SubmitButton").pressed.emit()
	var active_push := push_view.get_active_request_id()
	check.call(push_view.register_push("scene.interrupt"), "push registered during active request")
	push_fake.publish(_reply("scene.interrupt", "插话"))
	check.call(push_history.entry_count() == 2, "registered push ignored while a request is active")
	check.call(push_view.get_state() == Chrome.State.WAITING, "active request keeps waiting")
	push_fake.publish(_reply(active_push, "活动回复"))
	push_view.skip_playback()
	push_fake.publish(_reply("scene.interrupt", "迟到插话"))
	push_view.skip_playback()
	check.call(push_history.entry_count() == 4, "registered push shown after the active request closes")
	await _free(push)
	var status_push := await _make(host)
	status_push.view.register_push("scene.opening")
	check.call(status_push.fake.publish(Contract.status("scene.opening", Contract.STATUS_WAITING)),
		"registered push status published")
	check.call(status_push.view.get_state() == Chrome.State.WAITING,
		"registered push status promotes to active wait")
	status_push.fake.publish(_reply("scene.opening", "开场白"))
	status_push.view.skip_playback()
	check.call(_history(status_push.view).entry_count() == 1, "promoted push reply presented")
	await _free(status_push)

func _portraits_and_long_text(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var fake: FakeDialogue = ctx.fake
	view.register_push("scene.one")
	fake.publish(_reply("scene.one", "无立绘", [], "npc.test.name", "npc.missing"))
	check.call(not (view.find_child("PortraitTexture", true, false) as TextureRect).visible,
		"missing portrait keeps texture hidden")
	var fallback := view.find_child("PortraitFallback", true, false) as Label
	check.call(fallback.visible and fallback.text == "dialogue.portrait.missing",
		"missing portrait shows localized-key placeholder")
	view.skip_playback()
	var texture := GradientTexture2D.new()
	view.register_portrait("npc.test", texture)
	view.register_push("scene.two")
	fake.publish(_reply("scene.two", "有立绘", [], "npc.test.name", "npc.test"))
	var portrait := view.find_child("PortraitTexture", true, false) as TextureRect
	check.call(portrait.visible and portrait.texture == texture, "registered portrait displayed")
	check.call(not fallback.visible, "registered portrait hides placeholder")
	view.skip_playback()
	var long_text := "长".repeat(8000)
	view.register_push("scene.long")
	fake.publish(_reply("scene.long", long_text))
	view.skip_playback()
	check.call(view.get_reply_text().length() == 8000, "8000 character reply presented fully")
	check.call(_line_edit(view, "InputEdit").editable, "long reply keeps input usable")
	var long_option := "选".repeat(Contract.MAX_OPTION_TEXT_LENGTH)
	view.register_push("scene.options")
	fake.publish(_reply("scene.options", "超长选项", [{"option_id": "test.long", "text": long_option}]))
	view.skip_playback()
	var option_button := _options(view).get_child(0) as Button
	check.call(option_button.text.length() == Contract.MAX_OPTION_TEXT_LENGTH,
		"max-length option text rendered")
	await _free(ctx)

## A conversation boundary must clear the previous NPC's reply/options/name and mark the
## transcript, and leaving the dialogue must always be one visible click away.
func _conversation_boundary(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var fake: FakeDialogue = ctx.fake
	check.call(_button(view, "BackButton").visible, "idle dialogue offers a visible way out")
	var input := _line_edit(view, "InputEdit")
	input.text = "你好"
	_button(view, "SubmitButton").pressed.emit()
	check.call(_button(view, "BackButton").visible, "waiting dialogue offers a visible way out")
	var request_id := view.get_active_request_id()
	fake.publish(_reply(request_id, "第一句回答", [
		{"option_id": "test.ask", "text": "询问"}]))
	view.skip_playback()
	check.call(_options(view).get_child_count() == 1, "options shown before the boundary")
	view.begin_conversation("npc.other.name")
	check.call(view.get_reply_text().is_empty(), "new conversation clears the previous reply")
	check.call(_options(view).get_child_count() == 0, "new conversation clears the previous options")
	var name_label := view.find_child("SpeakerName", true, false) as Label
	check.call(name_label != null and name_label.text == "npc.other.name",
		"new conversation names the new speaker before any reply")
	check.call(view.get_state() == Chrome.State.IDLE, "new conversation starts idle")
	check.call(_history(view).entry_count() == 3,
		"transcript marks the conversation boundary instead of merging both speakers")
	await _free(ctx)

func _localization_and_history(check: Callable, host: Node) -> void:
	var ctx := await _make(host)
	var view: DialogueView = ctx.view
	var status := view.find_child("StatusLabel", true, false) as Label
	_line_edit(view, "InputEdit").text = "缺失本地化"
	_button(view, "SubmitButton").pressed.emit()
	check.call(status.text == "dialogue.waiting", "missing localization falls back to key")
	var history := _history(view)
	check.call(_editable_count(history) == 0, "history panel is read-only")
	var history_button := _button(view, "HistoryButton")
	check.call(not history.visible, "history starts hidden")
	history_button.pressed.emit()
	check.call(history.visible, "history toggle opens panel")
	var close := history.find_child("HistoryCloseButton", true, false) as Button
	close.pressed.emit()
	check.call(not history.visible, "history close hides panel")
	await _free(ctx)
	var translation := Translation.new()
	translation.locale = "i1_test"
	translation.add_message("dialogue.waiting", "等待中")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("i1_test")
	var localized := await _make(host)
	_line_edit(localized.view, "InputEdit").text = "本地化"
	_button(localized.view, "SubmitButton").pressed.emit()
	var localized_status := localized.view.find_child("StatusLabel", true, false) as Label
	check.call(localized_status.text == "等待中", "installed translation is used")
	TranslationServer.remove_translation(translation)
	TranslationServer.set_locale("zh_CN")
	await _free(localized)

func _editable_count(node: Node) -> int:
	var count := 0
	if node is LineEdit or node is TextEdit:
		count += 1
	for child: Node in node.get_children():
		count += _editable_count(child)
	return count

func _layout_sizes(check: Callable, host: Node) -> void:
	for size: Vector2 in [Vector2(1280, 720), Vector2(1366, 768), Vector2(1920, 1080), Vector2(2560, 1440)]:
		var ctx := await _make(host, null, size)
		var view: DialogueView = ctx.view
		check.call(view.size.is_equal_approx(size), "view fills %s" % str(size))
		var submit := _button(view, "SubmitButton")
		var input := _line_edit(view, "InputEdit")
		var box := view.find_child("DialogueBox", true, false) as Control
		var portrait := view.find_child("PortraitFrame", true, false) as Control
		check.call(_on_screen(view, submit), "submit visible at %s" % str(size))
		check.call(_on_screen(view, input) and input.size.x >= 240.0, "input visible at %s" % str(size))
		check.call(box.size.y >= 280.0 and box.size.y <= size.y, "dialogue box fits %s" % str(size))
		check.call(portrait.size.x > 0.0 and portrait.size.y > 0.0, "portrait area present at %s" % str(size))
		await _free(ctx)
