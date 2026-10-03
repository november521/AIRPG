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
	var crowbar: Node3D = play.find_child("manor_pickup_crowbar", true, false)
	check.call(crowbar != null and crowbar.has_node("Visual/CrowbarModel"),
		"INTERACT SCENE: crowbar world state uses imported model")
	play.player.place_at(Vector3(-5.0, 0.08, -1.6), -PI / 2)
	play.camera.look_at(crowbar.global_position + Vector3(0.0, -0.18, 0.0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.crowbar", "INTERACT SCENE: imported crowbar can be targeted")
	check.call(service.interact("manor.pickup.crowbar", 2).ok, "INTERACT SCENE: imported crowbar can be picked up")
	check.call(play.character_service.read_character().inventory.get("crowbar", 0) == 1,
		"INTERACT SCENE: crowbar pickup reaches inventory")
	check.call(play.character_service.hold_item("crowbar").ok and play._held_visual != null,
		"INTERACT SCENE: inventory crowbar enters held state")
	check.call(play._held_visual != null and play._held_visual.has_node("Visual/CrowbarModel"),
		"INTERACT SCENE: held state reuses imported model")
	if play._held_visual == null:
		play.queue_free()
		await tree.process_frame
		return
	play._held_visual._process(0.25)
	check.call(play._held_visual.presentation_state() == "idle", "INTERACT SCENE: held crowbar settles to idle state")
	play.player.velocity = Vector3(3.0, 0.0, 0.0)
	play._held_visual._process(0.2)
	check.call(play._held_visual.presentation_state() == "moving", "INTERACT SCENE: held crowbar reacts to player movement")
	play.player.velocity = Vector3.ZERO
	check.call(play.character_service.release_item().ok and play._held_visual == null,
		"INTERACT SCENE: holstering removes only held presentation")
	check.call(play.character_service.read_character().inventory.get("crowbar", 0) == 1,
		"INTERACT SCENE: holstering preserves inventory")
	play.character_service.hold_item("crowbar")
	check.call(play.character_service.drop_item("crowbar", 3).ok, "INTERACT SCENE: held crowbar can be dropped")
	play._drop_item_in_world("crowbar")
	var dropped: Node3D = play.get_node_or_null("World/manor_drop_0")
	check.call(dropped != null and dropped.item_id() == "crowbar" and dropped.has_node("Visual/CrowbarModel"),
		"INTERACT SCENE: dropped state preserves crowbar identity and model")
	if dropped == null:
		play.queue_free()
		await tree.process_frame
		return
	play.camera.look_at(dropped.global_position + Vector3(0.0, -0.18, 0.0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.drop.0", "INTERACT SCENE: dropped crowbar remains targetable")
	check.call(service.interact("manor.drop.0", 4).ok, "INTERACT SCENE: dropped crowbar can be picked up again")
	check.call(play.character_service.read_character().inventory.get("crowbar", 0) == 1,
		"INTERACT SCENE: re-pickup restores crowbar inventory")
	service.set_enabled(false)
	check.call(service.read_focus().is_empty(), "INTERACT SCENE: blocked input clears focus")
	play.queue_free()
	await tree.process_frame
