extends RefCounted
## Synthetic fixture, never an official investigator or gameplay formula.
const State = preload("res://domain/character/character_state.gd")
const Service = preload("res://application/character/character_service.gd")
const Crowbar = preload("res://items/data/crowbar.tres")
const SilverUrn = preload("res://items/data/silver_urn.tres")
const DoctorDiary = preload("res://items/data/doctor_diary.tres")
const Wallet = preload("res://items/data/wallet.tres")
const KeroseneBottle = preload("res://items/data/kerosene_bottle.tres")
const ManorKey = preload("res://items/data/manor_key.tres")
const Fuse = preload("res://items/data/fuse.tres")
const CopperWireCoil = preload("res://items/data/copper_wire_coil.tres")
const Wrench = preload("res://items/data/wrench.tres")
const ElectricalTape = preload("res://items/data/electrical_tape.tres")
const Lantern = preload("res://items/data/lantern.tres")
const Radio = preload("res://items/data/radio.tres")
const WorldItem = preload("res://items/world/world_item.tscn")
const HeldItem = preload("res://items/held/crowbar_held.tscn")

static func _definition(name_key: String, description_key: String, kind: String, equippable: bool, droppable: bool, tags: Array[StringName], healing: int = 0) -> Dictionary:
	return {"name_key": name_key, "description_key": description_key, "kind": kind, "healing": healing,
		"protected": not droppable, "equippable": equippable, "droppable": droppable, "tags": tags,
		"world_scene": WorldItem, "held_scene": HeldItem if equippable else null,
		"stackable": true, "max_stack": 999, "weight": 0.0}

static func _item_definition(item: Resource, kind: String) -> Dictionary:
	var value: Dictionary = item.to_runtime_view()
	value["kind"] = kind
	value["healing"] = 0
	value["protected"] = not value.droppable
	value.erase("id")
	return value

static func _crowbar_definition() -> Dictionary:
	return _item_definition(Crowbar, "tool")

static func _urn_definition() -> Dictionary:
	return _item_definition(SilverUrn, "key")

static func _diary_definition() -> Dictionary:
	return _item_definition(DoctorDiary, "key")

static func _wallet_definition() -> Dictionary:
	return _item_definition(Wallet, "key")

static func _kerosene_bottle_definition() -> Dictionary:
	return _item_definition(KeroseneBottle, "tool")

static func _manor_key_definition() -> Dictionary:
	return _item_definition(ManorKey, "key")

static func _fuse_definition() -> Dictionary:
	return _item_definition(Fuse, "key")

static func _copper_wire_coil_definition() -> Dictionary:
	return _item_definition(CopperWireCoil, "key")

static func _wrench_definition() -> Dictionary:
	return _item_definition(Wrench, "tool")

static func _electrical_tape_definition() -> Dictionary:
	return _item_definition(ElectricalTape, "key")

static func _lantern_definition() -> Dictionary:
	return _item_definition(Lantern, "tool")

static func _radio_definition() -> Dictionary:
	return _item_definition(Radio, "tool")

static func build() -> Service:
	var state := State.new()
	var result = state.configure({
		"demo_bandage": _definition("item.bandage", "item.bandage.desc", "consumable", false, true, [&"heal"], 15),
		"demo_lamp": _definition("item.lamp", "item.lamp.desc", "tool", true, true, [&"light_source"]),
		"demo_token": _definition("item.token", "item.token.desc", "key", true, false, [&"quest_item"]),
		"crowbar": _crowbar_definition(),
		"silver_urn": _urn_definition(),
		"doctor_diary": _diary_definition(),
		"wallet": _wallet_definition(),
		"kerosene_bottle": _kerosene_bottle_definition(),
		"manor_key": _manor_key_definition(),
		"fuse": _fuse_definition(),
		"copper_wire_coil": _copper_wire_coil_definition(),
		"wrench": _wrench_definition(),
		"electrical_tape": _electrical_tape_definition(),
		"lantern": _lantern_definition(),
		"radio": _radio_definition(),
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

