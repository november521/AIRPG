extends RefCounted
## Validated NPC character card (persona, state axes, knowledge gates and output limits).
## Cards are reviewed content data; nothing here talks to a model, a scene or a file.
##
## The persona template may reference {placeholders}; every placeholder must be present in
## the card's initial_values, so a request can never reach the model with an unfilled slot.

const Result = preload("res://shared/result.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")

const SCHEMA_VERSION: int = 1
const KEYS: Array[String] = ["character_id", "display_name_key", "greeting_key",
	"fallback_line_key", "portrait_id", "initial_state", "state_enum", "initial_trust",
	"trust_max", "initial_fear", "fear_max", "initial_values", "taboo_triggers", "reply_policy",
	"persona_template"]
const POLICY_KEYS: Array[String] = ["max_dialogue_lines", "max_line_length", "forbidden_phrases"]
const MAX_CARDS: int = 8
const MAX_PERSONA_LENGTH: int = 8000
const MAX_VALUES: int = 16
const MAX_TRIGGERS: int = 16
const MAX_FORBIDDEN: int = 32

static func validate_all(data: Variant) -> RefCounted:
	if not data is Dictionary or data.size() != 3 or not data.has("schema_version") \
			or not data.has("source") or not data.has("cards"):
		return Result.failure("CHARACTER_CARDS_INVALID")
	if data.schema_version != SCHEMA_VERSION or not data.source is String \
			or data.source.strip_edges().is_empty() or not data.cards is Array \
			or data.cards.is_empty() or data.cards.size() > MAX_CARDS:
		return Result.failure("CHARACTER_CARDS_INVALID")
	var copied: Array[Dictionary] = []
	var seen: Dictionary = {}
	for item: Variant in data.cards:
		var validated := validate(item)
		if not validated.ok:
			return validated
		var card: Dictionary = validated.value
		if seen.has(card.character_id):
			return Result.failure("CHARACTER_CARDS_DUPLICATE", [card.character_id])
		seen[card.character_id] = true
		copied.append(card)
	return Result.success(copied)

static func validate(data: Variant) -> RefCounted:
	if not data is Dictionary or data.size() != KEYS.size():
		return Result.failure("CHARACTER_CARD_INVALID")
	for key: String in KEYS:
		if not data.has(key):
			return Result.failure("CHARACTER_CARD_INVALID")
	for key: Variant in data:
		if not key is String or key not in KEYS:
			return Result.failure("CHARACTER_CARD_INVALID")
	if not data.character_id is String or not Ids.is_valid_id(data.character_id):
		return Result.failure("CHARACTER_CARD_INVALID")
	for key: String in ["display_name_key", "greeting_key", "fallback_line_key"]:
		if not data[key] is String or not Ids.is_valid_id(data[key]):
			return Result.failure("CHARACTER_CARD_INVALID")
	if not data.portrait_id is String \
			or (not data.portrait_id.is_empty() and not Ids.is_valid_id(data.portrait_id)):
		return Result.failure("CHARACTER_CARD_INVALID")
	var states := _valid_states(data)
	if not states.ok:
		return states
	var initial_trust: Variant = _as_int(data.initial_trust)
	var trust_max: Variant = _as_int(data.trust_max)
	var initial_fear: Variant = _as_int(data.initial_fear)
	var fear_max: Variant = _as_int(data.fear_max)
	if initial_trust == null or trust_max == null or initial_fear == null or fear_max == null:
		return Result.failure("CHARACTER_CARD_INVALID")
	if trust_max < 1 or initial_trust > trust_max \
			or fear_max < 1 or initial_fear < 0 or initial_fear > fear_max:
		return Result.failure("CHARACTER_CARD_INVALID")
	if not data.persona_template is String or data.persona_template.strip_edges().is_empty() \
			or data.persona_template.length() > MAX_PERSONA_LENGTH:
		return Result.failure("CHARACTER_CARD_INVALID")
	if not data.taboo_triggers is Array or data.taboo_triggers.size() > MAX_TRIGGERS:
		return Result.failure("CHARACTER_CARD_INVALID")
	for trigger: Variant in data.taboo_triggers:
		if not trigger is String or trigger.strip_edges().is_empty():
			return Result.failure("CHARACTER_CARD_INVALID")
	var values := _valid_values(data.initial_values)
	if not values.ok:
		return values
	var missing := _missing_placeholders(data.persona_template, values.value)
	if not missing.is_empty():
		return Result.failure("CHARACTER_CARD_PLACEHOLDER", missing)
	var policy := _valid_policy(data.reply_policy)
	if not policy.ok:
		return policy
	return Result.success({"character_id": data.character_id, "display_name_key": data.display_name_key,
		"greeting_key": data.greeting_key, "fallback_line_key": data.fallback_line_key,
		"portrait_id": data.portrait_id, "initial_state": states.value[0],
		"state_enum": states.value, "initial_trust": initial_trust,
		"trust_max": trust_max, "initial_fear": initial_fear, "fear_max": fear_max,
		"initial_values": values.value, "taboo_triggers": data.taboo_triggers.duplicate(),
		"reply_policy": policy.value, "persona_template": data.persona_template})

