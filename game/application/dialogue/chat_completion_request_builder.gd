extends RefCounted
## Converts an already-filtered F1 knowledge projection into a Chat Completions body.
## It never selects knowledge. Fact text is resolved only from an injected, reviewed map,
## and an NPC persona is rendered only from an injected, reviewed template.
##
## The system message is the shared boundary prompt plus, when configured, the speaking
## NPC's persona. A persona placeholder that has no value fails the request instead of
## reaching the model unfilled.

const Result = preload("res://shared/result.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")

const MAX_PROMPT_LENGTH: int = 24000
const MAX_PERSONA_LENGTH: int = 8000
const MAX_PERSONA_VALUES: int = 24
const SPEAKER_JSON_PLACEHOLDER: String = "__SPEAKER_ID_JSON__"
const CONTEXT_KEYS: Array[String] = ["schema_version", "speaker_id", "scene_id", "topic_id",
	"trusted_facts", "perceptible", "recent_dialogue", "key_memories", "untrusted",
	"allowed_actions"]

var _system_prompt: String = ""
var _fact_texts: Dictionary = {}
var _personas: Dictionary = {}

static func create(system_prompt: String, fact_texts: Dictionary, personas: Dictionary = {}) -> RefCounted:
	if system_prompt.strip_edges().is_empty() or system_prompt.length() > MAX_PROMPT_LENGTH:
		return Result.failure("MODEL_PROMPT_INVALID")
	var copied: Dictionary = {}
	for key: Variant in fact_texts:
		if not key is String or not fact_texts[key] is String \
				or fact_texts[key].strip_edges().is_empty() \
				or fact_texts[key].length() > 4000:
			return Result.failure("MODEL_PROMPT_INVALID")
		copied[key] = fact_texts[key]
	var checked_personas := _valid_personas(personas)
	if not checked_personas.ok:
		return checked_personas
	var instance := new()
	instance._system_prompt = system_prompt
	instance._fact_texts = copied
	instance._personas = checked_personas.value
	return Result.success(instance)

func build(filtered_context: Variant) -> RefCounted:
	if not filtered_context is Dictionary or filtered_context.size() != CONTEXT_KEYS.size():
		return Result.failure("MODEL_REQUEST_INVALID")
	for key: String in CONTEXT_KEYS:
		if not filtered_context.has(key):
			return Result.failure("MODEL_REQUEST_INVALID")
	for key: Variant in filtered_context:
		if not key is String or key not in CONTEXT_KEYS:
			return Result.failure("MODEL_REQUEST_INVALID")
	var rendered: Dictionary = filtered_context.duplicate(true)
	var trusted := _resolve_facts(rendered.trusted_facts)
	if not trusted.ok:
		return trusted
	rendered.trusted_facts = trusted.value
	if not rendered.untrusted is Dictionary:
		return Result.failure("MODEL_REQUEST_INVALID")
	for field: String in ["player_statements", "rumor_facts"]:
		var resolved := _resolve_facts(rendered.untrusted.get(field, []))
		if not resolved.ok:
			return resolved
		rendered.untrusted[field] = resolved.value
	var system_text := _system_message(rendered.speaker_id)
	if not system_text.ok:
		return system_text
	if system_text.value.length() > MAX_PROMPT_LENGTH:
		return Result.failure("MODEL_PROMPT_INVALID")
	var encoded := JSON.stringify(rendered)
	if encoded.is_empty() or encoded.length() > MAX_PROMPT_LENGTH:
		return Result.failure("MODEL_REQUEST_INVALID")
	return Result.success({
		"messages": [
			{"role": "system", "content": system_text.value},
			{"role": "user", "content": encoded},
		],
		"response_format": {"type": "json_object"},
	})

func _system_message(speaker_id: Variant) -> RefCounted:
	if not speaker_id is String or not Ids.is_valid_id(speaker_id):
		return Result.failure("MODEL_PERSONA_UNAVAILABLE", [str(speaker_id)])
	var boundary_prompt := _system_prompt.replace(SPEAKER_JSON_PLACEHOLDER,
		JSON.stringify(speaker_id))
	if _personas.is_empty():
		return Result.success(boundary_prompt)
	if not _personas.has(speaker_id):
		return Result.failure("MODEL_PERSONA_UNAVAILABLE", [str(speaker_id)])
	var persona: Dictionary = _personas[speaker_id]
	var template: String = persona.template
	for name: String in persona.values:
		template = template.replace("{" + name + "}", persona.values[name])
	if template.contains("{"):
		return Result.failure("MODEL_PERSONA_INCOMPLETE", [speaker_id])
	return Result.success(boundary_prompt + "\n\n" + template)

static func _valid_personas(value: Variant) -> RefCounted:
	if not value is Dictionary or value.size() > 64:
		return Result.failure("MODEL_PROMPT_INVALID")
	var copied: Dictionary = {}
	for speaker: Variant in value:
		if not speaker is String or not Ids.is_valid_id(speaker):
			return Result.failure("MODEL_PROMPT_INVALID")
		var persona: Variant = value[speaker]
		if not persona is Dictionary or persona.size() != 2 or not persona.has("template") \
				or not persona.has("values") or not persona.template is String \
				or persona.template.strip_edges().is_empty() \
				or persona.template.length() > MAX_PERSONA_LENGTH \
				or not persona.values is Dictionary or persona.values.is_empty() \
				or persona.values.size() > MAX_PERSONA_VALUES:
			return Result.failure("MODEL_PROMPT_INVALID")
		var values: Dictionary = {}
		for name: Variant in persona.values:
			if not name is String or not Ids.is_valid_id(name) or not persona.values[name] is String \
					or persona.values[name].is_empty() or persona.values[name].length() > 200:
				return Result.failure("MODEL_PROMPT_INVALID")
			values[name] = persona.values[name]
		# Fail while constructing, not when a request is built: every placeholder needs text.
		if not _missing_placeholders(persona.template, values).is_empty():
			return Result.failure("MODEL_PROMPT_INVALID")
		copied[speaker] = {"template": persona.template, "values": values}
	return Result.success(copied)

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

func _resolve_facts(value: Variant) -> RefCounted:
	if not value is Array:
		return Result.failure("MODEL_REQUEST_INVALID")
	var output: Array[Dictionary] = []
	for item: Variant in value:
		if not item is Dictionary or item.size() != 3 or not item.has("fact_id") \
				or not item.has("text_key") or not item.has("source"):
			return Result.failure("MODEL_REQUEST_INVALID")
		if not item.fact_id is String or not item.text_key is String \
				or not item.source is String or not _fact_texts.has(item.text_key):
			return Result.failure("MODEL_FACT_TEXT_UNAVAILABLE", [str(item.get("fact_id", ""))])
		output.append({"fact_id": item.fact_id, "text": _fact_texts[item.text_key],
			"source": item.source})
	return Result.success(output)
