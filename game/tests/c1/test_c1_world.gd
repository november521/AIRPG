extends RefCounted
## C1 world suite: movement, collision, layout validation, range and occlusion.

const World = preload("res://application/exploration/greybox_world.gd")
const Fixtures = preload("res://tests/c1/c1_fixtures.gd")

func run(check: Callable) -> void:
	_movement(check)
	_validation(check)
	_ranges(check)
	_occlusion(check)

func _movement(check: Callable) -> void:
	var built := World.from_layout(Fixtures.corridor_layout())
	check.call(built.ok, "corridor layout accepted")
	var world = built.value
	check.call(world.position() == world.spawn(), "spawn position applied")
	world.integrate(Vector2(1, 0), 1.0)
	check.call(is_equal_approx(world.position().x, 290.0), "right wall stops player at edge")
	check.call(is_equal_approx(world.position().y, 300.0), "horizontal move keeps y")
	world.integrate(Vector2(1, 0), 100.0)
	check.call(is_equal_approx(world.position().x, 290.0), "large step does not tunnel")
	world.integrate(Vector2(-1, -1), 10.0)
	check.call(is_equal_approx(world.position().x, 30.0)
		and is_equal_approx(world.position().y, 30.0), "corner blocks both axes")
	world.integrate(Vector2(0, 1), 1000.0)
	check.call(is_equal_approx(world.position().y, 550.0), "bottom wall blocks")
	world.integrate(Vector2(0, -1), 1000.0)
	check.call(is_equal_approx(world.position().y, 30.0), "top wall blocks")
	var frozen = world.position()
	world.integrate(Vector2(NAN, 0), 1.0)
	world.integrate(Vector2(0, INF), 1.0)
	world.integrate(Vector2(1, 0), -5.0)
	check.call(world.position() == frozen, "invalid axis or delta never moves")
	var lab = World.from_layout(Fixtures.lab_layout()).value
	lab.integrate(Vector2(0, -1), 10.0)
	check.call(is_equal_approx(lab.position().y, 320.0), "interactable body blocks movement")
	var side := {"player": {"spawn": Vector2(100, 300), "half_extents": Vector2(10, 10),
		"speed": 100.0}, "walls": [],
		"interactables": [{"target_id": "test.box",
			"prompt_key": "exploration.prompt.inspect", "position": Vector2(200, 300),
			"radius": 500.0, "solid_half_extents": Vector2(10, 10)}]}
	var sliding = World.from_layout(side).value
	sliding.integrate(Vector2(1, 0), 10.0)
	check.call(is_equal_approx(sliding.position().x, 180.0), "object body stops movement")
	sliding.integrate(Vector2(1, -1), 1.0)
	check.call(is_equal_approx(sliding.position().x, 180.0) and sliding.position().y < 300.0,
		"player slides along object body")
	var ghost = Fixtures.lab_layout()
	ghost.interactables[0].solid_half_extents = Vector2.ZERO
	var passable = World.from_layout(ghost).value
	passable.integrate(Vector2(0, -1), 10.0)
	check.call(passable.position().y < 300.0, "zero-extent object does not block movement")

