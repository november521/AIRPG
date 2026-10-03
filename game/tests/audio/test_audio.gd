extends RefCounted
## Audio contract, adapter and wiring. Three levels, deliberately:
##
##  * the contract: every semantic kind the port declares is mapped to a stream and a bus, the banks
##    are the ones the layout defines, and a menu button can never borrow a material hit;
##  * the adapter: the real one, run headless inside the tree, so the pool, the detune, the loop
##    binding, the fades and the crossfade are observed rather than assumed;
##  * the wiring: the manor, its views, the notebook and the menus are driven and their decisions
##    recorded. Nothing here asserts on an audio device, and no assertion needs one.
const Port = preload("res://application/ports/audio_port.gd")
const Library = preload("res://infrastructure/audio/audio_library.gd")
const GodotAudio = preload("res://infrastructure/audio/godot_audio.gd")
const Recorder = preload("res://tests/doubles/recording_audio.gd")
const Random = preload("res://infrastructure/random/godot_random_source.gd")
const Cadence = preload("res://application/exploration/step_cadence.gd")
const Surface = preload("res://infrastructure/exploration/ground_surface_probe.gd")
const Result = preload("res://shared/result.gd")
const CharacterPreview = preload("res://bootstrap/character_preview.gd")
const Inventory = preload("res://application/ports/pickup_inventory.gd")
const DoorState = preload("res://domain/exploration/door_state.gd")
const DeviceState = preload("res://domain/exploration/device_state.gd")
const InspectState = preload("res://domain/exploration/inspect_state.gd")
const LockState = preload("res://domain/exploration/lock_state.gd")
const Door = preload("res://application/exploration/interactions/door_interaction.gd")
const Device = preload("res://application/exploration/interactions/device_interaction.gd")
const Inspect = preload("res://application/exploration/interactions/inspect_interaction.gd")
const Pickup = preload("res://application/exploration/interactions/pickup_interaction.gd")
const Unlock = preload("res://application/exploration/interactions/unlock_interaction.gd")
const DoorView = preload("res://presentation/exploration/interactions/door_view.gd")
const PickupView = preload("res://presentation/exploration/interactions/pickup_view.gd")
const PICKUP = preload("res://presentation/exploration/interactions/pickup.tscn")
const GeneratorView = preload("res://presentation/manor/generator.gd")
const GENERATOR = preload("res://presentation/manor/generator.tscn")
const CabinetView = preload("res://presentation/manor/locked_object_view.gd")
const CABINET = preload("res://presentation/manor/medical_cabinet.tscn")
const PryView = preload("res://presentation/manor/pry_entrance_view.gd")
const InspectView = preload("res://presentation/manor/inspect_object_view.gd")
const Notebook = preload("res://presentation/character/character_hud.gd")
const START = preload("res://presentation/menu/start_screen.tscn")
const ARCHIVE = preload("res://presentation/story_archive/story_archive.tscn")
const Archive = preload("res://bootstrap/story_archive_composition.gd")
const Props = preload("res://bootstrap/manor_props.gd")
const MANOR = preload("res://bootstrap/manor_play.tscn")
const APP = preload("res://bootstrap/main.tscn")
## The names the audio library gives the two kinds the tests look for by name.
const PRY_ID := "manor.pry.cellar_boards"
const CABINET_ID := "manor.cabinet.medical"

class Clear extends "res://application/ports/door_clearance.gd":
	func is_clear_pose(_from_open: bool, _to_open: bool, _from_yaw: float, _to_yaw: float) -> bool:
		return true

func run(check: Callable, tree: SceneTree) -> void:
	_contract(check)
	_cadence(check)
	_surface(check)
	await _adapter(check, tree)
	await _views(check, tree)
	await _menus(check, tree)
	await _manor(check, tree)

