extends RefCounted
const JsonFile = preload("res://infrastructure/content/json_file.gd")
const Catalog = preload("res://domain/content/story_catalog.gd")
const Service = preload("res://application/story_archive/story_archive_service.gd")
const Launcher = preload("res://application/ports/story_launcher.gd")
const ART_LIBRARY = preload("res://presentation/story_archive/art/story_art_library.tres")

static func build() -> Dictionary:
	var raw := JsonFile.read("res://data/stories/catalog.json")
	var schema := JsonFile.read("res://data/schemas/story_catalog.schema.json")
	var messages := JsonFile.read("res://data/localization/zh_CN.json")
	var entries: Array = []
	var error := "STORY_CATALOG_UNAVAILABLE"
	if raw.ok and schema.ok and messages.ok:
		var validated := Catalog.validate(raw.value, schema.value, messages.value)
		error = validated.code
		if validated.ok:
			entries = validated.value
	# Explicit, export-safe resource allowlist; JSON cannot load scripts or arbitrary paths.
	return {"service": Service.new(entries, Launcher.new(), error),
		"art": ART_LIBRARY.textures.duplicate()}
