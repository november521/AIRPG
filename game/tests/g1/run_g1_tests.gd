extends SceneTree
## Standalone G1 runner launched with the project's Godot binary, --headless, --script.
## Fully offline; no real API key or network request is used.
## It also covers one real SceneTreeClock timeout scenario that requires awaiting frames;
## that scenario stays here because the registered suite run(check) must stay synchronous.

const Suite = preload("res://tests/g1/test_g1_suite.gd")
const Contract = preload("res://application/contracts/model_transport_contract.gd")
const Config = preload("res://infrastructure/ai/deepseek_config.gd")
const Credentials = preload("res://infrastructure/ai/deepseek_credentials.gd")
const Provider = preload("res://infrastructure/ai/deepseek_provider.gd")
const SceneTreeClock = preload("res://infrastructure/ai/scene_tree_clock.gd")
const FakeStream = preload("res://tests/g1/fake_http_stream.gd")

var _checks: int = 0
var _failures: Array[String] = []
var _real_clock_streams: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
		printerr("FAIL: " + description)

func _run() -> void:
	Suite.new().run(_check)
	await _real_clock_timeout()
	print("AIRPG_G1_TESTS: %d checks, %d failures" % [_checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _new_real_clock_stream() -> Object:
	var stream: Object = FakeStream.new()
	_real_clock_streams.append(stream)
	return stream

func _real_clock_timeout() -> void:
	var config: Config = Config.from_dictionary({
		"schema_version": 1,
		"endpoint_url": "https://deepseek.example.invalid/chat/completions",
		"model": "fixture-model",
		"request_timeout_seconds": 0.1,
		"idle_timeout_seconds": 0.1,
	}).value
	var credentials := Credentials.from_key("test-key-synthetic")
	var provider := Provider.new(config, credentials.value, _new_real_clock_stream,
		SceneTreeClock.new(self))
	var codes: Array = []
	provider.failed.connect(func(_id: String, code: String) -> void: codes.append(code))
	var accepted := provider.start("req-real-clock", {"messages": [{"role": "user", "content": "x"}]})
	await create_timer(0.5).timeout
	_check(accepted.ok and codes == [Contract.MODEL_TIMEOUT],
		"real SceneTreeClock terminates a silent request with MODEL_TIMEOUT")
	provider.cancel("req-real-clock")
	for entry: Variant in _real_clock_streams:
		if is_instance_valid(entry):
			entry.free()
	_real_clock_streams = []
