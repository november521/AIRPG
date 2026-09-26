extends RefCounted
## F1 knowledge suite: fact validation, per-NPC projection isolation and untrusted fields.

const Projector = preload("res://domain/dialogue/knowledge_projector.gd")
const Fact = preload("res://domain/dialogue/knowledge_fact.gd")
const Facts = preload("res://domain/dialogue/knowledge_facts.gd")
const Fixtures = preload("res://tests/f1/f1_fixtures.gd")

func run(check: Callable) -> void:
	_fact_validation(check)
	_projection(check)
	_isolation(check)
	_untrusted(check)
	_deep_copy(check)

func _input(speaker_id: String = Fixtures.SPEAKER_A, overrides: Dictionary = {}) -> Dictionary:
	var data := {"speaker_id": speaker_id, "scene_id": Fixtures.SCENE, "topic_id": Fixtures.TOPIC,
		"facts": Fixtures.facts(), "flags": {Fixtures.FLAG_CONFIDED: false},
		"recent_dialogue": [{"speaker_id": speaker_id, "text": "合成 NPC 台词"},
			{"speaker_id": Fixtures.PLAYER_ID, "text": "合成玩家台词"}],
		"key_memories": [{"source": "witnessed", "text": "合成记忆"}],
		"player_notes": ["合成玩家笔记"], "rumors": ["合成传闻"]}
	for key: Variant in overrides:
		data[key] = overrides[key]
	return data

func _fact_ids(entries: Array) -> Array:
	var ids: Array = []
	for entry: Dictionary in entries:
		ids.append(entry.fact_id)
	return ids

func _fact_validation(check: Callable) -> void:
	var sample: Dictionary = Fixtures.facts()[0]
	check.call(Fact.validate(sample).ok, "valid synthetic fact accepted")
	check.call(not Fact.validate(Fixtures._fact("test.fact.bad", ["test.npc_a"], false, [], [], [],
		"gossip")).ok, "unknown fact source rejected")
	var unknown_version := sample.duplicate(true)
	unknown_version.schema_version = 2
	check.call(Fact.validate(unknown_version).code == "KNOWLEDGE_FACT_VERSION",
		"unknown fact schema version rejected")
	var unknown_field := sample.duplicate(true)
	unknown_field.state_patch = {}
	check.call(not Fact.validate(unknown_field).ok, "unknown fact field rejected")
	var missing := sample.duplicate(true)
	missing.erase("disclosure_conditions")
	check.call(not Fact.validate(missing).ok, "missing fact field rejected")
	var public_no_scene := Fixtures._fact("test.fact.bad", [], true, [], [], [])
	check.call(not Fact.validate(public_no_scene).ok, "public fact without scene rejected")
	var unauthorized := Fixtures._fact("test.fact.bad", [], false, [], [], [])
	check.call(not Fact.validate(unauthorized).ok, "fact without speaker or public flag rejected")
	var duplicate_speaker := Fixtures._fact("test.fact.bad", ["test.npc_a", "test.npc_a"],
		false, [], [], [])
	check.call(not Fact.validate(duplicate_speaker).ok, "duplicate speaker grant rejected")
	var malformed_condition := Fixtures._fact("test.fact.bad", ["test.npc_a"], false, [], [],
		[{"flag": "test.flag.x"}])
	check.call(not Fact.validate(malformed_condition).ok, "malformed disclosure condition rejected")
	var catalog := Fixtures.facts()
	catalog.append(catalog[0].duplicate(true))
	check.call(Facts.validate_all(catalog).code == "KNOWLEDGE_FACTS_DUPLICATE",
		"duplicate fact IDs rejected by catalog")

func _projection(check: Callable) -> void:
	var projected := Projector.project(_input())
	check.call(projected.ok, "NPC A projection succeeds")
	var ids: Array = _fact_ids(projected.value.trusted_facts)
	check.call(ids.has("test.fact.road_public"), "public on-scene fact reaches NPC A")
	check.call(ids.has("test.fact.npc_a_secret"), "NPC A private fact reaches NPC A")
	check.call(not ids.has("test.fact.npc_a_gated"), "gated fact hidden until condition met")
	check.call(not ids.has("test.fact.player_claim"), "player claim never becomes trusted")
	check.call(not ids.has("test.fact.rumor"), "rumor never becomes trusted")
	var gated := Projector.project(_input(Fixtures.SPEAKER_A, {"topic_id": Fixtures.GATED_TOPIC,
		"flags": {Fixtures.FLAG_CONFIDED: true}}))
	check.call(_fact_ids(gated.value.trusted_facts).has("test.fact.npc_a_gated"),
		"gated fact disclosed when condition and topic match")
	var other_scene := Projector.project(_input(Fixtures.SPEAKER_A, {"scene_id": Fixtures.OTHER_SCENE}))
	check.call(not _fact_ids(other_scene.value.trusted_facts).has("test.fact.road_public"),
		"public fact is limited to its scene")

