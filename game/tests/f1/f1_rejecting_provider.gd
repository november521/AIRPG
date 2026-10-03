extends "res://application/ports/model_provider.gd"
## F1 test double: rejects every start synchronously. Test-only.

func start(_request_id: String, _filtered_context: Dictionary) -> RefCounted:
	return Result.failure("TEST_PROVIDER_REJECTED")
