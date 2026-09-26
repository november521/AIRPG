extends "res://application/ports/model_provider.gd"
## Manual provider for lifecycle and adversarial tests. force_* may intentionally violate protocol.

const Contract = preload("res://application/contracts/model_transport_contract.gd")

var accepted: Dictionary = {}
var cancelled: Dictionary = {}
var terminated: Dictionary = {}

func start(request_id: String, filtered_context: Dictionary) -> RefCounted:
	var request := Contract.request(request_id, filtered_context)
	if not request.ok or accepted.has(request_id):
		return Result.failure("MODEL_REQUEST_INVALID")
	accepted[request_id] = request.value
	return Result.success()

func cancel(request_id: String) -> void:
	if not accepted.has(request_id) or terminated.has(request_id):
		return
	cancelled[request_id] = true
	terminated[request_id] = Contract.REQUEST_CANCELLED
	failed.emit(request_id, Contract.REQUEST_CANCELLED)

func complete(request_id: String, response: Dictionary) -> bool:
	if not accepted.has(request_id) or terminated.has(request_id):
		return false
	terminated[request_id] = "completed"
	completed.emit(request_id, response.duplicate(true))
	return true

func fail(request_id: String, code: String) -> bool:
	if not accepted.has(request_id) or terminated.has(request_id):
		return false
	if not Contract.is_stable_error(code):
		return false
	terminated[request_id] = code
	failed.emit(request_id, code)
	return true

func force_raw(request_id: String, chunk: String) -> void:
	raw_delta.emit(request_id, chunk)

func force_complete(request_id: String, response: Dictionary) -> void:
	completed.emit(request_id, response.duplicate(true))

func force_failure(request_id: String, code: String) -> void:
	failed.emit(request_id, code)
