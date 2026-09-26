extends RefCounted
## F1 application use case. It owns the safe application layer between the model
## transport port and the dialogue view contract:
## - knowledge projection isolates what the current NPC may use
## - only fully validated replies become DialogueViewContract.verified_reply events
## - cancelled, stale, duplicated or identity-mismatched results never reach the UI
## It never commits StateStore, consumes items, rolls dice or trusts raw_delta.

const Result = preload("res://shared/result.gd")
const ViewContract = preload("res://application/contracts/dialogue_view_contract.gd")
const Transport = preload("res://application/contracts/model_transport_contract.gd")
const Ids = preload("res://domain/dialogue/identifiers.gd")
const Request = preload("res://domain/dialogue/dialogue_request.gd")
const Facts = preload("res://domain/dialogue/knowledge_facts.gd")
const Projector = preload("res://domain/dialogue/knowledge_projector.gd")
const ReplyValidator = preload("res://domain/dialogue/reply_validator.gd")
const Registry = preload("res://application/dialogue/dialogue_request_registry.gd")
const Publication = preload("res://application/dialogue/dialogue_publication.gd")

signal view_event(event: Dictionary)

const CONFIG_KEYS: Array[String] = ["session_id", "state_store", "provider", "context_source",
	"facts", "action_catalog", "speakers"]
const CODE_INVALID_CONFIG: String = "DIALOGUE_CONFIG_INVALID"
const CODE_NO_EXCHANGE: String = "DIALOGUE_EXCHANGE_NOT_OPENED"
const CODE_UNKNOWN_SPEAKER: String = "DIALOGUE_UNKNOWN_SPEAKER"
const CODE_INVALID_EXCHANGE: String = "DIALOGUE_INVALID_EXCHANGE"
const CODE_CONTEXT_UNAVAILABLE: String = "DIALOGUE_CONTEXT_UNAVAILABLE"
const CODE_CONTEXT_INVALID: String = "DIALOGUE_CONTEXT_INVALID"
const CODE_PROVIDER_REJECTED: String = "DIALOGUE_PROVIDER_REJECTED"
const CODE_OPTION_UNKNOWN: String = "DIALOGUE_OPTION_UNKNOWN"

var _session_id: String = ""
var _state_store: Object = null
var _provider: Object = null
var _context_source: Object = null
var _facts: Array[Dictionary] = []
var _known_ids: Array[String] = []
var _action_catalog: Object = null
var _speakers: Dictionary = {}
var _registry: Registry = null
var _speaker_id: String = ""
var _scene_id: String = ""
var _topic_id: String = ""
var _trusted_ids: Dictionary = {}
var _last_options: Dictionary = {}
var _released: bool = false

static func create(config: Variant) -> RefCounted:
	if not _valid_config(config):
		return Result.failure(CODE_INVALID_CONFIG)
	var facts := Facts.validate_all(config.facts)
	if not facts.ok:
		return facts
	var speakers := _validate_speakers(config.speakers)
	if not speakers.ok:
		return speakers
	var registry := Registry.create(config.session_id)
	if not registry.ok:
		return registry
	var instance := new()
	instance._session_id = config.session_id
	instance._state_store = config.state_store
	instance._provider = config.provider
	instance._context_source = config.context_source
	instance._facts = facts.value
	instance._known_ids = Facts.known_ids(facts.value)
	instance._action_catalog = config.action_catalog
	instance._speakers = speakers.value
	instance._registry = registry.value
	instance._provider.completed.connect(instance._on_completed)
	instance._provider.failed.connect(instance._on_failed)
	return Result.success(instance)

func begin_exchange(speaker_id: String, scene_id: String, topic_id: String) -> RefCounted:
	if _released or not Ids.is_valid_id(speaker_id) or not Ids.is_valid_id(scene_id) \
			or not Ids.is_valid_id(topic_id):
		return Result.failure(CODE_INVALID_EXCHANGE)
	if not _speakers.has(speaker_id):
		return Result.failure(CODE_UNKNOWN_SPEAKER)
	end_exchange()
	_speaker_id = speaker_id
	_scene_id = scene_id
	_topic_id = topic_id
	return Result.success()

