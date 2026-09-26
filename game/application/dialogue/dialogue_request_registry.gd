extends RefCounted
## Per-session dialogue request lifecycle. Terminal states are permanent for the session:
## a cancelled, stale, failed or completed request can never be authorized or completed
## again, and a retry must use a brand-new request ID. No state is written here.

const Result = preload("res://shared/result.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")
const Request = preload("res://domain/dialogue/dialogue_request.gd")

const CODE_UNKNOWN: String = "REQUEST_UNKNOWN"
const CODE_REUSED: String = "REQUEST_ID_REUSED"
const CODE_ACTIVE: String = "REQUEST_ALREADY_ACTIVE"
const CODE_SESSION_MISMATCH: String = "SESSION_MISMATCH"
const CODE_INVALID: String = "DIALOGUE_REQUEST_INVALID"
const CODE_CANCELLED: String = "REQUEST_CANCELLED"
const CODE_STALE: String = "REQUEST_STALE"
const CODE_COMPLETED: String = "REQUEST_ALREADY_COMPLETED"

var _session_id: String = ""
var _active: Dictionary = {}
var _closed: Dictionary = {}

static func create(session_id: String) -> RefCounted:
	if not Ids.is_valid_id(session_id):
		return Result.failure(CODE_INVALID)
	var instance := new()
	instance._session_id = session_id
	return Result.success(instance)

func begin(binding: Variant) -> RefCounted:
	var validated := Request.validate(binding)
	if not validated.ok:
		return validated
	var data: Dictionary = validated.value
	if data.session_id != _session_id:
		return Result.failure(CODE_SESSION_MISMATCH)
	if _active.has(data.request_id) or _closed.has(data.request_id):
		return Result.failure(CODE_REUSED)
	if not _active.is_empty():
		return Result.failure(CODE_ACTIVE)
	_active[data.request_id] = data
	return Result.success(data.duplicate(true))

func authorize(request_id: String, current_revision: int) -> RefCounted:
	var terminal := terminal_code(request_id)
	if not terminal.is_empty():
		return Result.failure(terminal)
	if not _active.has(request_id):
		return Result.failure(CODE_UNKNOWN)
	var binding: Dictionary = _active[request_id]
	if current_revision != binding.expected_revision:
		_close(request_id, CODE_STALE)
		return Result.failure(CODE_STALE)
	return Result.success(binding.duplicate(true))

func complete(request_id: String) -> RefCounted:
	var terminal := terminal_code(request_id)
	if not terminal.is_empty():
		return Result.failure(terminal)
	if not _active.has(request_id):
		return Result.failure(CODE_UNKNOWN)
	var binding: Dictionary = _active[request_id]
	_close(request_id, CODE_COMPLETED)
	return Result.success(binding.duplicate(true))

func cancel(request_id: String) -> bool:
	if not _active.has(request_id):
		return false
	_close(request_id, CODE_CANCELLED)
	return true

func fail(request_id: String, code: String) -> bool:
	if not _active.has(request_id) or code.is_empty():
		return false
	_close(request_id, code)
	return true

func is_active(request_id: String) -> bool:
	return _active.has(request_id)

func active_ids() -> Array[String]:
	var ids: Array[String] = []
	for request_id: String in _active:
		ids.append(request_id)
	return ids

func terminal_code(request_id: String) -> String:
	return String(_closed.get(request_id, ""))

func reset() -> void:
	_active.clear()
	_closed.clear()

func _close(request_id: String, code: String) -> void:
	_active.erase(request_id)
	_closed[request_id] = code
