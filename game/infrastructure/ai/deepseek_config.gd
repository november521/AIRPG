extends RefCounted
## Validated DeepSeek transport configuration envelope.
## Credentials are deliberately NOT part of this object; they are injected separately.
## External JSON must pass this boundary before the adapter is constructed. Unknown fields,
## unknown versions, reserved request keys and non-JSON-safe values are rejected.

const Result = preload("res://shared/result.gd")

const SCHEMA_VERSION: int = 1
const CONFIG_INVALID: String = "MODEL_CONFIG_INVALID"
const DEFAULT_MAX_RESPONSE_BYTES: int = 262144
const DEFAULT_MAX_REQUEST_BYTES: int = 262144
const DEFAULT_REQUEST_TIMEOUT_SECONDS: float = 60.0
const DEFAULT_IDLE_TIMEOUT_SECONDS: float = 30.0
const DEFAULT_MAX_CONCURRENT_REQUESTS: int = 4
const MAX_MESSAGES_DEPTH: int = 32
const MAX_STRING_LENGTH: int = 1000000
const MAX_ARRAY_ITEMS: int = 4096
const MAX_OBJECT_FIELDS: int = 4096

const ALLOWED_FIELDS: PackedStringArray = [
	"schema_version", "endpoint_url", "model", "max_response_bytes", "max_request_bytes",
	"request_timeout_seconds", "idle_timeout_seconds", "max_concurrent_requests",
	"include_usage", "parameters",
]
const RESERVED_PARAMETERS: PackedStringArray = ["messages", "model", "stream", "stream_options"]

var endpoint_url: String = ""
var model: String = ""
var max_response_bytes: int = DEFAULT_MAX_RESPONSE_BYTES
var max_request_bytes: int = DEFAULT_MAX_REQUEST_BYTES
var request_timeout_seconds: float = DEFAULT_REQUEST_TIMEOUT_SECONDS
var idle_timeout_seconds: float = DEFAULT_IDLE_TIMEOUT_SECONDS
var max_concurrent_requests: int = DEFAULT_MAX_CONCURRENT_REQUESTS
var include_usage: bool = true
var parameters: Dictionary = {}

static func from_dictionary(raw: Variant) -> RefCounted:
	if typeof(raw) != TYPE_DICTIONARY:
		return Result.failure(CONFIG_INVALID, ["config must be a JSON object"])
	var source: Dictionary = raw
	var issues: Array[String] = []
	for key: Variant in source:
		if typeof(key) != TYPE_STRING or String(key) not in ALLOWED_FIELDS:
			issues.append("unknown config field rejected")
	if _read_int(source, "schema_version", -1, SCHEMA_VERSION, SCHEMA_VERSION, issues) != SCHEMA_VERSION:
		issues.append("schema_version must be 1")
	var config := new()
	var endpoint: Variant = source.get("endpoint_url")
	if typeof(endpoint) != TYPE_STRING or endpoint_parts(endpoint).is_empty():
		issues.append("endpoint_url must be a valid https URL without embedded credentials")
	else:
		config.endpoint_url = endpoint
	var model_name: Variant = source.get("model")
	if typeof(model_name) != TYPE_STRING or not _model_ok(model_name):
		issues.append("model must be a non-empty printable name")
	else:
		config.model = model_name
	config.max_response_bytes = _read_int(source, "max_response_bytes",
		DEFAULT_MAX_RESPONSE_BYTES, 64, 16777216, issues)
	config.max_request_bytes = _read_int(source, "max_request_bytes",
		DEFAULT_MAX_REQUEST_BYTES, 64, 16777216, issues)
	config.request_timeout_seconds = _read_float(source, "request_timeout_seconds",
		DEFAULT_REQUEST_TIMEOUT_SECONDS, 0.1, 3600.0, issues)
	config.idle_timeout_seconds = _read_float(source, "idle_timeout_seconds",
		DEFAULT_IDLE_TIMEOUT_SECONDS, 0.1, 3600.0, issues)
	config.max_concurrent_requests = _read_int(source, "max_concurrent_requests",
		DEFAULT_MAX_CONCURRENT_REQUESTS, 1, 16, issues)
	config.include_usage = _read_bool(source, "include_usage", true, issues)
	config.parameters = _read_parameters(source, issues)
	if not issues.is_empty():
		return Result.failure(CONFIG_INVALID, issues)
	return Result.success(config)