## The port is the contract and the library is its only implementation: a kind that exists in one and
## not the other is a silent event waiting to happen.
func _contract(check: Callable) -> void:
	var library := Library.new()
	var kinds: Array[String] = []
	var missing: Array[String] = []
	for value: Variant in Port.new().get_script().get_script_constant_map().values():
		if value is String and String(value).contains("."):
			kinds.append(String(value))
			if not library.has(String(value)):
				missing.append(String(value))
	check.call(kinds.size() >= 20, "AUDIO: the port declares the events this round wires")
	check.call(missing.is_empty(), "AUDIO: every port kind is mapped by the library " + str(missing))
	var broken: Array[String] = []
	for kind: String in library.kinds():
		var entry: Dictionary = library.entry(kind)
		if String(entry.get("bus", "")).is_empty() or Array(entry.get("pool", [])).is_empty():
			broken.append(kind)
			continue
		for stream: Variant in entry.pool:
			if stream == null or not stream is AudioStream or (stream as AudioStream).get_length() <= 0.0:
				broken.append(kind)
	check.call(broken.is_empty(), "AUDIO: every mapped kind loads a real stream " + str(broken))
	check.call(AudioServer.bus_count >= 6 and AudioServer.get_bus_name(0) == "Master",
		"AUDIO: the project layout is loaded with Master at index 0")
	for bus: String in [Library.BUS_MUSIC, Library.BUS_AMBIENCE, Library.BUS_SFX, Library.BUS_UI]:
		var index: int = AudioServer.get_bus_index(bus)
		check.call(index > 0 and AudioServer.get_bus_send(index) == "Master"
			and AudioServer.get_bus_volume_db(index) < 0.0,
			"AUDIO: the " + bus + " bus exists, sends to Master and is independently adjustable")
	check.call(AudioServer.get_bus_index(Library.BUS_VOICE) > 0,
		"AUDIO: the voice bus exists for later rounds")
	for kind: String in [Port.UI_CLICK, Port.UI_CONFIRM, Port.UI_CANCEL, Port.UI_SWITCH,
			Port.MENU_START, Port.MENU_CLICK, Port.MENU_BACK]:
		var entry: Dictionary = library.entry(kind)
		check.call(String(entry.bus) == Library.BUS_UI and not bool(entry.spatial),
			"AUDIO: " + kind + " is a flat interface sound")
	for kind: String in [Port.PICKUP, Port.PUT, Port.DOOR_OPEN, Port.DOOR_CLOSE, Port.LOCK_OPEN,
			Port.LOCK_CLOSE, Port.PRY_WOOD, Port.PRY_METAL, Port.POUR_KEROSENE,
			Port.GENERATOR_CRANK, Port.FOOTSTEP_WOOD, Port.FOOTSTEP_STONE, Port.FOOTSTEP_WET]:
		var entry: Dictionary = library.entry(kind)
		check.call(String(entry.bus) == Library.BUS_SFX and bool(entry.spatial),
			"AUDIO: " + kind + " is a spatial sound on the effects bank")
	for kind: String in [Port.GENERATOR_LOOP, Port.RADIO_STATIC]:
		var entry: Dictionary = library.entry(kind)
		check.call(String(entry.bus) == Library.BUS_SFX and bool(entry.spatial) and bool(entry.loop),
			"AUDIO: " + kind + " is a looping machine source on the effects bank")
	check.call(Array(library.entry(Port.FOOTSTEP_WOOD).pool).size() == 4
		and Array(library.entry(Port.FOOTSTEP_STONE).pool).size() == 6
		and Array(library.entry(Port.FOOTSTEP_WET).pool).size() == 3,
		"AUDIO: the three footstep banks are the delivered four, six and three takes")
	check.call(Array(library.entry(Port.UI_CLICK).pool).size() == 3
		and Array(library.entry(Port.DOOR_OPEN).pool).size() == 2
		and bool(library.entry(Port.FOOTSTEP_WOOD).jitter)
		and not bool(library.entry(Port.DOOR_OPEN).jitter),
		"AUDIO: clicks, doors and footsteps are pools; only the steps are detuned")
	# The loop flag is the import sidecar's, and the adapter re-asserts it when it binds; both halves
	# are checked here so a re-import that drops it cannot pass unnoticed. The sidecar is read as a
	# file rather than off the loaded resource, because a run that already bound the loop has set the
	# flag in memory and would make the resource say the right thing for the wrong reason.
	for kind: String in [Port.GENERATOR_LOOP, Port.RADIO_STATIC]:
		check.call(_loops(library.entry(kind).pool[0]), "AUDIO: " + kind + " ships as a looping clip")
		check.call(_sidecar_loops(library.entry(kind).pool[0]),
			"AUDIO: " + kind + " ships with the loop flag in its import sidecar")
	check.call(not _loops(library.entry(Port.DOOR_OPEN).pool[0]),
		"AUDIO: a one-shot door clip does not loop")
	check.call(not _sidecar_loops(library.entry(Port.DOOR_OPEN).pool[0]),
		"AUDIO: a one-shot door clip ships with the loop flag off")
	for tier: String in Library.MUSIC_TIERS:
		check.call(library.music(tier) != null and _loops(library.music(tier)),
			"AUDIO: the " + tier + " music tier loads and loops")
		check.call(_sidecar_loops(library.music(tier)),
			"AUDIO: the " + tier + " music tier ships with the loop flag in its import sidecar")
	# A menu button must never borrow the manor's wood and metal.
	var material: Dictionary = _material_files(library)
	for kind: String in [Port.MENU_START, Port.MENU_CLICK, Port.MENU_BACK, Port.UI_CLICK,
			Port.UI_CONFIRM, Port.UI_CANCEL, Port.UI_SWITCH]:
		for stream: Variant in library.entry(kind).pool:
			var file: String = (stream as AudioStream).resource_path.get_file()
			check.call(not material.has(file), "AUDIO: " + kind + " is not a material hit (" + file + ")")

