extends RefCounted
## Composition for the manor NPC dialogue. It assembles reviewed content (shared prompt,
## character cards, world book facts), filtered dialogue, transport and coordinate-free
## action execution without becoming a service locator.
##
## Story knowledge stays in the reviewed world book: this file only selects the audience for
## the speakers this scene actually has, and never invents a fact, a line or a state change.

const Result = preload("res://shared/result.gd")
const Content = preload("res://bootstrap/manor_npc_content.gd")
const StateStore = preload("res://domain/story/state_store.gd")
const Actions = preload("res://domain/dialogue/allowed_actions.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")
const Builder = preload("res://application/dialogue/chat_completion_request_builder.gd")
const Gateway = preload("res://infrastructure/ai/chat_completion_gateway.gd")
const Context = preload("res://infrastructure/ai/manor_preview_dialogue_context.gd")
const Driver = preload("res://presentation/manor/npc_action_driver.gd")
const UseCase = preload("res://application/dialogue/dialogue_use_case.gd")
const RoomMap = preload("res://presentation/shell/manor_room_map.gd")

const SESSION_ID: String = "manor.session"
const SCENE_ID: String = "manor"
const FALLBACK_TOPIC: String = "manor.room.unknown"
const PRESENT_RANGE: float = 8.0

var _use_case: RefCounted = null
var _gateway: RefCounted = null
var _profiles: Dictionary = {}
var _open_speaker: String = ""

## Thin logging wrapper: a launcher log must say whether NPC dialogue reached the model or fell
## back to the fixed greeting, and why. No prompt, reply or credential value is printed.
static func build(host: Node, runtime: Object, roster: Array[Dictionary], actors: Array,
		player: Node3D, anchors: Dictionary) -> RefCounted:
	var built := _build(host, runtime, roster, actors, player, anchors)
	print("AIRPG_NPC_AI: ", "ready" if built.ok else built.code)
	return built

static func _build(host: Node, runtime: Object, roster: Array[Dictionary], actors: Array,
		player: Node3D, anchors: Dictionary) -> RefCounted:
	if host == null or runtime == null or not runtime.has_method("create_transport"):
		return Result.failure("AI_NOT_CONFIGURED")
	var content := Content.load_for(roster)
	if not content.ok:
		return content
	var transport: RefCounted = runtime.create_transport(host, host.get_tree())
	if not transport.ok:
		return transport
	var bundle: Dictionary = content.value
	var builder := Builder.create(bundle.system_prompt, bundle.fact_texts, bundle.personas)
	if not builder.ok:
		return builder
	var gateway := Gateway.new(transport.value, builder.value)
	var catalog := Actions.create(_action_entries(anchors))
	if not catalog.ok:
		gateway.release()
		return catalog
	var state := StateStore.new()
	var state_ready := state.configure(bundle.gate_flags)
	if not state_ready.ok:
		gateway.release()
		return state_ready
	var driver := Driver.new(actors, player, anchors, SESSION_ID, SCENE_ID, state)
	var context := Context.new(_observer(host, actors, player))
	var created := UseCase.create({"session_id": SESSION_ID, "state_store": state,
		"provider": gateway, "context_source": context, "facts": bundle.facts,
		"action_catalog": catalog.value, "speakers": bundle.speakers, "action_sink": driver,
		"reply_policies": bundle.policies})
	if not created.ok:
		gateway.release()
		return created
	var instance := new()
	instance._use_case = created.value
	instance._gateway = gateway
	instance._profiles = bundle.speakers
	return Result.success(instance)

## Live scene observation for one speaker: what the NPC perceives right now, never knowledge.
static func _observer(host: Node, actors: Array, player: Node3D) -> Callable:
	return func(speaker_id: String) -> Array:
		var observations: Array[Dictionary] = [{"observation_id": "manor.observation.talk",
			"text": host.tr("npc.observation.talk")}]
		var present: Array[String] = []
		for actor: Variant in actors:
			if actor == null or not is_instance_valid(actor) or actor.get("npc_id") == speaker_id:
				continue
			if player == null or actor.global_position.distance_to(player.global_position) > PRESENT_RANGE:
				continue
			present.append(host.tr(actor.name_key))
		if present.is_empty():
			observations.append({"observation_id": "manor.observation.alone",
				"text": host.tr("npc.observation.alone")})
		else:
			observations.append({"observation_id": "manor.observation.present",
				"text": host.tr("npc.observation.present") % ", ".join(present)})
		return observations

func use_case() -> RefCounted:
	return _use_case

## The room the conversation happens in scopes which memory fragments the NPC may recall, so
## she never reports a room she has not been in during this exchange. The optional view is
## re-anchored to the new speaker, so one NPC's reply never sits under the other's name.
func begin(speaker_id: String, listener: Node3D = null, view: Object = null) -> RefCounted:
	var room_id: String = RoomMap.room_id(listener.position) if listener != null else ""
	var topic: String = "manor.room." + room_id
	if room_id.is_empty() or not Ids.is_valid_id(topic):
		topic = FALLBACK_TOPIC
	var begun: RefCounted = _use_case.begin_exchange(speaker_id, SCENE_ID, topic)
	if not begun.ok:
		print("AIRPG_NPC_DIALOGUE_REJECTED: ", speaker_id, " ", begun.code)
		return begun
	if view != null and view.has_method("begin_conversation") and _profiles.has(speaker_id):
		view.begin_conversation(_profiles[speaker_id].name_key, _profiles[speaker_id].portrait_id)
	_open_speaker = speaker_id
	print("AIRPG_NPC_DIALOGUE_OPEN: ", speaker_id, " @ ", topic)
	return begun

func end() -> void:
	if _use_case != null:
		_use_case.end_exchange()
	if not _open_speaker.is_empty():
		print("AIRPG_NPC_DIALOGUE_CLOSE: ", _open_speaker)
		_open_speaker = ""

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
