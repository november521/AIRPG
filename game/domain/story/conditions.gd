extends RefCounted
## v1 supports conjunctions of boolean flags only. Unknown conditions never pass.

static func matches(conditions: Array, flags: Dictionary) -> bool:
	for condition: Variant in conditions:
		if not condition is Dictionary or condition.size() != 2:
			return false
		if not condition.get("flag") is String or not condition.get("equals") is bool:
			return false
		if not flags.has(condition.flag) or not flags[condition.flag] is bool:
			return false
		if flags[condition.flag] != condition.equals:
			return false
	return true