func _cadence(check: Callable) -> void:
	var cadence := Cadence.new()
	check.call(cadence.advance(0.4) == 0, "AUDIO: half a stride is not a step")
	check.call(cadence.advance(0.4) == 1, "AUDIO: the stride lands one step")
	check.call(cadence.advance(1.9) == 2, "AUDIO: a frame of walking lands every stride it covered")
	check.call(cadence.advance(0.6) == 1, "AUDIO: the leftover part of a stride is carried over")
	check.call(cadence.advance(5.0) == 0, "AUDIO: a shortcut teleport is not a walk")
	check.call(cadence.advance(0.8) == 1, "AUDIO: the accumulator survives the teleport guard")
	check.call(cadence.advance(-1.0) == 0 and cadence.advance(NAN) == 0 and cadence.advance(0.4) == 0,
		"AUDIO: a nonfinite or backwards jump clears the accumulator")
	cadence.reset()
	check.call(cadence.advance(0.78) == 1, "AUDIO: a reset body starts its next stride fresh")

func _surface(check: Callable) -> void:
	var surface := Surface.new()
	check.call(surface.material_for("cellar") == "stone" and surface.material_for("bathroom") == "stone",
		"AUDIO: the cellar and the bathroom are heard as stone")
	check.call(surface.material_for("reception") == "wood" and surface.material_for("kitchen") == "wood"
		and surface.material_for("doctor_study") == "wood",
		"AUDIO: the boarded ground floor and the studies are heard as wood")
	check.call(surface.material_for("porch") == "wet" and surface.material_for("outside") == "wet",
		"AUDIO: the exposed veranda is heard as wet")
	check.call(surface.material_for("no_such_room") == "stone",
		"AUDIO: an unknown room falls back to stone rather than to silence")

## The real adapter, headless: every player it builds is inspected instead of listened to.
func _adapter(check: Callable, tree: SceneTree) -> void:
	var host := Node3D.new()
	tree.root.add_child(host)
	var audio := GodotAudio.new(host, Random.new(20261004))
	for index: int in 12:
		audio.play_sfx(Port.FOOTSTEP_WOOD, Vector3(1.0, 0.0, 1.0))
	var steps: Array[AudioStreamPlayer3D] = []
	var files: Dictionary = {}
	var pitches: Dictionary = {}
	var out_of_tune: int = 0
	var wrong_bus: int = 0
	for child: Node in host.get_children():
		var player: AudioStreamPlayer3D = child as AudioStreamPlayer3D
		if player == null or player.stream == null:
			continue
		if not String(player.stream.resource_path.get_file()).begins_with("footstep_wood"):
			continue
		steps.append(player)
		files[player.stream.resource_path.get_file()] = true
		pitches[snappedf(player.pitch_scale, 0.0001)] = true
		out_of_tune += 1 if absf(player.pitch_scale - 1.0) > GodotAudio.PITCH_JITTER + 0.0001 else 0
		wrong_bus += 1 if player.bus != Library.BUS_SFX else 0
	check.call(steps.size() == 12, "AUDIO: twelve steps build twelve spatial players")
	check.call(files.size() >= 2, "AUDIO: twelve steps draw more than one take from the pool "
		+ str(files.keys()))
	check.call(pitches.size() >= 2, "AUDIO: twelve steps are not all at the same pitch")
	check.call(out_of_tune == 0 and wrong_bus == 0,
		"AUDIO: every step stays inside the recorded detune and on the effects bank")
	for index: int in 6:
		audio.play_ui(Port.UI_CLICK)
	var clicks: Array[AudioStreamPlayer] = []
	var click_files: Dictionary = {}
	var click_wrong: int = 0
	for child: Node in host.get_children():
		if child is AudioStreamPlayer3D or not child is AudioStreamPlayer:
			continue
		var player := child as AudioStreamPlayer
		if player.stream == null or not String(player.stream.resource_path.get_file()).begins_with("click_"):
			continue
		clicks.append(player)
		click_files[player.stream.resource_path.get_file()] = true
		if player.bus != Library.BUS_UI or not is_equal_approx(player.volume_db, Library.UI_LEVEL_DB):
			click_wrong += 1
	check.call(clicks.size() == 6 and click_wrong == 0,
		"AUDIO: interface clicks are flat players on the flat interface bank")
	check.call(click_files.size() >= 2, "AUDIO: the interface bank rotates its three click takes")
	# A machine loop: bound to its host, looping, ramped up, and ramped down rather than cut.
	audio.attach_loop(Port.GENERATOR_LOOP, host)
	var loop: AudioStreamPlayer3D = host.get_node_or_null("AudioLoop") as AudioStreamPlayer3D
	check.call(loop != null and loop.stream != null and _loops(loop.stream)
		and loop.bus == Library.BUS_SFX,
		"AUDIO: the generator loop hangs on its machine as a looping spatial source")
	check.call(loop != null and not loop.playing,
		"AUDIO: a bound loop stays silent until it is switched on")
	audio.set_ambience(Port.GENERATOR_LOOP, true)
	check.call(loop != null and loop.playing, "AUDIO: switching the machine on starts its loop")
	await tree.create_timer(0.5).timeout
	audio.set_ambience(Port.GENERATOR_LOOP, false)
	check.call(loop != null and loop.playing and loop.volume_db > GodotAudio.SILENT_DB + 1.0,
		"AUDIO: stopping a machine fades rather than cutting")
	await tree.create_timer(GodotAudio.FADE_SECONDS + 0.3).timeout
	check.call(loop != null and not loop.playing and loop.volume_db <= GodotAudio.SILENT_DB + 0.01,
		"AUDIO: the fade-out ends in silence and stops the source")
	audio.set_ambience(Port.GENERATOR_LOOP, true)
	audio.set_ambience(Port.GENERATOR_LOOP, true)
	check.call(loop != null and loop.playing,
		"AUDIO: switching a machine on again restarts it, and repeating it is a no-op")
	# Music: one tier at a time, crossfaded, and asking for the tier already playing changes nothing.
	audio.set_music(Port.MUSIC_DREAD_LOW)
	var playing: AudioStreamPlayer = _playing_music(host)
	check.call(playing != null and playing.bus == Library.BUS_MUSIC and _loops(playing.stream)
		and playing.stream.resource_path.get_file() == "mus_dread_low.ogg",
		"AUDIO: the default tier plays a looping bed on the music bank")
	audio.set_music(Port.MUSIC_DREAD_LOW)
	check.call(_playing_music(host) == playing,
		"AUDIO: re-asking for the current tier does not restart it")
	audio.set_music(Port.MUSIC_BLACKOUT)
	var switched: AudioStreamPlayer = _playing_music(host)
	check.call(switched != null and switched != playing
		and switched.stream.resource_path.get_file() == "mus_blackout.ogg",
		"AUDIO: a tier change starts the other bed instead of cutting the first")
	check.call(audio.silent().is_empty(), "AUDIO: the adapter never had to go silent "
		+ str(audio.silent()))
	tree.root.remove_child(host)
	host.queue_free()
	await tree.process_frame

