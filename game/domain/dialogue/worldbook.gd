extends RefCounted
## Reviewed Dead Light world book. Entries keep the source document's visibility layers and
## carry an explicit audience: `speakers` (one NPC may use it) or `public_scene` (every NPC
## present in those scenes may use it). Entries with neither audience are narrator/discovery
## content and reach no NPC.
##
## Safety invariant: `hidden` and `running` entries may never carry an NPC audience, so the
## document's truth layer cannot be wired into an NPC by accident.

const Result = preload("res://shared/result.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")
const Fact = preload("res://domain/dialogue/knowledge_fact.gd")

const SCHEMA_VERSION: int = 1
const LAYERS: Array[String] = ["public", "investigation", "hidden", "running"]
const NARRATOR_LAYERS: Array[String] = ["hidden", "running"]
const KEYS: Array[String] = ["entry_id", "layer", "section", "keywords", "text_key", "text",
	"speakers", "public_scene", "scenes", "topics", "conditions"]
const MAX_ENTRIES: int = 512
const MAX_KEYWORDS: int = 12
const MAX_AUDIENCE: int = 16
const MAX_CONDITIONS: int = 8
const MAX_TEXT_LENGTH: int = 4000
const SOURCE_AUTHORITATIVE: String = "authoritative"

static func validate_all(data: Variant) -> RefCounted:
	if not data is Dictionary or data.size() != 3 or not data.has("schema_version") \
			or not data.has("source") or not data.has("entries"):
		return Result.failure("WORLDBOOK_INVALID")
	if data.schema_version != SCHEMA_VERSION or not data.source is String \
			or data.source.strip_edges().is_empty() or not data.entries is Array \
			or data.entries.is_empty() or data.entries.size() > MAX_ENTRIES:
		return Result.failure("WORLDBOOK_INVALID")
	var copied: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	var seen_text: Dictionary = {}
	for item: Variant in data.entries:
		var validated := validate(item)
		if not validated.ok:
			return validated
		var entry: Dictionary = validated.value
		if seen_ids.has(entry.entry_id):
			return Result.failure("WORLDBOOK_DUPLICATE", [entry.entry_id])
		if seen_text.has(entry.text_key):
			return Result.failure("WORLDBOOK_DUPLICATE_TEXT", [entry.text_key])
		seen_ids[entry.entry_id] = true
		seen_text[entry.text_key] = true
		copied.append(entry)
	return Result.success(copied)

static func validate(data: Variant) -> RefCounted:
	if not data is Dictionary or data.size() != KEYS.size():
		return Result.failure("WORLDBOOK_ENTRY_INVALID")
	for key: String in KEYS:
		if not data.has(key):
			return Result.failure("WORLDBOOK_ENTRY_INVALID")
	for key: Variant in data:
		if not key is String or key not in KEYS:
			return Result.failure("WORLDBOOK_ENTRY_INVALID")
	if not data.entry_id is String or not Ids.is_valid_id(data.entry_id) \
			or not data.text_key is String or not Ids.is_valid_id(data.text_key):
		return Result.failure("WORLDBOOK_ENTRY_INVALID")
	if not data.layer is String or data.layer not in LAYERS:
		return Result.failure("WORLDBOOK_ENTRY_INVALID")
	if not data.section is String or data.section.strip_edges().is_empty():
		return Result.failure("WORLDBOOK_ENTRY_INVALID")
	if not data.text is String or data.text.strip_edges().is_empty() \
			or data.text.length() > MAX_TEXT_LENGTH:
		return Result.failure("WORLDBOOK_ENTRY_INVALID")
	var keywords := _valid_strings(data.keywords, MAX_KEYWORDS)
	if not keywords.ok:
		return keywords
	var speakers := _valid_ids(data.speakers, MAX_AUDIENCE)
	if not speakers.ok:
		return speakers
	var public_scene := _valid_ids(data.public_scene, MAX_AUDIENCE)
	if not public_scene.ok:
		return public_scene
	var scenes := _valid_ids(data.scenes, MAX_AUDIENCE)
	if not scenes.ok:
		return scenes
	var topics := _valid_ids(data.topics, MAX_AUDIENCE)
	if not topics.ok:
		return topics
	var conditions := _valid_conditions(data.conditions)
	if not conditions.ok:
		return conditions
	if data.layer in NARRATOR_LAYERS \
			and (not speakers.value.is_empty() or not public_scene.value.is_empty()):
		return Result.failure("WORLDBOOK_NARRATOR_AUDIENCE", [data.entry_id])
	return Result.success({"entry_id": data.entry_id, "layer": data.layer, "section": data.section,
		"keywords": keywords.value, "text_key": data.text_key, "text": data.text,
		"speakers": speakers.value, "public_scene": public_scene.value, "scenes": scenes.value,
		"topics": topics.value, "conditions": conditions.value})

