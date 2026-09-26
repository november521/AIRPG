extends RefCounted
## Deliberately bounded JSON Schema subset; unsupported keywords fail closed.
## No network, remote refs, expressions, scripts, or coercion.

const KEYWORDS := ["$schema", "title", "description", "type", "required", "properties",
	"additionalProperties", "items", "enum", "const", "minLength", "pattern",
	"minimum", "maximum", "maxItems", "maxProperties"]
const MAX_DEPTH := 32

static func validate(value: Variant, schema: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	_check_schema(schema, "$schema", 0, issues)
	if not issues.is_empty():
		return issues
	_visit(value, schema, "$", 0, issues)
	return issues

static func _check_schema(schema: Dictionary, path: String, depth: int, issues: Array[String]) -> void:
	if depth > MAX_DEPTH:
		issues.append(path + ": schema_depth_limit")
		return
	for keyword: String in schema:
		if keyword not in KEYWORDS:
			issues.append(path + ": unsupported_schema_keyword:" + keyword)
	for field: String in schema.get("properties", {}):
		_check_schema(schema.properties[field], path + "." + field, depth + 1, issues)
	for keyword: String in ["items", "additionalProperties"]:
		if schema.get(keyword) is Dictionary:
			_check_schema(schema[keyword], path + "." + keyword, depth + 1, issues)

static func _visit(value: Variant, schema: Dictionary, path: String,
		depth: int, issues: Array[String]) -> void:
	if depth > MAX_DEPTH:
		issues.append(path + ": depth_limit")
		return
	var expected: String = schema.get("type", "")
	if not _matches(value, expected):
		issues.append(path + ": type:" + expected)
		return
	if schema.has("enum") and value not in schema.enum:
		issues.append(path + ": enum")
	if schema.has("const") and value != schema.const:
		issues.append(path + ": const")
	if value is Dictionary:
		var properties: Dictionary = schema.get("properties", {})
		for field: String in schema.get("required", []):
			if not value.has(field):
				issues.append(path + "." + field + ": required")
		if value.size() > schema.get("maxProperties", 10000):
			issues.append(path + ": max_properties")
		for field: Variant in value:
			if not field is String:
				issues.append(path + ": key_type")
				continue
			if properties.has(field):
				_visit(value[field], properties[field], path + "." + field, depth + 1, issues)
			elif schema.get("additionalProperties", true) is Dictionary:
				_visit(value[field], schema.additionalProperties, path + "." + field, depth + 1, issues)
			elif schema.get("additionalProperties", true) == false:
				issues.append(path + ": unknown_field:" + field)
	elif value is Array:
		if value.size() > schema.get("maxItems", 10000):
			issues.append(path + ": max_items")
		for index: int in value.size():
			_visit(value[index], schema.get("items", {}), "%s[%d]" % [path, index], depth + 1, issues)
	elif value is String:
		if value.length() < schema.get("minLength", 0):
			issues.append(path + ": min_length")
		if schema.has("pattern"):
			var regex := RegEx.new()
			if regex.compile(schema.pattern) != OK or regex.search(value) == null:
				issues.append(path + ": pattern")
	elif value is float or value is int:
		if not is_finite(float(value)):
			issues.append(path + ": non_finite")
		elif value < schema.get("minimum", -INF) or value > schema.get("maximum", INF):
			issues.append(path + ": range")

static func _matches(value: Variant, expected: String) -> bool:
	match expected:
		"": return true
		"object": return value is Dictionary
		"array": return value is Array
		"string": return value is String
		"boolean": return value is bool
		"number": return value is int or value is float
		"integer": return value is int or (value is float and is_finite(value) and value == floor(value))
		"null": return value == null
		_: return false
