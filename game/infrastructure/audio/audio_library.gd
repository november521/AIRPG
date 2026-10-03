extends RefCounted
## The one place a semantic kind becomes a stream and a mixer slot. Bus names, file names and levels
## live here and nowhere else: the port above it speaks game events, the callers never see a path.
##
## The streams are `preload`ed rather than resolved by name at run time. That is a deliberate trade:
## the project gate forbids runtime resource resolution outside an adapter, and this is the adapter,
## but a preloaded stream also means a kind whose file went missing fails loudly at parse/load time
## instead of going quiet at the moment a door is opened.
##
## Pools exist because a repeated action must not be the same recording twice: the adapter picks a
## variant and (for the entries that ask for it) detunes it slightly. `game/audio/` itself is
## unchanged by all of this -- the 40 files are exactly the ones the asset round imported.
const Audio = preload("res://application/ports/audio_port.gd")
const BUS_MUSIC := "Music"
const BUS_AMBIENCE := "Ambience"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
## Reserved: the layout carries it and this round emits nothing on it, because no line is recorded.
const BUS_VOICE := "Voice"
## Spatial defaults: a source is audible across a room, not across the house.
const UNIT_SIZE: float = 4.0
const MAX_DISTANCE: float = 18.0
const FOOTSTEP_UNIT_SIZE: float = 3.0
const FOOTSTEP_MAX_DISTANCE: float = 12.0
## Interface sounds are short transients; they sit a little under the SFX bank so a click never
## fights a door.
const UI_LEVEL_DB: float = -2.0
## The generator is a long hum under the room and is left with more headroom than a one-shot.
const GENERATOR_LEVEL_DB: float = -4.0
const RADIO_LEVEL_DB: float = -6.0
## The three tiers this round can switch between. The library maps no other music, so a fourth tier
## cannot be asked for by accident.
const MUSIC_TIERS: Array[String] = [Audio.MUSIC_DREAD_LOW, Audio.MUSIC_BLACKOUT,
	Audio.MUSIC_FINALE]
# Interface bank (Kenney Interface Sounds / UI Audio, CC0).
const Click01 = preload("res://audio/ui/click_01.ogg")
const Click02 = preload("res://audio/ui/click_02.ogg")
const Click03 = preload("res://audio/ui/click_03.ogg")
const Confirm = preload("res://audio/ui/confirm.ogg")
const Cancel = preload("res://audio/ui/cancel.ogg")
const Switch = preload("res://audio/ui/switch.ogg")
const MenuStart = preload("res://audio/ui/menu_start.ogg")
const MenuClick = preload("res://audio/ui/menu_click.ogg")
const MenuBack = preload("res://audio/ui/menu_back.ogg")
# Manor one-shots and loops (rubberduck / qubodup / GboxMikeFozzy / YCbCr, all CC0).
const PickupItem = preload("res://audio/sfx/pickup_item.ogg")
const PutItem = preload("res://audio/sfx/put_item.ogg")
const DoorOpen = preload("res://audio/sfx/door_open.ogg")
const DoorClose = preload("res://audio/sfx/door_close.ogg")
const DoorCreak = preload("res://audio/sfx/door_creak.ogg")
const LockOpen = preload("res://audio/sfx/lock_open.ogg")
const LockClose = preload("res://audio/sfx/lock_close.ogg")
const PryWood = preload("res://audio/sfx/pry_wood.ogg")
const PryMetal = preload("res://audio/sfx/pry_metal.ogg")
const PourKerosene = preload("res://audio/sfx/pour_kerosene.ogg")
const GeneratorCrank = preload("res://audio/sfx/generator_crank.ogg")
const GeneratorLoop = preload("res://audio/sfx/generator_loop.ogg")
const RadioStatic = preload("res://audio/ambience/radio_static.ogg")
const FootstepWood = [
	preload("res://audio/sfx/footstep_wood_01.ogg"), preload("res://audio/sfx/footstep_wood_02.ogg"),
	preload("res://audio/sfx/footstep_wood_03.ogg"), preload("res://audio/sfx/footstep_wood_04.ogg"),
]
const FootstepStone = [
	preload("res://audio/sfx/footstep_stone_01.ogg"), preload("res://audio/sfx/footstep_stone_02.ogg"),
	preload("res://audio/sfx/footstep_stone_03.ogg"), preload("res://audio/sfx/footstep_stone_04.ogg"),
	preload("res://audio/sfx/footstep_stone_05.ogg"), preload("res://audio/sfx/footstep_stone_06.ogg"),
]
const FootstepWet = [
	preload("res://audio/sfx/footstep_wet_01.ogg"), preload("res://audio/sfx/footstep_wet_02.ogg"),
	preload("res://audio/sfx/footstep_wet_03.ogg"),
]
# Music beds (Joth, Ambience Pack 1, CC0).
const MusDreadLow = preload("res://audio/music/mus_dread_low.ogg")
const MusBlackout = preload("res://audio/music/mus_blackout.ogg")
const MusFinale = preload("res://audio/music/mus_finale.ogg")
var _kinds: Dictionary = {}

