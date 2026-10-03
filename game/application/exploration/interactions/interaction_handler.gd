extends RefCounted
## Per-target use case. Register implementations at bootstrap, never in a global bus.
const Outcome = preload("res://shared/result.gd")
signal changed()

func read() -> Dictionary:
	return {"available": false}

func execute(_expected_revision: int) -> Outcome:
	return Outcome.failure("INTERACTION_UNAVAILABLE")

func dispose() -> void:
	pass
