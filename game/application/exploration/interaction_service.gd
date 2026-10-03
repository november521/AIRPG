extends RefCounted
const Result = preload("res://shared/result.gd")
const Contract = preload("res://application/contracts/exploration_contract.gd")
const Probe = preload("res://application/ports/interaction_probe.gd")
const Handler = preload("res://application/exploration/interactions/interaction_handler.gd")
var _probe: Probe
var _reach: float
var _handlers: Dictionary = {}
var _focus: Dictionary = {}
var _enabled: bool = false
var _executing: bool = false
var _sealed: bool = false
var _closed: bool = false

func _init(probe: Probe, reach: float) -> void:
	_probe = probe
	_reach = reach

func register_target(id: String, handler: Handler) -> Result:
	if _sealed or not Contract.interact(id).ok or handler == null or _handlers.has(id):
		return Result.failure("INVALID_INTERACTION_REGISTRATION")
	_handlers[id] = handler
	return Result.success()

func register_runtime_target(id: String, handler: Handler, collider: CollisionObject3D) -> Result:
	if _closed or not Contract.interact(id).ok or handler == null or collider == null or _handlers.has(id):
		return Result.failure("INVALID_INTERACTION_REGISTRATION")
	var probe_result: Result = _probe.bind_target(collider, id)
	if not probe_result.ok:
		return probe_result
	_handlers[id] = handler
	return Result.success()

func set_enabled(enabled: bool) -> void:
	_sealed = true
	_enabled = enabled and not _closed
	if not _enabled:
		_focus.clear()

func close() -> void:
	set_enabled(false)
	_closed = true
	for handler: Handler in _handlers.values():
		handler.dispose()
	_handlers.clear()
	_probe = null

func refresh_focus() -> void:
	_focus.clear()
	if not _enabled:
		return
	var observation: Result = _observe()
	if not observation.ok:
		return
	var id: String = observation.value.target_id
	var view: Dictionary = _handlers[id].read()
	if not view.get("available", false):
		return
	_focus = view.duplicate(true)
	_focus["target_id"] = id
	_focus["distance"] = observation.value.distance

func read_focus() -> Dictionary:
	return _focus.duplicate(true)

func interact(target_id: String, expected_revision: int) -> Result:
	if not _enabled:
		return Result.failure("INTERACTION_DISABLED")
	if _executing:
		return Result.failure("INTERACTION_BUSY")
	if not Contract.interact(target_id).ok or not _handlers.has(target_id):
		return Result.failure("UNKNOWN_TARGET")
	# Requery physics when executing; a UI hint never authorizes a stale target.
	var observed: Result = _observe()
	if not observed.ok:
		return observed
	if observed.value.target_id != target_id:
		return Result.failure("TARGET_CHANGED")
	var handler: Handler = _handlers[target_id]
	if not handler.read().get("available", false):
		return Result.failure("TARGET_UNAVAILABLE")
	_executing = true
	var result: Result = handler.execute(expected_revision)
	_executing = false
	refresh_focus()
	return result

## The target that currently owns the player's action, or {} when none does. An exclusive target
## freezes movement and takes the interact key without the aim ray hitting anything, so the HUD can
## always offer the way out. Handlers keep registration order, so the answer is deterministic.
func read_exclusive() -> Dictionary:
	if not _enabled or _closed:
		return {}
	for id: String in _handlers:
		var handler: Handler = _handlers[id]
		if handler.exclusive():
			var view: Dictionary = handler.read().duplicate(true)
			view["target_id"] = id
			return view
	return {}

## Interact with the exclusive target. This is deliberately the one path that skips _observe():
## the player is already holding the object, so demanding that the aim ray land on its world target
## is exactly the trap this replaces. Every other guard still applies.
func interact_exclusive(expected_revision: int) -> Result:
	if not _enabled:
		return Result.failure("INTERACTION_DISABLED")
	if _executing:
		return Result.failure("INTERACTION_BUSY")
	for id: String in _handlers:
		var handler: Handler = _handlers[id]
		if not handler.exclusive():
			continue
		if not handler.read().get("available", false):
			return Result.failure("TARGET_UNAVAILABLE")
		_executing = true
		var result: Result = handler.execute(expected_revision)
		_executing = false
		refresh_focus()
		return result
	return Result.failure("UNKNOWN_TARGET")

func _observe() -> Result:
	if not is_finite(_reach) or _reach <= 0:
		return Result.failure("INVALID_INTERACTION_RANGE")
	var observed: Result = _probe.observe()
	if not observed.ok:
		return observed
	if not observed.value is Dictionary:
		return Result.failure("INVALID_TARGET_OBSERVATION")
	var hit: Dictionary = observed.value
	if hit.size() != 2 or not hit.get("target_id") is String:
		return Result.failure("INVALID_TARGET_OBSERVATION")
	if not hit.get("distance") is float and not hit.get("distance") is int:
		return Result.failure("INVALID_TARGET_OBSERVATION")
	var distance: float = hit.distance
	if not is_finite(distance) or distance < 0 or distance > _reach:
		return Result.failure("TARGET_OUT_OF_RANGE")
	if not _handlers.has(hit.target_id):
		return Result.failure("UNKNOWN_TARGET")
	return observed
