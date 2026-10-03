extends RefCounted
## Explicit scene bindings and prototype fixtures. No name-driven business discovery.
## Doors, the greybox pickups and the assembly live here; the placement contract and the observed
## objects live in manor_items, and the delivered props in manor_props.
const Result = preload("res://shared/result.gd")
const Service = preload("res://application/exploration/interaction_service.gd")
const Inventory = preload("res://application/ports/pickup_inventory.gd")
const Audio = preload("res://application/ports/audio_port.gd")
const State = preload("res://domain/exploration/door_state.gd")
const Door = preload("res://application/exploration/interactions/door_interaction.gd")
const Pickup = preload("res://application/exploration/interactions/pickup_interaction.gd")
const Probe = preload("res://infrastructure/exploration/camera_interaction_probe.gd")
const Clearance = preload("res://infrastructure/exploration/physics_door_clearance.gd")
const ImportedDoorCollision = preload("res://infrastructure/exploration/imported_door_collision.gd")
const DoorView = preload("res://presentation/exploration/interactions/door_view.gd")
const PickupView = preload("res://presentation/exploration/interactions/pickup_view.gd")
const PICKUP = preload("res://presentation/exploration/interactions/pickup.tscn")
const Inspect = preload("res://application/exploration/interactions/inspect_interaction.gd")
const InspectView = preload("res://presentation/manor/inspect_object_view.gd")
const Items = preload("res://bootstrap/manor_items.gd")
const Props = preload("res://bootstrap/manor_props.gd")
const Caption = preload("res://presentation/manor/narrative_caption.gd")
const REACH: float = 2.4
const DOORS: Array[Dictionary] = [
	{"id": "manor.door.side", "hinge": "MS_SideEntry_Hinge", "closed": -90.0, "name": "interaction.door.side"},
	{"id": "manor.door.main", "hinge": "MS_MainEntry_Hinge", "closed": -90.0, "name": "interaction.door.main"},
	{"id": "manor.door.bathroom", "hinge": "MS_Bathroom_Door_Hinge", "closed": 0.0, "name": "interaction.door.bathroom"},
	{"id": "manor.door.doctor_bedroom", "hinge": "MS_DoctorBedroom_Door_Hinge", "closed": -90.0, "name": "interaction.door.doctor_bedroom"},
	{"id": "manor.door.doctor_study", "hinge": "MS_DoctorStudy_Door_Hinge", "closed": -90.0, "name": "interaction.door.doctor_study"},
	{"id": "manor.door.emilia_bedroom", "hinge": "MS_EmiliaBedroom_Door_Hinge", "closed": -90.0, "name": "interaction.door.emilia_bedroom"},
	{"id": "manor.door.emilia_study", "hinge": "MS_EmiliaStudy_Door_Hinge", "closed": 0.0, "name": "interaction.door.emilia_study"},
	{"id": "manor.door.kitchen", "hinge": "MS_Kitchen_Door_Hinge", "closed": 0.0, "name": "interaction.door.kitchen"},
	{"id": "manor.door.reception", "hinge": "MS_Reception_Door_Hinge", "closed": 0.0, "name": "interaction.door.reception"},
	{"id": "manor.door.reception_kitchen", "hinge": "MS_Reception_Kitchen_Door_Hinge", "closed": -90.0, "name": "interaction.door.reception_kitchen"},
]
const PICKUPS: Array[Dictionary] = [
	{"id": "manor.pickup.hall_bandage", "item": "demo_bandage", "quantity": 2, "name": "item.bandage", "position": Vector3(-4.3, 0.24, -1.6)},
	{"id": "manor.pickup.reception_lamp", "item": "demo_lamp", "quantity": 1, "name": "item.lamp", "position": Vector3(-4.3, 0.24, 1.6)},
	# The greybox token used to stand at the cellar's centre, which is where the generator's case now
	# is (its south face measures z -7.752). It moved in front of that face instead of being buried.
	{"id": "manor.pickup.cellar_token", "item": "demo_token", "quantity": 1, "name": "item.token", "position": Vector3(-2.9, -2.99, -7.0)},
]

