extends RefCounted
## Manor scene roster. Emilia is the granddaughter who escaped the house; Mary is the gas
## station waitress who is canonically found in the manor reception while destroying
## evidence. Spawn points, wander areas and anchors are scene coordinates, not story facts.

const Presence = preload("res://application/exploration/npc_presence.gd")
const RandomSource = preload("res://infrastructure/random/godot_random_source.gd")

static func build() -> Presence:
	var roster: Array[Dictionary] = [
		{"id": "mary", "name_key": "npc.mary", "greeting_key": "npc.mary.greeting",
			"spawn": Vector3(-4.6, 0.08, 2.0), "area": Rect2(-5.4, 0.8, 2.0, 3.3)},
		{"id": "emilia", "name_key": "npc.emilia", "greeting_key": "npc.emilia.greeting",
			"spawn": Vector3(3.5, 0.08, -3.1), "area": Rect2(2.4, -4.5, 2.5, 3.1)},
	]
	return Presence.new(RandomSource.new(), roster)

static func action_anchors() -> Dictionary:
	# Explicitly scene-local anchor IDs. These coordinates never enter a model request;
	# only the IDs are exposed through the allowed action schema.
	return {
		"mary": {
			"manor.anchor.conversation": Vector3(-4.9, 0.08, 2.9),
		},
		"emilia": {
			"manor.anchor.conversation": Vector3(3.8, 0.08, -2.5),
		},
	}
