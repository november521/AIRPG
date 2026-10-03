extends "res://application/ports/model_provider.gd"
## Offline Chat Completions transport double. Never opens a network connection.

const Contract = preload("res://application/contracts/model_transport_contract.gd")

var accepted: Dictionary = {}
var cancelled: Array[String] = []
var completion_on_start: Dictionary = {}

func start(request_id: String, filtered_context: Dictionary) -> RefCounted:
	if accepted.has(request_id):
		return Result.failure("MODEL_REQUEST_INVALID")
	accepted[request_id] = filtered_context.duplicate(true)
	if not completion_on_start.is_empty():
		completed.emit(request_id, completion_on_start.duplicate(true))
	return Result.success()

func cancel(request_id: String) -> void:
	if not accepted.has(request_id) or request_id in cancelled:
		return
	cancelled.append(request_id)
	failed.emit(request_id, Contract.REQUEST_CANCELLED)

func finish(request_id: String, payload: Dictionary) -> void:
	completed.emit(request_id, payload.duplicate(true))

func fail(request_id: String, code: String) -> void:
	failed.emit(request_id, code)

func push_raw(request_id: String, text: String) -> void:
	raw_delta.emit(request_id, text)
