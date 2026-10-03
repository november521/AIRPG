extends RefCounted
## The manor session's sound: the adapter that plays it, plus the two rules that belong to walking
## rather than to any one object -- footsteps earned by distance over the floor the player is standing
## on, and the crosshair ticking onto a new target. Everything else the manor hears is wired per
## object by the placement helpers, so nothing here knows what a generator or a wallet is.
const Audio = preload("res://application/ports/audio_port.gd")
const GodotAudio = preload("res://infrastructure/audio/godot_audio.gd")
const GodotRandomSource = preload("res://infrastructure/random/godot_random_source.gd")
const Cadence = preload("res://application/exploration/step_cadence.gd")
const Surface = preload("res://infrastructure/exploration/ground_surface_probe.gd")
const RoomMap = preload("res://presentation/shell/manor_room_map.gd")
var _port: Audio
var _cadence := Cadence.new()
var _surface := Surface.new()
var _last := Vector3.ZERO
var _focus_id: String = ""

## Starts the session and answers the port every scene object is handed. `injected` is a caller's own
## port -- a test that records decisions instead of playing them -- and is used as it is; otherwise
## the real adapter is built with `root` as the parent of every player it will ever create, so
## leaving the manor takes the music, the machine loops and their fades with it.
func begin(root: Node, injected: Audio = null) -> Audio:
	_port = injected if injected != null else GodotAudio.new(root, GodotRandomSource.new())
	_port.set_music(Audio.MUSIC_DREAD_LOW)
	return _port

## Where the walk starts from, so the first frame does not count the spawn as distance covered.
func watch(player: Node3D) -> void:
	_last = player.global_position

## The aim ray finding something is an interface event rather than a world sound: the crosshair
## ticking onto an object is heard in the head, so it is a flat click and only when the target
## actually changes.
func focus_changed(target_id: String) -> void:
	if target_id == _focus_id:
		return
	_focus_id = target_id
	if not target_id.is_empty():
		_port.play_ui(Audio.UI_CLICK)

## The one sound that happens where the player is standing rather than where they are aiming.
func item_dropped(position: Vector3) -> void:
	_port.play_sfx(Audio.PUT, position)

## Steps are earned by distance walked rather than by elapsed time, so one cadence covers the walk and
## the slow pace without a second constant. The bank comes from the room the player is in; the probe
## only confirms there is a floor within a step, which is what keeps the stairwell quiet while the
## player is over an opened hole, and what takes a shortcut teleport out of the count.
func walked(player: CollisionObject3D) -> void:
	var here: Vector3 = player.global_position
	var moved: float = Vector2(here.x - _last.x, here.z - _last.z).length()
	_last = here
	var steps: int = _cadence.advance(moved)
	if steps < 1:
		return
	var kind: String = _surface.footstep_kind(player.get_world_3d().direct_space_state, here,
		RoomMap.room_id(here), [player.get_rid()])
	if kind.is_empty():
		return
	for _step: int in steps:
		_port.play_sfx(kind, here)
