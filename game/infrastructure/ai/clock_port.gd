extends RefCounted
## Internal scheduling seam for the DeepSeek adapter so timeout behavior is testable
## without wall-clock waits. Not an application contract and not exposed to UI.

## Schedules a one-shot callback and returns a token that unschedule() accepts.
func schedule(_delay_seconds: float, _callback: Callable) -> Variant:
	return null

## Cancels a scheduled callback. Must be safe to call after the callback already fired.
func unschedule(_token: Variant) -> void:
	pass
