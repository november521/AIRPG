extends RefCounted
## Composition for the synthetic manor NPC/API preview. It assembles reviewed prompt data,
## filtered dialogue, transport and coordinate-free action execution without becoming a
## service locator or changing formal story state.

const Result = preload("res://shared/result.gd")
const JsonFile = preload("res://infrastructure/content/json_file.gd")
const Schema = preload("res://shared/schema_validator.gd")
const StateStore = preload("res://domain/story/state_store.gd")
const Actions = preload("res://domain/dialogue/allowed_actions.gd")
const Builder = preload("res://application/dialogue/chat_completion_request_builder.gd")
const Gateway = preload("res://infrastructure/ai/chat_completion_gateway.gd")
const Context = preload("res://infrastructure/ai/manor_preview_dialogue_context.gd")
const Driver = preload("res://presentation/manor/npc_action_driver.gd")
const UseCase = preload("res://application/dialogue/dialogue_use_case.gd")

const SESSION_ID: String = "preview.manor.session"
const SCENE_ID: String = "preview.manor"
const TOPIC_ID: String = "preview.open_conversation"

var _use_case: RefCounted = null
var _gateway: RefCounted = null

static func build(host: Node, runtime: Object, roster: Array[Dictionary], actors: Array,
		player: Node3D, anchors: Dictionary) -> RefCounted:
	if host == null or runtime == null or not runtime.has_method("create_transport"):
		return Result.failure("AI_NOT_CONFIGURED")
	var transport: RefCounted = runtime.create_transport(host, host.get_tree())
	if not transport.ok:
		return transport
	var raw_prompt := JsonFile.read("res://data/ai/npc_prompt.zh_CN.json")
	var prompt_schema := JsonFile.read("res://data/schemas/npc_prompt.schema.json")
	if not raw_prompt.ok or not prompt_schema.ok:
		return Result.failure("MODEL_PROMPT_UNAVAILABLE")
	var prompt_issues := Schema.validate(raw_prompt.value, prompt_schema.value)
	if not prompt_issues.is_empty():
		return Result.failure("MODEL_PROMPT_INVALID", prompt_issues)
	var builder := Builder.create(raw_prompt.value.system_prompt, {})
	if not builder.ok:
		return builder
	var gateway := Gateway.new(transport.value, builder.value)
	var catalog := Actions.create(_action_entries(anchors))
	if not catalog.ok:
		gateway.release()
		return catalog
	var state := StateStore.new()
	var state_ready := state.configure({})
	if not state_ready.ok:
		gateway.release()
		return state_ready
	var speakers: Dictionary = {}
	for entry: Dictionary in roster:
		speakers[entry.id] = {"name_key": entry.name_key, "portrait_id": ""}
	var driver := Driver.new(actors, player, anchors, SESSION_ID, SCENE_ID, state)
	var context := Context.new(host.tr("npc.preview.observation"))
	var created := UseCase.create({"session_id": SESSION_ID, "state_store": state,
		"provider": gateway, "context_source": context, "facts": [],
		"action_catalog": catalog.value, "speakers": speakers, "action_sink": driver})
	if not created.ok:
		gateway.release()
		return created
	var instance := new()
	instance._use_case = created.value
	instance._gateway = gateway
	return Result.success(instance)

func use_case() -> RefCounted:
	return _use_case

func begin(speaker_id: String) -> RefCounted:
	return _use_case.begin_exchange(speaker_id, SCENE_ID, TOPIC_ID)

func end() -> void:
	if _use_case != null:
		_use_case.end_exchange()

func release() -> void:
	if _use_case != null:
		_use_case.release()
		_use_case = null
	if _gateway != null:
		_gateway.release()
		_gateway = null

static func _action_entries(anchors: Dictionary) -> Array:
	var anchor_ids: Array[String] = []
	for speaker_id: Variant in anchors:
		if not anchors[speaker_id] is Dictionary:
			continue
		for anchor_id: Variant in anchors[speaker_id]:
			if anchor_id is String and anchor_id not in anchor_ids:
				anchor_ids.append(anchor_id)
	anchor_ids.sort()
	return [
		{"command_id": "npc.stay", "parameter_schema": {"type": "object",
			"additionalProperties": false, "properties": {}}},
		{"command_id": "npc.face_player", "parameter_schema": {"type": "object",
			"additionalProperties": false, "properties": {}}},
		{"command_id": "npc.move_to_anchor", "parameter_schema": {"type": "object",
			"additionalProperties": false, "required": ["anchor_id"],
			"properties": {"anchor_id": {"type": "string", "enum": anchor_ids}}}},
	]
