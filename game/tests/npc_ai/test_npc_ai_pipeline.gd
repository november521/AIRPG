extends RefCounted

const Contract = preload("res://application/contracts/model_transport_contract.gd")
const ActionContract = preload("res://application/contracts/npc_action_contract.gd")
const Builder = preload("res://application/dialogue/chat_completion_request_builder.gd")
const Gateway = preload("res://infrastructure/ai/chat_completion_gateway.gd")
const Runtime = preload("res://infrastructure/ai/runtime_model_configuration.gd")
const ConnectionService = preload("res://application/ai/model_connection_service.gd")
const StateStore = preload("res://domain/story/state_store.gd")
const Actions = preload("res://domain/dialogue/allowed_actions.gd")
const UseCase = preload("res://application/dialogue/dialogue_use_case.gd")
const ContextSource = preload("res://tests/f1/f1_context_source.gd")
const FakeTransport = preload("res://tests/npc_ai/fake_chat_transport.gd")
const ActionSink = preload("res://tests/npc_ai/recording_action_sink.gd")
const ActionDriver = preload("res://presentation/manor/npc_action_driver.gd")
const ConnectionPanel = preload("res://presentation/menu/ai_connection_panel.gd")
const JsonFile = preload("res://infrastructure/content/json_file.gd")
const Schema = preload("res://shared/schema_validator.gd")

class FakeActor extends RefCounted:
	var npc_id: String = "preview_actor"
	var command: String = ""
	var target: Vector3 = Vector3.ZERO
	func apply_stay() -> bool:
		command = "stay"
		return true
	func apply_face_target(value: Vector3) -> bool:
		command = "face"
		target = value
		return true
	func apply_directed_destination(value: Vector3) -> bool:
		command = "move"
		target = value
		return true

func run(check: Callable) -> void:
	_builder_and_gateway(check)
	_prompt_resource(check)
	_runtime_configuration(check)
	_settings_panel(check)
	_action_boundary(check)
	_full_pipeline(check)

func _builder_and_gateway(check: Callable) -> void:
	var builder: RefCounted = Builder.create("Return one json object.", {"fact.synthetic": "合成事实正文"})
	check.call(builder.ok, "NPC-AI: request builder accepts injected prompt and fact text")
	var context: Dictionary = _context()
	var request: RefCounted = builder.value.build(context)
	check.call(request.ok and request.value.messages.size() == 2,
		"NPC-AI: filtered projection compiles to two chat messages")
	var encoded: String = request.value.messages[1].content
	check.call(encoded.contains("合成事实正文") and not encoded.contains("fact.synthetic\""),
		"NPC-AI: fact key resolves to reviewed text before API request")
	check.call(request.value.response_format == {"type": "json_object"},
		"NPC-AI: JSON response mode requested")
	var transport: RefCounted = FakeTransport.new()
	var gateway: RefCounted = Gateway.new(transport, builder.value)
	var completed: Array = []
	var failures: Array = []
	var leaked: Array = []
	gateway.completed.connect(func(_id: String, value: Dictionary) -> void: completed.append(value))
	gateway.failed.connect(func(_id: String, code: String) -> void: failures.append(code))
	gateway.raw_delta.connect(func(_id: String, text: String) -> void: leaked.append(text))
	check.call(gateway.start("test.gateway.1", context).ok,
		"NPC-AI: gateway accepts filtered context")
	transport.push_raw("test.gateway.1", "未验证内容")
	check.call(leaked.is_empty(), "NPC-AI: raw API chunks stop at validation gateway")
	transport.finish("test.gateway.1", _envelope(_reply()))
	check.call(completed.size() == 1 and completed[0].speaker_id == "preview_actor",
		"NPC-AI: cached JSON response decodes to structured reply")
	check.call(gateway.start("test.gateway.2", context).ok,
		"NPC-AI: second request accepted")
	transport.finish("test.gateway.2", _envelope(_reply(), "length"))
	check.call(failures == [Contract.MODEL_RESPONSE_INVALID],
		"NPC-AI: truncated finish reason fails closed")
	check.call(gateway.start("test.gateway.3", context).ok,
		"NPC-AI: active request accepted before release")
	gateway.release()
	check.call("test.gateway.3" in transport.cancelled,
		"NPC-AI: gateway release cancels active transport")

