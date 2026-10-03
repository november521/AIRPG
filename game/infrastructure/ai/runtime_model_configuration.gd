extends "res://application/ports/model_configuration.gd"
## Direct-input prototype configuration. Credentials live only in this process and are
## replaced or cleared atomically; no key is written to res://, user://, logs or diagnostics.

const Contract = preload("res://application/contracts/model_transport_contract.gd")
const Config = preload("res://infrastructure/ai/deepseek_config.gd")
const Credentials = preload("res://infrastructure/ai/deepseek_credentials.gd")
const Provider = preload("res://infrastructure/ai/deepseek_provider.gd")
const HttpStream = preload("res://infrastructure/ai/godot_http_stream.gd")
const Clock = preload("res://infrastructure/ai/scene_tree_clock.gd")

var _config: Config = null
var _credentials: Credentials = null

func configure(endpoint_url: String, model: String, api_key: String) -> RefCounted:
	var parsed := Config.from_dictionary({"schema_version": 1,
		"endpoint_url": endpoint_url.strip_edges(), "model": model.strip_edges()})
	if not parsed.ok:
		return parsed
	var credential := Credentials.from_key(api_key)
	if not credential.ok:
		return credential
	# Replace both only after the complete candidate passed validation.
	_config = parsed.value
	_credentials = credential.value
	return Result.success(diagnostics())

func clear() -> void:
	_config = null
	_credentials = null

func configured() -> bool:
	return _config != null and _credentials != null and _credentials.configured()

func diagnostics() -> Dictionary:
	if not configured():
		return {"configured": false, "endpoint_host": "", "model": ""}
	var parts: Dictionary = Config.endpoint_parts(_config.endpoint_url)
	return {"configured": true, "endpoint_host": parts.get("host", ""),
		"model": _config.model}

func create_transport(host: Node, tree: SceneTree) -> RefCounted:
	if not configured() or host == null or tree == null:
		return Result.failure(Contract.AI_NOT_CONFIGURED)
	var stream_factory := func() -> Object: return HttpStream.new(host)
	return Result.success(Provider.new(_config, _credentials, stream_factory, Clock.new(tree)))
