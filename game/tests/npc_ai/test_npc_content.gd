extends RefCounted
## Content-layer coverage for the two manor characters and the Dead Light world book:
## schemas, knowledge audience, disclosure gates, room-scoped memory, output policy and the
## end-to-end request that actually carries a persona and a filtered fact set.

const Result = preload("res://shared/result.gd")
const Contract = preload("res://application/contracts/model_transport_contract.gd")
const JsonFile = preload("res://infrastructure/content/json_file.gd")
const Schema = preload("res://shared/schema_validator.gd")
const Cards = preload("res://domain/dialogue/character_card.gd")
const Book = preload("res://domain/dialogue/worldbook.gd")
const Facts = preload("res://domain/dialogue/knowledge_facts.gd")
const Policy = preload("res://domain/dialogue/reply_policy.gd")
const Content = preload("res://bootstrap/manor_npc_content.gd")
const Preview = preload("res://bootstrap/npc_preview.gd")
const Builder = preload("res://application/dialogue/chat_completion_request_builder.gd")
const Gateway = preload("res://infrastructure/ai/chat_completion_gateway.gd")
const StateStore = preload("res://domain/story/state_store.gd")
const Actions = preload("res://domain/dialogue/allowed_actions.gd")
const UseCase = preload("res://application/dialogue/dialogue_use_case.gd")
const ContextSource = preload("res://tests/f1/f1_context_source.gd")
const FakeTransport = preload("res://tests/npc_ai/fake_chat_transport.gd")

const CARDS_PATH: String = "res://data/ai/npc_characters.zh_CN.json"
const CARDS_SCHEMA: String = "res://data/schemas/npc_characters.schema.json"
const BOOK_PATH: String = "res://data/ai/deadlight_worldbook.zh_CN.json"
const BOOK_SCHEMA: String = "res://data/schemas/worldbook.schema.json"
const NARRATOR_ONLY: Array[String] = ["deadlight.essence", "deadlight.weaknesses",
	"relic.sin_eater", "relic.control_ritual", "timeline.true_events", "narrator.hidden_roster",
	"ending.paths"]

func run(check: Callable) -> void:
	var cards := _cards(check)
	var entries := _worldbook(check)
	var bundle := _bundle(check, cards, entries)
	_knowledge_scoping(check, bundle)
	_disclosure_gates(check, bundle)
	_output_policy(check, cards)
	_persona_requests(check, bundle, entries)
	_end_to_end(check, bundle)

func _cards(check: Callable) -> Array:
	var raw: RefCounted = JsonFile.read(CARDS_PATH)
	var schema: RefCounted = JsonFile.read(CARDS_SCHEMA)
	var issues: Array[String] = [] if not raw.ok or not schema.ok \
		else Schema.validate(raw.value, schema.value)
	check.call(raw.ok and schema.ok and issues.is_empty(),
		"NPC content: character cards pass their strict schema")
	var validated: RefCounted = Cards.validate_all(raw.value) if raw.ok else null
	check.call(validated != null and validated.ok and validated.value.size() == 2,
		"NPC content: two reviewed character cards validate")
	var cards: Array = validated.value if validated != null and validated.ok else []
	var ids: Array[String] = []
	for card: Dictionary in cards:
		ids.append(card.character_id)
	check.call(ids == ["emilia", "mary"], "NPC content: cards are Emilia and Mary")
	var roster: Array[Dictionary] = Preview.build().roster()
	check.call(roster.size() == 2 and roster[0].id == "mary" and roster[1].id == "emilia",
		"NPC content: scene roster places Mary in the reception and Emilia in the study")
	var indexed: Dictionary = Cards.index(cards)
	for entry: Dictionary in roster:
		var card: Dictionary = indexed[entry.id]
		check.call(card.greeting_key == entry.greeting_key,
			"NPC content: roster and card agree on the greeting key for " + entry.id)
	var broken: Dictionary = cards[0].duplicate(true)
	broken.initial_values.erase("trust")
	check.call(not Cards.validate(broken).ok,
		"NPC content: an unfilled persona placeholder fails the card check")
	var duplicated: Dictionary = {"schema_version": 1, "source": "synthetic",
		"cards": [cards[0], cards[0]]}
	check.call(Cards.validate_all(duplicated).code == "CHARACTER_CARDS_DUPLICATE",
		"NPC content: duplicate character ids are rejected")
	return cards

