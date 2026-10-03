extends RefCounted
## Implementations return the first visible collider under the player's aim.
const Outcome = preload("res://shared/result.gd")

func observe() -> Outcome:
	return Outcome.failure("NO_TARGET")

func bind_target(_collider: CollisionObject3D, _target_id: String) -> Outcome:
	return Outcome.failure("PROBE_NOT_MUTABLE")