## The real views on real handlers, so the wiring between a state change and a sound is what is under
## test rather than a description of it.
func _views(check: Callable, tree: SceneTree) -> void:
	var world := Node3D.new()
	tree.root.add_child(world)
	var inventory = CharacterPreview.build()
	_pickup_view(check, world, inventory)
	_door_view(check, world)
	_cabinet_view(check, world)
	_pry_view(check, world)
	_generator_views(check, world)
	_photo_view(check, world, inventory)
	var layer := CanvasLayer.new()
	tree.root.add_child(layer)
	_notebook(check, layer)
	layer.queue_free()
	tree.root.remove_child(world)
	world.queue_free()
	await tree.process_frame

func _pickup_view(check: Callable, world: Node3D, inventory: Inventory) -> void:
	var recorder := Recorder.new(null, Random.new(11))
	var handler := Pickup.new(inventory, "audio.test.bandage", "demo_bandage", 2, "item.bandage",
		"narrative.audio.test")
	var view: PickupView = PICKUP.instantiate()
	world.add_child(view)
	view.configure(handler, "item.bandage", 2)
	view.attach_audio(recorder)
	handler.execute(0)
	check.call(not recorder.has_sound(Port.PICKUP),
		"AUDIO: reading a pickup's line out is not picking it up")
	handler.execute(inventory.read_pickup("audio.test.bandage").revision)
	check.call(recorder.count_sounds(Port.PICKUP) == 1 and recorder.bus_for(Port.PICKUP) == Library.BUS_SFX
		and recorder.spatial_for(Port.PICKUP),
		"AUDIO: a claimed pickup is heard once, where it stood")
	handler.execute(1)
	check.call(recorder.count_sounds(Port.PICKUP) == 1, "AUDIO: a refused second take is silent")

func _door_view(check: Callable, world: Node3D) -> void:
	var recorder := Recorder.new(null, Random.new(12))
	var body := AnimatableBody3D.new()
	world.add_child(body)
	var handler := Door.new(DoorState.new(), Clear.new(), "interaction.door.side", PI / 2.0)
	var view := DoorView.new()
	body.add_child(view)
	view.configure(handler, body, 0.0)
	view.attach_audio(recorder)
	handler.execute(0)
	check.call(recorder.count_sounds(Port.DOOR_OPEN) == 1 and not recorder.has_sound(Port.DOOR_CLOSE),
		"AUDIO: a door that swings is heard opening once")
	handler.finish_motion()
	handler.execute(1)
	check.call(recorder.count_sounds(Port.DOOR_CLOSE) == 1,
		"AUDIO: closing the same door is heard closing once")

