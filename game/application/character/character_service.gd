extends RefCounted
const State = preload("res://domain/character/character_state.gd")
const Result = preload("res://shared/result.gd")
signal changed()
var _state: State
var _profile: Dictionary
var _preview_effects: Dictionary
var _initial: Dictionary

func _init(state: State, profile: Dictionary, preview_effects: Dictionary) -> void:
	_state = state
	_profile = profile.duplicate(true)
	_preview_effects = preview_effects.duplicate(true)
	_initial = state.snapshot()

func read_character() -> Dictionary:
	var view: Dictionary = _state.snapshot()
	view["profile"] = _profile.duplicate(true)
	view["definitions"] = _state.definitions()
	return view

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
	return _submit(expected_revision, candidate)

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
	return _submit(expected_revision, candidate)

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
			candidate = _initial.duplicate(true)
			candidate.revision = expected_revision
		_:
			return Result.failure("UNKNOWN_ACTION")
	return _submit(expected_revision, candidate)

func _submit(expected_revision: int, candidate: Dictionary) -> Result:
	var result: Result = _state.commit(expected_revision, candidate)
	if result.ok:
		changed.emit()
	return result
