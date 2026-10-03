extends "res://application/ports/audio_port.gd"
## The AudioServer adapter: the only place a bus name, a stream or an engine player appears. Every
## kind is resolved through the library, so callers keep speaking game events.
##
## The root is the node every player is added to -- the manor's own tree for the manor session, the
## app shell for the menus, either one for a test. A plain `Node` root is allowed: the menu shell
## never asks for a spatial sound, and one requested there anyway degrades to a flat player rather
## than shouting from the world origin.
##
## Continuous sources fade. A machine that stops dead is the single most artificial thing an engine
## can do, so switching a loop off ramps it to silence and only then stops it; switching it back on
## during the ramp kills the fade and takes the volume over from wherever it had reached.
const Library = preload("res://infrastructure/audio/audio_library.gd")
const Source = preload("res://application/ports/random_source.gd")
## Where a source sits while it is off. Not -80: the ramp has to be audible as a ramp.
const SILENT_DB: float = -60.0
const FADE_SECONDS: float = 0.75
const MUSIC_FADE_SECONDS: float = 1.6
const MUSIC_LEVEL_DB: float = 0.0
## The footstep detune, as a fraction either side of the recorded pitch.
const PITCH_JITTER: float = 0.05
## Resolution the integer random port is read at when a fraction is needed. The port itself is
## deliberately left alone: it is a shared contract with its own consumers.
const ROLL_STEPS: int = 1000
## Where the fade a source is currently running through is remembered on that source's own player.
const FADE_META := &"audio_fade"
var _root: Node
var _rng: Source
var _library: Library
## kind -> {player, on, level_db}. Loop sources and the non-positional beds share the shape; the fade
## they are running through is kept on the player they are moving, not here.
var _sources: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _music_index: int = 0
var _music_tier: String = ""
var _silent: Array[String] = []

func _init(root: Node, rng: Source = null) -> void:
	_root = root
	_rng = rng
	_library = Library.new()

func play_ui(kind: String) -> void:
	_play(kind, Vector3.ZERO, false)

func play_sfx(kind: String, position: Vector3) -> void:
	_play(kind, position, true)

## Binds a 3D loop to the machine it comes out of. Re-binding the same kind to the same host is a
## no-op, so a view may call this from its own configure without duplicating players.
func attach_loop(kind: String, host: Node) -> void:
	var entry: Dictionary = _library.entry(kind)
	if entry.is_empty() or host == null or not bool(entry.spatial):
		_note_silent(kind)
		return
	var bound: Dictionary = _sources.get(kind, {})
	if not bound.is_empty() and bound.player != null and bound.player.get_parent() == host:
		return
	_new_source(kind, entry, host)

func set_ambience(kind: String, on: bool) -> void:
	var entry: Dictionary = _library.entry(kind)
	if entry.is_empty():
		_note_silent(kind)
		return
	var state: Dictionary = _sources.get(kind, {})
	if state.is_empty():
		# A spatial source has no voice until it is bound to the machine it belongs to; a
		# non-positional bed is built on demand, because it belongs to no machine.
		if bool(entry.spatial):
			_note_silent(kind)
			return
		if not on:
			return
		state = _new_source(kind, entry, null)
	_switch(state, on)

## Two players alternate so a tier change is a crossfade rather than a gap.
func set_music(tier: String) -> void:
	if tier == _music_tier:
		return
	var stream: AudioStream = _library.music(tier)
	if stream == null or not is_instance_valid(_root):
		_note_silent("music." + tier)
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	while _music_players.size() < 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % _music_players.size()
		player.bus = _bus(Library.BUS_MUSIC)
		player.volume_db = SILENT_DB
		_root.add_child(player)
		_music_players.append(player)
	var outgoing: AudioStreamPlayer = _music_players[_music_index]
	_music_index = (_music_index + 1) % _music_players.size()
	var incoming: AudioStreamPlayer = _music_players[_music_index]
	_music_tier = tier
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	_ramp(incoming, false, MUSIC_LEVEL_DB, MUSIC_FADE_SECONDS)
	if outgoing != incoming and outgoing.playing:
		_ramp(outgoing, true, MUSIC_LEVEL_DB, MUSIC_FADE_SECONDS)

## Every kind that was asked for and produced no sound -- unmapped by this build, or a spatial source
## nobody bound to a machine. A scene can be driven in a test and assert that what it emitted was all
## real. Never raised as an error: audio must not be able to break a command.
func silent() -> Array[String]:
	return _silent.duplicate()

## The bus the project layout actually has, resolved by name. Falling back to Master keeps a scene
## audible if the layout resource is ever missing, instead of silently routing nowhere.
func _bus(name: String) -> String:
	return name if AudioServer.get_bus_index(name) >= 0 else "Master"

