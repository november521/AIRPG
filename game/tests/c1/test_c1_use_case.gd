extends RefCounted
## C1 use-case suite: A1 contract routing, cooldown, sink rejection and signals.

const Result = preload("res://shared/result.gd")
const Sink = preload("res://application/exploration/exploration_request_sink.gd")
const UseCase = preload("res://application/exploration/exploration_use_case.gd")
const Fixtures = preload("res://tests/c1/c1_fixtures.gd")

func run(check: Callable) -> void:
	_contract_flow(check)
	_cooldown(check)
	_rejection(check)
	_creation(check)
	_signals(check)

func _contract_flow(check: Callable) -> void:
	var sink = Fixtures.recording_sink()
	var built := Fixtures.build(Fixtures.lab_layout(), sink)
	check.call(built.ok, "use case builds from layout and sink")
	var use_case = built.value
	var spawn = use_case.player_position()
	check.call(not use_case.move(Vector2(2, 0)).ok, "oversized movement axis rejected")
	use_case.advance(1.0)
	check.call(use_case.player_position() == spawn, "rejected axis does not move player")
	check.call(use_case.move(Vector2(0, -1)).ok, "bounded movement axis accepted")
	use_case.advance(1.0)
	check.call(use_case.player_position().y < spawn.y, "accepted axis moves player")
	check.call(sink.commands.is_empty(), "movement intent is not submitted to the sink")
	var candidate = use_case.nearest_candidate()
	check.call(candidate.ok and candidate.value.target_id == "test.crate",
		"interaction candidate available in range")
	var requested = use_case.interact("test.crate")
	check.call(requested.ok and requested.value.kind == "interact"
		and requested.value.schema_version == 1, "interact goes through A1 contract")
	check.call(requested.value.target_id == "test.crate", "contract carries stable target ID")
	check.call(sink.commands.size() == 1 and sink.commands[0] == requested.value,
		"sink receives the validated contract DTO")
	check.call(sink.commands[0].keys().size() == 3, "submitted DTO carries no extra fields")
	check.call(not use_case.interact("test.missing").ok
		and use_case.interact("test.missing").code == "EXPLORATION_UNKNOWN_TARGET",
		"unknown target rejected")
	check.call(not use_case.interact("../escape").ok
		and use_case.interact("../escape").code == "EXPLORATION_INVALID_TARGET",
		"invalid target ID rejected by contract")
	check.call(not use_case.interact("test.npc").ok
		and use_case.interact("test.npc").code == "EXPLORATION_TARGET_OUT_OF_RANGE",
		"out-of-range target rejected")
	check.call(sink.commands.size() == 1, "failed interactions never reach the sink")

func _cooldown(check: Callable) -> void:
	var sink = Fixtures.recording_sink()
	var use_case = Fixtures.build(Fixtures.lab_layout(), sink).value
	var first = use_case.investigate()
	check.call(first.ok and first.value.kind == "investigate", "investigate uses A1 contract")
	check.call(sink.commands.size() == 1, "investigation submitted once")
	check.call(not use_case.investigate_ready() and use_case.cooldown_remaining() > 0.0,
		"cooldown starts after investigate")
	var blocked = use_case.investigate()
	check.call(not blocked.ok and blocked.code == UseCase.CODE_COOLDOWN_ACTIVE,
		"second investigate during cooldown rejected")
	check.call(sink.commands.size() == 1, "cooldown rejection does not reach the sink")
	use_case.advance(Fixtures.COOLDOWN)
	check.call(use_case.investigate_ready(), "cooldown expires with advance ticks")
	for index: int in 4:
		check.call(use_case.investigate().ok, "investigate stays unlimited in the scene")
		use_case.advance(Fixtures.COOLDOWN)
	var investigations := 0
	for command: Dictionary in sink.commands:
		if command.kind == "investigate":
			investigations += 1
	check.call(investigations == 5 and sink.commands.size() == investigations,
		"repeat investigations submit only investigate commands")

