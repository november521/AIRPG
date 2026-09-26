extends RefCounted
## Synthetic greybox movement, collision, interaction-range and line-of-sight model.
## Pure math on engine value types: no scene tree, no physics server, no dice,
## no story state. Layout data is synthetic and never enters a content pack.

const Result = preload("res://shared/result.gd")
const Contract = preload("res://application/contracts/exploration_contract.gd")

const CODE_LAYOUT_INVALID: String = "EXPLORATION_LAYOUT_INVALID"
const CODE_SPAWN_BLOCKED: String = "EXPLORATION_SPAWN_BLOCKED"
const CODE_UNKNOWN_TARGET: String = "EXPLORATION_UNKNOWN_TARGET"
const CODE_OUT_OF_RANGE: String = "EXPLORATION_TARGET_OUT_OF_RANGE"
const CODE_OCCLUDED: String = "EXPLORATION_TARGET_OCCLUDED"
const CODE_NO_CANDIDATE: String = "EXPLORATION_NO_CANDIDATE"

const _ROOT_KEYS: Array[String] = ["player", "walls", "interactables"]
const _PLAYER_KEYS: Array[String] = ["spawn", "half_extents", "speed"]
const _ITEM_KEYS: Array[String] = ["target_id", "prompt_key", "position", "radius",
	"solid_half_extents", "blocks_sight"]

var _spawn: Vector2 = Vector2.ZERO
var _position: Vector2 = Vector2.ZERO
var _half: Vector2 = Vector2(16.0, 16.0)
var _speed: float = 240.0
var _solids: Array[Dictionary] = []
var _interactables: Array[Dictionary] = []

static func from_layout(layout: Variant) -> RefCounted:
	if not layout is Dictionary:
		return Result.failure(CODE_LAYOUT_INVALID)
	var world := new()
	var error := world._configure(layout)
	if error != "":
		return Result.failure(error)
	return Result.success(world)

func position() -> Vector2:
	return _position

func spawn() -> Vector2:
	return _spawn

func half_extents() -> Vector2:
	return _half

func speed() -> float:
	return _speed

func integrate(axis: Vector2, delta: float) -> void:
	if not axis.is_finite() or not is_finite(delta) or delta <= 0.0:
		return
	var motion := axis.limit_length(1.0) * _speed * delta
	if not motion.is_finite():
		return
	if motion.x != 0.0:
		_position.x = _swept_x(_position.x, _position.x + motion.x)
	if motion.y != 0.0:
		_position.y = _swept_y(_position.y, _position.y + motion.y)

func candidate_for(target_id: String) -> RefCounted:
	var item := _find(target_id)
	if item.is_empty():
		return Result.failure(CODE_UNKNOWN_TARGET)
	var distance := _position.distance_to(item.position)
	if distance > item.radius:
		return Result.failure(CODE_OUT_OF_RANGE)
	if _occluded(item):
		return Result.failure(CODE_OCCLUDED)
	return Contract.candidate(item.target_id, item.prompt_key, distance)

func nearest_candidate() -> RefCounted:
	var best: Dictionary = {}
	var best_distance := INF
	for item: Dictionary in _interactables:
		var checked := candidate_for(item.target_id)
		if not checked.ok:
			continue
		var candidate: Dictionary = checked.value
		var better: bool = candidate.distance < best_distance
		if candidate.distance == best_distance and not best.is_empty():
			better = candidate.target_id < best.target_id
		if better:
			best = candidate
			best_distance = candidate.distance
	if best.is_empty():
		return Result.failure(CODE_NO_CANDIDATE)
	return Result.success(best)

func layout() -> Dictionary:
	var copy := {"player": {"spawn": _spawn, "half_extents": _half, "speed": _speed},
		"walls": [], "interactables": []}
	for solid: Dictionary in _solids:
		if solid.owner_id.is_empty():
			copy.walls.append(solid.rect)
	for item: Dictionary in _interactables:
		copy.interactables.append({"target_id": item.target_id, "prompt_key": item.prompt_key,
			"position": item.position, "radius": item.radius,
			"solid_half_extents": item.solid_half, "blocks_sight": item.sight})
	return copy

func _configure(layout: Dictionary) -> String:
	if not _known_keys(layout, _ROOT_KEYS):
		return CODE_LAYOUT_INVALID
	var player_error := _configure_player(layout.get("player"))
	if player_error != "":
		return player_error
	var wall_error := _configure_walls(layout.get("walls"))
	if wall_error != "":
		return wall_error
	var item_error := _configure_interactables(layout.get("interactables"))
	if item_error != "":
		return item_error
	for solid: Dictionary in _solids:
		if _player_rect(_spawn).intersects(solid.rect):
			return CODE_SPAWN_BLOCKED
	return ""

func _configure_player(value: Variant) -> String:
	if not value is Dictionary:
		return CODE_LAYOUT_INVALID
	if not _known_keys(value, _PLAYER_KEYS):
		return CODE_LAYOUT_INVALID
	for key: String in _PLAYER_KEYS:
		if not value.has(key):
			return CODE_LAYOUT_INVALID
	if not value.spawn is Vector2 or not value.half_extents is Vector2:
		return CODE_LAYOUT_INVALID
	if not value.spawn.is_finite() or not _positive(value.half_extents):
		return CODE_LAYOUT_INVALID
	if not (value.speed is float or value.speed is int):
		return CODE_LAYOUT_INVALID
	if not is_finite(value.speed) or value.speed <= 0.0:
		return CODE_LAYOUT_INVALID
	_spawn = value.spawn
	_position = _spawn
	_half = value.half_extents
	_speed = value.speed
	return ""