func _play(kind: String, position: Vector3, wants_place: bool) -> void:
	var entry: Dictionary = _library.entry(kind)
	if entry.is_empty():
		_note_silent(kind)
		return
	var pool: Array = entry.pool
	if pool.is_empty():
		_note_silent(kind)
		return
	var stream: AudioStream = pool[0] if pool.size() < 2 else pool[_pick(pool.size())]
	if stream == null:
		_note_silent(kind)
		return
	var spatial: bool = bool(entry.spatial) and wants_place
	emit_oneshot(kind, stream, entry, position, _pitch(entry), spatial)

## The mixer's whole decision for one one-shot: which take, on which bus, where, and by how much it
## was detuned. The production path turns that into a player and lets it free itself; a test
## overrides this one method to record the decision without an audio device.
func emit_oneshot(kind: String, stream: AudioStream, entry: Dictionary, position: Vector3,
		pitch: float, spatial: bool) -> void:
	if stream == null or not is_instance_valid(_root):
		return
	var player: Variant = null
	if spatial and _root is Node3D:
		var placed := AudioStreamPlayer3D.new()
		placed.unit_size = float(entry.unit_size)
		placed.max_distance = float(entry.max_distance)
		player = placed
	else:
		player = AudioStreamPlayer.new()
	_root.add_child(player)
	if player is AudioStreamPlayer3D:
		(player as AudioStreamPlayer3D).global_position = position
	player.stream = stream
	player.bus = _bus(String(entry.bus))
	player.volume_db = float(entry.level_db)
	player.pitch_scale = pitch
	player.play()
	player.connect(&"finished", player.queue_free)

## Builds one continuous source. `host` is the machine a spatial source hangs on; a null host means
## the kind is a non-positional bed and is parented to the root instead.
func _new_source(kind: String, entry: Dictionary, host: Node) -> Dictionary:
	var stream: AudioStream = entry.pool[0]
	if bool(entry.loop) and stream is AudioStreamOggVorbis:
		# The import sidecar already marks these, but "this kind loops" is the contract, so it is
		# enforced here as well rather than trusted to a re-import.
		(stream as AudioStreamOggVorbis).loop = true
	var player: Variant = null
	if host != null and host is Node3D:
		var placed := AudioStreamPlayer3D.new()
		placed.unit_size = float(entry.unit_size)
		placed.max_distance = float(entry.max_distance)
		placed.position = Vector3.ZERO
		player = placed
	else:
		player = AudioStreamPlayer.new()
	var parent: Node = host if host != null else _root
	if not is_instance_valid(parent):
		return {}
	parent.add_child(player)
	player.name = "AudioLoop" if host != null else "AudioBed"
	player.stream = stream
	player.bus = _bus(String(entry.bus))
	player.volume_db = SILENT_DB
	var state := {"player": player, "on": false, "level_db": float(entry.level_db)}
	_sources[kind] = state
	return state

## Idempotent on/off for a continuous source. Off ramps to silence and stops at the end of the ramp;
## on kills any ramp in flight and takes the volume over from where it was.
func _switch(state: Dictionary, on: bool) -> void:
	if bool(state.on) == on:
		return
	state.on = on
	_ramp(state.player, not on, float(state.level_db), FADE_SECONDS)

func _ramp(player: Variant, down: bool, level_db: float, seconds: float) -> void:
	# The fade in flight is remembered on the player itself, so it dies with the node it moves and a
	# re-bound loop never inherits a stale one.
	var fade: Tween = null
	if player.has_meta(FADE_META):
		fade = player.get_meta(FADE_META)
	if fade != null and fade.is_valid():
		fade.kill()
	if not player.is_inside_tree():
		# A fixture outside a tree still has to end up in the right state; it just cannot ramp.
		player.volume_db = SILENT_DB if down else level_db
		return
	if not down and not player.playing:
		player.play()
	fade = player.create_tween()
	fade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_property(player, "volume_db", SILENT_DB if down else level_db, seconds)
	if down:
		fade.tween_callback(player.stop)
	player.set_meta(FADE_META, fade)

func _pick(sides: int) -> int:
	if _rng == null or sides < 2:
		return 0
	var outcome: Variant = _rng.roll(sides)
	return int(outcome.value) - 1 if outcome.ok else 0

## Footsteps land on the same sample over and over without this: the pitch is nudged by up to the
## recorded fraction either way, which is what makes a bank of four sound like a walk.
func _pitch(entry: Dictionary) -> float:
	if not bool(entry.jitter) or _rng == null:
		return 1.0
	var fraction: float = float(_pick(ROLL_STEPS)) / float(ROLL_STEPS - 1)
	return 1.0 + (fraction * 2.0 - 1.0) * PITCH_JITTER

func _note_silent(kind: String) -> void:
	if not _silent.has(kind):
		_silent.append(kind)