## Splits an https endpoint into host/port/path. Returns an empty Dictionary when unsafe.
## Rejects plain http, userinfo, whitespace, raw IPv6 and malformed ports.
static func endpoint_parts(url: String) -> Dictionary:
	if not url.begins_with("https://"):
		return {}
	var remainder := url.substr(8)
	var slash := remainder.find("/")
	var authority := remainder if slash < 0 else remainder.substr(0, slash)
	var path := "/" if slash < 0 else remainder.substr(slash)
	if authority.is_empty() or authority.contains("@") or path.contains(" ") or path.contains("\\"):
		return {}
	if authority.contains(" ") or authority.contains("\\") or authority.contains("?") or path.contains("#"):
		return {}
	var host := authority
	var port := 443
	var colon := authority.rfind(":")
	if colon >= 0:
		host = authority.substr(0, colon)
		var port_text := authority.substr(colon + 1)
		if not port_text.is_valid_int():
			return {}
		port = port_text.to_int()
		if port < 1 or port > 65535:
			return {}
	if not _host_ok(host):
		return {}
	return {"host": host, "port": port, "path": path}

## Bounded recursive check that a value only contains JSON-safe data.
static func is_json_safe(value: Variant, max_depth: int = MAX_MESSAGES_DEPTH) -> bool:
	if max_depth < 0:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_STRING:
			return value.length() <= MAX_STRING_LENGTH
		TYPE_ARRAY:
			if value.size() > MAX_ARRAY_ITEMS:
				return false
			for item: Variant in value:
				if not is_json_safe(item, max_depth - 1):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > MAX_OBJECT_FIELDS:
				return false
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or String(key).length() > 128:
					return false
				if not is_json_safe(value[key], max_depth - 1):
					return false
			return true
		_:
			return false

static func _read_int(source: Dictionary, key: String, fallback: int,
		minimum: int, maximum: int, issues: Array[String]) -> int:
	if not source.has(key):
		return fallback
	var value: Variant = source[key]
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		value = int(value)
	if typeof(value) != TYPE_INT:
		issues.append(key + " must be an integer")
		return fallback
	var number: int = value
	if number < minimum or number > maximum:
		issues.append(key + " out of range")
		return fallback
	return number

static func _read_float(source: Dictionary, key: String, fallback: float,
		minimum: float, maximum: float, issues: Array[String]) -> float:
	if not source.has(key):
		return fallback
	var value: Variant = source[key]
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		issues.append(key + " must be a number")
		return fallback
	var number := float(value)
	if not is_finite(number) or number < minimum or number > maximum:
		issues.append(key + " out of range")
		return fallback
	return number

static func _read_bool(source: Dictionary, key: String, fallback: bool, issues: Array[String]) -> bool:
	if not source.has(key):
		return fallback
	var value: Variant = source[key]
	if typeof(value) != TYPE_BOOL:
		issues.append(key + " must be a boolean")
		return fallback
	return value

static func _read_parameters(source: Dictionary, issues: Array[String]) -> Dictionary:
	var output: Dictionary = {}
	if not source.has("parameters"):
		return output
	var raw: Variant = source["parameters"]
	if typeof(raw) != TYPE_DICTIONARY:
		issues.append("parameters must be an object")
		return output
	for key: Variant in raw:
		if typeof(key) != TYPE_STRING or not _parameter_key_ok(key) or key in RESERVED_PARAMETERS:
			issues.append("parameter key rejected")
			continue
		if not is_json_safe(raw[key], 4):
			issues.append("parameter value rejected")
			continue
		output[key] = raw[key]
	return output

static func _model_ok(value: String) -> bool:
	if value.is_empty() or value.length() > 128:
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		if code < 33 or code > 126:
			return false
	return true

static func _parameter_key_ok(key: String) -> bool:
	if key.is_empty() or key.length() > 64:
		return false
	for index: int in key.length():
		var code := key.unicode_at(index)
		var is_lower := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		var is_underscore := code == 95
		if index == 0 and not is_lower:
			return false
		if not (is_lower or is_digit or is_underscore):
			return false
	return true

static func _host_ok(host: String) -> bool:
	if host.is_empty() or host.length() > 253:
		return false
	for index: int in host.length():
		var code := host.unicode_at(index)
		var is_alnum := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if not (is_alnum or code == 45 or code == 46):
			return false
	return true