func end_exchange() -> void:
	for request_id: String in _registry.active_ids():
		cancel(request_id)
	_registry.reset()
	_speaker_id = ""
	_scene_id = ""
	_topic_id = ""
	_trusted_ids.clear()
	_last_options.clear()

func submit_text(request_id: String, text: String) -> RefCounted:
	var validated := ViewContract.player_text(request_id, text)
	if not validated.ok:
		return validated
	return _start(request_id, text)

func select_option(request_id: String, option_id: String) -> RefCounted:
	var validated := ViewContract.option_selection(request_id, option_id)
	if not validated.ok:
		return validated
	if not _last_options.has(option_id):
		return Result.failure(CODE_OPTION_UNKNOWN)
	var started := _start(request_id, _last_options[option_id])
	if started.ok:
		_last_options.clear()
	return started

func cancel(request_id: String) -> bool:
	if _released or not _registry.cancel(request_id):
		return false
	_trusted_ids.erase(request_id)
	_last_options.clear()
	_provider.cancel(request_id)
	_emit_status(request_id, ViewContract.STATUS_CANCELLED)
	return true

func release() -> void:
	if _released:
		return
	_released = true
	if _provider != null and is_instance_valid(_provider):
		if _provider.completed.is_connected(_on_completed):
			_provider.completed.disconnect(_on_completed)
		if _provider.failed.is_connected(_on_failed):
			_provider.failed.disconnect(_on_failed)
	_registry.reset()
	_trusted_ids.clear()
	_last_options.clear()
	_provider = null
	_state_store = null
	_context_source = null
	_action_catalog = null

func _start(request_id: String, player_text: String) -> RefCounted:
	if _released or _speaker_id.is_empty():
		return Result.failure(CODE_NO_EXCHANGE)
	var snapshot: Dictionary = _state_store.snapshot()
	var binding := Request.create(_session_id, request_id, int(snapshot.revision), _speaker_id,
		_scene_id, _topic_id)
	if not binding.ok:
		return binding
	var begun := _registry.begin(binding.value)
	if not begun.ok:
		return begun
	var gathered: RefCounted = _context_source.gather(_speaker_id, _scene_id, _topic_id)
	if not gathered.ok or not gathered.value is Dictionary:
		_registry.fail(request_id, CODE_CONTEXT_UNAVAILABLE)
		return Result.failure(CODE_CONTEXT_UNAVAILABLE, [gathered.code])
	var context_input: Dictionary = gathered.value.duplicate(true)
	context_input["speaker_id"] = _speaker_id
	context_input["scene_id"] = _scene_id
	context_input["topic_id"] = _topic_id
	context_input["facts"] = _facts
	context_input["flags"] = snapshot.flags
	context_input["player_text"] = player_text
	var projected := Projector.project(context_input)
	if not projected.ok:
		_registry.fail(request_id, projected.code)
		return Result.failure(CODE_CONTEXT_INVALID, [projected.code])
	var trusted: Array[String] = []
	for fact: Dictionary in projected.value.trusted_facts:
		trusted.append(fact.fact_id)
	var started: RefCounted = _provider.start(request_id, projected.value)
	if not started.ok:
		_registry.fail(request_id, started.code)
		return Result.failure(CODE_PROVIDER_REJECTED, [started.code])
	_trusted_ids[request_id] = trusted
	return _emit_status(request_id, ViewContract.STATUS_WAITING)

func _on_completed(request_id: String, response: Dictionary) -> void:
	if _released:
		return
	var snapshot: Dictionary = _state_store.snapshot()
	var authorized := _registry.authorize(request_id, int(snapshot.revision))
	if not authorized.ok:
		if authorized.code == Registry.CODE_STALE:
			_emit_status(request_id, ViewContract.STATUS_FAILED, Transport.REQUEST_STALE, false)
		return
	var binding: Dictionary = authorized.value
	var validated := ReplyValidator.validate(response, binding.speaker_id,
		_trusted_ids.get(request_id, []), _known_ids, _action_catalog)
	if not validated.ok:
		_registry.fail(request_id, validated.code)
		_trusted_ids.erase(request_id)
		_emit_status(request_id, ViewContract.STATUS_FAILED, _stable_error(validated.code), true)
		return
	var completed := _registry.complete(request_id)
	if not completed.ok:
		return
	_trusted_ids.erase(request_id)
	var profile: Dictionary = _speakers[binding.speaker_id]
	var event := Publication.build(request_id, binding.speaker_id, profile.name_key,
		profile.portrait_id, validated.value)
	if not event.ok:
		_last_options.clear()
		_emit_status(request_id, ViewContract.STATUS_FAILED, Transport.MODEL_RESPONSE_INVALID, true)
		return
	_last_options = {}
	for option: Dictionary in validated.value.options:
		_last_options[option.option_id] = option.text
	_emit(event.value)

