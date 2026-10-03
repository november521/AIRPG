extends "res://application/ports/pickup_inventory.gd"
const State = preload("res://domain/character/character_state.gd")
const Result = preload("res://shared/result.gd")
var _state: State
var _profile: Dictionary
var _preview_effects: Dictionary
var _initial: Dictionary
var _held_item: String = ""

func _init(state: State, profile: Dictionary, preview_effects: Dictionary) -> void:
	_state = state
	_profile = profile.duplicate(true)
	_preview_effects = preview_effects.duplicate(true)
	_initial = state.snapshot()

func read_character() -> Dictionary:
	var view: Dictionary = _state.snapshot()
	view["profile"] = _profile.duplicate(true)
	view["definitions"] = _state.definitions()
	view["held_item"] = _held_item
	return view

## 车卡确认后把档案写进只读 profile；只影响展示，不改领域状态。
func apply_created_profile(creation: Dictionary) -> Result:
	if not creation.get("locked", false):
		return Result.failure("INVALID_STATE")
	_profile["name"] = creation.name
	_profile["role"] = creation.role
	_profile["attributes"] = creation.attributes.duplicate(true)
	_profile["skills"] = creation.skills.duplicate(true)
	_profile["background_text"] = creation.background
	changed.emit()
	return Result.success()

func read_pickup(source_id: String) -> Dictionary:
	var view: Dictionary = _state.snapshot()
	return {"revision": view.revision, "claimed": view.pickup_receipts.has(source_id)}

func claim_pickup(source_id: String, item_id: String, quantity: int, expected_revision: int) -> Result:
	var candidate: Dictionary = _state.snapshot()
	if candidate.revision != expected_revision:
		return Result.failure("STALE_STATE")
	if not State.valid_source_id(source_id) or quantity < 1 or quantity > State.LIMIT:
		return Result.failure("INVALID_PICKUP")
	if candidate.pickup_receipts.has(source_id):
		return Result.failure("PICKUP_ALREADY_CLAIMED")
	if not _state.definitions().has(item_id):
		return Result.failure("ITEM_UNKNOWN")
	var total: int = candidate.inventory.get(item_id, 0) + quantity
	if total > State.LIMIT:
		return Result.failure("STACK_LIMIT")
	if candidate.pickup_receipts.size() >= State.RECEIPT_LIMIT:
		return Result.failure("PICKUP_LIMIT")
	candidate.inventory[item_id] = total
	candidate.pickup_receipts[source_id] = true
	# Receipt and quantity share one validated candidate; no disappearing-on-failure path.
	return _submit(expected_revision, candidate)

func use_item(id: String, expected_revision: int) -> Result:
	var candidate: Dictionary = _state.snapshot()
	if candidate.revision != expected_revision:
		return Result.failure("STALE_STATE")
	var items: Dictionary = _state.definitions()
	if not candidate.inventory.has(id):
		return Result.failure("ITEM_MISSING")
	if items[id].kind != "consumable" or items[id].healing <= 0:
		return Result.failure("NOT_USABLE")
	if candidate.hp >= candidate.hp_max:
		return Result.failure("HEALTH_FULL")
	candidate.hp = mini(candidate.hp_max, candidate.hp + items[id].healing)
	candidate.inventory[id] -= 1
	if candidate.inventory[id] == 0:
		candidate.inventory.erase(id)
	var was_held: bool = _held_item == id
	var result: Result = _submit(expected_revision, candidate)
	if result.ok and was_held and not candidate.inventory.has(id):
		_held_item = ""
		changed.emit()
	return result

func hold_item(id: String) -> Result:
	var view: Dictionary = _state.snapshot()
	if not view.inventory.has(id):
		return Result.failure("ITEM_MISSING")
	if not _state.definitions().has(id):
		return Result.failure("ITEM_UNKNOWN")
	if not _state.definitions()[id].equippable:
		return Result.failure("ITEM_NOT_EQUIPPABLE")
	_held_item = id
	changed.emit()
	return Result.success(read_character())

func equip_item(id: String) -> Result:
	return hold_item(id)

func release_item() -> Result:
	if _held_item.is_empty():
		return Result.failure("NO_HELD_ITEM")
	_held_item = ""
	changed.emit()
	return Result.success(read_character())

func unequip_item() -> Result:
	return release_item()

func drop_item(id: String, expected_revision: int) -> Result:
	var candidate: Dictionary = _state.snapshot()
	if candidate.revision != expected_revision:
		return Result.failure("STALE_STATE")
	if not candidate.inventory.has(id):
		return Result.failure("ITEM_MISSING")
	var items: Dictionary = _state.definitions()
	if not items[id].droppable:
		return Result.failure("ITEM_NOT_DROPPABLE")
	candidate.inventory[id] -= 1
	if candidate.inventory[id] == 0:
		candidate.inventory.erase(id)
	var result: Result = _submit(expected_revision, candidate)
	if result.ok and _held_item == id and not candidate.inventory.has(id):
		_held_item = ""
		changed.emit()
	return result

func use_held_item(expected_revision: int) -> Result:
	if _held_item.is_empty():
		return Result.failure("NO_HELD_ITEM")
	var result: Result = use_item(_held_item, expected_revision)
	return result

func discard_item(id: String, expected_revision: int) -> Result:
	var candidate: Dictionary = _state.snapshot()
	var items: Dictionary = _state.definitions()
	if candidate.revision != expected_revision:
		return Result.failure("STALE_STATE")
	if not candidate.inventory.has(id):
		return Result.failure("ITEM_MISSING")
	if items[id].protected:
		return Result.failure("ITEM_PROTECTED")
	candidate.inventory[id] -= 1
	if candidate.inventory[id] == 0:
		candidate.inventory.erase(id)
	var result: Result = _submit(expected_revision, candidate)
	if result.ok and not candidate.inventory.has(_held_item):
		_held_item = ""
		changed.emit()
	return result

func preview_action(action: String, expected_revision: int) -> Result:
	var candidate: Dictionary = _state.snapshot()
	if candidate.revision != expected_revision:
		return Result.failure("STALE_STATE")
	match action:
		"damage":
			candidate.hp = maxi(0, candidate.hp - _preview_effects.damage)
		"stress":
			candidate.sanity = maxi(0, candidate.sanity - _preview_effects.stress)
		"supply":
			var id: String = _preview_effects.supply_id
			candidate.inventory[id] = candidate.inventory.get(id, 0) + 1
		"reset":
			var receipts: Dictionary = candidate.pickup_receipts.duplicate(true)
			candidate = _initial.duplicate(true)
			candidate.revision = expected_revision
			candidate.pickup_receipts = receipts
		_:
			return Result.failure("UNKNOWN_ACTION")
	var result: Result = _submit(expected_revision, candidate)
	if result.ok and not candidate.inventory.has(_held_item):
		_held_item = ""
		changed.emit()
	return result

func _submit(expected_revision: int, candidate: Dictionary) -> Result:
	var result: Result = _state.commit(expected_revision, candidate)
	if result.ok:
		changed.emit()
	return result
