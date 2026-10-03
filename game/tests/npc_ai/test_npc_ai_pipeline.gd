extends RefCounted

const Contract = preload("res://application/contracts/model_transport_contract.gd")
const ActionContract = preload("res://application/contracts/npc_action_contract.gd")
const Builder = preload("res://application/dialogue/chat_completion_request_builder.gd")
const Gateway = preload("res://infrastructure/ai/chat_completion_gateway.gd")
const Runtime = preload("res://infrastructure/ai/runtime_model_configuration.gd")
const CredentialStore = preload("res://infrastructure/ai/local_credential_store.gd")
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
const ModelReply = preload("res://domain/dialogue/model_reply.gd")

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
	_local_credentials(check)
	_settings_panel(check)
	_action_boundary(check)
	_full_pipeline(check)

## Remembered credentials: a solo player configures once, the next launch restores it, and no
## path ever prints or returns the key.
func _local_credentials(check: Callable) -> void:
	var path: String = "user://test_ai_credentials.json"
	var store: RefCounted = CredentialStore.new(path)
	store.clear()
	check.call(not store.load_credentials().ok, "NPC-AI: absent credential file reports no store")
	check.call(store.save_credentials("https://example.invalid/chat/completions", "test-model",
		"synthetic-secret-never-log").ok, "NPC-AI: credentials are written to the local store")
	check.call(store.has_stored_credentials(), "NPC-AI: stored credentials are reported present")
	var loaded: RefCounted = store.load_credentials()
	check.call(loaded.ok and loaded.value.api_key == "synthetic-secret-never-log",
		"NPC-AI: stored key round-trips through the local store")
	var runtime: RefCounted = Runtime.new(CredentialStore.new(path))
	check.call(runtime.restore().ok and runtime.configured(),
		"NPC-AI: a fresh runtime restores stored credentials")
	var serialized: String = JSON.stringify(runtime.diagnostics()) + str(runtime)
	check.call(not serialized.contains("synthetic-secret-never-log"),
		"NPC-AI: restored key stays out of diagnostics")
	check.call(runtime.diagnostics().stored, "NPC-AI: diagnostics report local storage without the key")
	var reused: RefCounted = ConnectionService.new(Runtime.new(CredentialStore.new(path)))
	check.call(reused.configure("https://example.invalid/chat/completions", "next-model", "").ok,
		"NPC-AI: an empty key field reuses the remembered credentials")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"schema_version\":1,\"endpoint_url\":\"https://example.invalid\",\"api_key\":\"leak\"}")
	file.close()
	check.call(not CredentialStore.new(path).load_credentials().ok,
		"NPC-AI: a malformed credential file fails closed")
	check.call(not CredentialStore.new(path).save_credentials("https://example.invalid/\nchat",
		"test-model", "key").ok, "NPC-AI: control characters are refused by the store")
	store.clear()
	check.call(not store.has_stored_credentials(), "NPC-AI: disconnect deletes the stored file")

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
	var retry_two := _recovery_id("test.gateway.2")
	check.call(failures.is_empty() and transport.accepted.has(retry_two),
		"NPC-AI: truncated answer retries once without interrupting the player")
	transport.finish(retry_two, _envelope(_reply()))
	check.call(completed.size() == 2 and failures.is_empty(),
		"NPC-AI: recovered answer completes under the original logical request")
	check.call(gateway.start("test.gateway.invalid", context).ok,
		"NPC-AI: invalid-response recovery request accepted")
	transport.fail("test.gateway.invalid", Contract.MODEL_RESPONSE_INVALID)
	var retry_invalid := _recovery_id("test.gateway.invalid")
	check.call(transport.accepted.has(retry_invalid) and failures.is_empty(),
		"NPC-AI: provider-reported empty or invalid content retries once")
	transport.fail(retry_invalid, Contract.MODEL_RESPONSE_INVALID)
	check.call(failures == [Contract.MODEL_RESPONSE_INVALID],
		"NPC-AI: a second invalid answer fails closed instead of looping")
	_classified_failures(check, gateway, transport, context, completed, failures)
	check.call(gateway.start("test.gateway.3", context).ok,
		"NPC-AI: active request accepted before release")
	gateway.release()
	check.call("test.gateway.3" in transport.cancelled,
		"NPC-AI: gateway release cancels active transport")

