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
const RESPONSE_SCHEMA_VERSION: int = 1
const MAX_RESPONSE_TEXT_LENGTH: int = 48000

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

static func completed_response(content: String, finish_reason: String,
		usage: Dictionary) -> RefCounted:
	if content.is_empty() or content.length() > MAX_RESPONSE_TEXT_LENGTH:
		return Result.failure(MODEL_RESPONSE_INVALID)
	if finish_reason.is_empty() or finish_reason.length() > 64:
		return Result.failure(MODEL_RESPONSE_INVALID)
	if usage.size() > 16 or not _valid_usage(usage):
		return Result.failure(MODEL_RESPONSE_INVALID)
	return Result.success({"transport_schema_version": RESPONSE_SCHEMA_VERSION,
		"content": content, "finish_reason": finish_reason, "usage": usage.duplicate(true)})

static func validate_completed_response(value: Variant) -> RefCounted:
	if not value is Dictionary or value.size() != 4:
		return Result.failure(MODEL_RESPONSE_INVALID)
	for key: String in ["transport_schema_version", "content", "finish_reason", "usage"]:
		if not value.has(key):
			return Result.failure(MODEL_RESPONSE_INVALID)
	for key: Variant in value:
		if not key is String or key not in ["transport_schema_version", "content",
				"finish_reason", "usage"]:
			return Result.failure(MODEL_RESPONSE_INVALID)
	if not value.transport_schema_version is int \
			or value.transport_schema_version != RESPONSE_SCHEMA_VERSION:
		return Result.failure(MODEL_RESPONSE_INVALID)
	if not value.content is String or not value.finish_reason is String \
			or not value.usage is Dictionary:
		return Result.failure(MODEL_RESPONSE_INVALID)
	return completed_response(value.content, value.finish_reason, value.usage)

static func _valid_usage(usage: Dictionary) -> bool:
	var integer_keys: Array[String] = ["prompt_tokens", "completion_tokens", "total_tokens",
		"prompt_cache_hit_tokens", "prompt_cache_miss_tokens"]
	var detail_keys: Dictionary = {"prompt_tokens_details": ["cached_tokens"],
		"completion_tokens_details": ["reasoning_tokens"]}
	for key: Variant in usage:
		if not key is String:
			return false
		if key in integer_keys:
			if not usage[key] is int or usage[key] < 0:
				return false
		elif detail_keys.has(key):
			if not usage[key] is Dictionary or usage[key].size() > 4:
				return false
			for nested: Variant in usage[key]:
				if not nested is String or nested not in detail_keys[key] \
						or not usage[key][nested] is int or usage[key][nested] < 0:
					return false
		else:
			return false
	return true
