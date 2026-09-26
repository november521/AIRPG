extends Node
## Internal streaming HTTP seam for the DeepSeek adapter. Not an application contract.
## Implementations must:
## - emit body_chunk for raw response bytes only,
## - emit exactly one of response_finished / transport_failed per accepted start,
## - never place API keys, Authorization headers or vendor error text in signals.
## Offline tests supply fake implementations through an injected factory.

const Result = preload("res://shared/result.gd")

signal body_chunk(bytes: PackedByteArray)
signal response_finished(status_code: int)
signal transport_failed(code: String)

func start(_url: String, _headers: Dictionary, _body: PackedByteArray) -> RefCounted:
	return Result.failure("NOT_IMPLEMENTED")

func cancel() -> void:
	pass
