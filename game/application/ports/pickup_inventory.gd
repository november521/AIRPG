extends RefCounted
const Outcome = preload("res://shared/result.gd")
signal changed()

func read_pickup(_source_id: String) -> Dictionary:
	return {}

func claim_pickup(_source_id: String, _item_id: String, _quantity: int, _revision: int) -> Outcome:
	return Outcome.failure("PICKUP_UNAVAILABLE")
