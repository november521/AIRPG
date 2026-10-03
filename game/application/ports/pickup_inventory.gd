extends RefCounted
const Outcome = preload("res://shared/result.gd")
signal changed()

func read_pickup(_source_id: String) -> Dictionary:
	return {}

func claim_pickup(_source_id: String, _item_id: String, _quantity: int, _revision: int) -> Outcome:
	return Outcome.failure("PICKUP_UNAVAILABLE")

## Read-only side of the same port: does the player currently carry this item? A container asks this
## before it opens, so the key or tool it accepts is never consumed by the question.
func holds(_item_id: String) -> bool:
	return false