func _configure_walls(value: Variant) -> String:
	if value == null:
		return ""
	if not value is Array:
		return CODE_LAYOUT_INVALID
	for entry: Variant in value:
		if not entry is Rect2 or not _positive(entry.size):
			return CODE_LAYOUT_INVALID
		_solids.append({"rect": entry, "sight": true, "owner_id": ""})
	return ""

func _configure_interactables(value: Variant) -> String:
	if not value is Array:
		return CODE_LAYOUT_INVALID
	var seen: Dictionary = {}
	for entry: Variant in value:
		if not entry is Dictionary or not _exact_item_keys(entry):
			return CODE_LAYOUT_INVALID
		var item_error := _configure_item(entry, seen)
		if item_error != "":
			return item_error
	return ""

func _configure_item(entry: Dictionary, seen: Dictionary) -> String:
	var target_id: Variant = entry.get("target_id")
	var prompt_key: Variant = entry.get("prompt_key")
	if not target_id is String or not prompt_key is String:
		return CODE_LAYOUT_INVALID
	var item_position: Variant = entry.get("position")
	var radius: Variant = entry.get("radius")
	if not item_position is Vector2 or not item_position.is_finite():
		return CODE_LAYOUT_INVALID
	if not (radius is float or radius is int):
		return CODE_LAYOUT_INVALID
	if not is_finite(radius) or radius <= 0.0:
		return CODE_LAYOUT_INVALID
	if not Contract.candidate(target_id, prompt_key, 0.0).ok:
		return CODE_LAYOUT_INVALID
	if seen.has(target_id):
		return CODE_LAYOUT_INVALID
	seen[target_id] = true
	var half := Vector2.ZERO
	if entry.has("solid_half_extents"):
		if not entry.solid_half_extents is Vector2 or not _non_negative(entry.solid_half_extents):
			return CODE_LAYOUT_INVALID
		half = entry.solid_half_extents
	var sight := false
	if entry.has("blocks_sight"):
		if not entry.blocks_sight is bool:
			return CODE_LAYOUT_INVALID
		sight = entry.blocks_sight
	var item := {"target_id": target_id, "prompt_key": prompt_key,
		"position": item_position, "radius": radius, "solid_half": half, "sight": sight}
	_interactables.append(item)
	if half.x > 0.0 and half.y > 0.0:
		_solids.append({"rect": Rect2(item_position - half, half * 2.0), "sight": sight,
			"owner_id": target_id})
	return ""

func _exact_item_keys(entry: Dictionary) -> bool:
	return _known_keys(entry, _ITEM_KEYS)

func _known_keys(value: Dictionary, allowed: Array[String]) -> bool:
	for key: Variant in value.keys():
		if not key is String or key not in allowed:
			return false
	return true

func _find(target_id: String) -> Dictionary:
	for item: Dictionary in _interactables:
		if item.target_id == target_id:
			return item
	return {}

func _occluded(item: Dictionary) -> bool:
	for solid: Dictionary in _solids:
		if not solid.sight or solid.owner_id == item.target_id:
			continue
		if _segment_hits_rect(_position, item.position, solid.rect):
			return true
	return false

func _swept_x(from_x: float, to_x: float) -> float:
	if to_x > from_x:
		for solid: Dictionary in _solids:
			if not _overlaps_y(solid.rect):
				continue
			var limit: float = solid.rect.position.x - _half.x
			if from_x <= limit and to_x > limit:
				to_x = minf(to_x, limit)
	else:
		for solid: Dictionary in _solids:
			if not _overlaps_y(solid.rect):
				continue
			var limit: float = solid.rect.end.x + _half.x
			if from_x >= limit and to_x < limit:
				to_x = maxf(to_x, limit)
	return to_x

func _swept_y(from_y: float, to_y: float) -> float:
	if to_y > from_y:
		for solid: Dictionary in _solids:
			if not _overlaps_x(solid.rect):
				continue
			var limit: float = solid.rect.position.y - _half.y
			if from_y <= limit and to_y > limit:
				to_y = minf(to_y, limit)
	else:
		for solid: Dictionary in _solids:
			if not _overlaps_x(solid.rect):
				continue
			var limit: float = solid.rect.end.y + _half.y
			if from_y >= limit and to_y < limit:
				to_y = maxf(to_y, limit)
	return to_y

func _overlaps_x(rect: Rect2) -> bool:
	return _position.x - _half.x < rect.end.x and _position.x + _half.x > rect.position.x

func _overlaps_y(rect: Rect2) -> bool:
	return _position.y - _half.y < rect.end.y and _position.y + _half.y > rect.position.y

func _player_rect(center: Vector2) -> Rect2:
	return Rect2(center - _half, _half * 2.0)

func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	var delta := to - from
	var low := 0.0
	var high := 1.0
	var p := [-delta.x, delta.x, -delta.y, delta.y]
	var q := [from.x - rect.position.x, rect.end.x - from.x,
		from.y - rect.position.y, rect.end.y - from.y]
	for index: int in 4:
		if p[index] == 0.0:
			if q[index] < 0.0:
				return false
			continue
		var ratio: float = q[index] / p[index]
		if p[index] < 0.0:
			low = maxf(low, ratio)
		else:
			high = minf(high, ratio)
		if low > high:
			return false
	return true

func _positive(value: Vector2) -> bool:
	return value.is_finite() and value.x > 0.0 and value.y > 0.0

func _non_negative(value: Vector2) -> bool:
	return value.is_finite() and value.x >= 0.0 and value.y >= 0.0