func _rejection(check: Callable) -> void:
	var sink = Fixtures.recording_sink()
	var use_case = Fixtures.build(Fixtures.lab_layout(), sink).value
	use_case.move(Vector2(0, -1))
	use_case.advance(1.0)
	sink.fail_next = true
	var rejected = use_case.interact("test.crate")
	check.call(not rejected.ok and rejected.code == UseCase.CODE_REQUEST_REJECTED,
		"sink rejection propagates as stable use-case code")
	check.call(rejected.issues == ["EXPLORATION_SINK_TEST_FAILURE"],
		"rejection carries the sink failure code")
	check.call(sink.commands.is_empty(), "rejected interaction is not recorded")
	sink.fail_next = true
	var investigate = use_case.investigate()
	check.call(not investigate.ok and investigate.code == UseCase.CODE_REQUEST_REJECTED,
		"rejected investigation reports stable code")
	check.call(use_case.investigate_ready(), "rejected investigation does not start cooldown")
	check.call(sink.commands.is_empty(), "rejected investigation is not recorded")
	var base_sink := Sink.new()
	check.call(not base_sink.submit({}).ok, "base sink fails closed")
	check.call(base_sink.submit({}).code == "EXPLORATION_SINK_NOT_IMPLEMENTED",
		"base sink exposes stable code")
	var base_case = Fixtures.build(Fixtures.lab_layout(), base_sink).value
	check.call(base_case.investigate().code == UseCase.CODE_REQUEST_REJECTED,
		"unconfigured sink rejects the use case")
	use_case.move(Vector2(0, 1))
	var before = use_case.player_position()
	use_case.advance(NAN)
	use_case.advance(INF)
	use_case.advance(-5.0)
	check.call(use_case.player_position() == before, "invalid delta does not move player")

func _creation(check: Callable) -> void:
	var sink = Fixtures.recording_sink()
	check.call(not UseCase.create(Fixtures.lab_layout(), null, Fixtures.COOLDOWN).ok,
		"null sink rejected")
	check.call(UseCase.create(Fixtures.lab_layout(), sink, 0.0).code
		== UseCase.CODE_COOLDOWN_INVALID, "zero cooldown rejected")
	check.call(UseCase.create(Fixtures.lab_layout(), sink, NAN).code
		== UseCase.CODE_COOLDOWN_INVALID, "non-finite cooldown rejected")
	check.call(not UseCase.create(null, sink, Fixtures.COOLDOWN).ok,
		"invalid layout propagates to caller")

func _signals(check: Callable) -> void:
	var sink = Fixtures.recording_sink()
	var use_case = Fixtures.build(Fixtures.lab_layout(), sink).value
	var proximity: Array = []
	var cooldown: Array = []
	use_case.proximity_changed.connect(func(candidate: Dictionary) -> void:
		proximity.append(candidate.duplicate(true)))
	use_case.cooldown_changed.connect(func(remaining: float, ready: bool) -> void:
		cooldown.append({"remaining": remaining, "ready": ready}))
	use_case.advance(0.1)
	check.call(proximity.is_empty(), "no proximity event while no candidate exists")
	use_case.move(Vector2(0, -1))
	use_case.advance(1.0)
	check.call(proximity.size() == 1 and proximity[0].target_id == "test.crate",
		"entering range emits one candidate event")
	use_case.move(Vector2.ZERO)
	use_case.advance(0.5)
	check.call(proximity.size() == 1, "staying in range does not repeat the candidate event")
	use_case.move(Vector2(0, 1))
	use_case.advance(1.0)
	check.call(proximity.size() == 2 and proximity[1].is_empty(),
		"leaving range emits an empty candidate event")
	use_case.investigate()
	check.call(cooldown.size() == 1 and not cooldown[0].ready, "cooldown start emitted once")
	use_case.advance(Fixtures.COOLDOWN)
	check.call(cooldown.size() == 2 and cooldown[1].ready, "cooldown ready emitted once")
	use_case.advance(1.0)
	check.call(cooldown.size() == 2, "ready state does not repeat events")
