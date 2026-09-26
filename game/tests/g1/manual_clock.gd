extends "res://infrastructure/ai/clock_port.gd"
## Deterministic clock for timeout tests: nothing fires until the test asks. Test-only.

var _entries: Array = []
var _next_id: int = 1

func schedule(delay_seconds: float, callback: Callable) -> Variant:
	var entry := {
		"id": _next_id,
		"delay": delay_seconds,
		"callback": callback,
		"active": true,
	}
	_next_id += 1
	_entries.append(entry)
	return entry

func unschedule(token: Variant) -> void:
	if typeof(token) == TYPE_DICTIONARY:
		token["active"] = false
	_prune()

func fire_delay(delay_seconds: float) -> bool:
	for entry: Variant in _entries:
		if entry.active and is_equal_approx(float(entry.delay), delay_seconds):
			entry.active = false
			entry.callback.call()
			_prune()
			return true
	return false

func fire_all() -> void:
	var pending: Array = []
	for entry: Variant in _entries:
		if entry.active:
			pending.append(entry)
	for entry: Variant in pending:
		entry.active = false
		entry.callback.call()
	_prune()

func active_count() -> int:
	var count := 0
	for entry: Variant in _entries:
		if entry.active:
			count += 1
	return count

func _prune() -> void:
	var kept: Array = []
	for entry: Variant in _entries:
		if entry.active:
			kept.append(entry)
	_entries = kept
