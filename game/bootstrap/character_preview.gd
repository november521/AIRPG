extends RefCounted
## Synthetic fixture, never an official investigator or gameplay formula.
const State = preload("res://domain/character/character_state.gd")
const Service = preload("res://application/character/character_service.gd")
const Crowbar = preload("res://items/data/crowbar.tres")
const WorldItem = preload("res://items/world/world_item.tscn")
const HeldItem = preload("res://items/held/crowbar_held.tscn")

static func _definition(name_key: String, description_key: String, kind: String, equippable: bool, droppable: bool, tags: Array[StringName], healing: int = 0) -> Dictionary:
	return {"name_key": name_key, "description_key": description_key, "kind": kind, "healing": healing,
		"protected": not droppable, "equippable": equippable, "droppable": droppable, "tags": tags,
		"world_scene": WorldItem, "held_scene": HeldItem if equippable else null,
		"stackable": true, "max_stack": 999, "weight": 0.0}

static func _crowbar_definition() -> Dictionary:
	var value: Dictionary = Crowbar.to_runtime_view()
	value["kind"] = "tool"
	value["healing"] = 0
	value["protected"] = false
	value.erase("id")
	return value

static func build() -> Service:
	var state := State.new()
	var result = state.configure({
		"demo_bandage": _definition("item.bandage", "item.bandage.desc", "consumable", false, true, [&"heal"], 15),
		"demo_lamp": _definition("item.lamp", "item.lamp.desc", "tool", true, true, [&"light_source"]),
		"demo_token": _definition("item.token", "item.token.desc", "key", true, false, [&"quest_item"]),
		"crowbar": _crowbar_definition(),
	}, {
		"schema_version": 2, "revision": 0, "hp": 70, "hp_max": 100,
		"sanity": 60, "sanity_max": 100,
		"inventory": {"demo_bandage": 3, "demo_lamp": 1, "demo_token": 1}, "pickup_receipts": {},
	})
	assert(result.ok, "Invalid character preview fixture")
	return Service.new(state, {
		"name_key": "character.demo", "role_key": "character.role", "age": null,
		"condition_key": "character.condition_preview",
		"attributes": {"strength": 50, "dexterity": 50, "constitution": 50, "intelligence": 50, "perception": 50, "charisma": 50},
		"skills": {"spot": 40, "listen": null, "psychology": 40, "persuade": null, "first_aid": null},
		"background": {"beliefs": "dossier.pending", "people": "dossier.pending", "possessions": "dossier.pending", "experience": "dossier.pending"},
	}, {"damage": 10, "stress": 5, "supply_id": "demo_bandage"})

