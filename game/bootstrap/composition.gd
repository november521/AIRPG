extends RefCounted
## Sole composition root. Explicit wiring; no service locator or autoload business singleton.
const JsonFile = preload("res://infrastructure/content/json_file.gd")
const Schema = preload("res://shared/schema_validator.gd")
const Result = preload("res://shared/result.gd")
const ContentValidator = preload("res://domain/content/content_validator.gd")
const StateStore = preload("res://domain/story/state_store.gd")
const Session = preload("res://application/session_service.gd")
const DisabledProvider = preload("res://infrastructure/ai/disabled_provider.gd")
const StoryArchive = preload("res://bootstrap/story_archive_composition.gd")
const Launcher = preload("res://application/ports/story_launcher.gd")

static func build(config_path: String = "res://data/config/app.json", launcher: Launcher = null) -> RefCounted:
	var config_schema := JsonFile.read("res://data/schemas/app_config.schema.json")
	var config := JsonFile.read(config_path)
	if not config_schema.ok or not config.ok:
		return Result.failure("CONFIG_UNAVAILABLE")
	var issues := Schema.validate(config.value, config_schema.value)
	if not issues.is_empty():
		return Result.failure("CONFIG_INVALID", issues)
	var schema := JsonFile.read("res://data/schemas/content_pack.schema.json")
	var content := JsonFile.read(config.value.content_path)
	if not schema.ok or not content.ok:
		return Result.failure("CONTENT_UNAVAILABLE")
	var validated := ContentValidator.validate(content.value, schema.value)
	if not validated.ok:
		return validated
	if content.value.locale != config.value.locale:
		return Result.failure("LOCALE_MISMATCH")
	var state := StateStore.new()
	var initialized := state.configure(content.value.flags)
	if not initialized.ok:
		return initialized
	var archive := StoryArchive.build(OS.is_debug_build() and config.value.get("story_archive_placeholders", false), launcher)
	return Result.success({"session": Session.new(state), "provider": DisabledProvider.new(),
		"story_archive": archive.service, "story_art": archive.art,
		"config": config.value, "pack_id": content.value.pack_id,
		"content_version": content.value.content_version})
