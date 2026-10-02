extends RefCounted
const JsonFile = preload("res://infrastructure/content/json_file.gd")
const Catalog = preload("res://domain/content/story_catalog.gd")
const Service = preload("res://application/story_archive/story_archive_service.gd")
const Launcher = preload("res://application/ports/story_launcher.gd")
const ART_LIBRARY = preload("res://presentation/story_archive/art/story_art_library.tres")

static func build(include_placeholders: bool = false, launcher: Launcher = null) -> Dictionary:
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
			if include_placeholders:
				var previews := JsonFile.read("res://data/stories/preview_catalog.json")
				if previews.ok:
					var combined: Dictionary = raw.value.duplicate(true)
					var checked := Catalog.validate(previews.value, schema.value, messages.value)
					if checked.ok:
						combined.stories.append_array(checked.value)
						if Catalog.validate(combined, schema.value, messages.value).ok:
							for entry: Dictionary in checked.value:
								entry["preview_only"] = true
								entries.append(entry)
	# Explicit, export-safe resource allowlist; JSON cannot load scripts or arbitrary paths.
	return {"service": Service.new(entries, launcher if launcher != null else Launcher.new(), error),
		"art": ART_LIBRARY.textures.duplicate()}
