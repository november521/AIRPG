extends RefCounted
const Result = preload("res://shared/result.gd")
const MAX_BYTES := 2 * 1024 * 1024

static func read(path: String) -> RefCounted:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return Result.failure("FILE_UNAVAILABLE")
	if file.get_length() > MAX_BYTES:
		return Result.failure("FILE_TOO_LARGE")
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return Result.failure("JSON_INVALID")
	return Result.success(parser.data)
