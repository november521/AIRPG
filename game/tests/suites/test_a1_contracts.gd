extends RefCounted

const Result = preload("res://shared/result.gd")
const Exploration = preload("res://application/contracts/exploration_contract.gd")
const Dialogue = preload("res://application/contracts/dialogue_view_contract.gd")
const Transport = preload("res://application/contracts/model_transport_contract.gd")
const FakeExploration = preload("res://tests/doubles/fake_exploration_use_case.gd")
const FakeDialogue = preload("res://tests/doubles/fake_dialogue_use_case.gd")
const FakeProvider = preload("res://tests/doubles/programmable_model_provider.gd")

func run(check: Callable) -> void:
	_exploration(check)
	_dialogue(check)
	_transport(check)

func _exploration(check: Callable) -> void:
	check.call(Exploration.move(Vector2(0.5, -0.5)).ok, "bounded movement intent accepted")
	check.call(not Exploration.move(Vector2(2.0, 0.0)).ok, "oversized movement intent rejected")
	check.call(Exploration.interact("test.vehicle").ok, "valid interaction target accepted")
	check.call(not Exploration.interact("../vehicle").ok, "unsafe interaction target rejected")
	check.call(not Exploration.candidate("test.vehicle", "prompt.inspect", -1.0).ok,
		"negative candidate distance rejected")
	var fake := FakeExploration.new()
	check.call(fake.investigate().ok and fake.commands.size() == 1,
		"exploration fake records validated command")

func _dialogue(check: Callable) -> void:
	var reply := Dialogue.verified_reply("request-1", "test.npc", "npc.test.name", "", "回答",
		[{"option_id": "test.ask", "text": "继续询问"}])
	check.call(reply.ok and reply.value.kind == "verified_reply", "verified reply DTO accepted")
	var unknown := [{"option_id": "test.ask", "text": "继续询问", "state_patch": {}}]
	check.call(not Dialogue.verified_reply("request-1", "test.npc", "npc.test.name", "", "回答",
		unknown).ok, "unknown reply fields rejected")
	var too_many: Array[Dictionary] = []
	for index: int in Dialogue.MAX_OPTIONS + 1:
		too_many.append({"option_id": "test.option%d" % index, "text": "选项"})
	check.call(not Dialogue.verified_reply("request-1", "test.npc", "npc.test.name", "", "回答",
		too_many).ok, "excessive reply options rejected")
	check.call(not Dialogue.verified_reply("request-1", "test.npc", "npc.test.name", "", "回答",
		[{"option_id": "test.ask", "text": "字".repeat(Dialogue.MAX_OPTION_TEXT_LENGTH + 1)}]).ok,
		"oversized option text rejected")
	check.call(not Dialogue.status("request-1", Dialogue.STATUS_FAILED).ok,
		"failed status requires stable error")
	check.call(not Dialogue.status("request-1", Dialogue.STATUS_FAILED,
		"provider stack trace with bearer token", true).ok,
		"raw provider error rejected from view status")
	check.call(Dialogue.status("request-1", Dialogue.STATUS_FAILED,
		Transport.MODEL_TIMEOUT, true).ok, "stable transport error accepted by view status")
	var duplicate_options := [{"option_id": "test.ask", "text": "问题一"},
		{"option_id": "test.ask", "text": "问题二"}]
	check.call(not Dialogue.verified_reply("request-1", "test.npc", "npc.test.name", "", "回答",
		duplicate_options).ok, "duplicate option IDs rejected")
	var fake := FakeDialogue.new()
	check.call(fake.submit_text("request-1", "  原样输入  ").ok,
		"player text accepted without rewriting")
	check.call(fake.submissions[0].text == "  原样输入  ", "player text preserved exactly")
	check.call(fake.publish(reply), "dialogue fake publishes contract event")
	check.call(not fake.publish(Result.success({"raw_delta": "未验证秘密"})),
		"dialogue fake rejects unverified success payload")

func _transport(check: Callable) -> void:
	var context := {"speaker_id": "test.npc", "trusted_fact_ids": ["test.fact"]}
	var request := Transport.request("request-1", context)
	check.call(request.ok, "provider-neutral request accepted")
	context.trusted_fact_ids.append("test.secret")
	check.call(request.value.filtered_context.trusted_fact_ids.size() == 1,
		"transport request isolates caller context")
	check.call(Transport.is_stable_error(Transport.MODEL_TIMEOUT), "stable model error recognized")
	check.call(not Transport.is_stable_error("provider stack trace"), "provider error text rejected")
	var provider := FakeProvider.new()
	var terminals: Array[String] = []
	provider.failed.connect(func(_id: String, code: String) -> void: terminals.append(code))
	check.call(provider.start("request-1", {"speaker_id": "test.npc"}).ok,
		"programmable provider accepts valid request")
	provider.cancel("request-1")
	provider.cancel("request-1")
	check.call(terminals == [Transport.REQUEST_CANCELLED], "provider cancellation is idempotent")
	check.call(provider.start("request-2", {"speaker_id": "test.npc"}).ok,
		"second programmable request accepted")
	check.call(provider.complete("request-2", {"text": "done"}), "normal completion accepted once")
	provider.cancel("request-2")
	check.call(terminals == [Transport.REQUEST_CANCELLED], "completed request ignores cancellation")
	check.call(not provider.fail("request-2", Transport.MODEL_TIMEOUT),
		"completed request rejects second terminal")
	check.call(provider.start("request-3", {"speaker_id": "test.npc"}).ok,
		"third programmable request accepted")
	check.call(provider.fail("request-3", Transport.MODEL_TIMEOUT), "normal failure accepted once")
	provider.cancel("request-3")
	check.call(terminals == [Transport.REQUEST_CANCELLED, Transport.MODEL_TIMEOUT],
		"failed request ignores cancellation")
