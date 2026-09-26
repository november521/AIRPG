extends "res://application/ports/model_provider.gd"
## Default composition is offline and fail-closed, never fabricates a story response.

func start(_request_id: String, _filtered_context: Dictionary) -> RefCounted:
	return Result.failure("AI_NOT_CONFIGURED")