func _worldbook(check: Callable) -> Array:
	var raw: RefCounted = JsonFile.read(BOOK_PATH)
	var schema: RefCounted = JsonFile.read(BOOK_SCHEMA)
	var issues: Array[String] = [] if not raw.ok or not schema.ok \
		else Schema.validate(raw.value, schema.value)
	check.call(raw.ok and schema.ok and issues.is_empty(),
		"NPC content: world book passes its strict schema")
	var validated: RefCounted = Book.validate_all(raw.value) if raw.ok else null
	check.call(validated != null and validated.ok, "NPC content: world book entries validate")
	var entries: Array = validated.value if validated != null and validated.ok else []
	var layers: Dictionary = {}
	for entry: Dictionary in entries:
		layers[entry.layer] = true
	check.call(layers.has("public") and layers.has("investigation") and layers.has("hidden")
		and layers.has("running"), "NPC content: every world book layer is represented")
	var leaked: Dictionary = entries[0].duplicate(true)
	leaked.layer = "hidden"
	leaked.speakers = ["emilia"]
	check.call(Book.validate(leaked).code == "WORLDBOOK_NARRATOR_AUDIENCE",
		"NPC content: narrator-layer entry with an NPC audience is rejected")
	var without_audience: Dictionary = entries[0].duplicate(true)
	without_audience.speakers = []
	without_audience.public_scene = []
	check.call(Book.validate(without_audience).ok,
		"NPC content: an entry with no audience stays valid narrator content")
	return entries

func _bundle(check: Callable, _cards: Array, _entries: Array) -> Dictionary:
	var roster: Array[Dictionary] = Preview.build().roster()
	var loaded: RefCounted = Content.load_for(roster)
	check.call(loaded.ok, "NPC content: manor composition loads reviewed content")
	if not loaded.ok:
		return {}
	var bundle: Dictionary = loaded.value
	check.call(bundle.speakers.size() == 2 and bundle.personas.size() == 2
		and bundle.policies.size() == 2, "NPC content: every scene speaker has a card binding")
	check.call(bundle.narrator_entries > 0, "NPC content: narrator-only entries are tracked, not wired")
	var unknown_roster: Array[Dictionary] = [{"id": "unknown_npc"}]
	var missing: RefCounted = Content.load_for(unknown_roster)
	check.call(not missing.ok and missing.code == "NPC_CHARACTER_MISSING",
		"NPC content: a scene speaker without a card fails composition")
	return bundle

func _knowledge_scoping(check: Callable, bundle: Dictionary) -> void:
	if bundle.is_empty():
		return
	var catalog: Array = bundle.facts
	var ids: Array[String] = []
	for fact: Dictionary in catalog:
		ids.append(fact.fact_id)
	for forbidden: String in NARRATOR_ONLY:
		check.call(forbidden not in ids,
			"NPC content: narrator entry never becomes an NPC fact: " + forbidden)
	var emilia := Facts.trusted(catalog, "emilia", "manor", "manor.room.doctor_study", {})
	var mary := Facts.trusted(catalog, "mary", "manor", "manor.room.reception", {})
	check.call(_has(emilia, "emilia.knows.attack") and _has(emilia, "emilia.memory.study"),
		"NPC content: Emilia receives her own knowledge and the room she stands in")
	check.call(not _has(emilia, "emilia.memory.cellar"),
		"NPC content: Emilia does not recall a room she is not in")
	check.call(not _has(mary, "emilia.knows.attack"),
		"NPC content: Emilia's knowledge never reaches Mary")
	check.call(_has(mary, "mary.says.name") and _has(mary, "mary.says.emilia_by_car"),
		"NPC content: Mary receives only her technically-true surface statements")
	check.call(_has(mary, "world.place.greenapple_manor"),
		"NPC content: public scene facts reach NPCs present in the scene")
	check.call(not _has(mary, "character.clem.raid") and not _has(mary, "deadlight.weaknesses"),
		"NPC content: Mary is not handed the raid aftermath or the Dead Light")

