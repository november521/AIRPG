extends RefCounted
## Loads and cross-checks the reviewed NPC content for the manor scene: the shared boundary
## prompt, the character cards and the Dead Light world book. Every file passes its strict
## schema and then its domain validator, so a scene cannot start on half-valid content.
##
## The returned bundle is the only thing the composition hands to the dialogue use case.

const Result = preload("res://shared/result.gd")
const JsonFile = preload("res://infrastructure/content/json_file.gd")
const Schema = preload("res://shared/schema_validator.gd")
const Cards = preload("res://domain/dialogue/character_card.gd")
const Book = preload("res://domain/dialogue/worldbook.gd")
const Facts = preload("res://domain/dialogue/knowledge_facts.gd")

const PROMPT_PATH: String = "res://data/ai/npc_prompt.zh_CN.json"
const PROMPT_SCHEMA: String = "res://data/schemas/npc_prompt.schema.json"
const CARDS_PATH: String = "res://data/ai/npc_characters.zh_CN.json"
const CARDS_SCHEMA: String = "res://data/schemas/npc_characters.schema.json"
const BOOK_PATH: String = "res://data/ai/deadlight_worldbook.zh_CN.json"
const BOOK_SCHEMA: String = "res://data/schemas/worldbook.schema.json"

static func load_for(roster: Array[Dictionary]) -> RefCounted:
	var prompt := _read(PROMPT_PATH, PROMPT_SCHEMA, "MODEL_PROMPT")
	if not prompt.ok:
		return prompt
	var cards := _read(CARDS_PATH, CARDS_SCHEMA, "NPC_CHARACTERS")
	if not cards.ok:
		return cards
	var book := _read(BOOK_PATH, BOOK_SCHEMA, "WORLDBOOK")
	if not book.ok:
		return book
	var validated_cards := Cards.validate_all(cards.value)
	if not validated_cards.ok:
		return validated_cards
	var entries := Book.validate_all(book.value)
	if not entries.ok:
		return entries
	var indexed: Dictionary = Cards.index(validated_cards.value)
	var roster_ids: Array[String] = []
	var speakers: Dictionary = {}
	var personas: Dictionary = {}
	var policies: Dictionary = {}
	for entry: Dictionary in roster:
		var id: String = entry.id
		if not indexed.has(id):
			return Result.failure("NPC_CHARACTER_MISSING", [id])
		var card: Dictionary = indexed[id]
		roster_ids.append(id)
		speakers[id] = {"name_key": card.display_name_key, "portrait_id": card.portrait_id}
		personas[id] = Cards.persona(card)
		policies[id] = card.reply_policy.duplicate(true)
	var catalog := Facts.validate_all(Book.facts_for(entries.value, roster_ids))
	if not catalog.ok:
		return catalog
	return Result.success({"system_prompt": prompt.value.system_prompt, "speakers": speakers,
		"personas": personas, "policies": policies, "facts": catalog.value,
		"fact_texts": Book.text_map(entries.value), "gate_flags": _gate_flags(entries.value),
		"narrator_entries": Book.narrator_entries(entries.value).size()})

## Every disclosure flag the content references, seeded false so the systems that will own
## them (clues, trust, evidence) can commit a change later without a state migration.
static func _gate_flags(entries: Array) -> Dictionary:
	var flags: Dictionary = {}
	for entry: Dictionary in entries:
		for condition: Dictionary in entry.conditions:
			flags[condition.flag] = false
	return flags

static func _read(path: String, schema_path: String, code: String) -> RefCounted:
	var raw: RefCounted = JsonFile.read(path)
	var schema: RefCounted = JsonFile.read(schema_path)
	if not raw.ok or not schema.ok:
		return Result.failure(code + "_UNAVAILABLE")
	var issues: Array[String] = Schema.validate(raw.value, schema.value)
	if not issues.is_empty():
		return Result.failure(code + "_INVALID", issues)
	return Result.success(raw.value)
