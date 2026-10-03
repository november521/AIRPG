extends RefCounted
## The props the manor hands the player: eight plain pickups that each tell one line when they are
## taken, one radio that is only ever observed, and the generator device. Every position here was
## measured against the delivered V4 model, and each one names the surface it rests on.
##
## The delivered cellar is an empty room (floor, four walls and the ramp), so the tool wall, the
## shelf and the small box the props are described as living on used to be staging only: five props
## hung along the south wall at plausible heights and spacings. A real shelf now hangs on that wall
## and the props sit on its boards -- see bootstrap/manor_shelf.gd, which owns the boards, their two
## heights and the props' places on them.
const Items = preload("res://bootstrap/manor_items.gd")
const Shelf = preload("res://bootstrap/manor_shelf.gd")
const Inventory = preload("res://application/ports/pickup_inventory.gd")
const Audio = preload("res://application/ports/audio_port.gd")
const InspectState = preload("res://domain/exploration/inspect_state.gd")
const Caption = preload("res://presentation/manor/narrative_caption.gd")
const Device = preload("res://application/exploration/interactions/device_interaction.gd")
const DeviceState = preload("res://domain/exploration/device_state.gd")
const InspectView = preload("res://presentation/manor/inspect_object_view.gd")
const GeneratorView = preload("res://presentation/manor/generator.gd")
const GENERATOR_SCENE = preload("res://presentation/manor/generator.tscn")
const WorldItem = preload("res://items/world/world_item.gd")
const Crowbar = preload("res://items/data/crowbar.tres")
const KeroseneBottle = preload("res://items/data/kerosene_bottle.tres")
const ManorKey = preload("res://items/data/manor_key.tres")
const Fuse = preload("res://items/data/fuse.tres")
const CopperWireCoil = preload("res://items/data/copper_wire_coil.tres")
const Wrench = preload("res://items/data/wrench.tres")
const ElectricalTape = preload("res://items/data/electrical_tape.tres")
const Lantern = preload("res://items/data/lantern.tres")
const RadioView = preload("res://items/data/radio_view.tres")
## The one scene layer a pickup's line survives on. Named so the composition root and the tests can
## find it without reaching into a picked-up node that the receipt has already freed.
const CAPTION_HOST_NAME := "NarrativeCaption"
# Measured support surfaces. The cellar floor is flat at -3.23 over x -5.90..-1.58, z -12.6..-5.9
# (its ramp band, x -5.85..-4.60, only runs between z -10.20 and -7.45, well clear of the wall run
# below); the boarded ground floor of the reception and the kitchen is its subfloor top at -0.025,
# but the reception's area rug reaches 0.0245 and covers x -6.92..-3.25, z 2.92..6.44, so the key is
# kept off the rug; the porch stone deck tops out at 0.020 and the kitchen counter worktop at 1.000.
const CELLAR_FLOOR: float = -3.23
const GROUND_FLOOR: float = -0.025
const PORCH_DECK: float = 0.020
## The kitchen's north run of worktop, measured point by point: it is 1.000 high over x 1.36..2.80,
## z 7.68..7.95, while the stove top beside it stands 1.308 high over x 0.60..1.44, z 6.80..7.48.
## Between those two, x 1.44..1.76 at z 7.50..7.65 is an open gap with no surface at all, which is
## where the radio used to stand: it was floating over the join, 4.8 cm above the worktop beside it.
const KITCHEN_WORKTOP: float = 1.000
## The crowbar's imported mesh reaches 0.359872 below its own origin, so floor contact is the origin
## lifted by that much; every other prop scene already sits on its own base.
const CROWBAR_DROP: float = 0.359872
## The radio's own scene already lifts its model by 0.105238 -- the case's centre above its base --
## so that the case's bottom lands on the root. The root therefore goes straight onto the worktop;
## adding that offset here as well is what made the radio float 10.5 cm above it.
const GENERATOR_BASE: float = 0.033332
## The front door leads from the kitchen onto the covered veranda, whose deck is the only walkable
## ground immediately outside it: the lawn proper is 0.48 m lower and beyond the veranda's edge, and
## the delivered model has no grass at the threshold.
const CROWBAR_POSITION := Vector3(5.60, PORCH_DECK + CROWBAR_DROP, 3.40)
const MANOR_KEY_POSITION := Vector3(-5.20, GROUND_FLOOR, 1.60)
## The six cellar objects that are not the generator stand on the two shelf boards; the positions
## and the boards they rest on live in manor_shelf, which also records how each was measured.
const COPPER_WIRE_COIL_POSITION := Shelf.COPPER_WIRE_COIL_POSITION
const FUSE_POSITION := Shelf.FUSE_POSITION
const ELECTRICAL_TAPE_POSITION := Shelf.ELECTRICAL_TAPE_POSITION
const WRENCH_POSITION := Shelf.WRENCH_POSITION
const LANTERN_POSITION := Shelf.LANTERN_POSITION
const KEROSENE_BOTTLE_POSITION := Shelf.KEROSENE_BOTTLE_POSITION
## The wrench now lies on a board rather than hanging; the pose is measured in manor_shelf.
const WRENCH_PITCH: float = Shelf.WRENCH_PITCH
## The radio stands on the kitchen's north worktop, clear of the open gap between the stove's run and
## that one: measured, the worktop is 1.000 high over x 1.36..2.80 and z 7.70..7.95, while the near
## side of the radio's 0.40 x 0.194 m case hangs over that gap if it stands any further south, so it
## stands at z = 7.80, where the worktop is under all four corners.
const RADIO_POSITION := Vector3(1.60, KITCHEN_WORKTOP, 7.80)
## The generator runs its long axis north-south: its 4.67 m case fits the cellar's 6.7 m length with
## 0.18 m behind it and 0.30 m in front, its 1.55 m width leaves a 0.84 m walkway along the east wall
## and 0.63 m to the ramp band, and its 2.57 m height clears the 2.94 m cellar ceiling.
const GENERATOR_POSITION := Vector3(-3.20, CELLAR_FLOOR + GENERATOR_BASE, -10.65)
const CROWBAR_ID := "manor.pickup.crowbar"
const MANOR_KEY_ID := "manor.pickup.manor_key"
const COPPER_WIRE_COIL_ID := "manor.pickup.copper_wire_coil"
const ELECTRICAL_TAPE_ID := "manor.pickup.electrical_tape"
const LANTERN_ID := "manor.pickup.lantern"
const KEROSENE_BOTTLE_ID := "manor.pickup.kerosene_bottle"
const FUSE_ID := "manor.pickup.fuse"
const WRENCH_ID := "manor.pickup.wrench"
## The radio is an observation object, not a pickup: it is fixed to the worktop and only ever read.
const RADIO_ID := "manor.inspect.radio"
const GENERATOR_ID := "manor.device.generator"
const CROWBAR_CAPTION := "narrative.pickup.crowbar"
const MANOR_KEY_CAPTION := "narrative.pickup.manor_key"
const COPPER_WIRE_COIL_CAPTION := "narrative.pickup.copper_wire_coil"
const ELECTRICAL_TAPE_CAPTION := "narrative.pickup.electrical_tape"
const LANTERN_CAPTION := "narrative.pickup.lantern"
const KEROSENE_BOTTLE_CAPTION := "narrative.pickup.kerosene_bottle"
const FUSE_CAPTION := "narrative.pickup.fuse"
const WRENCH_CAPTION := "narrative.pickup.wrench"
## Two stages and no third: the radio is switched on and stays on, so its one text is permanent for
## this round -- the supply chain that would change it is not built. Its hand stage is set past every
## stage it has, so the radio is never drawn in the player's hand.
const RADIO_STAGE_COUNT: int = 2
const RADIO_HAND_STAGE: int = 99
## The stage at which the radio is on: the first look is the switch, so its static starts there and
## never stops, because nothing in this round switches it off again.
const RADIO_ON_STAGE: int = 1
const RADIO_CAPTIONS: Array[String] = ["", "inspect.radio.stage_one"]
const RADIO_ACTION_KEYS: Array[String] = ["interaction.inspect", "interaction.inspect"]
const GENERATOR_NAME_KEY := "interaction.device.generator"
const GENERATOR_INSPECT_CAPTION := "inspect.device.generator"
## The generator will not run without the kerosene in the notebook. It is only asked for, never
## spent: topping the tank up is the deferred power-supply step, so this round stops at the door.
const GENERATOR_FUEL_ITEM := String(KeroseneBottle.id)
const GENERATOR_NEEDS_FUEL := "GENERATOR_NEEDS_KEROSENE"