func _on_failed(request_id: String, code: String) -> void:
	if _released or not _registry.is_active(request_id):
		return
	if code == Transport.REQUEST_CANCELLED:
		_registry.cancel(request_id)
		_trusted_ids.erase(request_id)
		_last_options.clear()
		_emit_status(request_id, ViewContract.STATUS_CANCELLED)
		return
	var stable := code if Transport.is_stable_error(code) else Transport.MODEL_TRANSPORT_ERROR
	_registry.fail(request_id, stable)
	_trusted_ids.erase(request_id)
	_last_options.clear()
	_emit_status(request_id, ViewContract.STATUS_FAILED, stable, _retryable(stable))

func _emit_status(request_id: String, status: String, error_code: String = "",
		retryable: bool = false) -> RefCounted:
	var event := ViewContract.status(request_id, status, error_code, retryable)
	if event.ok:
		_emit(event.value)
	return event

func _emit(event: Dictionary) -> void:
	var validated := ViewContract.validate_view_event(event)
	if not validated.ok:
		return
	view_event.emit(validated.value.duplicate(true))

static func _valid_config(config: Variant) -> bool:
	if not config is Dictionary or config.size() != CONFIG_KEYS.size():
		return false
	for key: String in CONFIG_KEYS:
		if not config.has(key):
			return false
	for key: Variant in config:
		if not key is String or key not in CONFIG_KEYS:
			return false
	if not config.session_id is String or not Ids.is_valid_id(config.session_id):
		return false
	if not config.state_store is Object or not config.state_store.has_method("snapshot"):
		return false
	if not config.provider is Object or not config.provider.has_signal("completed") \
			or not config.provider.has_signal("failed") or not config.provider.has_method("start") \
			or not config.provider.has_method("cancel"):
		return false
	if not config.context_source is Object or not config.context_source.has_method("gather"):
		return false
	if not config.action_catalog is Object or not config.action_catalog.has_method("validate"):
		return false
	return true

static func _validate_speakers(speakers: Variant) -> RefCounted:
	if not speakers is Dictionary or speakers.is_empty() or speakers.size() > 64:
		return Result.failure(CODE_INVALID_CONFIG)
	var copied: Dictionary = {}
	for speaker_id: Variant in speakers:
		if not speaker_id is String or not Ids.is_valid_id(speaker_id):
			return Result.failure(CODE_INVALID_CONFIG)
		var profile: Variant = speakers[speaker_id]
		if not profile is Dictionary or profile.size() != 2 or not profile.has("name_key") \
				or not profile.has("portrait_id"):
			return Result.failure(CODE_INVALID_CONFIG)
		if not profile.name_key is String or not Ids.is_valid_id(profile.name_key):
			return Result.failure(CODE_INVALID_CONFIG)
		if not profile.portrait_id is String or (not profile.portrait_id.is_empty() \
				and not Ids.is_valid_id(profile.portrait_id)):
			return Result.failure(CODE_INVALID_CONFIG)
		copied[speaker_id] = {"name_key": profile.name_key, "portrait_id": profile.portrait_id}
	return Result.success(copied)

static func _stable_error(code: String) -> String:
	if code in ["REPLY_SPEAKER_MISMATCH", "REPLY_UNKNOWN_FACT", "REPLY_FACT_NOT_ALLOWED"]:
		return Transport.KNOWLEDGE_SCOPE_VIOLATION
	return Transport.MODEL_RESPONSE_INVALID

static func _retryable(code: String) -> bool:
	return code in [Transport.MODEL_TIMEOUT, Transport.MODEL_TRANSPORT_ERROR,
		Transport.MODEL_RESPONSE_INVALID, Transport.KNOWLEDGE_SCOPE_VIOLATION,
		Transport.AI_NOT_CONFIGURED]