func _validation(check: Callable) -> void:
	check.call(not World.from_layout(null).ok, "null layout rejected")
	check.call(not World.from_layout({}).ok, "missing player rejected")
	var layout := Fixtures.lab_layout()
	layout.erase("walls")
	check.call(World.from_layout(layout).ok, "walls section is optional")
	layout = Fixtures.lab_layout()
	layout.extra = true
	check.call(not World.from_layout(layout).ok, "unknown layout field rejected")
	layout = Fixtures.lab_layout()
	layout.player.extra = true
	check.call(not World.from_layout(layout).ok, "unknown player field rejected")
	layout = Fixtures.lab_layout()
	layout.erase("interactables")
	check.call(not World.from_layout(layout).ok, "missing interactables rejected")
	layout = Fixtures.lab_layout()
	layout.player.speed = 0.0
	check.call(not World.from_layout(layout).ok, "non-positive speed rejected")
	layout = Fixtures.lab_layout()
	layout.player.speed = NAN
	check.call(not World.from_layout(layout).ok, "non-finite speed rejected")
	layout = Fixtures.lab_layout()
	layout.player.spawn = Vector2(INF, 0)
	check.call(not World.from_layout(layout).ok, "non-finite spawn rejected")
	layout = Fixtures.lab_layout()
	layout.player.half_extents = Vector2(0, 10)
	check.call(not World.from_layout(layout).ok, "zero player extent rejected")
	layout = Fixtures.lab_layout()
	layout.walls = "wall"
	check.call(not World.from_layout(layout).ok, "non-array walls rejected")
	layout = Fixtures.lab_layout()
	layout.walls.append(Rect2(0, 0, 0, 10))
	check.call(not World.from_layout(layout).ok, "zero-size wall rejected")
	layout = Fixtures.lab_layout()
	layout.walls.append(17)
	check.call(not World.from_layout(layout).ok, "non-rect wall rejected")
	layout = Fixtures.lab_layout()
	layout.interactables[0].erase("prompt_key")
	check.call(not World.from_layout(layout).ok, "missing prompt key rejected")
	layout = Fixtures.lab_layout()
	layout.interactables[0].extra = true
	check.call(not World.from_layout(layout).ok, "unknown item field rejected")
	layout = Fixtures.lab_layout()
	layout.interactables[0].target_id = "Bad Id"
	check.call(not World.from_layout(layout).ok, "invalid target ID rejected")
	layout = Fixtures.lab_layout()
	layout.interactables.append(layout.interactables[0].duplicate(true))
	check.call(not World.from_layout(layout).ok, "duplicate target ID rejected")
	layout = Fixtures.lab_layout()
	layout.interactables[0].radius = 0.0
	check.call(not World.from_layout(layout).ok, "non-positive radius rejected")
	layout = Fixtures.lab_layout()
	layout.interactables[0].blocks_sight = "yes"
	check.call(not World.from_layout(layout).ok, "non-boolean sight flag rejected")
	layout = Fixtures.lab_layout()
	layout.interactables[0].solid_half_extents = Vector2(-1, 1)
	check.call(not World.from_layout(layout).ok, "negative solid extent rejected")
	layout = Fixtures.lab_layout()
	layout.interactables[0].position = "here"
	check.call(not World.from_layout(layout).ok, "non-vector item position rejected")
	var blocked := Fixtures.corridor_layout()
	blocked.player.spawn = Vector2(5, 300)
	var blocked_result := World.from_layout(blocked)
	check.call(blocked_result.code == World.CODE_SPAWN_BLOCKED, "spawn inside wall rejected")
	var overlap := Fixtures.corridor_layout()
	overlap.interactables = [{"target_id": "test.rock",
		"prompt_key": "exploration.prompt.inspect", "position": Vector2(200, 300),
		"radius": 50.0, "solid_half_extents": Vector2(20, 20)}]
	check.call(World.from_layout(overlap).code == World.CODE_SPAWN_BLOCKED,
		"spawn inside object rejected")
	var copy_world = World.from_layout(Fixtures.corridor_layout()).value
	var copy: Dictionary = copy_world.layout()
	copy.walls.clear()
	copy.player.spawn = Vector2(1, 1)
	copy.interactables.clear()
	check.call(copy_world.layout().walls.size() == 4, "layout output does not alias world")
	check.call(copy_world.spawn() == Vector2(200, 300), "spawn unchanged by layout mutation")

func _ranges(check: Callable) -> void:
	var world = World.from_layout(Fixtures.lab_layout()).value
	var out_of_range = world.candidate_for("test.crate")
	check.call(not out_of_range.ok and out_of_range.code == World.CODE_OUT_OF_RANGE,
		"crate out of range at spawn")
	check.call(world.candidate_for("test.missing").code == World.CODE_UNKNOWN_TARGET,
		"unknown target reported separately")
	check.call(world.candidate_for("../escape").code == World.CODE_UNKNOWN_TARGET,
		"unregistered invalid ID stays unknown at world level")
	world.integrate(Vector2(0, -1), 1.0)
	var boundary = world.candidate_for("test.crate")
	check.call(boundary.ok, "range boundary is inclusive")
	check.call(is_equal_approx(boundary.value.distance, 100.0), "boundary distance reported")
	check.call(boundary.value.target_id == "test.crate"
		and boundary.value.prompt_key == "exploration.prompt.inspect",
		"candidate carries stable IDs")
	boundary.value.target_id = "hacked"
	check.call(world.candidate_for("test.crate").value.target_id == "test.crate",
		"candidate output does not alias world")
	world.integrate(Vector2(0, 1), 0.01)
	check.call(not world.candidate_for("test.crate").ok, "just outside boundary excluded")
	world.integrate(Vector2(0, 1), 100.0)
	var none = world.nearest_candidate()
	check.call(not none.ok and none.code == World.CODE_NO_CANDIDATE, "leaving range clears candidates")
	var tie = World.from_layout(Fixtures.tie_layout()).value
	check.call(tie.nearest_candidate().value.target_id == "test.alpha",
		"equal distance resolves deterministically")

func _occlusion(check: Callable) -> void:
	var blocked = World.from_layout(Fixtures.occlusion_layout(Vector2(200, 300))).value
	var hidden = blocked.candidate_for("test.npc")
	check.call(not hidden.ok and hidden.code == World.CODE_OCCLUDED, "wall blocks line of sight")
	check.call(blocked.candidate_for("test.crate").ok, "clear target remains available")
	check.call(blocked.nearest_candidate().value.target_id == "test.crate",
		"nearest candidate skips occluded target")
	var walk = World.from_layout(Fixtures.occlusion_layout(Vector2(250, 480))).value
	var around = walk.candidate_for("test.npc")
	check.call(around.ok and around.value.distance < 250.0,
		"walking around wall clears line of sight")
