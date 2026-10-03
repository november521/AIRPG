extends RefCounted
## Synthetic engineering previews; replace roster only with approved character input.
const Presence = preload("res://application/exploration/npc_presence.gd")
const RandomSource = preload("res://infrastructure/random/godot_random_source.gd")

static func build() -> Presence:
	var roster: Array[Dictionary] = [
		{"id": "preview_reception", "name_key": "npc.preview_reception", "greeting_key": "npc.greeting",
			"spawn": Vector3(-4.6, 0.08, 2.0), "area": Rect2(-5.4, 0.8, 2.0, 3.3)},
		{"id": "preview_study", "name_key": "npc.preview_study", "greeting_key": "npc.greeting",
			"spawn": Vector3(3.5, 0.08, -3.1), "area": Rect2(2.4, -4.5, 2.5, 3.1)},
	]
	return Presence.new(RandomSource.new(), roster)

static func action_anchors() -> Dictionary:
	# Explicitly synthetic, scene-local anchor IDs. These coordinates never enter a model
	# request; only the IDs are exposed through the allowed action schema.
	return {
		"preview_reception": {
			"preview.anchor.conversation": Vector3(-4.9, 0.08, 2.9),
		},
		"preview_study": {
			"preview.anchor.conversation": Vector3(3.8, 0.08, -2.5),
		},
	}
