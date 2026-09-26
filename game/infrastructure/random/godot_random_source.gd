extends "res://application/ports/random_source.gd"
## Separate instance per session. Captures 64-bit integers as decimal strings for JSON safety.
var _rng := RandomNumberGenerator.new()

func _init(fixed_seed: Variant = null) -> void:
	if fixed_seed is int:
		_rng.seed = fixed_seed
	else:
		_rng.randomize()

func roll(sides: int) -> RefCounted:
	if sides < 2 or sides > 1000000:
		return Result.failure("INVALID_DIE")
	return Result.success(_rng.randi_range(1, sides))

func capture() -> Dictionary:
	return {"algorithm": "godot-4.7.2-pcg", "seed": str(_rng.seed), "state": str(_rng.state)}

func restore(checkpoint: Dictionary) -> RefCounted:
	if checkpoint.size() != 3 or checkpoint.get("algorithm") != "godot-4.7.2-pcg":
		return Result.failure("RNG_INCOMPATIBLE")
	for field: String in ["seed", "state"]:
		var value: Variant = checkpoint.get(field)
		if not value is String or not _is_int64(value):
			return Result.failure("RNG_INVALID")
	_rng.seed = checkpoint.seed.to_int()
	_rng.state = checkpoint.state.to_int()
	return Result.success()

static func _is_int64(value: String) -> bool:
	if not value.is_valid_int() or value.begins_with("+"):
		return false
	var digits := value.substr(1) if value.begins_with("-") else value
	var limit := "9223372036854775808" if value.begins_with("-") else "9223372036854775807"
	if digits.length() > 19 or (digits.length() == 19 and digits > limit):
		return false
	return str(value.to_int()) == value
