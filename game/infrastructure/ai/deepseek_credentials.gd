extends RefCounted
## DeepSeek API credentials.
## The API key is injected from outside the project (local config or environment variable).
## It is never returned from this object, never logged, never placed in diagnostics and never
## written to project resources. request_headers() is the only way to obtain the key for a
## request, and _to_string() masks the object for any accidental print/format call.

const Result = preload("res://shared/result.gd")
const Contract = preload("res://application/contracts/model_transport_contract.gd")

const MAX_KEY_LENGTH: int = 512
const MAX_ENV_NAME_LENGTH: int = 64
const MIN_PRINTABLE: int = 33
const MAX_PRINTABLE: int = 126

var _api_key: String = ""

func _init(api_key: String = "") -> void:
	_api_key = api_key

## Reads the key from a process environment variable. The variable name comes from external
## configuration; only the name is stored in project configuration, never the value.
static func from_environment(variable_name: String) -> RefCounted:
	if not _valid_variable_name(variable_name):
		return Result.failure(Contract.AI_NOT_CONFIGURED, ["environment variable name rejected"])
	return from_key(OS.get_environment(variable_name))

## Builds credentials from an already-injected key; invalid keys fail closed.
static func from_key(api_key: String) -> RefCounted:
	if not _valid_key(api_key):
		return Result.failure(Contract.AI_NOT_CONFIGURED, ["api key missing or malformed"])
	return Result.success(new(api_key))

func _to_string() -> String:
	return "<deepseek credentials>"

func configured() -> bool:
	return not _api_key.is_empty()

## Returns the per-request header set. Callers must pass this straight to the transport and
## must not log, serialize or persist the returned Authorization value.
func request_headers() -> Dictionary:
	return {
		"Authorization": "Bearer " + _api_key,
		"Content-Type": "application/json",
		"Accept": "text/event-stream",
	}

static func _valid_key(value: String) -> bool:
	if value.is_empty() or value.length() > MAX_KEY_LENGTH:
		return false
	if value != value.strip_edges():
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if code < MIN_PRINTABLE or code > MAX_PRINTABLE:
			return false
	return true

static func _valid_variable_name(name: String) -> bool:
	if name.is_empty() or name.length() > MAX_ENV_NAME_LENGTH:
		return false
	for index: int in name.length():
		var code := name.unicode_at(index)
		var is_upper := code >= 65 and code <= 90
		var is_digit := code >= 48 and code <= 57
		var is_underscore := code == 95
		if index == 0 and not is_upper:
			return false
		if not (is_upper or is_digit or is_underscore):
			return false
	return true
