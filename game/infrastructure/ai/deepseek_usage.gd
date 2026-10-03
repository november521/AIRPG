extends RefCounted
## Sanitizes vendor token-usage payloads into a fixed whitelist of non-negative integers.
## Unknown counters, nested vendor extras and non-numeric values are dropped, never forwarded.
## Output is a plain structured Dictionary and contains no vendor error or prompt text.

const MAX_COUNTER: int = 2147483647
const COUNTER_KEYS: PackedStringArray = [
	"prompt_tokens",
	"completion_tokens",
	"total_tokens",
	"prompt_cache_hit_tokens",
	"prompt_cache_miss_tokens",
]
const DETAIL_KEYS: Dictionary = {
	"prompt_tokens_details": ["cached_tokens"],
	"completion_tokens_details": ["reasoning_tokens"],
}

static func sanitize(raw: Variant) -> Dictionary:
	var output: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return output
	var source: Dictionary = raw
	for key: String in COUNTER_KEYS:
		var counter := _counter(source.get(key))
		if counter >= 0:
			output[key] = counter
	for detail_key: String in DETAIL_KEYS:
		var nested: Variant = source.get(detail_key)
		if typeof(nested) != TYPE_DICTIONARY:
			continue
		var detail: Dictionary = {}
		for counter_key: String in DETAIL_KEYS[detail_key]:
			var counter := _counter(nested.get(counter_key))
			if counter >= 0:
				detail[counter_key] = counter
		if not detail.is_empty():
			output[detail_key] = detail
	return output

static func _counter(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var integer: int = value
		return integer if integer >= 0 and integer <= MAX_COUNTER else -1
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and number >= 0.0 and number <= float(MAX_COUNTER) and number == floor(number):
			return int(number)
	return -1