func _disclosure_gates(check: Callable, bundle: Dictionary) -> void:
	if bundle.is_empty():
		return
	var catalog: Array = bundle.facts
	var flags: Dictionary = bundle.gate_flags
	check.call(flags.has("emilia.trust_locket") and flags["emilia.trust_locket"] == false,
		"NPC content: disclosure gates start closed in the supplied state")
	var closed := Facts.trusted(catalog, "emilia", "manor", "manor.room.doctor_study", flags)
	check.call(not _has(closed, "emilia.knows.locket"),
		"NPC content: the locket fact stays hidden at trust 0")
	flags["emilia.trust_locket"] = true
	var open := Facts.trusted(catalog, "emilia", "manor", "manor.room.doctor_study", flags)
	check.call(_has(open, "emilia.knows.locket"),
		"NPC content: raising the gate releases the locket fact")
	check.call(not _has(open, "mary.confession"),
		"NPC content: Mary's confession needs her own exposure gate")

func _output_policy(check: Callable, cards: Array) -> void:
	var indexed: Dictionary = Cards.index(cards)
	var emilia: Dictionary = indexed["emilia"].reply_policy
	var mary: Dictionary = indexed["mary"].reply_policy
	check.call(Policy.validate(emilia, "我不知道。……我只看见光。").ok,
		"NPC policy: Emilia's short answer passes")
	check.call(Policy.validate(emilia, "我不是疯子。").ok,
		"NPC policy: Emilia's sanctioned line passes")
	check.call(not Policy.validate(emilia, "是的，我住过疗养院。").ok,
		"NPC policy: Emilia's compliant self-label is rejected")
	check.call(not Policy.validate(mary, "不是我干的。").ok,
		"NPC policy: Mary's falsifiable denial is rejected")
	check.call(Policy.validate(mary, "那不是我带来的。").ok,
		"NPC policy: Mary's precisely-true limitation is allowed")
	check.call(Policy.validate(mary, "……谁？").ok, "NPC policy: Mary's counter-question passes")
	check.call(not Policy.validate(mary, "我不知道。我不知道。我不知道。").ok,
		"NPC policy: more sentences than the bubble budget is rejected")
	check.call(not Policy.validate(mary, "这一句话故意写得非常长已经明显超过了四十个字的单句上限用来验证长度检查确实会拒绝它。").ok,
		"NPC policy: a line beyond the per-sentence character budget is rejected")
	check.call(Policy.validate(mary, "……").ok and Policy.validate(mary, "（她先移开视线。）").ok,
		"NPC policy: silence and a single action line pass")
	check.call(not Policy.validate(emilia, "作为AI，我可以帮你。").ok,
		"NPC policy: meta exposure is rejected for every speaker")
	check.call(Policy.validate({}, "任意文本").ok,
		"NPC policy: an unconfigured speaker still only faces the safety net")

func _persona_requests(check: Callable, bundle: Dictionary, entries: Array) -> void:
	if bundle.is_empty():
		return
	var builder: RefCounted = Builder.create(bundle.system_prompt, bundle.fact_texts, bundle.personas)
	check.call(builder.ok, "NPC persona: builder accepts reviewed personas and fact text")
	var context: Dictionary = _context("emilia", "manor.room.doctor_study")
	context.trusted_facts = Facts.trusted(bundle.facts, "emilia", "manor",
		"manor.room.doctor_study", {})
	var request: RefCounted = builder.value.build(context)
	check.call(request.ok and request.value.messages.size() == 2,
		"NPC persona: one request still compiles to two chat messages")
	var system_text: String = request.value.messages[0].content
	check.call(system_text.contains("艾米利亚") and system_text.contains("SHOCK")
		and system_text.contains("0/5"), "NPC persona: Emilia's persona is rendered with her state")
	check.call(not system_text.contains("{state}") and not system_text.contains("{trust}"),
		"NPC persona: no template placeholder survives into the prompt")
	check.call(request.value.messages[1].content.contains("她在树林里见过那个东西"),
		"NPC persona: filtered fact text reaches the user message")
	var unknown: Dictionary = _context("nobody", "manor.room.doctor_study")
	check.call(builder.value.build(unknown).code == "MODEL_PERSONA_UNAVAILABLE",
		"NPC persona: a speaker without a card fails closed")
	var broken_persona: Dictionary = bundle.personas.duplicate(true)
	broken_persona["emilia"].template = "缺少占位符 {missing_value}"
	check.call(not Builder.create(bundle.system_prompt, bundle.fact_texts, broken_persona).ok,
		"NPC persona: unresolved placeholder data is rejected at build time")
	check.call(Book.narrator_entries(entries).size() > 0,
		"NPC persona: the narrator layer is available to a future host, not to NPCs")

