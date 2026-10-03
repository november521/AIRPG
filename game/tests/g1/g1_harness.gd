extends RefCounted
## Offline G1 harness: fake stream factory, manual clock and signal recorder.
## Every generated stream node is owned by the harness and released with release(). Test-only.

const Config = preload("res://infrastructure/ai/deepseek_config.gd")
const Credentials = preload("res://infrastructure/ai/deepseek_credentials.gd")
const Provider = preload("res://infrastructure/ai/deepseek_provider.gd")
const FakeStream = preload("res://tests/g1/fake_http_stream.gd")
const ManualClock = preload("res://tests/g1/manual_clock.gd")

const DEFAULT_KEY: String = "test-key-synthetic"
const DEFAULT_ENDPOINT: String = "https://deepseek.example.invalid/chat/completions"
const DEFAULT_MODEL: String = "fixture-model"

var streams: Array = []
var completed: Array = []
var failed: Array = []
var deltas: Array = []
var clock: ManualClock = null
var provider: Provider = null
var config: Config = null
var next_start_failure: String = ""

static func base_config(overrides: Dictionary = {}) -> Dictionary:
	var raw := {"schema_version": 1, "endpoint_url": DEFAULT_ENDPOINT, "model": DEFAULT_MODEL}
	for key: Variant in overrides:
		raw[key] = overrides[key]
	return raw

static func context(content: String = "巡查车辆") -> Dictionary:
	return {"messages": [{"role": "user", "content": content}]}

func _init(config_overrides: Dictionary = {}, credentials_key: String = DEFAULT_KEY) -> void:
	clock = ManualClock.new()
	var parsed := Config.from_dictionary(base_config(config_overrides))
	config = parsed.value
	var credentials := Credentials.from_key(credentials_key)
	provider = Provider.new(config, credentials.value, _new_stream, clock)
	provider.raw_delta.connect(func(request_id: String, chunk: String) -> void:
		deltas.append({"request_id": request_id, "chunk": chunk}))
	provider.completed.connect(func(request_id: String, payload: Dictionary) -> void:
		completed.append({"request_id": request_id, "payload": payload}))
	provider.failed.connect(func(request_id: String, code: String) -> void:
		failed.append({"request_id": request_id, "code": code}))

func _new_stream() -> Object:
	var stream: Object = FakeStream.new()
	stream.start_failure_code = next_start_failure
	next_start_failure = ""
	streams.append(stream)
	return stream

func stream() -> FakeStream:
	if streams.is_empty():
		return null
	return streams[0]

func text() -> String:
	var combined := ""
	for entry: Variant in deltas:
		combined += String(entry["chunk"])
	return combined

func terminal_count() -> int:
	return completed.size() + failed.size()

func failure_codes() -> Array:
	var codes: Array = []
	for entry: Variant in failed:
		codes.append(entry["code"])
	return codes

func release() -> void:
	for entry: Variant in streams:
		if is_instance_valid(entry):
			entry.free()
	streams = []
	# Break the harness <-> provider Callable cycle so offline suites leak nothing.
	provider = null
	config = null
	clock = null