## Places everything this round delivers. `captions` is the scene's one narrative layer, built by the
## composition root before anything that may put a line on it; when it is left out a layer is made
## here instead, so a caller that only wants the props still gets a working host. `audio` is the
## scene's port and is handed to every prop it places, including the two that own a source of their
## own: the radio's static and the generator's loop.
static func place_props(world: Node3D, inventory: Inventory, player: CollisionObject3D,
		handlers: Dictionary, bindings: Dictionary, captions: Caption = null,
		audio: Audio = null) -> Caption:
	if captions == null:
		captions = Caption.new()
		captions.name = CAPTION_HOST_NAME
		world.add_child(captions)
	Items.place_item(world, Crowbar, CROWBAR_ID, CROWBAR_POSITION, inventory, handlers, bindings,
		CROWBAR_CAPTION, captions, audio)
	# Every pickup in this round tells one line, so every one of them takes two commands: the first
	# reads its line out and leaves it in the world, the second pockets it and retires the line.
	Items.place_item(world, ManorKey, MANOR_KEY_ID, MANOR_KEY_POSITION, inventory, handlers, bindings,
		MANOR_KEY_CAPTION, captions, audio)
	Shelf.place(world)
	Items.place_item(world, CopperWireCoil, COPPER_WIRE_COIL_ID, COPPER_WIRE_COIL_POSITION, inventory,
		handlers, bindings, COPPER_WIRE_COIL_CAPTION, captions, audio)
	Items.place_item(world, ElectricalTape, ELECTRICAL_TAPE_ID, ELECTRICAL_TAPE_POSITION, inventory,
		handlers, bindings, ELECTRICAL_TAPE_CAPTION, captions, audio)
	Items.place_item(world, Lantern, LANTERN_ID, LANTERN_POSITION, inventory, handlers, bindings,
		LANTERN_CAPTION, captions, audio)
	Items.place_item(world, KeroseneBottle, KEROSENE_BOTTLE_ID, KEROSENE_BOTTLE_POSITION, inventory,
		handlers, bindings, KEROSENE_BOTTLE_CAPTION, captions, audio)
	Items.place_item(world, Fuse, FUSE_ID, FUSE_POSITION, inventory, handlers, bindings, FUSE_CAPTION,
		captions, audio)
	var wrench: WorldItem = Items.place_item(world, Wrench, WRENCH_ID, WRENCH_POSITION, inventory,
		handlers, bindings, WRENCH_CAPTION, captions, audio)
	wrench.rotation.x = WRENCH_PITCH
	var radio: InspectView = Items.place_inspect(world, RadioView, RADIO_ID, RADIO_POSITION, player,
		handlers, bindings, RADIO_CAPTIONS, RADIO_ACTION_KEYS,
		InspectState.new(RADIO_STAGE_COUNT, RADIO_STAGE_COUNT, RADIO_HAND_STAGE, RADIO_HAND_STAGE),
		[], [], {}, audio)
	# The radio is the one observed object that is a running appliance: from its first look onwards it
	# has static coming out of its own case, and the switch that starts it is an interface click.
	radio.attach_appliance(audio, Audio.RADIO_STATIC, RADIO_ON_STAGE)
	place_generator(world, inventory, handlers, bindings, audio)
	return captions

## The generator is a device, not a pickup: it is started and stopped, and it shows its own
## first-look text once before it will run. It is also the one device that needs fuel on hand, so it
## is handed the notebook port: the first command is still its first look, and every start after
## that asks whether the kerosene is carried.
static func place_generator(world: Node3D, inventory: Inventory, handlers: Dictionary,
		bindings: Dictionary, audio: Audio = null) -> void:
	var device := Device.new(DeviceState.new(false, true), GENERATOR_NAME_KEY, GENERATOR_INSPECT_CAPTION,
		inventory, GENERATOR_FUEL_ITEM, GENERATOR_NEEDS_FUEL)
	var generator: GeneratorView = GENERATOR_SCENE.instantiate()
	generator.name = GENERATOR_ID.replace(".", "_")
	world.add_child(generator)
	generator.position = GENERATOR_POSITION
	# Before `configure`, so the loop is already bound to this casing the first time the view asks
	# whether the machine is running.
	generator.attach_audio(audio)
	generator.configure(device)
	handlers[GENERATOR_ID] = device
	bindings[generator.get_node("Body")] = GENERATOR_ID
