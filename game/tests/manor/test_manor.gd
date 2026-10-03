extends RefCounted

const World = preload("res://presentation/manor/world.tscn")
const Main = preload("res://bootstrap/manor_play.tscn")
const WalkSession = preload("res://application/exploration/walk_session.gd")
const Player = preload("res://presentation/exploration/player.gd")
const RoomMap = preload("res://presentation/shell/manor_room_map.gd")
var checks: int = 0
var failures: int = 0
var _world: Node3D
var _player: Player
var _session := WalkSession.new()
var _started: int = 0

var _tree: SceneTree
var _verify: Callable

func _check(condition: bool, message: String) -> void:
	checks += 1
	_verify.call(condition, message)
	if not condition:
		failures += 1
		push_error("FAIL: " + message + (" at " + str(_player.position) if is_instance_valid(_player) else ""))

func _frames(count: int) -> void:
	for index: int in count:
		await _tree.physics_frame

func _walk(start: Vector3, yaw: float, frames: int, axis: Vector2 = Vector2.UP) -> void:
	_player.place_at(start, yaw)
	await _frames(20)
	_session.set_movement(axis)
	await _frames(frames)
	_session.stop()
	await _frames(3)

func run(verify: Callable, tree: SceneTree) -> void:
	_tree = tree
	_verify = verify
	var rooms: Array[Dictionary] = [
		{"id": "outside", "point": Vector3(-8.05, -.39, -1.64)},
		{"id": "porch", "point": Vector3(5.4, .1, 3.9)},
		{"id": "reception", "point": Vector3(-4.4, .1, 3.9)},
		{"id": "kitchen", "point": Vector3(.6, .1, 3.9)},
		{"id": "hall", "point": Vector3(-.7, .1, -2.0)},
		{"id": "emilia_bedroom", "point": Vector3(-5.2, .1, -5.7)},
		{"id": "emilia_study", "point": Vector3(-4.0, .1, -10.8)},
		{"id": "doctor_bedroom", "point": Vector3(3.0, .1, -9.3)},
		{"id": "doctor_study", "point": Vector3(4.5, .1, -2.9)},
		{"id": "bathroom", "point": Vector3(-.7, .1, -11.0)},
		{"id": "cellar_stairs", "point": Vector3(-5.2, -.7, -10.7)},
		{"id": "cellar", "point": Vector3(-4.4, -2.7, -10.7)},
	]
	for room: Dictionary in rooms:
		_check(RoomMap.room_id(room.point) == room.id, "room mapping: " + room.id)
		_check(tr("ui.room." + room.id) != "ui.room." + room.id, "room name localized: " + room.id)
		_check(tr("ui.room_note." + room.id) != "ui.room_note." + room.id, "room note localized: " + room.id)
	_world = World.instantiate()
	_tree.root.add_child(_world)
	_player = _world.get_node("Player")
	_player.configure(_session)
	await _frames(30)
	_check(_player.is_on_floor() and absf(_player.position.y + .46) < .04, "spawn supported by outside grade")
	_check(_world.get_node("Model").find_children("*", "StaticBody3D", true, false).size() > 0, "native GLB static collision")
	_check(_world.find_child("MS_Complete_CrossGable_Roof", true, false) != null, "complete roof visible")
	_check(_world.find_child("MS_HallMain_Ceiling", true, false) != null, "ceiling retained")
	_check(_world.find_child("MS_SideEntry_StoneStep_3", true, false) != null, "three side treads retained")
	await _walk(Vector3(-8.05, -.39, -1.64), -PI / 2, 80)
	_check(_player.position.x > -5.4 and _player.is_on_floor() and absf(_player.position.y) < .04, "outside to hall through side door and 3 stairs")
	await _walk(Vector3(-4.9, .08, -1.64), PI / 2, 85)
	_check(_player.position.x < -7.5 and absf(_player.position.y + .46) < .04, "side stairs descend to outside")
	# Traverse every interior opening from a point outside its door-leaf sweep.
	var doors: Array[Dictionary] = [
		{"id": "Emilia bedroom", "point": Vector3(-1.3, .08, -5.28), "yaw": PI / 2, "axis": 0, "bound": -2.8, "less": true},
		{"id": "Doctor bedroom", "point": Vector3(-.1, .08, -7.52), "yaw": -PI / 2, "axis": 0, "bound": 1.5, "less": false},
		{"id": "Doctor study", "point": Vector3(-.1, .08, -2.84), "yaw": -PI / 2, "axis": 0, "bound": 1.5, "less": false},
		{"id": "Reception", "point": Vector3(-4.04, .08, -1.2), "yaw": PI, "axis": 2, "bound": .7, "less": false},
		{"id": "Kitchen", "point": Vector3(-.68, .08, -1.2), "yaw": PI, "axis": 2, "bound": .7, "less": false},
		{"id": "Reception to kitchen", "point": Vector3(-3.25, .08, 3.08), "yaw": -PI / 2, "axis": 0, "bound": -1.25, "less": false},
		{"id": "Emilia study", "point": Vector3(-3.6, .08, -7.1), "yaw": 0.0, "axis": 2, "bound": -8.8, "less": true},
		{"id": "Bathroom", "point": Vector3(-.68, .08, -8.4), "yaw": 0.0, "axis": 2, "bound": -9.8, "less": true},
		{"id": "Main porch entry", "point": Vector3(4.5, .10, 2.84), "yaw": PI / 2, "axis": 0, "bound": 2.5, "less": true},
	]
	for door: Dictionary in doors:
		await _walk(door.point, door.yaw, 55)
		var coordinate: float = _player.position[door.axis]
		_check(coordinate < door.bound if door.less else coordinate > door.bound, "walk through " + door.id)
	await _walk(Vector3(-4.8, .08, -1.64), 0, 45)
	_check(_player.position.z > -2.96, "solid bedroom partition blocks capsule")
	await _walk(Vector3(5.4, -.39, 9.25), 0, 70)
	_check(_player.position.z < 7.4 and _player.position.y > -.04, "front veranda stair ascent")
	await _walk(Vector3(-5.2, .08, -8.8), 0, 112)
	print("CELLAR_DESCENT: ", _player.position)
	_check(_player.position.z < -12.0 and _player.position.y < -2.45, "cellar stairs descend with headroom")
	_session.set_movement(Vector2.DOWN)
	await _frames(122)
	_session.stop()
	print("CELLAR_ASCENT: ", _player.position)
	_check(_player.position.z > -9.0 and _player.position.y > -.10, "cellar stairs ascend without snagging")
	_player.place_at(Vector3(-3.4, -2.65, -10.7), 0)
	await _frames(30)
	_check(_player.is_on_floor() and absf(_player.position.y + 2.72) < .04, "cellar floor supports capsule")
	_world.queue_free()
	await _tree.process_frame
	var main := Main.instantiate()
	_tree.root.add_child(main)
	_check(main.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and main.camera.get_parent() == main.player, "first person perspective")
	main.apply_look(Vector2(100, -100000))
	_check(is_equal_approx(main.camera.rotation.x, deg_to_rad(80)), "camera pitch clamp")
	main.reset_at_side_entry()
	_check(main.player.position.is_equal_approx(Vector3(-8.05, -.39, -1.64)), "reset goes to side entry")
	main.visit_cellar()
	_check(main.player.position.y < -2.6 and main.session.movement() == Vector2.ZERO, "cellar shortcut stops movement")
	main._hud.show_location(Vector3(4.5, .1, -2.9), true)
	_check(main._hud.get_node("Layout/Location").text == tr("ui.room.doctor_study"), "entered room name shown")
	_check(main._hud.get_node("Layout/Note").text == tr("ui.room_note.doctor_study"), "entered room mystery note shown")
	_check(tr("walk.help") != "walk.help", "help is localized")
	var view: Dictionary = main.character_service.read_character()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.keycode = KEY_E
	key.pressed = true
	main._input(key)
	_check(main.character_hud.is_open(), "E opens dossier")
	_check(main.character_hud._tabs.size() == 3, "notebook categories visible")
	_check(main.character_hud._meter.visible == false and main.character_hud._dimmer.visible, "notebook replaces exploration HUD")
	_check(main.session.movement() == Vector2.ZERO and main._controls.movement() == Vector2.ZERO, "dossier stops walk session")
	key.echo = true
	main._input(key)
	_check(main.character_hud.is_open(), "E repeat ignored")
	main.character_hud._tabs[1].pressed.emit()
	_check(main.character_hud._other_pages[0].visible and not main.character_hud._item_page.visible, "clues tab shows honest empty state")
	main.character_hud._tabs[0].pressed.emit()
	main.character_hud._use.pressed.emit()
	view = main.character_service.read_character()
	_check(view.hp == 85 and view.inventory.demo_bandage == 2, "integrated item use atomic")
	_check(main.character_hud._hp.value == 85 and main.character_hud._hp_number.text == "85", "vital meter follows item use")
	main.reset_at_side_entry()
	_check(main.character_service.read_character() == view, "reset location keeps inventory")
	main.visit_cellar()
	_check(main.character_service.read_character() == view, "cellar travel keeps inventory")
	key.echo = false
	main._input(key)
	_check(not main.character_hud.is_open(), "E closes dossier")
	_check(main.character_hud._meter.visible and main.character_hud._bag.visible, "exploration HUD returns after closing")
	main._input(key)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	main._input(escape)
	_check(not main.character_hud.is_open(), "Esc closes notebook")
	var returned: Array[String] = []
	main.route_requested.connect(func(route: String) -> void: returned.append(route))
	main._return_to_archive()
	_check(returned == ["story_archive"], "return goes to archive")
	await _check_npcs(main)
	main.queue_free()
	await _tree.process_frame
	print("AIRPG_STRUCTURE_WALK_TESTS: %d checks, %d failures" % [checks, failures])

