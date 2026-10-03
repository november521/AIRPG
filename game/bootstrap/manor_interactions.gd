extends RefCounted
## Explicit scene bindings and prototype fixtures. No name-driven business discovery.
const Result = preload("res://shared/result.gd")
const Service = preload("res://application/exploration/interaction_service.gd")
const Inventory = preload("res://application/ports/pickup_inventory.gd")
const State = preload("res://domain/exploration/door_state.gd")
const Door = preload("res://application/exploration/interactions/door_interaction.gd")
const Pickup = preload("res://application/exploration/interactions/pickup_interaction.gd")
const Probe = preload("res://infrastructure/exploration/camera_interaction_probe.gd")
const Clearance = preload("res://infrastructure/exploration/physics_door_clearance.gd")
const ImportedDoorCollision = preload("res://infrastructure/exploration/imported_door_collision.gd")
const DoorView = preload("res://presentation/exploration/interactions/door_view.gd")
const PickupView = preload("res://presentation/exploration/interactions/pickup_view.gd")
const PICKUP = preload("res://presentation/exploration/interactions/pickup.tscn")
const Crowbar = preload("res://items/data/crowbar.tres")
const SilverUrn = preload("res://items/data/silver_urn.tres")
const DoctorDiary = preload("res://items/data/doctor_diary.tres")
const Wallet = preload("res://items/data/wallet.tres")
const KeroseneBottle = preload("res://items/data/kerosene_bottle.tres")
const ManorKey = preload("res://items/data/manor_key.tres")
const Fuse = preload("res://items/data/fuse.tres")
const CopperWireCoil = preload("res://items/data/copper_wire_coil.tres")
const Wrench = preload("res://items/data/wrench.tres")
const ElectricalTape = preload("res://items/data/electrical_tape.tres")
const Lantern = preload("res://items/data/lantern.tres")
const Radio = preload("res://items/data/radio.tres")
const Generator = preload("res://presentation/manor/generator.tscn")
const GeneratorView = preload("res://presentation/manor/generator.gd")
const Device = preload("res://application/exploration/interactions/device_interaction.gd")
const DeviceState = preload("res://domain/exploration/device_state.gd")
const WorldItem = preload("res://items/world/world_item.gd")
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
	{"id": "manor.pickup.cellar_token", "item": "demo_token", "quantity": 1, "name": "item.token", "position": Vector3(-3.2, -2.48, -10.6)},
]
const CROWBAR_POSITION := Vector3(-4.3, 0.24, 0.0)
# Floor-contact placement: the urn scene sits on its own base, not on a centred box.
const URN_POSITION := Vector3(-4.3, 0.065, -0.8)
# Doctor's study: the room map's study band is z -5.84..0.0 while the floor mesh named
# MS_DoctorStudy_Boards runs z -8.75..-2.92, so the diary goes in the overlap at z -4.4.
const DIARY_POSITION := Vector3(3.4, 0.0, -4.4)
# Reception floor: the room map's reception is z 0.0..7.80 and the MS_Reception_Main_Boards
# mesh runs z -3.89..3.90, so the wallet goes in the overlap at z 2.0.
const WALLET_POSITION := Vector3(-6.5, 0.0, 2.0)
# Kitchen floor, inside the room-map bounds and away from the reception pickup.
const KEROSENE_BOTTLE_POSITION := Vector3(0.5, 0.0, 2.0)
# Provisional discoverable placements; neither item has an authorized downstream use yet.
const MANOR_KEY_POSITION := Vector3(5.2, 0.0, -4.4)
const FUSE_POSITION := Vector3(-3.8, -2.48, -10.6)
# Cellar floor probe reports the walk surface at y = -2.72; the coil scene sits on its own
# base, so the node goes straight on that surface, clear of the stairs at x ~= -5.78.
const COPPER_WIRE_COIL_POSITION := Vector3(-4.7, -2.72, -10.0)
# Same cellar floor (walk surface at y = -2.72), clear of the stairs at x ~= -5.78.
const ELECTRICAL_TAPE_POSITION := Vector3(-4.0, -2.72, -12.0)
const LANTERN_POSITION := Vector3(-5.4, -2.72, -10.2)
# Yard slab, flat at y = -0.46; left beside the generator (which spans x -11.78..-10.23).
const WRENCH_POSITION := Vector3(-9.3, -0.46, -8.6)
# Reception: room map and MS_Reception_Main_Boards overlap over x -8.40..-4.48, z 0.0..3.90.
const RADIO_POSITION := Vector3(-7.8, -0.005, 3.2)
# The generator is a 1.55 x 2.60 x 4.67 m industrial set and cannot fit the 4.72 x 4.52 m
# cellar, so it stands on the yard slab (flat at y = -0.46). The mesh base sits 0.033 below
# its own origin, hence the 0.033 lift.
const GENERATOR_POSITION := Vector3(-11.0, -0.427, -7.0)
const GENERATOR_ID := "manor.device.generator"

