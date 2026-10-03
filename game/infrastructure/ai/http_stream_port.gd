extends Node
## Internal streaming HTTP seam for the DeepSeek adapter. Not an application contract.
## Implementations must:
## - emit response_started(status) exactly once, after headers and before any body_chunk,
## - emit body_chunk for raw response bytes only,
## - emit exactly one of response_finished / transport_failed per accepted start,
## - never place API keys, Authorization headers or vendor error text in signals.
## Offline tests supply fake implementations through an injected factory.

const Result = preload("res://shared/result.gd")

## Must be emitted exactly once, before the first body_chunk, once response headers are known.
signal response_started(status_code: int)
signal body_chunk(bytes: PackedByteArray)
signal response_finished(status_code: int)
signal transport_failed(code: String)

func start(_url: String, _headers: Dictionary, _body: PackedByteArray) -> RefCounted:
	return Result.failure("NOT_IMPLEMENTED")

func cancel() -> void:
	pass