func _check_npcs(main: Node3D) -> void:
	_check(main.npc_actors.size() == 2, "two explicitly synthetic NPC previews")
	var roster: Array[Dictionary] = main.npc_presence.roster()
	roster[0].name_key = "changed"
	_check(main.npc_presence.roster()[0].name_key != "changed", "NPC roster deep copied")
	_check(not main.npc_presence.begin_greeting("missing", 0, true).ok, "unknown NPC rejected")
	var id: String = main.npc_actors[0].npc_id
	_check(not main.npc_presence.begin_greeting(id, 3, true).ok, "distant greeting rejected")
	_check(not main.npc_presence.begin_greeting(id, NAN, true).ok, "invalid greeting distance rejected")
	_check(not main.npc_presence.begin_greeting(id, 1, false).ok, "occluded greeting rejected")
	var initial: Vector3 = main.npc_actors[0].position
	main.npc_actors[0]._target = initial + Vector3(0.7, 0, 0)
	main.npc_actors[0]._wait = 0
	await _frames(80)
	_check(main.npc_actors[0].position.distance_to(initial) > 0.1, "NPC autonomously wanders")
	for actor: CharacterBody3D in main.npc_actors:
		_check(actor.is_on_floor() and absf(actor.position.y) < 0.05, "NPC supported by actual manor floor")
		actor.set_physics_process(false)
	main.npc_actors[0].position = Vector3(-4.6, 0, 2.0)
	main.player.place_at(Vector3(-4.6, 0, 3.5), 0)
	main.camera.rotation.x = 0
	await _frames(2)
	_check(main._find_candidate() == main.npc_actors[0], "nearby facing NPC selected")
	main._open_greeting()
	_check(main.npc_hud.is_open() and main.npc_hud._line.text == tr("npc.greeting"), "localized greeting shown")
	_check(main.npc_presence.paused(id) and main.session.movement() == Vector2.ZERO,
		"speaking NPC and player pause")
	_check(not main.npc_presence.begin_greeting(id, 1, true).ok, "repeated greeting rejected")
	main._close_greeting()
	_check(not main.npc_hud.is_open() and not main.npc_presence.paused(id), "close releases speaker")
	main.player.place_at(Vector3(-5.0, 0, -1.0), PI)
	main.npc_actors[0].position = Vector3(-5.0, 0, 0.5)
	await _frames(2)
	_check(not main._can_see(main.npc_actors[0]), "actual reception partition blocks greeting")
	
