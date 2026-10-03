extends RefCounted
## Local credential store for the single-player prototype.
##
## The key is written to user:// — outside res://, outside the repository and outside any
## exported package — because re-entering it every launch is impractical for solo play. The
## file is validated on read, is never logged, never enters diagnostics and is deleted by the
## settings panel's disconnect action. Anyone with access to this Windows account can read the
## file: that is the accepted trade-off for a personal prototype, and rotating the key at the
## provider revokes it.
##
## This adapter is the only place allowed to touch the file; callers pass plain values in and
## get plain values out, never a file handle.

const Result = preload("res://shared/result.gd")

const SCHEMA_VERSION: int = 1
const DEFAULT_PATH: String = "user://ai_credentials.json"
const KEYS: Array[String] = ["schema_version", "endpoint_url", "model", "api_key"]
const MAX_BYTES: int = 8192
const MAX_ENDPOINT: int = 2048
const MAX_MODEL: int = 128
const MAX_KEY: int = 512

var _path: String = DEFAULT_PATH

func _init(path: String = DEFAULT_PATH) -> void:
	_path = path

## Returns the stored credentials, or a failure code: CREDENTIALS_ABSENT / CREDENTIALS_INVALID.
func load_credentials() -> RefCounted:
	if not FileAccess.file_exists(_path):
		return Result.failure("CREDENTIALS_ABSENT")
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return Result.failure("CREDENTIALS_ABSENT")
	if file.get_length() > MAX_BYTES:
		file.close()
		return Result.failure("CREDENTIALS_INVALID")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		file.close()
		return Result.failure("CREDENTIALS_INVALID")
	file.close()
	return _validated(parser.data)

## Best-effort persist. A write failure returns a failure but never blocks configuring.
func save_credentials(endpoint_url: String, model: String, api_key: String) -> RefCounted:
	var checked := _validated({"schema_version": SCHEMA_VERSION, "endpoint_url": endpoint_url,
		"model": model, "api_key": api_key})
	if not checked.ok:
		return checked
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return Result.failure("CREDENTIALS_UNWRITABLE")
	file.store_string(JSON.stringify(checked.value))
	file.close()
	return Result.success(checked.value)

func clear() -> void:
	if not FileAccess.file_exists(_path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))

func has_stored_credentials() -> bool:
	return FileAccess.file_exists(_path)

static func _validated(data: Dictionary) -> RefCounted:
	if data.size() != KEYS.size() or not data.has("schema_version"):
		return Result.failure("CREDENTIALS_INVALID")
	for key: String in KEYS:
		if not data.has(key):
			return Result.failure("CREDENTIALS_INVALID")
	for key: Variant in data:
		if not key is String or key not in KEYS:
			return Result.failure("CREDENTIALS_INVALID")
	if not data.schema_version is int or data.schema_version != SCHEMA_VERSION:
		# JSON numbers come back as floats, so accept only integral values of the right version.
		if not data.schema_version is float or not is_finite(data.schema_version) \
				or data.schema_version != float(SCHEMA_VERSION):
			return Result.failure("CREDENTIALS_INVALID")
	var limits: Dictionary = {"endpoint_url": MAX_ENDPOINT, "model": MAX_MODEL, "api_key": MAX_KEY}
	var copied: Dictionary = {"schema_version": SCHEMA_VERSION}
	for key: String in limits:
		if not data[key] is String or data[key].strip_edges().is_empty() \
				or data[key].length() > limits[key] or _has_control_characters(data[key]):
			return Result.failure("CREDENTIALS_INVALID")
		copied[key] = data[key].strip_edges() if key != "api_key" else data[key]
	return Result.success(copied)

static func _has_control_characters(value: String) -> bool:
	for index: int in value.length():
		if value.unicode_at(index) < 32:
			return true
	return false