static func build(world: Node3D, camera: Camera3D, player: CollisionObject3D, inventory: Inventory,
		audio: Audio = null) -> Result:
	var handlers: Dictionary = {}
	var bindings: Dictionary = {}
	var model: Node3D = world.get_node("Model")
	# Validate every source binding before changing the imported scene.
	var leaves: Array[MeshInstance3D] = []
	var handles: Array[MeshInstance3D] = []
	for spec: Dictionary in DOORS:
		var hinge: Node3D = model.find_child(spec.hinge, true, false)
		if hinge == null or _leaf(hinge) == null:
			return Result.failure("MANOR_DOOR_BINDING_MISSING")
		leaves.append(_leaf(hinge))
		handles.append(_handle(hinge))
	var collision_result: Result = ImportedDoorCollision.strip(model, leaves, handles)
	if not collision_result.ok:
		return collision_result
	# The concealed cellar entrance is only interactive while the model still ships both halves of it.
	if (model.find_child(Items.PRY_BOARDS, true, false) == null
			or model.find_child(Items.PRY_BLOCKER, true, false) == null):
		return Result.failure("MANOR_PRY_BINDING_MISSING")
	Items.remove_baked(model, Items.LEAD_CASKET_GROUP, Items.LEAD_CASKET_MESHES)
	Items.remove_baked(model, Items.DIARY_PROP, Items.DIARY_PROP_MESHES)
	# The line the pried-up entrance tells and the props' own lines live on the same layer, so it is
	# created here, before anything that may put a line on it, and handed to both.
	var captions := Caption.new()
	captions.name = Props.CAPTION_HOST_NAME
	world.add_child(captions)
	for spec: Dictionary in DOORS:
		var bound: Dictionary = _door(model, spec, player, audio)
		handlers[spec.id] = bound.handler
		bindings[bound.body] = spec.id
		bindings[bound.target] = spec.id
	for spec: Dictionary in PICKUPS:
		var handler := Pickup.new(inventory, spec.id, spec.item, spec.quantity, spec.name)
		var view: PickupView = PICKUP.instantiate()
		view.name = spec.id.replace(".", "_")
		world.add_child(view)
		view.position = spec.position
		view.configure(handler, spec.name, spec.quantity)
		view.attach_audio(audio)
		handlers[spec.id] = handler
		bindings[view.get_node("Target")] = spec.id
	Items.place_inspect(world, Items.SilverUrn, Items.SILVER_BOX_ID, Items.SILVER_BOX_POSITION,
		player, handlers, bindings, Items.SILVER_BOX_CAPTIONS, Inspect.DEFAULT_ACTION_KEYS, null, [], [],
		Items.SILVER_BOX_VISUAL, audio)
	var wallet: InspectView = Items.place_inspect(world, Items.Wallet, Items.WALLET_ID,
		Items.WALLET_POSITION, player, handlers, bindings, Items.WALLET_CAPTIONS,
		Items.WALLET_ACTION_KEYS, null, Items.WALLET_EMPTIED_ACTION_KEYS, [], Items.WALLET_VISUAL,
		audio)
	wallet.handler().enable_keep(inventory, Items.WALLET_ID, String(Items.PolaroidPhoto.id), 1)
	# The diary is observed inside the locked cabinet and only becomes aimable once that is open, so
	# the cabinet is placed last and gets the diary's own ray target to hand over.
	var diary: InspectView = Items.place_inspect(world, Items.DoctorDiary, Items.DIARY_ID,
		Items.DIARY_POSITION, player, handlers, bindings, Items.DIARY_CAPTIONS,
		Items.DIARY_ACTION_KEYS, Items.diary_state(), Items.DIARY_EMPTIED_ACTION_KEYS,
		Items.DIARY_EMPTIED_CAPTIONS, Items.DIARY_VISUAL, audio)
	diary.handler().enable_keep(inventory, Items.DIARY_ID, String(Items.DoctorDiary.id), 1)
	Items.place_cabinet(world, inventory, diary.get_node("Target") as CollisionObject3D, model, handlers,
		bindings, audio)
	# The boards over the new cellar stairwell. They ship with the model, so they are bound rather
	# than placed: prying them is a state change, not a new object.
	Items.place_pry_entrance(world, model, inventory, handlers, bindings, captions, audio)
	# The eight pickups, the radio and the generator. The caption layer they share is the one this
	# function already built, so a receipt can never find it missing.
	Props.place_props(world, inventory, player, handlers, bindings, captions, audio)
	var service := Service.new(Probe.new(camera, player, bindings, REACH), REACH)
	for id: String in handlers:
		var registration: Result = service.register_target(id, handlers[id])
		if not registration.ok:
			return registration
	return Result.success(service)