## Every transient answer defect retries once and then reports its own class, so a stuck
## conversation can be told apart from a truncated or protocol-breaking answer.
func _classified_failures(check: Callable, gateway: RefCounted, transport: RefCounted,
		context: Dictionary, completed: Array, failures: Array) -> void:
	var empty_start: int = failures.size()
	check.call(gateway.start("test.gateway.empty", context).ok,
		"NPC-AI: empty-content request accepted")
	transport.finish("test.gateway.empty", _raw_envelope("", "stop"))
	var empty_retry := _recovery_id("test.gateway.empty")
	check.call(transport.accepted.has(empty_retry) and failures.size() == empty_start,
		"NPC-AI: an empty answer is resampled once instead of surfacing")
	transport.finish(empty_retry, _raw_envelope("", "stop"))
	check.call(failures.slice(empty_start) == [Contract.MODEL_EMPTY_CONTENT],
		"NPC-AI: a repeated empty answer is reported as MODEL_EMPTY_CONTENT")
	var truncated_start: int = failures.size()
	check.call(gateway.start("test.gateway.truncated", context).ok,
		"NPC-AI: truncated request accepted")
	transport.finish("test.gateway.truncated", _envelope(_reply(), "length"))
	transport.finish(_recovery_id("test.gateway.truncated"), _envelope(_reply(), "length"))
	check.call(failures.slice(truncated_start) == [Contract.MODEL_FINISH_INCOMPLETE],
		"NPC-AI: a truncated answer is reported as MODEL_FINISH_INCOMPLETE")
	var malformed_start: int = failures.size()
	check.call(gateway.start("test.gateway.malformed", context).ok,
		"NPC-AI: malformed reply request accepted")
	transport.finish("test.gateway.malformed", _raw_envelope("{\"a\":1}", "stop"))
	transport.finish(_recovery_id("test.gateway.malformed"), _raw_envelope("{\"a\":1}", "stop"))
	check.call(failures.slice(malformed_start) == [Contract.MODEL_REPLY_INVALID],
		"NPC-AI: a protocol-breaking answer is reported as MODEL_REPLY_INVALID")
	var issues: Array = ModelReply.parse("{\"a\":1}").issues
	check.call(str(issues).contains("fields:") and not str(issues).contains("a\":1"),
		"NPC-AI: field classification stays free of reply content")
	check.call(completed.size() == 2, "NPC-AI: classified failures publish no reply")

## A transport envelope is the only way to hand the gateway content the contract rejects.
func _raw_envelope(content: String, finish_reason: String) -> Dictionary:
	return {"transport_schema_version": 1, "content": content, "finish_reason": finish_reason,
		"usage": {}}

func _prompt_resource(check: Callable) -> void:
	var prompt: RefCounted = JsonFile.read("res://data/ai/npc_prompt.zh_CN.json")
	var schema: RefCounted = JsonFile.read("res://data/schemas/npc_prompt.schema.json")
	var issues: Array[String] = [] if not prompt.ok or not schema.ok \
		else Schema.validate(prompt.value, schema.value)
	check.call(prompt.ok and schema.ok and issues.is_empty(),
		"NPC-AI: versioned prompt resource passes its strict schema")
	var built: RefCounted = Builder.create(prompt.value.system_prompt,
		{"fact.synthetic": "合成事实正文"}) if prompt.ok else null
	check.call(built != null and built.ok,
		"NPC-AI: reviewed prompt resource passes request-builder limits")
	if built == null or not built.ok:
		return
	var request: RefCounted = built.value.build(_context())
	check.call(request.ok and request.value.messages[0].content.contains("\"speaker_id\":\"preview_actor\"") \
		and not request.value.messages[0].content.contains("__SPEAKER_ID_JSON__"),
		"NPC-AI: JSON example carries the exact current speaker ID")
	check.call(Contract.completed_response("", "stop", {}).code == Contract.MODEL_EMPTY_CONTENT \
		and Contract.completed_response("{}", "", {}).code == Contract.MODEL_FINISH_INCOMPLETE,
		"NPC-AI: empty content and missing stop reason carry their own stable codes")
	check.call(Contract.is_stable_error(Contract.MODEL_EMPTY_CONTENT) \
		and Contract.is_stable_error(Contract.MODEL_FINISH_INCOMPLETE) \
		and Contract.is_stable_error(Contract.MODEL_REPLY_INVALID),
		"NPC-AI: answer-defect classes are stable errors")

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

func _recovery_id(request_id: String) -> String:
	return "recovery." + request_id.sha256_text().substr(0, 32) + ".1"
