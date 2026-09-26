extends RefCounted
## Provider-neutral request envelope and stable transport failure codes.

const Result = preload("res://shared/result.gd")

const SCHEMA_VERSION: int = 1
const AI_NOT_CONFIGURED: String = "AI_NOT_CONFIGURED"
const MODEL_TIMEOUT: String = "MODEL_TIMEOUT"
const MODEL_TRANSPORT_ERROR: String = "MODEL_TRANSPORT_ERROR"
const MODEL_RESPONSE_INVALID: String = "MODEL_RESPONSE_INVALID"
const KNOWLEDGE_SCOPE_VIOLATION: String = "KNOWLEDGE_SCOPE_VIOLATION"
const REQUEST_CANCELLED: String = "REQUEST_CANCELLED"
const REQUEST_STALE: String = "REQUEST_STALE"

const _ERRORS: Array[String] = [AI_NOT_CONFIGURED, MODEL_TIMEOUT, MODEL_TRANSPORT_ERROR,
	MODEL_RESPONSE_INVALID, KNOWLEDGE_SCOPE_VIOLATION, REQUEST_CANCELLED, REQUEST_STALE]

static func request(request_id: String, filtered_context: Dictionary) -> RefCounted:
	if request_id.is_empty() or request_id.length() > 128:
		return Result.failure("MODEL_REQUEST_INVALID")
	if filtered_context.is_empty():
		return Result.failure("MODEL_REQUEST_INVALID")
	return Result.success({"schema_version": SCHEMA_VERSION, "request_id": request_id,
		"filtered_context": filtered_context.duplicate(true)})

static func is_stable_error(code: String) -> bool:
	return code in _ERRORS