func _end_to_end(check: Callable, bundle: Dictionary) -> void:
	if bundle.is_empty():
		return
	var transport: RefCounted = FakeTransport.new()
	var builder: RefCounted = Builder.create(bundle.system_prompt, bundle.fact_texts, bundle.personas)
	var gateway: RefCounted = Gateway.new(transport, builder.value)
	var state: RefCounted = StateStore.new()
	state.configure(bundle.gate_flags)
	var catalog: RefCounted = Actions.create([{"command_id": "npc.stay",
		"parameter_schema": {"type": "object", "additionalProperties": false, "properties": {}}}])
	var created: RefCounted = UseCase.create({"session_id": "manor.session", "state_store": state,
		"provider": gateway, "context_source": ContextSource.new(), "facts": bundle.facts,
		"action_catalog": catalog.value, "speakers": bundle.speakers,
		"reply_policies": bundle.policies})
	check.call(created.ok, "NPC end to end: use case builds from reviewed content")
	if not created.ok:
		return
	var use_case: RefCounted = created.value
	var events: Array = []
	use_case.view_event.connect(func(event: Dictionary) -> void: events.append(event))
	use_case.begin_exchange("emilia", "manor", "manor.room.doctor_study")
	check.call(use_case.submit_text("content.1", "那东西到底是什么？").ok,
		"NPC end to end: player input starts the request")
	var body: Dictionary = transport.accepted["content.1"]
	check.call(body.messages[0].content.contains("艾米利亚")
		and body.messages[1].content.contains("她在树林里见过那个东西"),
		"NPC end to end: persona and Emilia-only fact travel together")
	transport.finish("content.1", _envelope("我不知道。……我只看见光。", "emilia", []))
	var replies: Array = events.filter(func(item: Dictionary) -> bool:
		return item.kind == "verified_reply")
	check.call(replies.size() == 1, "NPC end to end: a compliant reply is published")
	use_case.begin_exchange("mary", "manor", "manor.room.reception")
	use_case.submit_text("content.2", "是你让他们来的。")
	transport.finish("content.2", _envelope("不是我干的。", "mary", []))
	var failures: Array = events.filter(func(item: Dictionary) -> bool:
		return item.kind == "status" and item.get("status") == "failed")
	check.call(failures.size() == 1 and not events.any(func(item: Dictionary) -> bool:
		return item.kind == "verified_reply" and item.get("speaker_id") == "mary"),
		"NPC end to end: Mary's falsifiable denial never reaches the view")
	use_case.begin_exchange("mary", "manor", "manor.room.reception")
	use_case.submit_text("content.3", "照片上的人是你。")
	transport.finish("content.3", _envelope("……很多人有照片。", "mary", []))
	var verified: Array = events.filter(func(item: Dictionary) -> bool:
		return item.kind == "verified_reply" and item.get("speaker_id") == "mary")
	check.call(verified.size() == 1, "NPC end to end: Mary's evasion is published")
	use_case.release()
	gateway.release()

func _has(facts: Array, fact_id: String) -> bool:
	for fact: Dictionary in facts:
		if fact.fact_id == fact_id:
			return true
	return false

func _context(speaker_id: String, topic_id: String) -> Dictionary:
	return {"schema_version": 1, "speaker_id": speaker_id, "scene_id": "manor",
		"topic_id": topic_id, "trusted_facts": [], "perceptible": [], "recent_dialogue": [],
		"key_memories": [], "untrusted": {"player_text": "玩家文本", "player_notes": [],
			"rumors": [], "player_statements": [], "rumor_facts": [], "other_dialogue": []},
		"allowed_actions": []}

func _envelope(text: String, speaker_id: String, fact_ids: Array) -> Dictionary:
	var reply: Dictionary = {"schema_version": 1, "speaker_id": speaker_id, "reply_text": text,
		"used_fact_ids": fact_ids, "options": [], "actions": []}
	return Contract.completed_response(JSON.stringify(reply), "stop", {}).value