func _cabinet_view(check: Callable, world: Node3D) -> void:
	var recorder := Recorder.new(null, Random.new(13))
	var keys = CharacterPreview.build()
	check.call(keys.claim_pickup("audio.test.key", "manor_key", 1, 0).ok,
		"AUDIO: the fixture can carry the manor key")
	var handler := Unlock.new(LockState.new(true), keys, CABINET_ID, "interaction.unlock",
		["manor_key", "crowbar"])
	var view: CabinetView = CABINET.instantiate()
	world.add_child(view)
	view.configure(handler, null, null)
	view.attach_audio(recorder)
	handler.execute(0)
	check.call(handler.pried() and recorder.count_sounds(Port.LOCK_OPEN) == 1,
		"AUDIO: unlocking the medical cabinet is heard as a lock turning")

func _pry_view(check: Callable, world: Node3D) -> void:
	var recorder := Recorder.new(null, Random.new(14))
	var tools = CharacterPreview.build()
	check.call(tools.claim_pickup("audio.test.crowbar", "crowbar", 1, 0).ok,
		"AUDIO: the fixture can carry the crowbar")
	var handler := Unlock.new(LockState.new(true), tools, "interaction.pry.cellar", "interaction.pry",
		["crowbar"], "PRY_NEEDS_CROWBAR", "interaction.pry.done")
	var view := PryView.new()
	world.add_child(view)
	view.position = Vector3(-5.15, 0.0, -9.89)
	view.configure(handler, null, null)
	view.attach_audio(recorder)
	handler.execute(0)
	check.call(handler.pried() and recorder.count_sounds(Port.PRY_WOOD) == 1
		and recorder.count_sounds(Port.PRY_METAL) == 1,
		"AUDIO: prying the cellar open is heard as wood giving and metal following")
	check.call(recorder.bus_for(Port.PRY_WOOD) == Library.BUS_SFX
		and (recorder.sounds()[0].position as Vector3).is_equal_approx(Vector3(-5.15, 0.0, -9.89)),
		"AUDIO: the pry is placed at the entrance it happens at")

func _generator_views(check: Callable, world: Node3D) -> void:
	# Nothing in the notebook: the start is refused, so the machine never starts, cranks or pours.
	var dry := Recorder.new(null, Random.new(15))
	var gated := Device.new(DeviceState.new(false, true), Props.GENERATOR_NAME_KEY,
		Props.GENERATOR_INSPECT_CAPTION, Inventory.new(), Props.GENERATOR_FUEL_ITEM,
		Props.GENERATOR_NEEDS_FUEL)
	var view: GeneratorView = GENERATOR.instantiate()
	world.add_child(view)
	view.attach_audio(dry)
	view.configure(gated)
	check.call(dry.has_event("attach", Port.GENERATOR_LOOP),
		"AUDIO: the generator binds its loop to its own casing")
	check.call(gated.execute(0).ok and gated.read().action_key == "interaction.device.start",
		"AUDIO: the gated generator inspects first")
	check.call(gated.execute(1).code == Props.GENERATOR_NEEDS_FUEL, "AUDIO: a dry start is refused")
	check.call(not dry.has_sound(Port.POUR_KEROSENE) and not dry.has_sound(Port.GENERATOR_CRANK)
		and dry.ambience_state(Port.GENERATOR_LOOP) == null,
		"AUDIO: a refused start neither pours, cranks nor starts a loop")
	# Carrying the kerosene: the same two commands now start it, pour, and switch the loop on.
	var fed := Recorder.new(null, Random.new(16))
	var fuel = CharacterPreview.build()
	check.call(fuel.claim_pickup("audio.test.fuel", "kerosene_bottle", 1, 0).ok,
		"AUDIO: the fixture can carry the kerosene")
	var running := Device.new(DeviceState.new(false, true), Props.GENERATOR_NAME_KEY,
		Props.GENERATOR_INSPECT_CAPTION, fuel, Props.GENERATOR_FUEL_ITEM, Props.GENERATOR_NEEDS_FUEL)
	var second: GeneratorView = GENERATOR.instantiate()
	world.add_child(second)
	second.attach_audio(fed)
	second.configure(running)
	running.execute(0)
	check.call(running.execute(1).ok and second.is_running(),
		"AUDIO: carrying the kerosene lets the same command start it")
	check.call(fed.count_sounds(Port.GENERATOR_CRANK) == 1 and fed.count_sounds(Port.POUR_KEROSENE) == 1,
		"AUDIO: starting the generator is heard as a crank and a pour of fuel")
	check.call(fed.ambience_state(Port.GENERATOR_LOOP) == true,
		"AUDIO: the running machine's loop is switched on")
	check.call(running.execute(2).ok and not second.is_running(), "AUDIO: the generator stops again")
	check.call(fed.ambience_state(Port.GENERATOR_LOOP) == false,
		"AUDIO: the stopped machine's loop is switched off")

