extends RefCounted
## Boundary result. Codes are stable identifiers, never provider error text.

var ok: bool = false
var code: String = ""
var value: Variant = null
var issues: Array[String] = []

static func success(data: Variant = null) -> RefCounted:
	var result := new()
	result.ok = true
	result.value = data
	return result

static func failure(error_code: String, details: Array[String] = []) -> RefCounted:
	var result := new()
	result.code = error_code
	result.issues = details.duplicate()
	return result
