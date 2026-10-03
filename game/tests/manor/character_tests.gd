extends RefCounted
const Preview = preload("res://bootstrap/character_preview.gd")
const State = preload("res://domain/character/character_state.gd")
const Service = preload("res://application/character/character_service.gd")
var checks: int = 0
var failures: int = 0
var _external: Callable

func _check(value: bool, description: String) -> void:
	checks += 1
	if _external.is_valid():
		_external.call(value, description)
	if not value:
		failures += 1
		push_error("FAIL: " + description)

func run(verify: Callable = Callable()) -> Dictionary:
	_external = verify
	var service: Service = Preview.build()
	var before: Dictionary = service.read_character()
	_check(before.hp == 70 and before.inventory.demo_bandage == 3, "preview initial state")
	before.inventory.demo_bandage = 999
	before.profile.name_key = "changed"
	before.profile.attributes.strength = 999
	before.definitions.demo_bandage.healing = 999
	_check(service.read_character().inventory.demo_bandage == 3, "inventory snapshot isolated")
	_check(service.read_character().profile.name_key == "character.demo", "profile snapshot isolated")
	_check(service.read_character().profile.attributes.strength == 50, "nested attribute snapshot isolated")
	_check(service.use_item("demo_bandage", 0).ok, "use succeeds")
	var after: Dictionary = service.read_character()
	_check(after.hp == 85 and after.inventory.demo_bandage == 2 and after.revision == 1, "heal and consumption atomic")
	_check(not service.use_item("demo_bandage", 0).ok, "stale duplicate rejected")
	_check(service.read_character() == after, "stale duplicate leaves state intact")
	_check(service.use_item("demo_bandage", 1).ok, "heal up to maximum")
	after = service.read_character()
	_check(after.hp == 100 and after.inventory.demo_bandage == 1, "healing definition isolated")
	_check(service.use_item("demo_bandage", 2).code == "HEALTH_FULL", "full health rejected")
	_check(service.read_character() == after, "full health does not consume")
	_check(service.discard_item("demo_token", 2).code == "ITEM_PROTECTED", "key item protected")
	_check(service.use_item("demo_lamp", 2).code == "NOT_USABLE", "tool does not pretend to function")
	_check(service.use_item("unknown", 2).code == "ITEM_MISSING", "unknown item rejected")
	_check(service.preview_action("unknown", 2).code == "UNKNOWN_ACTION", "unknown command rejected")
	_check(service.read_character() == after, "failed actions do not advance revision")
	service.discard_item("demo_bandage", 2)
	_check(not service.read_character().inventory.has("demo_bandage"), "empty stack removed")
	_check(service.use_item("demo_bandage", 3).code == "ITEM_MISSING", "empty stack cannot consume")
	service.preview_action("supply", 3)
	_check(service.read_character().inventory.demo_bandage == 1, "acquire item")
	service.preview_action("damage", 4)
	_check(service.read_character().hp == 90, "preview damage")
	service.preview_action("stress", 5)
	_check(service.read_character().sanity == 55, "preview sanity")
	service.preview_action("reset", 6)
	after = service.read_character()
	_check(after.hp == 70 and after.inventory.demo_bandage == 3 and after.revision == 7, "reset keeps monotonic revision")
	var urn_revision: int = after.revision
	_check(service.claim_pickup("manor.pickup.silver_urn", "silver_urn", 1, urn_revision).ok, "urn pickup commits")
	urn_revision = service.read_character().revision
	_check(service.read_character().inventory.silver_urn == 1, "urn enters the notebook")
	_check(service.discard_item("silver_urn", urn_revision).code == "ITEM_PROTECTED", "urn is a protected key item")
	_check(service.drop_item("silver_urn", urn_revision).code == "ITEM_NOT_DROPPABLE", "urn cannot be dropped")
	_check(service.use_item("silver_urn", urn_revision).code == "NOT_USABLE", "urn has no consume effect")
	_check(service.hold_item("silver_urn").ok, "urn can be held")
	_check(service.read_character().held_item == "silver_urn", "urn becomes the held item")
	_check(service.read_character().revision == urn_revision, "urn refusals and hold do not advance revision")
	_check(service.read_character().definitions.silver_urn.held_scene != null, "urn exposes a held scene")
	var diary_revision: int = service.read_character().revision
	_check(service.claim_pickup("manor.pickup.doctor_diary", "doctor_diary", 1, diary_revision).ok, "diary pickup commits")
	diary_revision = service.read_character().revision
	_check(service.read_character().inventory.doctor_diary == 1, "diary enters the notebook")
	_check(service.discard_item("doctor_diary", diary_revision).code == "ITEM_PROTECTED", "diary is a protected key item")
	_check(service.drop_item("doctor_diary", diary_revision).code == "ITEM_NOT_DROPPABLE", "diary cannot be dropped")
	_check(service.use_item("doctor_diary", diary_revision).code == "NOT_USABLE", "diary has no consume effect")
	_check(service.hold_item("doctor_diary").ok, "diary can be held")
	_check(service.read_character().definitions.doctor_diary.held_scene != null, "diary exposes a held scene")
	_check(service.read_character().revision == diary_revision, "diary refusals and hold do not advance revision")
	var wallet_revision: int = service.read_character().revision
	_check(service.claim_pickup("manor.pickup.wallet", "wallet", 1, wallet_revision).ok, "wallet pickup commits")
	wallet_revision = service.read_character().revision
	_check(service.read_character().inventory.wallet == 1, "wallet enters the notebook")
	_check(service.discard_item("wallet", wallet_revision).code == "ITEM_PROTECTED", "wallet is a protected key item")
	_check(service.drop_item("wallet", wallet_revision).code == "ITEM_NOT_DROPPABLE", "wallet cannot be dropped")
	_check(service.use_item("wallet", wallet_revision).code == "NOT_USABLE", "wallet has no consume effect")
	_check(service.hold_item("wallet").ok, "wallet can be held")
	_check(service.read_character().definitions.wallet.held_scene != null, "wallet exposes a held scene")
	_check(service.read_character().revision == wallet_revision, "wallet refusals and hold do not advance revision")
	var kerosene_revision: int = service.read_character().revision
	_check(service.claim_pickup("manor.pickup.kerosene_bottle", "kerosene_bottle", 1, kerosene_revision).ok, "kerosene bottle pickup commits")
	kerosene_revision = service.read_character().revision
	_check(service.read_character().inventory.kerosene_bottle == 1, "kerosene bottle enters the notebook")
	_check(service.use_item("kerosene_bottle", kerosene_revision).code == "NOT_USABLE", "kerosene bottle has no invented fuel effect")
	_check(service.hold_item("kerosene_bottle").ok, "kerosene bottle can be held")
	_check(service.read_character().definitions.kerosene_bottle.kind == "tool", "kerosene bottle is classified as a tool")
	_check(service.read_character().definitions.kerosene_bottle.droppable, "kerosene bottle can be dropped")
	_check(service.read_character().definitions.kerosene_bottle.held_scene != null, "kerosene bottle exposes a held scene")
	var key_revision: int = service.read_character().revision
	_check(service.claim_pickup("manor.pickup.manor_key", "manor_key", 1, key_revision).ok, "manor key pickup commits")
	key_revision = service.read_character().revision
	_check(service.read_character().inventory.manor_key == 1, "manor key enters the notebook")
	_check(service.discard_item("manor_key", key_revision).code == "ITEM_PROTECTED", "manor key is protected")
	_check(service.use_item("manor_key", key_revision).code == "NOT_USABLE", "manor key has no invented lock binding")
	_check(service.hold_item("manor_key").ok, "manor key can be held")
	var fuse_revision: int = service.read_character().revision
	_check(service.claim_pickup("manor.pickup.fuse", "fuse", 1, fuse_revision).ok, "fuse pickup commits")
	fuse_revision = service.read_character().revision
	_check(service.read_character().inventory.fuse == 1, "fuse enters the notebook")
	_check(service.discard_item("fuse", fuse_revision).code == "ITEM_PROTECTED", "fuse is protected")
	_check(service.use_item("fuse", fuse_revision).code == "NOT_USABLE", "fuse has no invented repair effect")
	_check(service.hold_item("fuse").ok, "fuse can be held")
	var coil_revision: int = service.read_character().revision
	_check(service.claim_pickup("manor.pickup.copper_wire_coil", "copper_wire_coil", 1, coil_revision).ok, "copper wire coil pickup commits")
	coil_revision = service.read_character().revision
	_check(service.read_character().inventory.copper_wire_coil == 1, "copper wire coil enters the notebook")
	_check(service.discard_item("copper_wire_coil", coil_revision).code == "ITEM_PROTECTED", "copper wire coil is protected")
	_check(service.drop_item("copper_wire_coil", coil_revision).code == "ITEM_NOT_DROPPABLE", "copper wire coil cannot be dropped")
	_check(service.use_item("copper_wire_coil", coil_revision).code == "NOT_USABLE", "copper wire coil has no invented wiring effect")
	_check(service.hold_item("copper_wire_coil").ok, "copper wire coil can be held")
	_check(service.read_character().definitions.copper_wire_coil.held_scene != null, "copper wire coil exposes a held scene")
	_check(service.read_character().revision == coil_revision, "copper wire coil refusals and hold do not advance revision")
	var tape_revision: int = service.read_character().revision
	_check(service.claim_pickup("manor.pickup.electrical_tape", "electrical_tape", 1, tape_revision).ok, "electrical tape pickup commits")
	tape_revision = service.read_character().revision
	_check(service.read_character().inventory.electrical_tape == 1, "electrical tape enters the notebook")
	_check(service.discard_item("electrical_tape", tape_revision).code == "ITEM_PROTECTED", "electrical tape is a protected electrical part")
	_check(service.drop_item("electrical_tape", tape_revision).code == "ITEM_NOT_DROPPABLE", "electrical tape cannot be dropped")
	_check(service.hold_item("electrical_tape").ok, "electrical tape can be held")
	_check(service.read_character().revision == tape_revision, "electrical tape refusals and hold do not advance revision")
	var wrench_revision: int = service.read_character().revision
	_check(service.claim_pickup("manor.pickup.wrench", "wrench", 1, wrench_revision).ok, "wrench pickup commits")
	wrench_revision = service.read_character().revision
	_check(service.read_character().definitions.wrench.kind == "tool", "wrench is classified as a tool")
	_check(service.hold_item("wrench").ok, "wrench can be held")
	_check(service.drop_item("wrench", wrench_revision).ok, "wrench can be dropped")
	_check(not service.read_character().inventory.has("wrench"), "dropped wrench leaves the notebook")
	var lantern_revision: int = service.read_character().revision
	_check(service.claim_pickup("manor.pickup.lantern", "lantern", 1, lantern_revision).ok, "lantern pickup commits")
	lantern_revision = service.read_character().revision
	_check(service.read_character().definitions.lantern.tags.has(&"light_source"), "lantern carries the light_source tag")
	_check(service.hold_item("lantern").ok, "lantern can be held")
	_check(service.drop_item("lantern", lantern_revision).ok, "lantern can be dropped")
	_check(not service.read_character().inventory.has("lantern"), "dropped lantern leaves the notebook")
	var radio_revision: int = service.read_character().revision
	_check(service.claim_pickup("manor.pickup.radio", "radio", 1, radio_revision).ok, "radio pickup commits")
	radio_revision = service.read_character().revision
	_check(service.read_character().inventory.radio == 1, "radio enters the notebook")
	_check(service.hold_item("radio").ok, "radio can be held")
	_check(service.read_character().definitions.radio.held_scene != null, "radio exposes a held scene")
	_check(service.drop_item("radio", radio_revision).ok, "radio can be dropped")
	_check(not service.read_character().inventory.has("radio"), "dropped radio leaves the notebook")
	var other: Service = Preview.build()
	_check(other.read_character().revision == 0, "sessions isolated")
	var state := State.new()
	var initial: Dictionary = other.read_character()
	initial.erase("profile")
	initial.erase("definitions")
	initial.erase("held_item")
	_check(state.configure(other.read_character().definitions, initial).ok, "domain configure")
	var candidate: Dictionary = state.snapshot()
	candidate.hp = 85
	candidate.inventory.demo_bandage = -1
	_check(not state.commit(0, candidate).ok, "invalid inventory rejects combined heal")
	_check(state.snapshot() == initial, "invalid combined change rolls back")
	candidate = state.snapshot()
	candidate.hp = -1
	_check(not state.commit(0, candidate).ok, "negative hp rejected")
	candidate = state.snapshot()
	candidate.sanity = 101
	_check(not state.commit(0, candidate).ok, "sanity over maximum rejected")
	candidate = state.snapshot()
	candidate.inventory.demo_bandage = true
	_check(not state.commit(0, candidate).ok, "boolean quantity rejected")
	candidate = state.snapshot()
	candidate.inventory.unknown = 1
	_check(not state.commit(0, candidate).ok, "unknown item ID rejected")
	candidate = state.snapshot()
	candidate.schema_version = 99
	_check(not state.commit(0, candidate).ok, "unknown state version rejected")
	candidate = state.snapshot()
	candidate.unexpected = 1
	_check(not state.commit(0, candidate).ok, "unknown field rejected")
	candidate = state.snapshot()
	candidate.hp_max = 200
	_check(not state.commit(0, candidate).ok, "maxima immutable during item transaction")
	candidate = state.snapshot()
	candidate.inventory.demo_bandage = 1000
	_check(not state.commit(0, candidate).ok, "stack limit rejects overflow")
	_check(state.snapshot() == initial, "all invalid candidates preserve state")
	var overflow := Service.new(state, {}, {"damage": 10, "stress": 5, "supply_id": "demo_bandage"})
	candidate = state.snapshot()
	candidate.inventory.demo_bandage = 999
	state.commit(0, candidate)
	before = state.snapshot()
	_check(not overflow.preview_action("supply", 1).ok and state.snapshot() == before, "supply overflow atomic")
	for index: int in 11:
		var view: Dictionary = overflow.read_character()
		overflow.preview_action("damage", view.revision)
	_check(overflow.read_character().hp == 0, "damage bounded at zero")
	print("AIRPG_CHARACTER_TESTS: %d checks, %d failures" % [checks, failures])
	return {"checks": checks, "failures": failures}