func _photo_view(check: Callable, world: Node3D, inventory: Inventory) -> void:
	# The wallet's world scene comes from the notebook's own definitions, so this is the delivered
	# object rather than a fixture scene built for the test.
	var definition: Dictionary = inventory.read_character().definitions["wallet"]
	var node: InspectView = definition.world_scene.instantiate()
	world.add_child(node)
	var holder := Node3D.new()
	world.add_child(holder)
	var recorder := Recorder.new(null, Random.new(17))
	var handler := Inspect.new(InspectState.new(), "item.wallet",
		["", "inspect.wallet.floor", "inspect.wallet.held"],
		["interaction.inspect", "interaction.take_photo", "interaction.keep_photo"])
	node.configure(handler, holder, "Model/Reveal", InspectView.POSE_PHOTO_CARD, true, "", null)
	node.attach_audio(recorder)
	handler.execute(0)
	check.call(not recorder.has_sound(Port.PICKUP), "AUDIO: opening the wallet is silent")
	handler.execute(1)
	check.call(recorder.count_sounds(Port.PICKUP) == 1,
		"AUDIO: drawing the photograph out of the wallet is heard")

func _notebook(check: Callable, layer: CanvasLayer) -> void:
	var recorder := Recorder.new(null, Random.new(18))
	var hud: Notebook = Notebook.new()
	hud.configure(CharacterPreview.build())
	layer.add_child(hud)
	hud.attach_audio(recorder)
	check.call(not recorder.has_sound(Port.UI_SWITCH),
		"AUDIO: a notebook that closes itself on the way in does not click")
	hud.set_open(true)
	check.call(recorder.count_sounds(Port.UI_SWITCH) == 1, "AUDIO: opening the notebook is a switch")
	hud._choose_item("demo_bandage")
	check.call(recorder.has_sound(Port.UI_CLICK), "AUDIO: choosing an entry in the notebook is a click")
	hud._show_result(Result.failure("ITEM_MISSING"))
	check.call(recorder.has_sound(Port.UI_CANCEL),
		"AUDIO: a refused notebook command gets the negative sound")
	hud._show_result(Result.success())
	check.call(recorder.has_sound(Port.UI_CONFIRM),
		"AUDIO: a committed notebook command gets the affirmative sound")
	check.call(recorder.bus_for(Port.UI_CONFIRM) == Library.BUS_UI
		and not recorder.spatial_for(Port.UI_CONFIRM),
		"AUDIO: every notebook sound is a flat interface sound")

func _menus(check: Callable, tree: SceneTree) -> void:
	var recorder := Recorder.new(null, Random.new(19))
	var screen = START.instantiate()
	tree.root.add_child(screen)
	screen.attach_audio(recorder)
	screen._start_game()
	check.call(recorder.count_sounds(Port.MENU_START) == 1
		and recorder.files_for(Port.MENU_START) == ["menu_start.ogg"],
		"AUDIO: starting the game plays the menu's own start sound")
	check.call(recorder.bus_for(Port.MENU_START) == Library.BUS_UI
		and not recorder.spatial_for(Port.MENU_START),
		"AUDIO: the menu's start sound is a flat interface sound")
	screen._quit_game()
	check.call(recorder.count_sounds(Port.MENU_CLICK) == 1, "AUDIO: the menu's other buttons click")
	var material: Dictionary = _material_files(Library.new())
	for entry: Dictionary in recorder.sounds():
		check.call(not material.has(String(entry.file)),
			"AUDIO: the menu never plays a material hit (" + String(entry.file) + ")")
	# The archive is a menu too: it enters a story, and it has a way back.
	var composition: Dictionary = Archive.build(false, null)
	var archive = ARCHIVE.instantiate()
	tree.root.add_child(archive)
	archive.attach_audio(recorder)
	archive.configure(composition.service, composition.art)
	archive._return_home()
	check.call(recorder.count_sounds(Port.MENU_BACK) == 1, "AUDIO: leaving the archive plays the way back")
	var second = ARCHIVE.instantiate()
	tree.root.add_child(second)
	second.attach_audio(recorder)
	second.configure(composition.service, composition.art)
	await tree.create_timer(0.7).timeout
	second._start()
	check.call(recorder.count_sounds(Port.MENU_START) == 2,
		"AUDIO: entering a story from the archive plays the start sound")
	for node: Node in [screen, archive, second]:
		tree.root.remove_child(node)
		node.queue_free()
	await tree.process_frame
	# The shell assembles the menu runtime and injects it on the way in: the booted start screen and
	# the application root must be holding the same port, or the menu buttons the tests above drive by
	# hand would be silent in the real run.
	var app := APP.instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	var home: Node = app._active_view
	check.call(home != null and app._audio != null and home._audio == app._audio,
		"AUDIO: the shell injects its own runtime into the menu it routes to")
	app.queue_free()
	await tree.process_frame

