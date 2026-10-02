extends RefCounted
## Synthetic fixture, never an official investigator or gameplay formula.
const State = preload("res://domain/character/character_state.gd")
const Service = preload("res://application/character/character_service.gd")

static func build() -> Service:
	var state := State.new()
	var result = state.configure({
		"demo_bandage": {"name_key": "item.bandage", "description_key": "item.bandage.desc", "kind": "consumable", "healing": 15, "protected": false},
		"demo_lamp": {"name_key": "item.lamp", "description_key": "item.lamp.desc", "kind": "tool", "healing": 0, "protected": false},
		"demo_token": {"name_key": "item.token", "description_key": "item.token.desc", "kind": "key", "healing": 0, "protected": true},
	}, {
		"schema_version": 1, "revision": 0, "hp": 70, "hp_max": 100,
		"sanity": 60, "sanity_max": 100,
		"inventory": {"demo_bandage": 3, "demo_lamp": 1, "demo_token": 1},
	})
	assert(result.ok, "Invalid character preview fixture")
	return Service.new(state, {
		"name_key": "character.demo", "role_key": "character.role", "age": null,
		"condition_key": "character.condition_preview",
		"attributes": {"strength": 50, "dexterity": 50, "constitution": 50, "intelligence": 50, "perception": 50, "charisma": 50},
		"skills": {"spot": 40, "listen": null, "psychology": 40, "persuade": null, "first_aid": null},
		"background": {"beliefs": "dossier.pending", "people": "dossier.pending", "possessions": "dossier.pending", "experience": "dossier.pending"},
	}, {"damage": 10, "stress": 5, "supply_id": "demo_bandage"})

