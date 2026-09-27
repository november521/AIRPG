extends RefCounted
## Application use case for the greybox exploration slice.
## It validates player intent through the frozen A1 ExplorationContract, resolves
## movement/range locally, and hands accepted commands to an injected sink.
## It never reads or writes StateStore and never advances story state.

const Result = preload("res://shared/result.gd")
const Contract = preload("res://application/contracts/exploration_contract.gd")
const World = preload("res://application/exploration/greybox_world.gd")
const Cooldown = preload("res://application/exploration/investigation_cooldown.gd")
const Sink = preload("res://application/exploration/exploration_request_sink.gd")

signal proximity_changed(candidate: Dictionary)
signal cooldown_changed(remaining: float, ready: bool)

const CODE_COOLDOWN_ACTIVE: String = "EXPLORATION_INVESTIGATE_COOLDOWN"
const CODE_REQUEST_REJECTED: String = "EXPLORATION_REQUEST_REJECTED"
const CODE_COOLDOWN_INVALID: String = "EXPLORATION_COOLDOWN_INVALID"
const CODE_SINK_INVALID: String = "EXPLORATION_SINK_INVALID"

var _world: World
var _cooldown: Cooldown
var _sink: Sink
var _axis: Vector2 = Vector2.ZERO
var _last_target: String = ""
var _last_ready: bool = true
var _last_tenths: int = 0

static func create(layout: Variant, sink: RefCounted, cooldown_seconds: float) -> RefCounted:
	var built := World.from_layout(layout)
	if not built.ok:
		return built
	if sink == null:
		return Result.failure(CODE_SINK_INVALID)
	if not is_finite(cooldown_seconds) or cooldown_seconds <= 0.0:
		return Result.failure(CODE_COOLDOWN_INVALID)
	var instance := new()
	instance._world = built.value
	instance._sink = sink
	instance._cooldown = Cooldown.new(cooldown_seconds)
	instance._last_ready = instance._cooldown.ready()
	instance._last_tenths = _tenths(instance._cooldown.remaining())
	return Result.success(instance)

func move(axis: Vector2) -> RefCounted:
	var validated := Contract.move(axis)
	if not validated.ok:
		return validated
	_axis = axis
	return validated

func advance(delta: float) -> void:
	_world.integrate(_axis, delta)
	_cooldown.tick(delta)
	_emit_candidate()
	_emit_cooldown()

func interact(target_id: String) -> RefCounted:
	var requested := Contract.interact(target_id)
	if not requested.ok:
		return requested
	var candidate := _world.candidate_for(target_id)
	if not candidate.ok:
		return candidate
	return _submit(requested)

func investigate() -> RefCounted:
	if not _cooldown.ready():
		return Result.failure(CODE_COOLDOWN_ACTIVE)
	var requested := Contract.investigate()
	if not requested.ok:
		return requested
	var submitted := _submit(requested)
	if not submitted.ok:
		return submitted
	_cooldown.start()
	_emit_cooldown()
	return requested

func nearest_candidate() -> RefCounted:
	return _world.nearest_candidate()

func candidate_for(target_id: String) -> RefCounted:
	return _world.candidate_for(target_id)

func player_position() -> Vector2:
	return _world.position()

func spawn() -> Vector2:
	return _world.spawn()

func player_half_extents() -> Vector2:
	return _world.half_extents()

func layout() -> Dictionary:
	return _world.layout()

func cooldown_remaining() -> float:
	return _cooldown.remaining()

func investigate_ready() -> bool:
	return _cooldown.ready()

func _submit(requested: RefCounted) -> RefCounted:
	var command: Dictionary = requested.value.duplicate(true)
	var submitted := _sink.submit(command)
	if not submitted.ok:
		return Result.failure(CODE_REQUEST_REJECTED, [submitted.code])
	return requested

func _emit_candidate() -> void:
	var candidate := _world.nearest_candidate()
	var target: String = "" if not candidate.ok else candidate.value.target_id
	if target == _last_target:
		return
	_last_target = target
	proximity_changed.emit(candidate.value.duplicate(true) if candidate.ok else {})

func _emit_cooldown() -> void:
	var remaining := _cooldown.remaining()
	var ready := _cooldown.ready()
	var tenths := _tenths(remaining)
	if ready == _last_ready and tenths == _last_tenths:
		return
	_last_ready = ready
	_last_tenths = tenths
	cooldown_changed.emit(remaining, ready)

static func _tenths(value: float) -> int:
	return int(round(value * 10.0))
