extends RefCounted
## Bounded FIFO dedup log for terminated request IDs. Keeps immediate ID reuse rejected without
## retaining response text, parsers or streams; the oldest IDs are evicted once the bound is hit.
## This is deliberately NOT a security boundary: callers must retry with new request IDs.

const MAX_ENTRIES: int = 256

var _ids: Dictionary = {}
var _order: Array[String] = []

func has(request_id: String) -> bool:
	return _ids.has(request_id)

func remember(request_id: String) -> void:
	if _ids.has(request_id):
		return
	_ids[request_id] = true
	_order.append(request_id)
	while _order.size() > MAX_ENTRIES:
		var oldest: String = _order.pop_front()
		_ids.erase(oldest)

func size() -> int:
	return _order.size()