func _prompt_resource(check: Callable) -> void:
	var prompt: RefCounted = JsonFile.read("res://data/ai/npc_prompt.zh_CN.json")
	var schema: RefCounted = JsonFile.read("res://data/schemas/npc_prompt.schema.json")
	var issues: Array[String] = [] if not prompt.ok or not schema.ok \
		else Schema.validate(prompt.value, schema.value)
	check.call(prompt.ok and schema.ok and issues.is_empty(),
		"NPC-AI: versioned prompt resource passes its strict schema")
	var built: RefCounted = Builder.create(prompt.value.system_prompt, {}) \
		if prompt.ok else null
	check.call(built != null and built.ok,
		"NPC-AI: reviewed prompt resource passes request-builder limits")

func _runtime_configuration(check: Callable) -> void:
	var runtime: RefCounted = Runtime.new()
	var secret: String = "synthetic-secret-never-log"
	check.call(runtime.configure("https://example.invalid/chat/completions", "test-model", secret).ok,
		"NPC-AI: runtime API entry accepted")
	var serialized: String = JSON.stringify(runtime.diagnostics()) + str(runtime)
	check.call(not serialized.contains(secret), "NPC-AI: API key absent from diagnostics")
	check.call(not runtime.configure("https://example.invalid/\nchat", "test-model", secret).ok,
		"NPC-AI: endpoint control characters rejected")
	runtime.clear()
	check.call(not runtime.diagnostics().configured, "NPC-AI: runtime credentials can be cleared")

func _settings_panel(check: Callable) -> void:
	var runtime: RefCounted = Runtime.new()
	var service: RefCounted = ConnectionService.new(runtime)
	var panel: PanelContainer = ConnectionPanel.new()
	panel._ready()
	check.call(panel.configure(service), "NPC-AI: settings view accepts application facade")
	var scroll: ScrollContainer = panel.get_node_or_null("SettingsScroll")
	check.call(scroll != null and scroll.follow_focus \
		and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"NPC-AI: settings fields stay reachable through a focus-following vertical scroll")
	var endpoint: LineEdit = panel.get("_endpoint")
	var model: LineEdit = panel.get("_model")
	var key: LineEdit = panel.get("_key")
	endpoint.text = "https://example.invalid/chat/completions"
	model.text = "test-model"
	key.text = "synthetic-key-cleared-after-submit"
	panel.call("_submit")
	check.call(key.text.is_empty() and runtime.diagnostics().configured,
		"NPC-AI: secret input clears immediately after runtime submission")
	panel.free()

func _action_boundary(check: Callable) -> void:
	var actor: FakeActor = FakeActor.new()
	var player: Node3D = Node3D.new()
	player.position = Vector3(1, 0, 2)
	var anchors: Dictionary = {"preview_actor": {"preview.anchor.safe": Vector3(3, 0, 4)}}
	var revisions: RefCounted = StateStore.new()
	revisions.configure({"test.flag": false})
	var driver: RefCounted = ActionDriver.new([actor], player, anchors, "preview.session",
		"preview.scene", revisions)
	var proposal: RefCounted = ActionContract.proposal("preview.session", "request.1", 0,
		"preview_actor", "preview.scene", {"command_id": "npc.move_to_anchor",
			"parameters": {"anchor_id": "preview.anchor.safe"}})
	check.call(proposal.ok and driver.accept(proposal.value).ok \
		and actor.command == "move" and actor.target == Vector3(3, 0, 4),
		"NPC-AI: trusted anchor ID resolves inside scene adapter")
	var injected: Dictionary = proposal.value.duplicate(true)
	injected["position"] = {"x": 99}
	check.call(not ActionContract.validate(injected).ok,
		"NPC-AI: coordinate injection rejected by exact action contract")
	var wrong_type: Dictionary = proposal.value.duplicate(true)
	wrong_type.session_id = 7
	check.call(not ActionContract.validate(wrong_type).ok,
		"NPC-AI: malformed action identity fails without reaching typed execution")
	var wrong_context: Dictionary = proposal.value.duplicate(true)
	wrong_context.scene_id = "preview.other_scene"
	check.call(not driver.accept(wrong_context).ok and actor.target == Vector3(3, 0, 4),
		"NPC-AI: action from another scene cannot reach actor")
	var denied: RefCounted = ActionContract.proposal("preview.session", "request.2", 0,
		"preview_actor", "preview.scene", {"command_id": "npc.move_to_anchor",
			"parameters": {"anchor_id": "preview.anchor.other"}})
	check.call(not driver.accept(denied.value).ok and actor.target == Vector3(3, 0, 4),
		"NPC-AI: unauthorized anchor cannot change actor target")
	var invalid_driver: RefCounted = ActionDriver.new([actor], player,
		{"preview_actor": {"preview.anchor.safe": "not-a-position"}}, "preview.session",
		"preview.scene", revisions)
	check.call(not invalid_driver.accept(proposal.value).ok,
		"NPC-AI: malformed trusted anchor fails closed before typed actor call")
	revisions.commit(0, {"test.flag": true})
	check.call(not driver.accept(proposal.value).ok and actor.target == Vector3(3, 0, 4),
		"NPC-AI: stale state revision cannot reach actor")
	player.free()