func _isolation(check: Callable) -> void:
	var projected := Projector.project(_input(Fixtures.SPEAKER_A))
	check.call(projected.ok, "isolation projection succeeds")
	var serialized := JSON.stringify(projected.value)
	check.call(not serialized.contains("test.fact.npc_b_secret"),
		"NPC B private fact absent from NPC A context")
	var b_context := Projector.project(_input(Fixtures.SPEAKER_B))
	check.call(_fact_ids(b_context.value.trusted_facts).has("test.fact.npc_b_secret"),
		"NPC B private fact reaches NPC B")
	check.call(not JSON.stringify(b_context.value).contains("test.fact.npc_a_secret"),
		"NPC A private fact absent from NPC B context")
	var expected_keys := ["schema_version", "speaker_id", "scene_id", "topic_id", "trusted_facts",
		"perceptible", "recent_dialogue", "key_memories", "untrusted"]
	var actual_keys: Array = projected.value.keys()
	actual_keys.sort()
	var sorted_expected := expected_keys.duplicate()
	sorted_expected.sort()
	check.call(actual_keys == sorted_expected, "projected context carries only whitelisted keys")
	var extra := Projector.project(_input(Fixtures.SPEAKER_A, {"facts": Fixtures.facts(),
		"content_pack": {"definitions": []}}))
	check.call(extra.code == "KNOWLEDGE_CONTEXT_INVALID", "unknown context key is rejected")
	var bad_speaker := Projector.project(_input("../escape"))
	check.call(bad_speaker.code == "KNOWLEDGE_CONTEXT_INVALID", "invalid speaker ID rejected")

func _untrusted(check: Callable) -> void:
	var projected := Projector.project(_input(Fixtures.SPEAKER_A,
		{"player_text": "玩家原话原文"}))
	var untrusted: Dictionary = projected.value.untrusted
	check.call(untrusted.player_text == "玩家原话原文", "player words land only in untrusted field")
	check.call(untrusted.player_notes == ["合成玩家笔记"], "player notes land in untrusted field")
	check.call(untrusted.rumors == ["合成传闻"], "rumors land in untrusted field")
	check.call(_fact_ids(untrusted.player_statements) == ["test.fact.player_claim"],
		"player statement facts stay in untrusted field")
	check.call(_fact_ids(untrusted.rumor_facts) == ["test.fact.rumor"],
		"rumor facts stay in untrusted field")
	check.call(untrusted.other_dialogue[0].speaker_id == Fixtures.PLAYER_ID,
		"non-speaker dialogue is untrusted")
	check.call(projected.value.recent_dialogue[0].speaker_id == Fixtures.SPEAKER_A,
		"own dialogue stays in the trusted memory field")

func _deep_copy(check: Callable) -> void:
	var input := _input(Fixtures.SPEAKER_A, {"player_text": "原始"})
	var first := Projector.project(input)
	first.value.trusted_facts[0].text_key = "hacked.key"
	first.value.untrusted.player_notes.append("hacked")
	first.value.trusted_facts.append({"fact_id": "test.fact.injected"})
	var second := Projector.project(input)
	check.call(second.value.trusted_facts[0].text_key != "hacked.key",
		"mutating a returned context cannot leak into later projections")
	check.call(not second.value.untrusted.player_notes.has("hacked"),
		"mutating untrusted arrays cannot leak into later projections")
	check.call(not _fact_ids(second.value.trusted_facts).has("test.fact.injected"),
		"appending to a returned context cannot leak into later projections")
	var facts := Fixtures.facts()
	var third := Projector.project(_input(Fixtures.SPEAKER_A, {"facts": facts}))
	facts[0].text_key = "mutated.key"
	check.call(third.value.trusted_facts[0].text_key == "test.fact.road_public.text",
		"projection result is isolated from later caller mutation")
