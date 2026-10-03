extends RefCounted
## Converts an already-filtered F1 knowledge projection into a Chat Completions body.
## It never selects knowledge. Fact text is resolved only from an injected, reviewed map.

const Result = preload("res://shared/result.gd")

const MAX_PROMPT_LENGTH: int = 24000
const CONTEXT_KEYS: Array[String] = ["schema_version", "speaker_id", "scene_id", "topic_id",
	"trusted_facts", "perceptible", "recent_dialogue", "key_memories", "untrusted",
	"allowed_actions"]

var _system_prompt: String = ""
var _fact_texts: Dictionary = {}

static func create(system_prompt: String, fact_texts: Dictionary) -> RefCounted:
	if system_prompt.strip_edges().is_empty() or system_prompt.length() > MAX_PROMPT_LENGTH:
		return Result.failure("MODEL_PROMPT_INVALID")
	var copied: Dictionary = {}
	for key: Variant in fact_texts:
		if not key is String or not fact_texts[key] is String \
				or fact_texts[key].strip_edges().is_empty() \
				or fact_texts[key].length() > 4000:
			return Result.failure("MODEL_PROMPT_INVALID")
		copied[key] = fact_texts[key]
	var instance := new()
	instance._system_prompt = system_prompt
	instance._fact_texts = copied
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
	var encoded := JSON.stringify(rendered)
	if encoded.is_empty() or encoded.length() > MAX_PROMPT_LENGTH:
		return Result.failure("MODEL_REQUEST_INVALID")
	return Result.success({
		"messages": [
			{"role": "system", "content": _system_prompt},
			{"role": "user", "content": encoded},
		],
		"response_format": {"type": "json_object"},
	})

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
