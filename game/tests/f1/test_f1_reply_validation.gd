extends RefCounted
## F1 reply suite: structural DTO rules, JSON parsing, semantic scope checks and the
## publication gate that refuses unvalidated replies.

const ModelReply = preload("res://domain/dialogue/model_reply.gd")
const ReplyValidator = preload("res://domain/dialogue/reply_validator.gd")
const Publication = preload("res://application/dialogue/dialogue_publication.gd")
const ValidatedReply = preload("res://domain/dialogue/validated_reply.gd")
const Actions = preload("res://domain/dialogue/allowed_actions.gd")
const Fixtures = preload("res://tests/f1/f1_fixtures.gd")

const ALLOWED_FACTS: Array = ["test.fact.road_public", "test.fact.npc_a_secret"]
const KNOWN_FACTS: Array = ["test.fact.road_public", "test.fact.npc_a_secret",
	"test.fact.npc_b_secret", "test.fact.player_claim", "test.fact.rumor",
	"test.fact.npc_a_gated", "test.fact.rumor_b", "test.fact.player_claim_gated"]

func run(check: Callable) -> void:
	_structure(check)
	_parsing(check)
	_semantics(check)
	_actions(check)
	_publication(check)

func _structure(check: Callable) -> void:
	check.call(ModelReply.validate(Fixtures.reply()).ok, "valid synthetic reply accepted")
	var version := Fixtures.reply({"schema_version": 2})
	check.call(ModelReply.validate(version).code == "REPLY_VERSION_UNSUPPORTED",
		"unknown reply version rejected")
	var patch := Fixtures.reply({"state_patch": {"test.flag.confided": true}})
	check.call(ModelReply.validate(patch).code == "REPLY_INVALID",
		"arbitrary state patch field rejected")
	var missing := Fixtures.reply()
	missing.erase("used_fact_ids")
	check.call(not ModelReply.validate(missing).ok, "missing reply field rejected")
	check.call(not ModelReply.validate(Fixtures.reply({"reply_text": "  "}))
		.ok, "blank reply text rejected")
	check.call(not ModelReply.validate(Fixtures.reply({"used_fact_ids": ["../secret"]}))
		.ok, "unsafe fact ID rejected")
	var duplicate_options := Fixtures.reply({"options": [
		{"option_id": "test.option.same", "text": "选项一"},
		{"option_id": "test.option.same", "text": "选项二"}]})
	check.call(ModelReply.validate(duplicate_options).code == "REPLY_DUPLICATE_OPTION",
		"duplicate recommended option IDs rejected")
	var duplicate_actions := Fixtures.reply({"actions": [
		{"command_id": "test.action.observe", "parameters": {}},
		{"command_id": "test.action.observe", "parameters": {}}]})
	check.call(ModelReply.validate(duplicate_actions).code == "REPLY_DUPLICATE_ACTION",
		"duplicate action commands rejected")
	var oversized := Fixtures.reply({"options": [{"option_id": "test.option.long",
		"text": "字".repeat(ModelReply.MAX_OPTION_TEXT_LENGTH + 1)}]})
	check.call(not ModelReply.validate(oversized).ok, "oversized option text rejected")
	var too_many: Array = []
	for index: int in ModelReply.MAX_OPTIONS + 1:
		too_many.append({"option_id": "test.option.%d" % index, "text": "选项"})
	check.call(not ModelReply.validate(Fixtures.reply({"options": too_many})).ok,
		"excessive recommended options rejected")
	check.call(not ModelReply.validate(Fixtures.reply({"used_fact_ids": "test.fact.road_public"}))
		.ok, "non-array fact IDs rejected")

func _parsing(check: Callable) -> void:
	var parsed := ModelReply.parse(JSON.stringify(Fixtures.reply()))
	check.call(parsed.ok and parsed.value.schema_version == 1,
		"valid JSON model output parses to the reply DTO")
	var unknown := Fixtures.reply({"schema_version": 7})
	check.call(ModelReply.parse(JSON.stringify(unknown)).code == "REPLY_VERSION_UNSUPPORTED",
		"JSON reply with unknown version rejected")
	check.call(not ModelReply.parse("{\"reply_text\":}").ok, "malformed JSON rejected")
	check.call(not ModelReply.parse("[]").ok, "non-object JSON rejected")