static func _leaf(hinge: Node3D) -> MeshInstance3D:
	return hinge.find_child("*_SolidTimberLeaf", true, false) as MeshInstance3D

static func _handle(hinge: Node3D) -> MeshInstance3D:
	return hinge.find_child("*_BrassHandle", true, false) as MeshInstance3D

static func _door(model: Node3D, spec: Dictionary, player: Node3D, audio: Audio) -> Dictionary:
	var hinge: Node3D = model.find_child(spec.hinge, true, false)
	var leaf: MeshInstance3D = _leaf(hinge)
	# Delivered models disagree about the authored pose, so they declare it: V4-and-later carry the
	# swing angle as extras and ship every leaf closed, while older exports ship the leaf already
	# open and expect the manifest's closed angle. The swing side still follows the player.
	var extras: Dictionary = hinge.get_meta("extras", {})
	var open_yaw: float = hinge.rotation.y
	var closed_yaw: float = deg_to_rad(spec.closed)
	if extras.has("angle_open_deg"):
		closed_yaw = hinge.rotation.y
		var swing: float = absf(deg_to_rad(float(extras.angle_open_deg)))
		open_yaw = closed_yaw + swing if swing > 0.0 else closed_yaw + PI / 2.0
	# Older manor exports may still contain a visual handle.
	var handle: MeshInstance3D = _handle(hinge)
	if handle != null:
		handle.free()
	var body := AnimatableBody3D.new()
	body.name = spec.id.replace(".", "_")
	body.sync_to_physics = false
	body.collision_layer = 1
	body.collision_mask = 6
	hinge.get_parent().add_child(body)
	body.transform = hinge.transform
	hinge.reparent(body, false)
	hinge.transform = Transform3D.IDENTITY
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var bounds: AABB = leaf.get_aabb()
	box.size = bounds.size * leaf.scale.abs()
	shape.shape = box
	shape.position = leaf.transform * bounds.get_center()
	body.add_child(shape)
	# Broad ray target follows the leaf, while physical blocking keeps its thin box.
	var target := Area3D.new()
	target.name = "RayTarget"
	target.collision_layer = 8
	target.collision_mask = 0
	target.monitoring = false
	body.add_child(target)
	var target_shape := CollisionShape3D.new()
	var target_box := BoxShape3D.new()
	target_box.size = box.size + Vector3(0.2, 0.28, 0.62)
	target_shape.shape = target_box
	target_shape.position = shape.position
	target.add_child(target_shape)
	# A small hinge-side volume remains easy to aim at when the leaf lies along a wall.
	var hinge_target := CollisionShape3D.new()
	var hinge_box := BoxShape3D.new()
	hinge_box.size = Vector3(0.6, 1.5, 0.6)
	hinge_target.shape = hinge_box
	hinge_target.position = Vector3(0.0, 1.1, 0.0)
	target.add_child(hinge_target)
	var handler := Door.new(State.new(false), Clearance.new(body, shape, closed_yaw, open_yaw), spec.name,
		open_yaw, _open_yaw_for_player.bind(body, shape, player, closed_yaw, open_yaw))
	var view := DoorView.new()
	body.add_child(view)
	view.configure(handler, body, closed_yaw)
	view.attach_audio(audio)
	return {"handler": handler, "body": body, "target": target}

static func _open_yaw_for_player(body: AnimatableBody3D, shape: CollisionShape3D, player: Node3D,
		closed_yaw: float, open_yaw: float) -> float:
	var relative: Vector3 = body.global_transform.basis.inverse() * (player.global_position - body.global_position)
	var radial: Vector3 = shape.position
	# Godot's positive Y rotation moves a local radial point along this tangent.
	var tangent: Vector3 = Vector3(radial.z, 0.0, -radial.x)
	var opening_delta: float = absf(wrapf(open_yaw - closed_yaw, -PI, PI))
	# The leaf's center must move opposite to the player's side of the door.
	var chosen_delta: float = -opening_delta if tangent.dot(relative) > 0.0 else opening_delta
	return closed_yaw + chosen_delta
