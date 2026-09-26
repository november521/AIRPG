extends RefCounted
## F1 use-case suite: safe publication, cancellation/staleness/duplicate rejection,
## model-context isolation and no authoritative state changes on failure.

const Transport = preload("res://application/contracts/model_transport_contract.gd")
const ViewContract = preload("res://application/contracts/dialogue_view_contract.gd")
const Registry = preload("res://application/dialogue/dialogue_request_registry.gd")
const RejectingProvider = preload("res://tests/f1/f1_rejecting_provider.gd")
const Fixtures = preload("res://tests/f1/f1_fixtures.gd")

func run(check: Callable) -> void:
	_happy_path(check)
	_scope_failures(check)
	_cancel_and_stale(check)
	_duplicates_and_unknown(check)
	_failure_paths(check)
	_option_flow(check)
	_context_isolation(check)
	_configuration(check)

func _harness(check: Callable, opened: bool = true) -> Dictionary:
	var harness := Fixtures.build()
	check.call(harness.result.ok, "F1 use case builds from explicit config")
	if opened:
		check.call(harness.use_case.begin_exchange(Fixtures.SPEAKER_A, Fixtures.SCENE,
			Fixtures.TOPIC).ok, "dialogue exchange opened for synthetic NPC")
	return harness

func _happy_path(check: Callable) -> void:
	var h := _harness(check)
	var before: Dictionary = h.state.snapshot()
	check.call(h.use_case.submit_text("test.request.1", "玩家原话").ok,
		"valid player text accepted")
	check.call(h.events.size() == 1 and h.events[0].kind == "status" \
		and h.events[0].status == ViewContract.STATUS_WAITING, "waiting status emitted once")
	var context: Dictionary = h.provider.accepted["test.request.1"].filtered_context
	check.call(context.speaker_id == Fixtures.SPEAKER_A and context.scene_id == Fixtures.SCENE \
		and context.topic_id == Fixtures.TOPIC, "transport receives the exchange binding")
	check.call(context.untrusted.player_text == "玩家原话",
		"player words are marked untrusted in the model context")
	var trusted: Array = []
	for fact: Dictionary in context.trusted_facts:
		trusted.append(fact.fact_id)
	check.call(trusted.has("test.fact.road_public") and trusted.has("test.fact.npc_a_secret") \
		and not trusted.has("test.fact.npc_b_secret"), "model context carries only NPC A facts")
	check.call(h.provider.complete("test.request.1", Fixtures.reply()),
		"programmable provider completes once")
	var verified := Fixtures.verified(h.events)
	check.call(verified.size() == 1, "exactly one verified reply event published")
	check.call(verified[0].request_id == "test.request.1" \
		and verified[0].speaker_id == Fixtures.SPEAKER_A,
		"verified reply keeps request and speaker identity")
	check.call(verified[0].text == "合成回答文本" and verified[0].options.size() == 1,
		"verified reply carries text and recommended options")
	check.call(ViewContract.validate_view_event(verified[0]).ok,
		"published event validates against the view contract")
	check.call(h.state.snapshot() == before, "successful dialogue does not mutate authoritative state")
	h.use_case.release()

func _scope_failures(check: Callable) -> void:
	var h := _harness(check)
	var before: Dictionary = h.state.snapshot()
	h.use_case.submit_text("test.request.1", "第一句")
	h.provider.complete("test.request.1", Fixtures.reply({"speaker_id": Fixtures.SPEAKER_B}))
	check.call(Fixtures.verified(h.events).is_empty(), "wrong speaker reply never displayed")
	var failed := Fixtures.statuses(h.events, ViewContract.STATUS_FAILED)
	check.call(failed.size() == 1 and failed[0].error_code == Transport.KNOWLEDGE_SCOPE_VIOLATION \
		and failed[0].retryable, "wrong speaker reports knowledge scope violation")
	h.use_case.submit_text("test.request.2", "第二句")
	h.provider.complete("test.request.2", Fixtures.reply({"used_fact_ids": ["test.fact.npc_b_secret"]}))
	check.call(Fixtures.verified(h.events).is_empty(), "unauthorized fact reply never displayed")
	check.call(Fixtures.statuses(h.events, ViewContract.STATUS_FAILED).size() == 2,
		"unauthorized fact reports a stable failure")
	h.use_case.submit_text("test.request.3", "第三句")
	h.provider.complete("test.request.3", Fixtures.reply({"used_fact_ids": ["test.fact.missing"]}))
	check.call(Fixtures.verified(h.events).is_empty(), "nonexistent fact reply never displayed")
	h.use_case.submit_text("test.request.4", "第四句")
	h.provider.complete("test.request.4", Fixtures.reply({"actions": [
		{"command_id": "test.action.disengage", "parameters": {"mood": "hostile"}}]}))
	check.call(Fixtures.verified(h.events).is_empty(), "invalid action proposal never displayed")
	check.call(h.state.snapshot() == before, "scope failures never mutate authoritative state")
	h.use_case.release()