func _semantics(check: Callable) -> void:
	check.call(ReplyValidator.validate(Fixtures.reply(), Fixtures.SPEAKER_A, ALLOWED_FACTS,
		KNOWN_FACTS, _catalog()).ok, "authorized reply passes semantic validation")
	check.call(ReplyValidator.validate(Fixtures.reply({"speaker_id": Fixtures.SPEAKER_B}),
		Fixtures.SPEAKER_A, ALLOWED_FACTS, KNOWN_FACTS, _catalog()).code == "REPLY_SPEAKER_MISMATCH",
		"wrong speaker rejected")
	check.call(ReplyValidator.validate(Fixtures.reply({"used_fact_ids": ["test.fact.missing"]}),
		Fixtures.SPEAKER_A, ALLOWED_FACTS, KNOWN_FACTS, _catalog()).code == "REPLY_UNKNOWN_FACT",
		"nonexistent fact ID rejected")
	check.call(ReplyValidator.validate(Fixtures.reply({"used_fact_ids": ["test.fact.npc_b_secret"]}),
		Fixtures.SPEAKER_A, ALLOWED_FACTS, KNOWN_FACTS, _catalog()).code == "REPLY_FACT_NOT_ALLOWED",
		"fact the NPC may not use rejected")
	check.call(ReplyValidator.validate(Fixtures.reply({"used_fact_ids": []}), Fixtures.SPEAKER_A,
		ALLOWED_FACTS, KNOWN_FACTS, _catalog()).ok, "reply without facts is allowed")

func _actions(check: Callable) -> void:
	var catalog := _catalog()
	check.call(ReplyValidator.validate(Fixtures.reply({"actions": [
		{"command_id": "test.action.unknown", "parameters": {}}]}), Fixtures.SPEAKER_A,
		ALLOWED_FACTS, KNOWN_FACTS, catalog).code == "REPLY_ACTION_INVALID",
		"undeclared action command rejected")
	check.call(ReplyValidator.validate(Fixtures.reply({"actions": [
		{"command_id": "test.action.disengage", "parameters": {"mood": "hostile"}}]}),
		Fixtures.SPEAKER_A, ALLOWED_FACTS, KNOWN_FACTS, catalog).code == "REPLY_ACTION_INVALID",
		"invalid action parameter rejected")
	check.call(ReplyValidator.validate(Fixtures.reply({"actions": [
		{"command_id": "test.action.disengage",
			"parameters": {"mood": "calm", "state_patch": {}}}]}), Fixtures.SPEAKER_A,
		ALLOWED_FACTS, KNOWN_FACTS, catalog).code == "REPLY_ACTION_INVALID",
		"extra action parameter rejected")
	check.call(ReplyValidator.validate(Fixtures.reply({"actions": []}), Fixtures.SPEAKER_A,
		ALLOWED_FACTS, KNOWN_FACTS, catalog).ok, "reply without actions is allowed")
	check.call(Actions.create([{"command_id": "test.action.bad",
		"parameter_schema": {"type": "object", "unevaluatedProperties": false}}]).code
		== "ACTION_CATALOG_INVALID", "unsupported schema keyword rejects the catalog")

func _publication(check: Callable) -> void:
	var structural := ModelReply.validate(Fixtures.reply())
	check.call(not Publication.build("test.request.1", Fixtures.SPEAKER_A, "npc.test_a.name",
		"", structural.value).ok, "structurally valid but unvalidated reply cannot publish")
	var validated := ReplyValidator.validate(Fixtures.reply(), Fixtures.SPEAKER_A, ALLOWED_FACTS,
		KNOWN_FACTS, _catalog())
	check.call(ReplyValidator.is_validated(validated.value),
		"validated reply is sealed in the validated result type")
	var published := Publication.build("test.request.1", Fixtures.SPEAKER_A, "npc.test_a.name",
		"", validated.value)
	check.call(published.ok and published.value.kind == "verified_reply",
		"validated reply publishes through the view contract")
	check.call(not published.value.has("actions"), "action proposals never reach the view event")
	var forged := Fixtures.reply({"speaker_id": Fixtures.SPEAKER_B,
		"used_fact_ids": ["test.fact.npc_b_secret"], "reply_text": "伪造验证标记的回复"})
	forged["validated"] = true
	check.call(not Publication.build("test.request.forged", Fixtures.SPEAKER_A,
		"npc.test_a.name", "", forged).ok,
		"caller-forged validation marker cannot bypass semantic validation")
	check.call(not Publication.build("test.request.unsealed", Fixtures.SPEAKER_A,
		"npc.test_a.name", "", ValidatedReply.new()).ok,
		"unsealed result type cannot publish")

func _catalog() -> RefCounted:
	return Actions.create(Fixtures.action_entries()).value