func _full_pipeline(check: Callable) -> void:
	var transport: RefCounted = FakeTransport.new()
	var builder: RefCounted = Builder.create("Return one json object.", {})
	var gateway: RefCounted = Gateway.new(transport, builder.value)
	var state: RefCounted = StateStore.new()
	state.configure({})
	var catalog: RefCounted = Actions.create(_action_entries())
	var sink: RefCounted = ActionSink.new()
	var created: RefCounted = UseCase.create({"session_id": "preview.session", "state_store": state,
		"provider": gateway, "context_source": ContextSource.new(), "facts": [],
		"action_catalog": catalog.value, "speakers": {"preview_actor": {
			"name_key": "npc.preview_actor", "portrait_id": ""}}, "action_sink": sink})
	check.call(created.ok, "NPC-AI: full input API dialogue use case builds")
	var use_case: RefCounted = created.value
	var events: Array = []
	use_case.view_event.connect(func(event: Dictionary) -> void: events.append(event))
	use_case.begin_exchange("preview_actor", "preview.scene", "preview.topic")
	check.call(use_case.submit_text("pipeline.1", "原样玩家输入").ok,
		"NPC-AI: player input starts API request")
	var body: Dictionary = transport.accepted["pipeline.1"]
	check.call(body.messages[1].content.contains("原样玩家输入"),
		"NPC-AI: untrusted player text reaches user message")
	transport.finish("pipeline.1", _envelope(_reply()))
	var replies: Array = events.filter(func(item: Dictionary) -> bool:
		return item.kind == "verified_reply")
	check.call(replies.size() == 1 and sink.proposals.size() == 1,
		"NPC-AI: one validated response publishes one reply and one action")
	check.call(sink.proposals[0].parameters == {"anchor_id": "preview.anchor.safe"},
		"NPC-AI: action sink receives only semantic anchor ID")
	var prior_events: int = events.size()
	var prior_proposals: int = sink.proposals.size()
	transport.completion_on_start = _envelope(_reply())
	use_case.begin_exchange("preview_actor", "preview.scene", "preview.topic")
	check.call(use_case.submit_text("pipeline.sync", "同步完成").ok,
		"NPC-AI: synchronously completed transport remains a successful submission")
	var synchronous_events: Array = events.slice(prior_events)
	check.call(synchronous_events.size() == 1 \
		and synchronous_events[0].kind == "verified_reply" \
		and sink.proposals.size() == prior_proposals + 1,
		"NPC-AI: synchronous completion validates once without trailing waiting state")
	transport.completion_on_start = {}
	use_case.begin_exchange("preview_actor", "preview.scene", "preview.topic")
	use_case.submit_text("pipeline.2", "会在释放时取消")
	use_case.release()
	check.call("pipeline.2" in transport.cancelled,
		"NPC-AI: dialogue release cancels in-flight API request")
	gateway.release()

func _context() -> Dictionary:
	return {"schema_version": 1, "speaker_id": "preview_actor",
		"scene_id": "preview.scene", "topic_id": "preview.topic",
		"trusted_facts": [{"fact_id": "preview.fact", "text_key": "fact.synthetic",
			"source": "authoritative"}], "perceptible": [], "recent_dialogue": [],
		"key_memories": [], "untrusted": {"player_text": "玩家文本", "player_notes": [],
			"rumors": [], "player_statements": [], "rumor_facts": [], "other_dialogue": []},
		"allowed_actions": _action_entries()}

func _action_entries() -> Array:
	return [{"command_id": "npc.move_to_anchor", "parameter_schema": {"type": "object",
		"additionalProperties": false, "required": ["anchor_id"],
		"properties": {"anchor_id": {"type": "string",
			"enum": ["preview.anchor.safe"]}}}}]

func _reply() -> Dictionary:
	return {"schema_version": 1, "speaker_id": "preview_actor", "reply_text": "合成回答",
		"used_fact_ids": [], "options": [], "actions": [{
			"command_id": "npc.move_to_anchor",
			"parameters": {"anchor_id": "preview.anchor.safe"}}]}

func _envelope(reply: Dictionary, finish_reason: String = "stop") -> Dictionary:
	return Contract.completed_response(JSON.stringify(reply), finish_reason, {}).value
