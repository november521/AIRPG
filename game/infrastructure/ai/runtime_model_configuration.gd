extends "res://application/ports/model_configuration.gd"
## Direct-input prototype configuration. Credentials live in this process and, because solo
## play would otherwise re-ask for them at every launch, are also remembered in the injected
## local store (user:// by default — outside res:// and outside the repository).
## The key is replaced or cleared atomically, never printed, never returned and never part of
## diagnostics or an export.

const Contract = preload("res://application/contracts/model_transport_contract.gd")
const Config = preload("res://infrastructure/ai/deepseek_config.gd")
const Credentials = preload("res://infrastructure/ai/deepseek_credentials.gd")
const Provider = preload("res://infrastructure/ai/deepseek_provider.gd")
const HttpStream = preload("res://infrastructure/ai/godot_http_stream.gd")
const Clock = preload("res://infrastructure/ai/scene_tree_clock.gd")
const Store = preload("res://infrastructure/ai/local_credential_store.gd")

var _config: Config = null
var _credentials: Credentials = null
var _store: RefCounted = null
var _stored: bool = false

func _init(store: RefCounted = null) -> void:
	# No implicit default: only the composition root decides to remember credentials on disk, so
	# a test or a throwaway runtime can never overwrite the player's saved key.
	_store = store
	_stored = _store != null and _store.has_stored_credentials()

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
	# Persisting is best effort: a read-only profile must not stop this session from working.
	if _store != null:
		var saved: RefCounted = _store.save_credentials(endpoint_url, model, api_key)
		_stored = saved.ok or _store.has_stored_credentials()
	return Result.success(diagnostics())

## Reloads remembered credentials at start-up. Returns success with `restored` false when
## nothing (or nothing valid) is stored, so the game simply stays offline.
func restore() -> RefCounted:
	if _store == null:
		return Result.success({"restored": false, "reason": "NO_LOCAL_STORE"})
	var loaded: RefCounted = _store.load_credentials()
	if not loaded.ok:
		_stored = _store.has_stored_credentials() and loaded.code != "CREDENTIALS_ABSENT"
		return Result.success({"restored": false, "reason": loaded.code})
	var applied: RefCounted = configure(loaded.value.endpoint_url, loaded.value.model,
		loaded.value.api_key)
	if not applied.ok:
		return applied
	return Result.success({"restored": true})

## Reconfigures endpoint/model while reusing the remembered key, so the key field can stay empty.
func configure_stored(endpoint_url: String, model: String) -> RefCounted:
	if _store == null:
		return Result.failure("NO_LOCAL_STORE")
	var loaded: RefCounted = _store.load_credentials()
	if not loaded.ok:
		return loaded
	return configure(endpoint_url, model, loaded.value.api_key)

func clear() -> void:
	_config = null
	_credentials = null
	if _store != null:
		_store.clear()
	_stored = false

func configured() -> bool:
	return _config != null and _credentials != null and _credentials.configured()

func diagnostics() -> Dictionary:
	if not configured():
		return {"configured": false, "endpoint_host": "", "model": "", "stored": _stored}
	var parts: Dictionary = Config.endpoint_parts(_config.endpoint_url)
	return {"configured": true, "endpoint_host": parts.get("host", ""),
		"model": _config.model, "stored": _stored}

func create_transport(host: Node, tree: SceneTree) -> RefCounted:
	if not configured() or host == null or tree == null:
		return Result.failure(Contract.AI_NOT_CONFIGURED)
	var stream_factory := func() -> Object: return HttpStream.new(host)
	return Result.success(Provider.new(_config, _credentials, stream_factory, Clock.new(tree)))
