extends RefCounted
## Transport-only port. Raw deltas MUST NOT connect to player-facing UI.
## Exactly one terminal signal per accepted request, tagged with its request ID.
signal raw_delta(request_id: String, chunk: String)
signal completed(request_id: String, response: Dictionary)
signal failed(request_id: String, code: String)

const Result = preload("res://shared/result.gd")

func start(_request_id: String, _filtered_context: Dictionary) -> RefCounted:
	return Result.failure("NOT_IMPLEMENTED")

func cancel(_request_id: String) -> void:
	pass
