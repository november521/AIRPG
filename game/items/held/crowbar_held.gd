extends Node3D
## First-person presentation only. Gameplay ownership remains in CharacterService.

const REST_POSITION := Vector3(0.27, -0.16, -0.62)
const REST_ROTATION := Vector3(0.04, -0.08, -0.12)
const EQUIP_OFFSET := Vector3(0.08, -0.28, 0.12)
const EQUIP_DURATION: float = 0.24
const MOVEMENT_THRESHOLD: float = 0.08

var _player: CharacterBody3D
var _elapsed: float = 0.0
var _equip_elapsed: float = 0.0
var _movement_blend: float = 0.0

func _ready() -> void:
	_player = _find_player()
	position = REST_POSITION + EQUIP_OFFSET
	rotation = REST_ROTATION + Vector3(0.16, 0.0, 0.12)

func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_elapsed += delta
	_equip_elapsed = minf(EQUIP_DURATION, _equip_elapsed + delta)
	var speed: float = _horizontal_speed()
	var target_blend: float = clampf(speed / 3.2, 0.0, 1.0) if speed > MOVEMENT_THRESHOLD else 0.0
	_movement_blend = move_toward(_movement_blend, target_blend, delta * 5.5)
	var phase: float = _elapsed * lerpf(5.0, 9.0, _movement_blend)
	var breathing := Vector3(0.0, sin(_elapsed * 1.45) * 0.0035, 0.0)
	var bob := Vector3(sin(phase) * 0.008, absf(cos(phase)) * -0.012, 0.0) * _movement_blend
	var sway := Vector3(cos(phase) * 0.014, 0.0, sin(phase) * -0.018) * _movement_blend
	var equip_weight: float = _ease_out(_equip_elapsed / EQUIP_DURATION)
	position = (REST_POSITION + breathing + bob).lerp(REST_POSITION + EQUIP_OFFSET, 1.0 - equip_weight)
	rotation = (REST_ROTATION + sway).lerp(REST_ROTATION + Vector3(0.16, 0.0, 0.12), 1.0 - equip_weight)

func presentation_state() -> String:
	if _equip_elapsed < EQUIP_DURATION:
		return "equipping"
	return "moving" if _movement_blend > 0.05 else "idle"

func _horizontal_speed() -> float:
	if not is_instance_valid(_player):
		return 0.0
	return Vector2(_player.velocity.x, _player.velocity.z).length()

func _find_player() -> CharacterBody3D:
	var current: Node = get_parent()
	while current != null:
		if current is CharacterBody3D:
			return current as CharacterBody3D
		current = current.get_parent()
	return null

func _ease_out(value: float) -> float:
	var clamped: float = clampf(value, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped, 3.0)
