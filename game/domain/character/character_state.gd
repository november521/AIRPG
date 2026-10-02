extends RefCounted
## Prototype-only state; this is not the main game's save format.
const Result = preload("res://shared/result.gd")
const LIMIT: int = 999
var _state: Dictionary = {}
var _items: Dictionary = {}

func configure(items: Dictionary, initial: Dictionary) -> Result:
	if not _state.is_empty():
		return Result.failure("ALREADY_CONFIGURED")
	for id: Variant in items:
		if not id is String or id.is_empty() or not items[id] is Dictionary:
			return Result.failure("INVALID_DEFINITION")
		var item: Dictionary = items[id]
		if not _keys(item, ["name_key", "description_key", "kind", "healing", "protected"]):
			return Result.failure("INVALID_DEFINITION")
		if not item.name_key is String or not item.description_key is String:
			return Result.failure("INVALID_DEFINITION")
		if item.name_key.is_empty() or item.description_key.is_empty():
			return Result.failure("INVALID_DEFINITION")
		if item.kind not in ["consumable", "tool", "key"] or not item.protected is bool:
			return Result.failure("INVALID_DEFINITION")
		if not item.healing is int or item.healing < 0 or item.healing > LIMIT:
			return Result.failure("INVALID_DEFINITION")
		if item.kind != "consumable" and item.healing != 0:
			return Result.failure("INVALID_DEFINITION")
		if item.kind == "key" and not item.protected:
			return Result.failure("INVALID_DEFINITION")
	_items = items.duplicate(true)
	if not _valid(initial) or initial.revision != 0:
		_items.clear()
		return Result.failure("INVALID_STATE")
	_state = initial.duplicate(true)
	return Result.success(snapshot())

func snapshot() -> Dictionary:
	return _state.duplicate(true)

func definitions() -> Dictionary:
	return _items.duplicate(true)

func commit(expected_revision: int, candidate: Dictionary) -> Result:
	if _state.is_empty():
		return Result.failure("NOT_CONFIGURED")
	if expected_revision != _state.revision:
		return Result.failure("STALE_STATE")
	if not _valid(candidate) or candidate.revision != expected_revision:
		return Result.failure("INVALID_STATE")
	if candidate.hp_max != _state.hp_max or candidate.sanity_max != _state.sanity_max:
		return Result.failure("INVALID_STATE")
	if candidate == _state:
		return Result.failure("NO_CHANGE")
	var next: Dictionary = candidate.duplicate(true)
	next.revision += 1
	_state = next
	return Result.success(snapshot())

func _valid(value: Dictionary) -> bool:
	if not _keys(value, ["schema_version", "revision", "hp", "hp_max", "sanity", "sanity_max", "inventory"]):
		return false
	for key: String in ["schema_version", "revision", "hp", "hp_max", "sanity", "sanity_max"]:
		if not value[key] is int:
			return false
	if value.schema_version != 1 or value.revision < 0:
		return false
	if value.hp_max < 1 or value.hp_max > LIMIT or value.sanity_max < 1 or value.sanity_max > LIMIT:
		return false
	if value.hp < 0 or value.hp > value.hp_max or value.sanity < 0 or value.sanity > value.sanity_max:
		return false
	if not value.inventory is Dictionary:
		return false
	for id: Variant in value.inventory:
		if not id is String or not _items.has(id):
			return false
		var count: Variant = value.inventory[id]
		if not count is int or count < 1 or count > LIMIT:
			return false
	return true

func _keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true
