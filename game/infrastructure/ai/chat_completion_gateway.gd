extends "res://application/ports/model_provider.gd"
## Bridges AIRPG's filtered NPC context to a Chat Completions transport and decodes
## its cached completion. Raw deltas deliberately stop here and never reach F1 or UI.

const Contract = preload("res://application/contracts/model_transport_contract.gd")
const ModelReply = preload("res://domain/dialogue/model_reply.gd")

var _transport: Object = null
var _builder: Object = null
var _active: Dictionary = {}
var _released: bool = false

func _init(transport: Object = null, builder: Object = null) -> void:
	_transport = transport
	_builder = builder
	if _transport != null:
		_transport.completed.connect(_on_transport_completed)
		_transport.failed.connect(_on_transport_failed)

func start(request_id: String, filtered_context: Dictionary) -> RefCounted:
	if _released or _transport == null or _builder == null or _active.has(request_id):
		return Result.failure("MODEL_REQUEST_INVALID")
	var body: RefCounted = _builder.build(filtered_context)
	if not body.ok:
		return Result.failure(Contract.MODEL_RESPONSE_INVALID, body.issues)
	_active[request_id] = true
	var started: RefCounted = _transport.start(request_id, body.value)
	if not started.ok:
		_active.erase(request_id)
		return started
	return Result.success()

func cancel(request_id: String) -> void:
	if _released or not _active.has(request_id):
		return
	_transport.cancel(request_id)

func release() -> void:
	if _released:
		return
	for request_id: String in _active.keys():
		_transport.cancel(request_id)
	_active.clear()
	_released = true
	if _transport != null and is_instance_valid(_transport):
		if _transport.completed.is_connected(_on_transport_completed):
			_transport.completed.disconnect(_on_transport_completed)
		if _transport.failed.is_connected(_on_transport_failed):
			_transport.failed.disconnect(_on_transport_failed)
	_transport = null
	_builder = null

func _on_transport_completed(request_id: String, response: Dictionary) -> void:
	if _released or not _active.erase(request_id):
		return
	var envelope := Contract.validate_completed_response(response)
	if not envelope.ok or envelope.value.finish_reason != "stop":
		failed.emit(request_id, Contract.MODEL_RESPONSE_INVALID)
		return
	var parsed := ModelReply.parse(envelope.value.content)
	if not parsed.ok:
		failed.emit(request_id, Contract.MODEL_RESPONSE_INVALID)
		return
	completed.emit(request_id, parsed.value)

func _on_transport_failed(request_id: String, code: String) -> void:
	if _released or not _active.erase(request_id):
		return
	failed.emit(request_id, code if Contract.is_stable_error(code) \
		else Contract.MODEL_TRANSPORT_ERROR)
