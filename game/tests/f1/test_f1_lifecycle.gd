extends RefCounted
## F1 lifecycle suite: single completion, cancellation, stale revision, wrong speaker/ID
## and mandatory new request IDs for retries.

const Request = preload("res://domain/dialogue/dialogue_request.gd")
const Registry = preload("res://application/dialogue/dialogue_request_registry.gd")
const Fixtures = preload("res://tests/f1/f1_fixtures.gd")

func run(check: Callable) -> void:
	_binding(check)
	_single_completion(check)
	_cancel(check)
	_stale(check)
	_speaker_and_unknown(check)

func _registry() -> RefCounted:
	return Registry.create(Fixtures.SESSION_ID).value

func _binding_for(request_id: String, revision: int = 0) -> Dictionary:
	return Request.create(Fixtures.SESSION_ID, request_id, revision, Fixtures.SPEAKER_A,
		Fixtures.SCENE, Fixtures.TOPIC).value

func _binding(check: Callable) -> void:
	check.call(not Registry.create("../escape").ok, "invalid session ID rejected")
	var binding := Request.create(Fixtures.SESSION_ID, "test.request.1", 0, Fixtures.SPEAKER_A,
		Fixtures.SCENE, Fixtures.TOPIC)
	check.call(binding.ok and binding.value.schema_version == 1, "valid request binding accepted")
	var bad := Request.create(Fixtures.SESSION_ID, "", 0, Fixtures.SPEAKER_A, Fixtures.SCENE,
		Fixtures.TOPIC)
	check.call(not bad.ok, "empty request ID rejected")
	check.call(not Request.create(Fixtures.SESSION_ID, "test.request.1", 0, "../escape",
		Fixtures.SCENE, Fixtures.TOPIC).ok, "unsafe speaker ID rejected")
	var registry := _registry()
	check.call(registry.begin(binding.value).ok, "first request accepted")
	check.call(registry.begin(_binding_for("test.request.2")).code == Registry.CODE_ACTIVE,
		"second concurrent request rejected")
	check.call(registry.begin(binding.value).code == Registry.CODE_REUSED,
		"reused request ID rejected")
	var other_session: RefCounted = Registry.create("test.other_session").value
	var foreign := Request.create("test.other_session", "test.request.3", 0, Fixtures.SPEAKER_A,
		Fixtures.SCENE, Fixtures.TOPIC)
	check.call(other_session.begin(foreign.value).ok, "other session accepts its own binding")
	check.call(not registry.begin(foreign.value).ok, "foreign session binding rejected")
	var authorized: RefCounted = registry.authorize("test.request.1", 0)
	check.call(authorized.ok, "active request authorized at revision")
	check.call(registry.authorize("test.request.unknown", 0).code == Registry.CODE_UNKNOWN,
		"unknown request ID cannot be authorized")

func _single_completion(check: Callable) -> void:
	var registry := _registry()
	registry.begin(_binding_for("test.request.1"))
	check.call(registry.complete("test.request.1").ok, "first completion accepted")
	check.call(registry.complete("test.request.1").code == Registry.CODE_COMPLETED,
		"second completion rejected")
	check.call(registry.authorize("test.request.1", 0).code == Registry.CODE_COMPLETED,
		"completed request can never be authorized again")
	check.call(not registry.is_active("test.request.1"), "completed request is no longer active")
	var reusable := _registry()
	reusable.begin(_binding_for("test.request.1"))
	reusable.complete("test.request.1")
	check.call(reusable.begin(_binding_for("test.request.1")).code == Registry.CODE_REUSED,
		"retry must use a new request ID")

func _cancel(check: Callable) -> void:
	var registry := _registry()
	registry.begin(_binding_for("test.request.1"))
	check.call(registry.cancel("test.request.1"), "active request cancelled")
	check.call(not registry.cancel("test.request.1"), "cancellation is idempotent")
	check.call(registry.authorize("test.request.1", 0).code == Registry.CODE_CANCELLED,
		"late result for cancelled request rejected")
	check.call(registry.complete("test.request.1").code == Registry.CODE_CANCELLED,
		"cancelled request cannot complete")
	registry.begin(_binding_for("test.request.2"))
	check.call(registry.cancel("test.request.2"), "new request cancels independently")

func _stale(check: Callable) -> void:
	var registry := _registry()
	registry.begin(_binding_for("test.request.1", 0))
	check.call(registry.authorize("test.request.1", 1).code == Registry.CODE_STALE,
		"result from an expired revision rejected")
	check.call(registry.authorize("test.request.1", 0).code == Registry.CODE_STALE,
		"stale request stays terminal even at the original revision")
	check.call(not registry.is_active("test.request.1"), "stale request is closed")

func _speaker_and_unknown(check: Callable) -> void:
	var registry := _registry()
	registry.begin(_binding_for("test.request.1"))
	var authorized: RefCounted = registry.authorize("test.request.1", 0)
	check.call(authorized.ok and authorized.value.speaker_id == Fixtures.SPEAKER_A,
		"authorized binding carries the expected speaker")
	registry.reset()
	check.call(registry.authorize("test.request.1", 0).code == Registry.CODE_UNKNOWN,
		"reset forgets closed and active requests")
