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
const ActionContract = preload("res://application/contracts/npc_action_contract.gd")
const Configuration = preload("res://application/dialogue/dialogue_configuration.gd")

signal view_event(event: Dictionary)
signal action_proposed(proposal: Dictionary)

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
var _reply_policies: Dictionary = {}
var _action_sink: Object = null
var _registry: Registry = null
var _speaker_id: String = ""
var _scene_id: String = ""
var _topic_id: String = ""
var _trusted_ids: Dictionary = {}
var _last_options: Dictionary = {}
var _released: bool = false

static func create(config: Variant) -> RefCounted:
	var checked := Configuration.validate(config)
	if not checked.ok:
		return checked
	var facts := Facts.validate_all(config.facts)
	if not facts.ok:
		return facts
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
	instance._speakers = checked.value
	instance._reply_policies = config.get("reply_policies", {})
	instance._action_sink = config.get("action_sink")
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
	# Cancel accepted network work before disconnecting callbacks so the underlying HTTP
	# stream releases its response buffer and credentials instead of living until timeout.
	for request_id: String in _registry.active_ids():
		_registry.cancel(request_id)
		_provider.cancel(request_id)
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
	_action_sink = null

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
	projected.value["allowed_actions"] = _action_catalog.describe()
	# A transport is allowed to complete synchronously from start(). Publish the trust
	# binding first so that such a callback follows the same validation path.
	_trusted_ids[request_id] = trusted
	var started: RefCounted = _provider.start(request_id, projected.value)
	if not started.ok:
		_registry.fail(request_id, started.code)
		_trusted_ids.erase(request_id)
		return Result.failure(CODE_PROVIDER_REJECTED, [started.code])
	# A synchronous terminal callback may already have closed the request and published its
	# final event. Do not append a stale waiting event after that terminal result.
	if not _registry.is_active(request_id):
		return Result.success()
	return _emit_status(request_id, ViewContract.STATUS_WAITING)

func _on_completed(request_id: String, response: Dictionary) -> void:
	if _released:
		return
	var snapshot: Dictionary = _state_store.snapshot()
	var authorized := _registry.authorize(request_id, int(snapshot.revision))
	if not authorized.ok:
		if authorized.code == Registry.CODE_STALE:
			_trusted_ids.erase(request_id)
			_emit_status(request_id, ViewContract.STATUS_FAILED, Transport.REQUEST_STALE, false)
		return
	var binding: Dictionary = authorized.value
	var validated := ReplyValidator.validate(response, binding.speaker_id,
		_trusted_ids.get(request_id, []), _known_ids, _action_catalog,
		_reply_policies.get(binding.speaker_id, {}))
	if not validated.ok:
		_registry.fail(request_id, validated.code)
		_trusted_ids.erase(request_id)
		_emit_status(request_id, ViewContract.STATUS_FAILED, _stable_error(validated.code), true)
		return
	var reply: Dictionary = validated.value.data()
	var profile: Dictionary = _speakers[binding.speaker_id]
	var event := Publication.build(request_id, binding.speaker_id, profile.name_key,
		profile.portrait_id, validated.value)
	if not event.ok:
		_registry.fail(request_id, event.code)
		_trusted_ids.erase(request_id)
		_last_options.clear()
		_emit_status(request_id, ViewContract.STATUS_FAILED, Transport.MODEL_RESPONSE_INVALID, true)
		return
	var proposal: Dictionary = {}
	if not reply.actions.is_empty():
		var built_action := ActionContract.proposal(_session_id, request_id,
			binding.expected_revision, binding.speaker_id, binding.scene_id, reply.actions[0])
		if not built_action.ok:
			_registry.fail(request_id, built_action.code)
			_trusted_ids.erase(request_id)
			_emit_status(request_id, ViewContract.STATUS_FAILED, Transport.MODEL_RESPONSE_INVALID, true)
			return
		proposal = built_action.value
		if _action_sink != null:
			var accepted: RefCounted = _action_sink.accept(proposal)
			if not accepted.ok:
				_registry.fail(request_id, accepted.code)
				_trusted_ids.erase(request_id)
				_emit_status(request_id, ViewContract.STATUS_FAILED,
					Transport.MODEL_RESPONSE_INVALID, true)
				return
	var completed := _registry.complete(request_id)
	if not completed.ok:
		return
	_trusted_ids.erase(request_id)
	_last_options = {}
	for option: Dictionary in reply.options:
		_last_options[option.option_id] = option.text
	if not proposal.is_empty():
		action_proposed.emit(proposal.duplicate(true))
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

static func _stable_error(code: String) -> String:
	if code in ["REPLY_SPEAKER_MISMATCH", "REPLY_UNKNOWN_FACT", "REPLY_FACT_NOT_ALLOWED"]:
		return Transport.KNOWLEDGE_SCOPE_VIOLATION
	return Transport.MODEL_RESPONSE_INVALID

static func _retryable(code: String) -> bool:
	return code in [Transport.MODEL_TIMEOUT, Transport.MODEL_TRANSPORT_ERROR,
		Transport.MODEL_RESPONSE_INVALID, Transport.KNOWLEDGE_SCOPE_VIOLATION,
		Transport.AI_NOT_CONFIGURED]
