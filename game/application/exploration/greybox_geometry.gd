extends RefCounted
## Pure geometry helpers for the synthetic greybox model.
## Static value functions only: no state, no scene tree, no engine I/O.

static func player_rect(center: Vector2, half: Vector2) -> Rect2:
	return Rect2(center - half, half * 2.0)

static func positive_extents(value: Vector2) -> bool:
	return value.is_finite() and value.x > 0.0 and value.y > 0.0

static func non_negative_extents(value: Vector2) -> bool:
	return value.is_finite() and value.x >= 0.0 and value.y >= 0.0

static func segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	var delta := to - from
	var low := 0.0
	var high := 1.0
	var p := [-delta.x, delta.x, -delta.y, delta.y]
	var q := [from.x - rect.position.x, rect.end.x - from.x,
		from.y - rect.position.y, rect.end.y - from.y]
	for index: int in 4:
		if p[index] == 0.0:
			if q[index] < 0.0:
				return false
			continue
		var ratio: float = q[index] / p[index]
		if p[index] < 0.0:
			low = maxf(low, ratio)
		else:
			high = minf(high, ratio)
		if low > high:
			return false
	return true
