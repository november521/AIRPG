extends RefCounted
const MAIN = preload("res://bootstrap/manor_play.tscn")
const GeneratorView = preload("res://presentation/manor/generator.gd")

func run(check: Callable, tree: SceneTree) -> void:
	var play := MAIN.instantiate()
	tree.root.add_child(play)
	play.set_physics_process(false)
	play.player.set_physics_process(false)
	play.player.place_at(Vector3(-7.2, 0.08, -1.64), -PI / 2)
	for frame: int in 3:
		await tree.physics_frame
	var service = play.interaction_service
	service.set_enabled(true)
	service.refresh_focus()
	var focus: Dictionary = service.read_focus()
	check.call(focus.get("target_id") == "manor.door.side", "INTERACT SCENE: real ray focuses closed side door")
	var side: AnimatableBody3D = play.find_child("manor_door_side", true, false)
	check.call(side != null and is_equal_approx(side.rotation.y, -PI / 2), "INTERACT SCENE: visible door and collision initially closed")
	check.call(service.interact("manor.door.side", 0).ok, "INTERACT SCENE: real physics allows door opening outside sweep")
	for frame: int in 30:
		await tree.physics_frame
	var door_view: Node = side.get_child(side.get_child_count() - 1)
	var open_yaw: float = door_view._handler.read().open_yaw
	check.call(is_equal_approx(side.rotation.y, open_yaw), "INTERACT SCENE: collider reaches animated door model pose")
	play.player.place_at(Vector3(-5.75, 0.08, -1.65), 0)
	play.camera.look_at(side.to_global(Vector3(0.55, 1.1, 0)))
	for frame: int in 2:
		await tree.physics_frame
	var blocked = door_view._handler.execute(1) # Check swept clearance independent of aim.
	check.call(blocked.code == "DOOR_BLOCKED", "INTERACT SCENE: actor in swept volume blocks closing")
	check.call(is_equal_approx(side.rotation.y, open_yaw), "INTERACT SCENE: failed close leaves geometry open")
	play.player.place_at(Vector3(-5.0, 0.08, -1.6), 0)
	var pickup: Node3D = play.find_child("manor_pickup_hall_bandage", true, false)
	play.camera.look_at(pickup.global_position)
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.hall_bandage", "INTERACT SCENE: aim can focus floor pickup")
	check.call(service.interact("manor.pickup.hall_bandage", 0).ok, "INTERACT SCENE: pickup commits by shared service")
	check.call(not pickup.visible and pickup.get_node("Target").collision_layer == 0, "INTERACT SCENE: receipt disables visual and ray target together")
	check.call(play.character_service.read_character().inventory.demo_bandage == 5, "INTERACT SCENE: inventory quantity increases by two")
	play.character_service.preview_action("reset", 1)
	check.call(not pickup.visible, "INTERACT SCENE: preview reset cannot respawn claimed object")
	var urn: Node3D = play.find_child("manor_pickup_silver_urn", true, false)
	check.call(urn != null, "INTERACT SCENE: urn world instance is implicitly bound")
	play.player.place_at(Vector3(-5.0, 0.08, -0.8), 0)
	play.camera.look_at(urn.global_position + Vector3(0, 0.04, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.silver_urn", "INTERACT SCENE: aim can focus the urn")
	check.call(service.interact("manor.pickup.silver_urn", focus.get("revision", -1)).ok, "INTERACT SCENE: urn pickup commits by shared service")
	check.call(play.character_service.read_character().inventory.silver_urn == 1, "INTERACT SCENE: urn reaches the notebook")
	check.call(not urn.visible and urn.get_node("Target").collision_layer == 0, "INTERACT SCENE: urn receipt hides visual and ray target together")
	check.call(play.character_service.discard_item("silver_urn", play.character_service.read_character().revision).code == "ITEM_PROTECTED", "INTERACT SCENE: picked-up urn stays protected")
	var diary: Node3D = play.find_child("manor_pickup_doctor_diary", true, false)
	check.call(diary != null, "INTERACT SCENE: doctor diary is placed and bound")
	play.player.place_at(Vector3(2.4, 0.0, -4.4), -PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(diary.global_position + Vector3(0, 0.03, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.doctor_diary", "INTERACT SCENE: aim can focus the diary")
	check.call(service.interact("manor.pickup.doctor_diary", focus.get("revision", -1)).ok, "INTERACT SCENE: diary pickup commits")
	check.call(play.character_service.read_character().inventory.doctor_diary == 1, "INTERACT SCENE: diary reaches the notebook")
	check.call(not diary.visible and diary.get_node("Target").collision_layer == 0, "INTERACT SCENE: diary receipt hides visual and ray target together")
	var wallet: Node3D = play.find_child("manor_pickup_wallet", true, false)
	check.call(wallet != null, "INTERACT SCENE: reception wallet is placed and bound")
	play.player.place_at(Vector3(-5.5, 0.0, 2.0), PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(wallet.global_position + Vector3(0, 0.02, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.wallet", "INTERACT SCENE: aim can focus the wallet")
	check.call(service.interact("manor.pickup.wallet", focus.get("revision", -1)).ok, "INTERACT SCENE: wallet pickup commits")
	check.call(play.character_service.read_character().inventory.wallet == 1, "INTERACT SCENE: wallet reaches the notebook")
	check.call(not wallet.visible and wallet.get_node("Target").collision_layer == 0, "INTERACT SCENE: wallet receipt hides visual and ray target together")
	var kerosene: Node3D = play.find_child("manor_pickup_kerosene_bottle", true, false)
	check.call(kerosene != null, "INTERACT SCENE: kitchen kerosene bottle is placed and bound")
	play.player.place_at(Vector3(-0.5, 0.0, 2.0), -PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(kerosene.global_position + Vector3(0, 0.22, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.kerosene_bottle", "INTERACT SCENE: aim can focus the kerosene bottle")
	check.call(service.interact("manor.pickup.kerosene_bottle", focus.get("revision", -1)).ok, "INTERACT SCENE: kerosene bottle pickup commits")
	check.call(play.character_service.read_character().inventory.kerosene_bottle == 1, "INTERACT SCENE: kerosene bottle reaches the notebook")
	check.call(not kerosene.visible and kerosene.get_node("Target").collision_layer == 0, "INTERACT SCENE: kerosene bottle receipt hides visual and ray target together")
	var manor_key: Node3D = play.find_child("manor_pickup_manor_key", true, false)
	check.call(manor_key != null, "INTERACT SCENE: manor key is placed and bound")
	var key_bounds: AABB = _mesh_bounds(manor_key)
	check.call(key_bounds.size.length() > 0.1 and key_bounds.position.y > -0.02
		and key_bounds.end.y < 0.2 and key_bounds.get_center().length() < 0.15,
		"INTERACT SCENE: manor key geometry is visible beside its pickup target")
	play.player.place_at(Vector3(4.2, 0.0, -4.4), -PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(manor_key.global_position + Vector3(0, 0.04, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.manor_key", "INTERACT SCENE: aim can focus the manor key")
	check.call(service.interact("manor.pickup.manor_key", focus.get("revision", -1)).ok, "INTERACT SCENE: manor key pickup commits")
	check.call(play.character_service.read_character().inventory.manor_key == 1, "INTERACT SCENE: manor key reaches the notebook")
	var fuse: Node3D = play.find_child("manor_pickup_fuse", true, false)
	check.call(fuse != null, "INTERACT SCENE: cellar fuse is placed and bound")
	play.player.place_at(Vector3(-2.8, -2.48, -10.6), PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(fuse.global_position + Vector3(0, 0.08, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.fuse", "INTERACT SCENE: aim can focus the fuse")
	check.call(service.interact("manor.pickup.fuse", focus.get("revision", -1)).ok, "INTERACT SCENE: fuse pickup commits")
	check.call(play.character_service.read_character().inventory.fuse == 1, "INTERACT SCENE: fuse reaches the notebook")
	var coil: Node3D = play.find_child("manor_pickup_copper_wire_coil", true, false)
	check.call(coil != null, "INTERACT SCENE: cellar copper wire coil is placed and bound")
	play.player.place_at(Vector3(-3.7, -2.72, -10.0), PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(coil.global_position + Vector3(0, 0.04, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.copper_wire_coil", "INTERACT SCENE: aim can focus the copper wire coil")
	check.call(service.interact("manor.pickup.copper_wire_coil", focus.get("revision", -1)).ok, "INTERACT SCENE: copper wire coil pickup commits")
	check.call(play.character_service.read_character().inventory.copper_wire_coil == 1, "INTERACT SCENE: copper wire coil reaches the notebook")
	check.call(not coil.visible and coil.get_node("Target").collision_layer == 0, "INTERACT SCENE: copper wire coil receipt hides visual and ray target together")
	var tape: Node3D = play.find_child("manor_pickup_electrical_tape", true, false)
	check.call(tape != null, "INTERACT SCENE: cellar electrical tape is placed and bound")
	play.player.place_at(Vector3(-3.0, -2.72, -12.0), PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(tape.global_position + Vector3(0, 0.02, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.electrical_tape", "INTERACT SCENE: aim can focus the electrical tape")
	check.call(service.interact("manor.pickup.electrical_tape", focus.get("revision", -1)).ok, "INTERACT SCENE: electrical tape pickup commits")
	check.call(play.character_service.read_character().inventory.electrical_tape == 1, "INTERACT SCENE: electrical tape reaches the notebook")
	var lantern: Node3D = play.find_child("manor_pickup_lantern", true, false)
	check.call(lantern != null, "INTERACT SCENE: cellar lantern is placed and bound")
	play.player.place_at(Vector3(-4.4, -2.72, -10.2), PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(lantern.global_position + Vector3(0, 0.1, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.lantern", "INTERACT SCENE: aim can focus the lantern")
	check.call(service.interact("manor.pickup.lantern", focus.get("revision", -1)).ok, "INTERACT SCENE: lantern pickup commits")
	check.call(play.character_service.read_character().inventory.lantern == 1, "INTERACT SCENE: lantern reaches the notebook")
	var wrench: Node3D = play.find_child("manor_pickup_wrench", true, false)
	check.call(wrench != null, "INTERACT SCENE: yard wrench is placed and bound")
	play.player.place_at(Vector3(-9.3, -0.46, -7.6), 0.0)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(wrench.global_position + Vector3(0, 0.02, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.wrench", "INTERACT SCENE: aim can focus the wrench")
	check.call(service.interact("manor.pickup.wrench", focus.get("revision", -1)).ok, "INTERACT SCENE: wrench pickup commits")
	check.call(play.character_service.read_character().inventory.wrench == 1, "INTERACT SCENE: wrench reaches the notebook")
	var radio: Node3D = play.find_child("manor_pickup_radio", true, false)
	check.call(radio != null, "INTERACT SCENE: reception radio is placed and bound")
	play.player.place_at(Vector3(-6.8, -0.005, 3.2), PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(radio.global_position + Vector3(0, 0.05, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.radio", "INTERACT SCENE: aim can focus the radio")
	check.call(service.interact("manor.pickup.radio", focus.get("revision", -1)).ok, "INTERACT SCENE: radio pickup commits")
	check.call(play.character_service.read_character().inventory.radio == 1, "INTERACT SCENE: radio reaches the notebook")
	var generator: GeneratorView = play.find_child("manor_device_generator", true, false)
	check.call(generator != null, "INTERACT SCENE: yard generator is placed and bound")
	play.player.place_at(Vector3(-9.2, -0.46, -7.0), PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(generator.global_position + Vector3(0.8, 1.2, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.device.generator", "INTERACT SCENE: aim can focus the generator")
	check.call(not generator.is_running() and not generator.get_node("Running").visible, "INTERACT SCENE: generator starts idle")
	check.call(service.interact("manor.device.generator", focus.get("revision", -1)).ok, "INTERACT SCENE: generator starts by shared service")
	check.call(generator.is_running() and generator.get_node("Running").visible, "INTERACT SCENE: running generator shows its lamp")
	check.call(service.interact("manor.device.generator", 1).ok and not generator.is_running(), "INTERACT SCENE: generator stops again")
	service.set_enabled(false)
	check.call(service.read_focus().is_empty(), "INTERACT SCENE: blocked input clears focus")
	play.queue_free()
	await tree.process_frame

static func _mesh_bounds(scene: Node3D) -> AABB:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for child: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		var relative: Transform3D = scene.global_transform.affine_inverse() * mesh_node.global_transform
		for surface: int in mesh_node.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var placed: Vector3 = relative * vertex
				low = low.min(placed)
				high = high.max(placed)
	return AABB(low, high - low)
