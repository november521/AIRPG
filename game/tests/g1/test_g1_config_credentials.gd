extends RefCounted
## G1: external config and credential boundary tests. Offline only.

const Contract = preload("res://application/contracts/model_transport_contract.gd")
const Config = preload("res://infrastructure/ai/deepseek_config.gd")
const Credentials = preload("res://infrastructure/ai/deepseek_credentials.gd")
const Harness = preload("res://tests/g1/g1_harness.gd")

const ENV_NAME: String = "AIRPG_G1_TEST_KEY"

func run(check: Callable) -> void:
	_config(check)
	_credentials(check)

func _config(check: Callable) -> void:
	var valid := Config.from_dictionary(Harness.base_config())
	check.call(valid.ok and valid.value.model == Harness.DEFAULT_MODEL, "valid config accepted")
	check.call(valid.value.max_response_bytes == 262144 and valid.value.include_usage,
		"config defaults applied")
	check.call(not Config.from_dictionary(Harness.base_config({"unknown_field": 1})).ok,
		"unknown config field rejected")
	check.call(not Config.from_dictionary(Harness.base_config({"schema_version": 2})).ok,
		"unknown config version rejected")
	check.call(not Config.from_dictionary(
		{"endpoint_url": Harness.DEFAULT_ENDPOINT, "model": Harness.DEFAULT_MODEL}).ok,
		"missing schema version rejected")
	check.call(not Config.from_dictionary(Harness.base_config({"model": ""})).ok,
		"empty model rejected")
	check.call(not Config.from_dictionary(Harness.base_config(
		{"endpoint_url": "http://deepseek.example.invalid/chat/completions"})).ok,
		"plain http endpoint rejected")
	check.call(not Config.from_dictionary(Harness.base_config(
		{"endpoint_url": "https://user:pass@deepseek.example.invalid/chat/completions"})).ok,
		"endpoint userinfo rejected")
	check.call(not Config.from_dictionary(Harness.base_config({"request_timeout_seconds": 0.0})).ok,
		"out-of-range timeout rejected")
	check.call(not Config.from_dictionary(Harness.base_config({"max_response_bytes": 10})).ok,
		"undersized response cap rejected")
	var params := Config.from_dictionary(Harness.base_config(
		{"parameters": {"temperature": 0.2, "max_tokens": 256}}))
	check.call(params.ok and params.value.parameters.size() == 2,
		"safe generation parameters accepted")
	check.call(not Config.from_dictionary(Harness.base_config(
		{"parameters": {"messages": []}})).ok, "reserved parameter key rejected")
	check.call(not Config.from_dictionary(Harness.base_config(
		{"parameters": {"temperature": Vector2(1, 2)}})).ok, "non-JSON parameter value rejected")
	var parts := Config.endpoint_parts(
		"https://deepseek.example.invalid:8443/v1/chat/completions?x=1")
	check.call(parts.get("host") == "deepseek.example.invalid" and parts.get("port") == 8443
		and parts.get("path") == "/v1/chat/completions?x=1", "endpoint parts parsed")
	check.call(Config.is_json_safe({"messages": [{"role": "user", "content": "文本"}]}),
		"json-safe context accepted")
	check.call(not Config.is_json_safe({"bad": Vector2(0, 0)}), "engine object rejected by json safety")
	check.call(not Config.is_json_safe({"deep": _deep(40)}), "over-deep context rejected")

func _deep(levels: int) -> Dictionary:
	var root: Dictionary = {}
	var cursor := root
	for _index: int in levels:
		var child: Dictionary = {}
		cursor["child"] = child
		cursor = child
	return root

func _credentials(check: Callable) -> void:
	var missing := Credentials.from_key("")
	check.call(not missing.ok and missing.code == Contract.AI_NOT_CONFIGURED,
		"missing key fails closed with AI_NOT_CONFIGURED")
	check.call(not Credentials.from_key("bad key with space").ok, "malformed key rejected")
	check.call(not Credentials.from_key("line\nbreak").ok, "control characters in key rejected")
	var credentials := Credentials.from_key("test-key-synthetic")
	check.call(credentials.ok and credentials.value.configured(), "injected key accepted")
	var headers: Dictionary = credentials.value.request_headers()
	check.call(headers.get("Authorization") == "Bearer test-key-synthetic",
		"authorization header built for request only")
	check.call(str(credentials.value) == "<deepseek credentials>",
		"credentials string form masks the key")
	check.call(not Credentials.from_environment("not a name").ok,
		"invalid environment variable name rejected")
	OS.set_environment(ENV_NAME, "test-key-from-env")
	var from_env := Credentials.from_environment(ENV_NAME)
	check.call(from_env.ok and from_env.value.configured(), "environment key accepted")
	OS.set_environment(ENV_NAME, "")
	check.call(not Credentials.from_environment(ENV_NAME).ok,
		"empty environment key fails closed")