static func build(world: Node3D, camera: Camera3D, player: CollisionObject3D, inventory: Inventory) -> Result:
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
	for spec: Dictionary in DOORS:
		var bound: Dictionary = _door(model, spec, player)
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
		handlers[spec.id] = handler
		bindings[view.get_node("Target")] = spec.id
	_place_item(world, Crowbar, "manor.pickup.crowbar", CROWBAR_POSITION, inventory, handlers, bindings)
	_place_item(world, SilverUrn, "manor.pickup.silver_urn", URN_POSITION, inventory, handlers, bindings)
	_place_item(world, DoctorDiary, "manor.pickup.doctor_diary", DIARY_POSITION, inventory, handlers, bindings)
	_place_item(world, Wallet, "manor.pickup.wallet", WALLET_POSITION, inventory, handlers, bindings)
	_place_item(world, KeroseneBottle, "manor.pickup.kerosene_bottle", KEROSENE_BOTTLE_POSITION, inventory, handlers, bindings)
	_place_item(world, ManorKey, "manor.pickup.manor_key", MANOR_KEY_POSITION, inventory, handlers, bindings)
	_place_item(world, Fuse, "manor.pickup.fuse", FUSE_POSITION, inventory, handlers, bindings)
	_place_item(world, CopperWireCoil, "manor.pickup.copper_wire_coil", COPPER_WIRE_COIL_POSITION, inventory, handlers, bindings)
	_place_item(world, ElectricalTape, "manor.pickup.electrical_tape", ELECTRICAL_TAPE_POSITION, inventory, handlers, bindings)
	_place_item(world, Lantern, "manor.pickup.lantern", LANTERN_POSITION, inventory, handlers, bindings)
	_place_item(world, Wrench, "manor.pickup.wrench", WRENCH_POSITION, inventory, handlers, bindings)
	_place_item(world, Radio, "manor.pickup.radio", RADIO_POSITION, inventory, handlers, bindings)
	var device := Device.new(DeviceState.new(false), "interaction.device.generator")
	var generator: GeneratorView = Generator.instantiate()
	generator.name = GENERATOR_ID.replace(".", "_")
	world.add_child(generator)
	generator.position = GENERATOR_POSITION
	generator.configure(device)
	handlers[GENERATOR_ID] = device
	bindings[generator.get_node("Body")] = GENERATOR_ID
	var service := Service.new(Probe.new(camera, player, bindings, REACH), REACH)
	for id: String in handlers:
		var registration: Result = service.register_target(id, handlers[id])
		if not registration.ok:
			return registration
	return Result.success(service)

## One stable source id per placed instance; identity comes from ItemData, not the node name.
static func _place_item(world: Node3D, item: Resource, source_id: String, position: Vector3,
		inventory: Inventory, handlers: Dictionary, bindings: Dictionary) -> void:
	var handler := Pickup.new(inventory, source_id, String(item.id), 1, item.display_name_key)
	var node: WorldItem = item.world_scene.instantiate()
	node.name = source_id.replace(".", "_")
	world.add_child(node)
	node.position = position
	node.configure_data(item, handler, 1)
	handlers[source_id] = handler
	bindings[node.get_node("Target")] = source_id

static func _leaf(hinge: Node3D) -> MeshInstance3D:
	return hinge.find_child("*_SolidTimberLeaf", true, false) as MeshInstance3D

static func _handle(hinge: Node3D) -> MeshInstance3D:
	return hinge.find_child("*_BrassHandle", true, false) as MeshInstance3D

static func _door(model: Node3D, spec: Dictionary, player: Node3D) -> Dictionary:
	var hinge: Node3D = model.find_child(spec.hinge, true, false)
	var leaf: MeshInstance3D = _leaf(hinge)
	var open_yaw: float = hinge.rotation.y
	var closed_yaw: float = deg_to_rad(spec.closed)
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