## F1 fact records for the speakers this scene actually has. One record per entry: a fact
## several NPCs may use keeps every allowed speaker id, which keeps the catalog free of
## duplicate ids. Entries without an audience inside this scene are not projected at all,
## which is what keeps the narrator layer out of NPC context.
static func facts_for(entries: Array, speaker_ids: Array) -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var audience: Array[String] = []
		for speaker: Variant in speaker_ids:
			if speaker is String and entry.speakers.has(speaker) and speaker not in audience:
				audience.append(speaker)
		var public_scene: bool = audience.is_empty() and not entry.public_scene.is_empty()
		if audience.is_empty() and not public_scene:
			continue
		facts.append({"schema_version": Fact.SCHEMA_VERSION, "fact_id": entry.entry_id,
			"text_key": entry.text_key, "source": SOURCE_AUTHORITATIVE,
			"speaker_ids": audience, "public_on_scene": public_scene,
			"scene_ids": entry.scenes.duplicate() if not public_scene \
				else entry.public_scene.duplicate(),
			"topic_ids": entry.topics.duplicate(),
			"disclosure_conditions": entry.conditions.duplicate(true)})
	return facts

## Reviewed fact text by key; the request builder resolves text keys only through this map.
static func text_map(entries: Array) -> Dictionary:
	var texts: Dictionary = {}
	for entry: Dictionary in entries:
		texts[entry.text_key] = entry.text
	return texts

static func narrator_entries(entries: Array) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for entry: Dictionary in entries:
		if entry.speakers.is_empty() and entry.public_scene.is_empty():
			kept.append(entry.duplicate(true))
	return kept

static func _valid_strings(value: Variant, maximum: int) -> RefCounted:
	if not value is Array or value.size() > maximum:
		return Result.failure("WORLDBOOK_ENTRY_INVALID")
	var copied: Array[String] = []
	for item: Variant in value:
		if not item is String or item.strip_edges().is_empty() or item in copied:
			return Result.failure("WORLDBOOK_ENTRY_INVALID")
		copied.append(item)
	return Result.success(copied)

static func _valid_ids(value: Variant, maximum: int) -> RefCounted:
	if not value is Array or value.size() > maximum:
		return Result.failure("WORLDBOOK_ENTRY_INVALID")
	var copied: Array[String] = []
	for item: Variant in value:
		if not item is String or not Ids.is_valid_id(item) or item in copied:
			return Result.failure("WORLDBOOK_ENTRY_INVALID")
		copied.append(item)
	return Result.success(copied)

static func _valid_conditions(value: Variant) -> RefCounted:
	if not value is Array or value.size() > MAX_CONDITIONS:
		return Result.failure("WORLDBOOK_ENTRY_INVALID")
	var copied: Array[Dictionary] = []
	var seen: Dictionary = {}
	for item: Variant in value:
		if not item is Dictionary or item.size() != 2 or not item.has("flag") \
				or not item.has("equals") or not item.flag is String \
				or not Ids.is_valid_id(item.flag) or not item.equals is bool \
				or seen.has(item.flag):
			return Result.failure("WORLDBOOK_ENTRY_INVALID")
		seen[item.flag] = true
		copied.append({"flag": item.flag, "equals": item.equals})
	return Result.success(copied)
