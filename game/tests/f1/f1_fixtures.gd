extends RefCounted
## Synthetic F1 fixtures: two NPCs, one public fact, two private facts, a player claim,
## a rumor and one disclosure-gated fact. Never shipped as story content; no Dead Light
## facts live here.

const Result = preload("res://shared/result.gd")
const StateStore = preload("res://domain/story/state_store.gd")
const Fact = preload("res://domain/dialogue/knowledge_fact.gd")
const Actions = preload("res://domain/dialogue/allowed_actions.gd")
const UseCase = preload("res://application/dialogue/dialogue_use_case.gd")
const Provider = preload("res://tests/doubles/programmable_model_provider.gd")
const ContextSource = preload("res://tests/f1/f1_context_source.gd")

const SESSION_ID: String = "test.session"
const SPEAKER_A: String = "test.npc_a"
const SPEAKER_B: String = "test.npc_b"
const PLAYER_ID: String = "test.player"
const SCENE: String = "test.scene.road"
const OTHER_SCENE: String = "test.scene.diner"
const TOPIC: String = "test.topic.accident"
const GATED_TOPIC: String = "test.topic.confession"
const FLAG_CONFIDED: String = "test.flag.confided"

static func facts() -> Array:
	return [
		_fact("test.fact.road_public", [], true, [SCENE], [], []),
		_fact("test.fact.npc_a_secret", [SPEAKER_A], false, [], [], []),
		_fact("test.fact.npc_b_secret", [SPEAKER_B], false, [], [], []),
		_fact("test.fact.player_claim", [SPEAKER_A], false, [], [], [],
			Fact.SOURCE_PLAYER_STATEMENT),
		_fact("test.fact.rumor", [SPEAKER_A, SPEAKER_B], false, [], [], [], Fact.SOURCE_RUMOR),
		_fact("test.fact.npc_a_gated", [SPEAKER_A], false, [], [GATED_TOPIC],
			[{"flag": FLAG_CONFIDED, "equals": true}]),
		_fact("test.fact.rumor_b", [SPEAKER_B], false, [], [], [], Fact.SOURCE_RUMOR),
		_fact("test.fact.player_claim_gated", [SPEAKER_A], false, [], [GATED_TOPIC],
			[{"flag": FLAG_CONFIDED, "equals": true}], Fact.SOURCE_PLAYER_STATEMENT),
	]

static func action_entries() -> Array:
	return [
		{"command_id": "test.action.disengage", "parameter_schema": {"type": "object",
			"additionalProperties": false,
			"properties": {"mood": {"type": "string", "enum": ["calm", "wary"]}}}},
		{"command_id": "test.action.observe", "parameter_schema": {"type": "object",
			"additionalProperties": false, "properties": {}}},
	]

static func speakers() -> Dictionary:
	return {
		SPEAKER_A: {"name_key": "npc.test_a.name", "portrait_id": "npc.test_a.portrait"},
		SPEAKER_B: {"name_key": "npc.test_b.name", "portrait_id": ""},
	}

static func reply(overrides: Dictionary = {}) -> Dictionary:
	var data := {"schema_version": 1, "speaker_id": SPEAKER_A, "reply_text": "合成回答文本",
		"used_fact_ids": ["test.fact.npc_a_secret"],
		"options": [{"option_id": "test.option.continue", "text": "继续追问"}],
		"actions": [{"command_id": "test.action.disengage", "parameters": {"mood": "calm"}}]}
	for key: Variant in overrides:
		data[key] = overrides[key]
	return data

static func build(overrides: Dictionary = {}) -> Dictionary:
	var state := StateStore.new()
	state.configure({FLAG_CONFIDED: false})
	var provider := Provider.new()
	var source := ContextSource.new()
	var catalog := Actions.create(action_entries())
	var config := {"session_id": SESSION_ID, "state_store": state, "provider": provider,
		"context_source": source, "facts": facts(), "action_catalog": catalog.value,
		"speakers": speakers()}
	for key: Variant in overrides:
		config[key] = overrides[key]
	var built := UseCase.create(config)
	var harness := {"result": built, "provider": config.provider, "state": config.state_store,
		"source": config.context_source}
	if built.ok:
		harness["use_case"] = built.value
		harness["events"] = record_events(built.value)
	return harness

static func record_events(use_case: RefCounted) -> Array:
	var events: Array = []
	use_case.view_event.connect(func(event: Dictionary) -> void:
		events.append(event.duplicate(true)))
	return events

static func verified(events: Array) -> Array:
	var filtered: Array = []
	for event: Dictionary in events:
		if event.kind == "verified_reply":
			filtered.append(event)
	return filtered

static func statuses(events: Array, status: String) -> Array:
	var filtered: Array = []
	for event: Dictionary in events:
		if event.kind == "status" and event.status == status:
			filtered.append(event)
	return filtered

static func _fact(fact_id: String, speaker_ids: Array, public_on_scene: bool, scene_ids: Array,
		topic_ids: Array, conditions: Array,
		source: String = Fact.SOURCE_AUTHORITATIVE) -> Dictionary:
	return {"schema_version": 1, "fact_id": fact_id, "text_key": fact_id + ".text",
		"source": source, "speaker_ids": speaker_ids, "public_on_scene": public_on_scene,
		"scene_ids": scene_ids, "topic_ids": topic_ids, "disclosure_conditions": conditions}
