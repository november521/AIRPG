extends RefCounted
## Scene-local investigation cooldown. The clock advances by explicit delta ticks so the
## greybox stays deterministic in tests; no wall-clock API is read here.

var _duration: float = 0.0
var _remaining: float = 0.0

func _init(duration: float) -> void:
	if is_finite(duration) and duration > 0.0:
		_duration = duration

func is_valid() -> bool:
	return _duration > 0.0

func ready() -> bool:
	return _remaining <= 0.0

func start() -> void:
	if is_valid():
		_remaining = _duration

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or _remaining <= 0.0:
		return
	_remaining = maxf(0.0, _remaining - delta)

func remaining() -> float:
	return _remaining

func duration() -> float:
	return _duration