func _init() -> void:
	_kinds = {
		Audio.UI_CLICK: _flat(BUS_UI, [Click01, Click02, Click03]),
		Audio.UI_CONFIRM: _flat(BUS_UI, [Confirm]),
		Audio.UI_CANCEL: _flat(BUS_UI, [Cancel]),
		Audio.UI_SWITCH: _flat(BUS_UI, [Switch]),
		Audio.MENU_START: _flat(BUS_UI, [MenuStart]),
		Audio.MENU_CLICK: _flat(BUS_UI, [MenuClick]),
		Audio.MENU_BACK: _flat(BUS_UI, [MenuBack]),
		Audio.PICKUP: _spatial(BUS_SFX, [PickupItem]),
		Audio.PUT: _spatial(BUS_SFX, [PutItem]),
		# A door in this house sometimes gives a creak instead of a clean swing, so the creak is the
		# alternate take of both door kinds rather than a kind of its own: two entries, three files.
		Audio.DOOR_OPEN: _spatial(BUS_SFX, [DoorOpen, DoorCreak]),
		Audio.DOOR_CLOSE: _spatial(BUS_SFX, [DoorClose, DoorCreak]),
		Audio.LOCK_OPEN: _spatial(BUS_SFX, [LockOpen]),
		Audio.LOCK_CLOSE: _spatial(BUS_SFX, [LockClose]),
		Audio.PRY_WOOD: _spatial(BUS_SFX, [PryWood]),
		Audio.PRY_METAL: _spatial(BUS_SFX, [PryMetal]),
		Audio.POUR_KEROSENE: _spatial(BUS_SFX, [PourKerosene]),
		Audio.GENERATOR_CRANK: _spatial(BUS_SFX, [GeneratorCrank]),
		Audio.FOOTSTEP_WOOD: _steps(FootstepWood),
		Audio.FOOTSTEP_STONE: _steps(FootstepStone),
		Audio.FOOTSTEP_WET: _steps(FootstepWet),
		Audio.GENERATOR_LOOP: _loop(BUS_SFX, GeneratorLoop, GENERATOR_LEVEL_DB, 6.0, 26.0),
		Audio.RADIO_STATIC: _loop(BUS_SFX, RadioStatic, RADIO_LEVEL_DB, 4.0, 16.0),
	}

## One interface sound. Flat by definition: the UI bank is never positional.
func _flat(bus: String, pool: Array) -> Dictionary:
	return {"bus": bus, "pool": pool, "spatial": false, "jitter": false, "level_db": UI_LEVEL_DB,
		"unit_size": UNIT_SIZE, "max_distance": MAX_DISTANCE, "loop": false}

func _spatial(bus: String, pool: Array) -> Dictionary:
	return {"bus": bus, "pool": pool, "spatial": true, "jitter": false, "level_db": 0.0,
		"unit_size": UNIT_SIZE, "max_distance": MAX_DISTANCE, "loop": false}

## The footstep banks: the one family that asks for a detune, and the one that is always a pool.
func _steps(pool: Array) -> Dictionary:
	return {"bus": BUS_SFX, "pool": pool, "spatial": true, "jitter": true, "level_db": 0.0,
		"unit_size": FOOTSTEP_UNIT_SIZE, "max_distance": FOOTSTEP_MAX_DISTANCE, "loop": false}

func _loop(bus: String, stream: AudioStream, level_db: float, unit_size: float,
		max_distance: float) -> Dictionary:
	return {"bus": bus, "pool": [stream], "spatial": true, "jitter": false, "level_db": level_db,
		"unit_size": unit_size, "max_distance": max_distance, "loop": true}

## The mixer slot a kind plays through, or {} for a kind this build cannot emit. A caller asking for
## an unknown kind gets silence, never a crash: audio must not be able to break a command.
func entry(kind: String) -> Dictionary:
	return _kinds.get(kind, {})

func has(kind: String) -> bool:
	return _kinds.has(kind)

## Every kind this library can play, so a test can prove the port's contract and the table agree.
func kinds() -> Array[String]:
	var out: Array[String] = []
	for kind: String in _kinds:
		out.append(kind)
	out.sort()
	return out

## The music bed for a tier, or null for a tier this build has no track for.
func music(tier: String) -> AudioStream:
	match tier:
		Audio.MUSIC_DREAD_LOW:
			return MusDreadLow
		Audio.MUSIC_BLACKOUT:
			return MusBlackout
		Audio.MUSIC_FINALE:
			return MusFinale
	return null
