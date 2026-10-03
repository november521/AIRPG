extends RefCounted
const MAIN = preload("res://bootstrap/manor_play.tscn")

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
	service.set_enabled(false)
	check.call(service.read_focus().is_empty(), "INTERACT SCENE: blocked input clears focus")
	play.queue_free()
	await tree.process_frame
