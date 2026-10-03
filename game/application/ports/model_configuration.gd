extends RefCounted
## AI connection configuration port. Implementations must never expose keys: diagnostics carry
## only a host, a model name and whether credentials are remembered locally.
## `restore` lets the composition root reload local credentials; an implementation without
## local storage simply fails with NOT_IMPLEMENTED and the game stays offline.

const Result = preload("res://shared/result.gd")

func configure(_endpoint_url: String, _model: String, _api_key: String) -> RefCounted:
	return Result.failure("NOT_IMPLEMENTED")

func restore() -> RefCounted:
	return Result.failure("NOT_IMPLEMENTED")

## Reconfigures endpoint/model while reusing a remembered key, so a key field may stay empty.
func configure_stored(_endpoint_url: String, _model: String) -> RefCounted:
	return Result.failure("NOT_IMPLEMENTED")

func clear() -> void:
	pass

func diagnostics() -> Dictionary:
	return {"configured": false, "endpoint_host": "", "model": ""}
