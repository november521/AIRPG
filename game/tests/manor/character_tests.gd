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
	var other: Service = Preview.build()
	_check(other.read_character().revision == 0, "sessions isolated")
	var state := State.new()
	var initial: Dictionary = other.read_character()
	initial.erase("profile")
	initial.erase("definitions")
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
	candidate.schema_version = 2
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