static func _as_int(value: Variant) -> Variant:
	# JSON numbers may arrive as floats; only integral values are acceptable here.
	if value is int:
		return value
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	return null

## Cards indexed by character id, for composition and scene roster lookups.
static func index(cards: Array) -> Dictionary:
	var indexed: Dictionary = {}
	for card: Dictionary in cards:
		indexed[card.character_id] = card.duplicate(true)
	return indexed

## Template and values for the request builder; the builder never sees the raw card.
static func persona(card: Dictionary) -> Dictionary:
	return {"template": card.persona_template, "values": card.initial_values.duplicate(true)}

static func policies(cards: Array) -> Dictionary:
	var catalog: Dictionary = {}
	for card: Dictionary in cards:
		catalog[card.character_id] = card.reply_policy.duplicate(true)
	return catalog

static func _valid_states(data: Dictionary) -> RefCounted:
	if not data.state_enum is Array or data.state_enum.is_empty() or data.state_enum.size() > 8:
		return Result.failure("CHARACTER_CARD_INVALID")
	var copied: Array[String] = []
	for state: Variant in data.state_enum:
		if not state is String or state.strip_edges().is_empty() or state in copied:
			return Result.failure("CHARACTER_CARD_INVALID")
		copied.append(state)
	if not data.initial_state is String or data.initial_state not in copied:
		return Result.failure("CHARACTER_CARD_INVALID")
	# The initial state leads the enum so callers can read states[0] as the starting point.
	copied.erase(data.initial_state)
	copied.insert(0, data.initial_state)
	return Result.success(copied)

static func _valid_values(value: Variant) -> RefCounted:
	if not value is Dictionary or value.is_empty() or value.size() > MAX_VALUES:
		return Result.failure("CHARACTER_CARD_INVALID")
	var copied: Dictionary = {}
	for key: Variant in value:
		if not key is String or not Ids.is_valid_id(key) or not value[key] is String \
				or value[key].is_empty() or value[key].length() > 200:
			return Result.failure("CHARACTER_CARD_INVALID")
		copied[key] = value[key]
	return Result.success(copied)

static func _valid_policy(value: Variant) -> RefCounted:
	if not value is Dictionary or value.size() != POLICY_KEYS.size():
		return Result.failure("CHARACTER_CARD_INVALID")
	for key: String in POLICY_KEYS:
		if not value.has(key):
			return Result.failure("CHARACTER_CARD_INVALID")
	for key: Variant in value:
		if not key is String or key not in POLICY_KEYS:
			return Result.failure("CHARACTER_CARD_INVALID")
	var max_lines: Variant = _as_int(value.max_dialogue_lines)
	var max_length: Variant = _as_int(value.max_line_length)
	if max_lines == null or max_lines < 1 or max_lines > 8:
		return Result.failure("CHARACTER_CARD_INVALID")
	if max_length == null or max_length < 1 or max_length > 200:
		return Result.failure("CHARACTER_CARD_INVALID")
	if not value.forbidden_phrases is Array or value.forbidden_phrases.size() > MAX_FORBIDDEN:
		return Result.failure("CHARACTER_CARD_INVALID")
	var phrases: Array[String] = []
	for phrase: Variant in value.forbidden_phrases:
		if not phrase is String or phrase.strip_edges().length() < 2:
			return Result.failure("CHARACTER_CARD_INVALID")
		phrases.append(phrase)
	return Result.success({"max_dialogue_lines": max_lines, "max_line_length": max_length,
		"forbidden_phrases": phrases})

static func _missing_placeholders(template: String, values: Dictionary) -> Array[String]:
	var pattern := RegEx.new()
	if pattern.compile("\\{([a-z0-9_]+)\\}") != OK:
		return ["placeholder_scan_failed"]
	var missing: Array[String] = []
	for found: RegExMatch in pattern.search_all(template):
		var name: String = found.get_string(1)
		if not values.has(name) and name not in missing:
			missing.append(name)
	return missing