## The manor itself: the one place where the music, the two machine loops, the room-aware footsteps
## and the interaction wiring are all live at once. Sounds are recorded, never played.
func _manor(check: Callable, tree: SceneTree) -> void:
	var play := MANOR.instantiate()
	var recorder := Recorder.new(play, Random.new(99))
	play.attach_audio(recorder)
	tree.root.add_child(play)
	play.set_physics_process(false)
	play.player.set_physics_process(false)
	play.player.place_at(Vector3(-7.2, 0.08, -1.64), -PI / 2.0)
	for frame: int in 3:
		await tree.physics_frame
	check.call(recorder.has_event("music", Port.MUSIC_DREAD_LOW),
		"AUDIO: entering the manor starts the default music tier")
	check.call(recorder.has_event("attach", Port.GENERATOR_LOOP)
		and recorder.has_event("attach", Port.RADIO_STATIC),
		"AUDIO: the generator and the radio each own a source on their own case")
	recorder.clear()
	await _walk(play, tree, Vector3(-4.5, -3.19, -11.0), Vector3(0.0, 0.0, 0.5), 6)
	check.call(recorder.count_sounds(Port.FOOTSTEP_STONE) >= 2
		and recorder.kinds_starting_with("sfx.footstep_wood").is_empty()
		and recorder.kinds_starting_with("sfx.footstep_wet").is_empty(),
		"AUDIO: walking the cellar is heard as stone and nothing else")
	recorder.clear()
	await _walk(play, tree, Vector3(-6.0, 0.08, 2.0), Vector3(0.0, 0.0, 0.5), 6)
	check.call(recorder.count_sounds(Port.FOOTSTEP_WOOD) >= 2
		and recorder.kinds_starting_with("sfx.footstep_stone").is_empty(),
		"AUDIO: walking the reception's boards is heard as wood")
	var placement_ok: bool = true
	for entry: Dictionary in recorder.sounds():
		placement_ok = placement_ok and absf((entry.position as Vector3).y - 0.08) < 0.5
	check.call(placement_ok, "AUDIO: a step is placed under the feet that made it")
	recorder.clear()
	await _walk(play, tree, Vector3(5.6, 0.08, 3.0), Vector3(0.0, 0.0, 0.5), 6)
	check.call(recorder.count_sounds(Port.FOOTSTEP_WET) >= 2
		and recorder.kinds_starting_with("sfx.footstep_wood").is_empty(),
		"AUDIO: walking the exposed veranda is heard as wet")
	# The side door: the spawn faces it, and the swing is what is heard.
	recorder.clear()
	var service = play.interaction_service
	play.player.place_at(Vector3(-7.2, 0.08, -1.64), -PI / 2.0)
	for frame: int in 3:
		await tree.physics_frame
	service.set_enabled(true)
	service.refresh_focus()
	check.call(service.read_focus().get("target_id") == "manor.door.side",
		"AUDIO: the spawn still faces the closed side door")
	var open_result: RefCounted = service.interact("manor.door.side",
		service.read_focus().get("revision", -1))
	check.call(open_result.ok, "AUDIO: the side door opens by the shared service (" + open_result.code + ")")
	check.call(recorder.count_sounds(Port.DOOR_OPEN) == 1,
		"AUDIO: a door that swings open is heard once, at its own hinge")
	for frame: int in 30:
		await tree.physics_frame
	var side: Node3D = play.find_child("manor_door_side", true, false)
	var door_view: Node = side.get_child(side.get_child_count() - 1)
	play.player.place_at(Vector3(-4.5, 0.08, -3.5), 0.0)
	var close_result: RefCounted = door_view._handler.execute(1)
	check.call(close_result.ok, "AUDIO: the door closes again once the sweep is clear ("
		+ close_result.code + ")")
	check.call(recorder.count_sounds(Port.DOOR_CLOSE) == 1, "AUDIO: closing it is heard closing once")
	# Dropping is the one notebook command whose sound happens in the world.
	recorder.clear()
	play._held_item.drop("demo_bandage")
	check.call(recorder.count_sounds(Port.PUT) == 1 and recorder.spatial_for(Port.PUT),
		"AUDIO: a dropped item is heard landing in the world")
	# A floor pickup: the second command is the one that takes it, and the one that sounds.
	var pickup: Node3D = play.find_child("manor_pickup_hall_bandage", true, false)
	play.player.place_at(Vector3(-5.0, 0.08, -1.6), 0.0)
	for frame: int in 2:
		await tree.physics_frame
	play.camera.look_at(pickup.global_position)
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	recorder.clear()
	var focus: Dictionary = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.hall_bandage",
		"AUDIO: the aim still finds the greybox pickup")
	# The greybox pickups this round left behind carry no line, so one command takes them: the
	# two-command shape is the delivered props', and it is checked on its own view above.
	var take_result: RefCounted = service.interact("manor.pickup.hall_bandage",
		focus.get("revision", -1))
	check.call(take_result.ok, "AUDIO: taking the greybox pickup commits by the shared service ("
		+ take_result.code + ")")
	check.call(recorder.count_sounds(Port.PICKUP) == 1, "AUDIO: taking it is heard once")
	var again: RefCounted = service.interact("manor.pickup.hall_bandage", focus.get("revision", -1))
	check.call(not again.ok, "AUDIO: a second take of the same object is refused (" + again.code + ")")
	check.call(recorder.count_sounds(Port.PICKUP) == 1, "AUDIO: a refused second take is silent")
	# The radio: switched on by its first look, and its static runs from that moment.
	var radio: Node3D = play.find_child(Props.RADIO_ID.replace(".", "_"), true, false)
	play.player.place_at(Vector3(1.60, Props.GROUND_FLOOR, 6.90), 0.0)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(radio.global_position)
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	recorder.clear()
	check.call(focus.get("target_id") == Props.RADIO_ID, "AUDIO: the aim finds the radio on its worktop")
	var radio_result: RefCounted = service.interact(Props.RADIO_ID, focus.get("revision", -1))
	check.call(radio_result.ok, "AUDIO: the radio's first look commits by the shared service ("
		+ radio_result.code + ")")
	check.call(recorder.ambience_state(Port.RADIO_STATIC) == true
		and recorder.has_event("ambience", Port.RADIO_STATIC),
		"AUDIO: a radio that is on has static from its own case")
	check.call(recorder.has_sound(Port.UI_SWITCH), "AUDIO: the switch that turns it on is a switch")
	# The pry and the cabinet, reached by putting the tool in the notebook rather than by walking to
	# it: what is under test here is the wiring between the state change and the sound.
	var inventory = play.character_service
	check.call(inventory.claim_pickup("audio.test.crowbar", "crowbar", 1,
		inventory.read_character().revision).ok, "AUDIO: the crowbar reaches the notebook")
	play.player.place_at(Vector3(-5.15, 0.0, -11.0), 0.0)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(Vector3(-5.15, 0.0, -9.89))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	recorder.clear()
	check.call(focus.get("target_id") == PRY_ID, "AUDIO: the aim finds the boards")
	var pry_result: RefCounted = service.interact(PRY_ID, focus.get("revision", -1))
	check.call(pry_result.ok, "AUDIO: the crowbar pries the cellar open (" + pry_result.code + ")")
	check.call(recorder.count_sounds(Port.PRY_WOOD) == 1 and recorder.count_sounds(Port.PRY_METAL) == 1,
		"AUDIO: prying is heard as wood and metal together")
	check.call(inventory.claim_pickup("audio.test.key", "manor_key", 1,
		inventory.read_character().revision).ok, "AUDIO: the manor key reaches the notebook")
	var diary: Node3D = play.find_child("manor_inspect_doctor_diary", true, false)
	play.player.place_at(Vector3(7.56, -0.025, -1.6), PI)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(diary.global_position + Vector3(0.0, 0.1, 0.0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	recorder.clear()
	check.call(focus.get("target_id") == CABINET_ID
		and focus.get("action_key") == "interaction.unlock",
		"AUDIO: the aim finds the locked cabinet, not the diary behind it")
	var lock_result: RefCounted = service.interact(CABINET_ID, focus.get("revision", -1))
	check.call(lock_result.ok, "AUDIO: the manor key opens the cabinet (" + lock_result.code + ")")
	check.call(recorder.count_sounds(Port.LOCK_OPEN) == 1, "AUDIO: the lock turning once is heard once")
	check.call(recorder.silent().is_empty(),
		"AUDIO: every event this run emitted was a mapped, bound source " + str(recorder.silent()))
	play.queue_free()
	await tree.process_frame

## Walks the body in half-metre steps and asks the manor for the steps it earned. The body's own
## physics is off, so the distance comes from the placements and nothing else.
func _walk(play: Node3D, tree: SceneTree, from: Vector3, step: Vector3, count: int) -> void:
	var point: Vector3 = from
	for index: int in count:
		point += step
		play.player.place_at(point, 0.0)
		play._physics_process(0.016)
		await tree.physics_frame

func _material_files(library: Library) -> Dictionary:
	var material: Dictionary = {}
	for kind: String in library.kinds():
		if not kind.begins_with("sfx."):
			continue
		for stream: Variant in library.entry(kind).pool:
			material[(stream as AudioStream).resource_path.get_file()] = true
	return material

func _loops(stream: AudioStream) -> bool:
	return stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop

## What the shipped import sidecar says, rather than what the loaded resource currently holds.
func _sidecar_loops(stream: AudioStream) -> bool:
	if stream == null:
		return false
	var sidecar := FileAccess.open(stream.resource_path + ".import", FileAccess.READ)
	return sidecar != null and sidecar.get_as_text().contains("loop=true")

func _playing_music(host: Node) -> AudioStreamPlayer:
	for child: Node in host.get_children():
		if child is AudioStreamPlayer and String(child.name).begins_with("Music") \
				and (child as AudioStreamPlayer).playing:
			return child
	return null