func _cancel_and_stale(check: Callable) -> void:
	var h := _harness(check)
	h.use_case.submit_text("test.request.1", "会被取消")
	check.call(h.use_case.cancel("test.request.1"), "active request cancelled")
	check.call(Fixtures.statuses(h.events, ViewContract.STATUS_CANCELLED).size() == 1,
		"cancellation status emitted")
	var event_count: int = h.events.size()
	h.provider.force_complete("test.request.1", Fixtures.reply())
	check.call(h.events.size() == event_count and Fixtures.verified(h.events).is_empty(),
		"late result after cancellation cannot display")
	check.call(not h.use_case.cancel("test.request.1"), "second cancellation is a no-op")
	h.use_case.submit_text("test.request.2", "会被过期")
	check.call(h.state.commit(0, {Fixtures.FLAG_CONFIDED: true}).ok,
		"test commits an authoritative revision change while the request is in flight")
	var after_commit: Dictionary = h.state.snapshot()
	h.provider.complete("test.request.2", Fixtures.reply())
	var stale := Fixtures.statuses(h.events, ViewContract.STATUS_FAILED)
	check.call(Fixtures.verified(h.events).is_empty(), "stale revision reply never displayed")
	check.call(stale.size() == 1 and stale[0].error_code == Transport.REQUEST_STALE \
		and not stale[0].retryable, "stale revision reports REQUEST_STALE")
	check.call(h.state.snapshot() == after_commit, "stale handling does not mutate state")
	h.use_case.release()

func _duplicates_and_unknown(check: Callable) -> void:
	var h := _harness(check)
	h.use_case.submit_text("test.request.1", "第一句")
	h.provider.complete("test.request.1", Fixtures.reply())
	var count: int = h.events.size()
	h.provider.force_complete("test.request.1", Fixtures.reply({"reply_text": "重复"}))
	check.call(h.events.size() == count and Fixtures.verified(h.events).size() == 1,
		"second completion of the same request is ignored")
	h.provider.force_complete("test.request.other", Fixtures.reply())
	h.provider.force_failure("test.request.other", Transport.MODEL_TIMEOUT)
	check.call(h.events.size() == count, "results with a wrong request ID are ignored")
	check.call(Fixtures.verified(h.events).size() == 1, "only the first valid reply was displayed")
	h.use_case.release()

func _failure_paths(check: Callable) -> void:
	var h := _harness(check)
	var before: Dictionary = h.state.snapshot()
	h.use_case.submit_text("test.request.1", "会失败")
	h.provider.fail("test.request.1", Transport.MODEL_TIMEOUT)
	var failed := Fixtures.statuses(h.events, ViewContract.STATUS_FAILED)
	check.call(failed.size() == 1 and failed[0].error_code == Transport.MODEL_TIMEOUT \
		and failed[0].retryable, "transport failure reports a retryable stable error")
	check.call(Fixtures.verified(h.events).is_empty(), "transport failure never displays a reply")
	check.call(h.state.snapshot() == before, "transport failure never mutates state")
	h.use_case.submit_text("test.request.2", "非法回复")
	h.provider.complete("test.request.2", {"unexpected": true})
	check.call(Fixtures.verified(h.events).is_empty(), "malformed model payload never displayed")
	var all_failed := Fixtures.statuses(h.events, ViewContract.STATUS_FAILED)
	check.call(all_failed.size() == 2 \
		and all_failed[1].error_code == Transport.MODEL_RESPONSE_INVALID,
		"malformed payload fails closed as MODEL_RESPONSE_INVALID")
	check.call(h.state.snapshot() == before, "malformed payload never mutates state")
	h.use_case.submit_text("test.request.3", "模拟断流")
	h.provider.fail("test.request.3", Transport.MODEL_TRANSPORT_ERROR)
	var transport_failures := Fixtures.statuses(h.events, ViewContract.STATUS_FAILED)
	check.call(transport_failures.size() == 3 \
		and transport_failures[2].error_code == Transport.MODEL_TRANSPORT_ERROR \
		and transport_failures[2].retryable,
		"transport interruption reports a retryable stable error")
	check.call(h.state.snapshot() == before, "transport interruption never mutates state")
	h.use_case.release()
	var rejecting := Fixtures.build({"provider": RejectingProvider.new()})
	check.call(rejecting.result.ok, "rejecting provider harness builds")
	rejecting.use_case.begin_exchange(Fixtures.SPEAKER_A, Fixtures.SCENE, Fixtures.TOPIC)
	check.call(not rejecting.use_case.submit_text("test.request.1", "无法开始").ok,
		"provider sync rejection propagates to the caller")
	check.call(Fixtures.verified(rejecting.events).is_empty(), "sync rejection emits no reply")
	check.call(rejecting.state.snapshot() == before, "sync rejection never mutates state")
	rejecting.use_case.release()

