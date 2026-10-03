extends RefCounted
## Runtime-only AI connection configuration port. Implementations must never expose keys.

const Result = preload("res://shared/result.gd")

func configure(_endpoint_url: String, _model: String, _api_key: String) -> RefCounted:
	return Result.failure("NOT_IMPLEMENTED")

func clear() -> void:
	pass

func diagnostics() -> Dictionary:
	return {"configured": false, "endpoint_host": "", "model": ""}
