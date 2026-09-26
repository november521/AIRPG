extends RefCounted
## Synthetic greybox movement, collision, interaction-range and line-of-sight model.
## Pure math on engine value types: no scene tree, no physics server, no dice,
## no story state. Layout data is synthetic and never enters a content pack.

const Result = preload("res://shared/result.gd")
const Contract = preload("res://application/contracts/exploration_contract.gd")
const Geometry = preload("res://application/exploration/greybox_geometry.gd")

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

const MAX_SLIDE_PASSES: int = 8
const CONTACT_EPSILON: float = 1e-9

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
	var remaining := axis.limit_length(1.0) * _speed * delta
	if not remaining.is_finite() or remaining.is_zero_approx():
		return
	for _pass in MAX_SLIDE_PASSES:
		var hit := _earliest_hit(_position, remaining)
		if hit.is_empty():
			_position += remaining
			return
		var impact: float = hit.t
		var target := _position + remaining * impact
		if hit.contact.has(0):
			target.x = hit.contact[0]
		if hit.contact.has(1):
			target.y = hit.contact[1]
		_position = target
		var left := remaining * (1.0 - impact)
		if hit.axis == 0:
			left.x = 0.0
		else:
			left.y = 0.0
		if left.is_zero_approx():
			return
		remaining = left

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
	if not value.spawn.is_finite() or not Geometry.positive_extents(value.half_extents):
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
		if not entry is Rect2 or not Geometry.positive_extents(entry.size):
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
		if not entry.solid_half_extents is Vector2 or not Geometry.non_negative_extents(entry.solid_half_extents):
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
		if Geometry.segment_hits_rect(_position, item.position, solid.rect):
			return true
	return false

func _earliest_hit(origin: Vector2, motion: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_time := INF
	for solid: Dictionary in _solids:
		var hit := _slab_hit(origin, motion, solid.rect)
		if not hit.is_empty() and hit.t < best_time:
			best = hit
			best_time = hit.t
	return best

func _slab_hit(origin: Vector2, motion: Vector2, rect: Rect2) -> Dictionary:
	var low := rect.position - _half
	var high := rect.end + _half
	var x := _axis_slab(origin.x, motion.x, low.x, high.x)
	if not x.ok:
		return {}
	var y := _axis_slab(origin.y, motion.y, low.y, high.y)
	if not y.ok:
		return {}
	var enter := maxf(x.enter, y.enter)
	var exit := minf(x.exit, y.exit)
	if enter > exit:
		return {}
	if enter < 0.0:
		if exit <= 0.0:
			return {}
		enter = 0.0
	if enter > 1.0:
		return {}
	var contact: Dictionary = {}
	if x.enter >= enter - CONTACT_EPSILON:
		contact[0] = _contact_point(motion.x, origin.x, low.x, high.x)
	if y.enter >= enter - CONTACT_EPSILON:
		contact[1] = _contact_point(motion.y, origin.y, low.y, high.y)
	return {"t": enter, "axis": 0 if x.enter >= y.enter else 1, "contact": contact}

func _axis_slab(origin: float, motion: float, low: float, high: float) -> Dictionary:
	if motion == 0.0:
		return {"ok": origin > low and origin < high, "enter": -INF, "exit": INF}
	var inverse := 1.0 / motion
	var first := (low - origin) * inverse
	var second := (high - origin) * inverse
	return {"ok": true, "enter": minf(first, second), "exit": maxf(first, second)}

func _contact_point(motion: float, origin: float, low: float, high: float) -> float:
	if motion > 0.0:
		return low
	if motion < 0.0:
		return high
	return origin

func _player_rect(center: Vector2) -> Rect2:
	return Geometry.player_rect(center, _half)