func _option_flow(check: Callable) -> void:
	var h := _harness(check)
	h.use_case.submit_text("test.request.1", "问题")
	h.provider.complete("test.request.1", Fixtures.reply())
	check.call(h.use_case.select_option("test.request.2", "test.option.continue").ok,
		"recommended option starts a new request")
	check.call(h.provider.accepted["test.request.2"].filtered_context.untrusted.player_text \
		== "继续追问", "option text becomes the player utterance unchanged")
	check.call(not h.use_case.select_option("test.request.3", "test.option.missing").ok,
		"unknown option ID rejected")
	h.use_case.release()

func _context_isolation(check: Callable) -> void:
	var h := _harness(check)
	var before: Dictionary = h.state.snapshot()
	h.use_case.submit_text("test.request.1", "玩家原话")
	var context: Dictionary = h.provider.accepted["test.request.1"].filtered_context
	var serialized := JSON.stringify(context)
	check.call(not serialized.contains("test.fact.npc_b_secret"),
		"NPC B secret never enters the model context")
	check.call(serialized.contains("test.fact.player_claim"),
		"player claim is present only as untrusted data")
	check.call(context.untrusted.player_notes == ["合成玩家笔记"],
		"player notes are marked untrusted in the model context")
	var event_count: int = h.events.size()
	h.provider.force_raw("test.request.1", "未验证原始分片")
	check.call(h.events.size() == event_count, "raw deltas are never surfaced as view events")
	check.call(h.state.snapshot() == before, "raw deltas never mutate state")
	h.use_case.release()

func _configuration(check: Callable) -> void:
	var h := _harness(check, false)
	check.call(not h.use_case.submit_text("test.request.1", "未开场").ok,
		"submit before begin_exchange rejected")
	check.call(h.events.is_empty(), "rejected submit emits no view event")
	check.call(not h.use_case.begin_exchange("test.npc_unknown", Fixtures.SCENE, Fixtures.TOPIC).ok,
		"unknown speaker cannot open an exchange")
	check.call(h.use_case.begin_exchange(Fixtures.SPEAKER_A, Fixtures.SCENE, Fixtures.TOPIC).ok,
		"valid exchange opens for context checks")
	h.source.fail_next = true
	check.call(not h.use_case.submit_text("test.request.2", "上下文失败").ok,
		"context source failure rejects the request")
	check.call(h.provider.accepted.is_empty(), "context failure never reaches the model port")
	h.source.extra = {"content_pack": {"definitions": []}}
	check.call(not h.use_case.submit_text("test.request.3", "完整内容包").ok,
		"context with a full content pack rejected")
	check.call(h.provider.accepted.is_empty(), "content pack never reaches the model port")
	h.source.extra = {}
	h.use_case.submit_text("test.request.4", "取消后重试")
	h.use_case.cancel("test.request.4")
	var reused: RefCounted = h.use_case.submit_text("test.request.4", "同一个 ID")
	check.call(not reused.ok and reused.code == Registry.CODE_REUSED,
		"retry with the same request ID rejected")
	check.call(not Fixtures.build({"session_id": "../escape"}).result.ok,
		"invalid session ID rejected at construction")
	check.call(not Fixtures.build({"speakers": {"test.npc_a": {"name_key": "x"}}}).result.ok,
		"malformed speaker profile rejected")
	h.use_case.release()
