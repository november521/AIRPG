extends Control
## The Dead Light opening: one video, played when the instance is entered and before anything of it
## is built. The view owns the player, the skip affordance and a guard for a stream that never ends;
## it owns no routing, so whoever started it decides what the instance does next.
signal finished
## Declared because every route view in this shell carries it and the shell wires them uniformly.
## The opening never asks to navigate: what follows the video is the shell's decision.
signal route_requested(route_id: String)

## The media itself. Kept here rather than in the scene so the only reference to the file is one
## line, and a missing file fails while the project loads rather than leaving an empty player behind.
const OPENING = preload("res://presentation/cinematic/deadlight_opening.ogv")
const Audio = preload("res://application/ports/audio_port.gd")
## Key presses that skip. Movement keys deliberately do not: a player who walks in with W held
## should still see the opening.
const SKIP_KEYS: Array[int] = [KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_K]
## Grace added to the stream length before the guard fires, so a slow decode is not cut off.
const GUARD_MARGIN: float = 5.0

var _playback_enabled: bool = true
var _done: bool = false
var _audio: Audio

@onready var _video: VideoStreamPlayer = $Video
@onready var _skip: Button = $SkipButton
@onready var _hint: Label = $Hint
@onready var _guard: Timer = $Guard

## Handed by bootstrap: the media layer cannot play a stream in a headless run, and the suite has to
## drive the cutscene without one, so both keep the flow testable instead of hanging on a video.
func configure(playback_enabled: bool) -> void:
	_playback_enabled = playback_enabled

func attach_audio(port: Audio) -> void:
	_audio = port

func _ready() -> void:
	_skip.text = tr("cutscene.skip")
	_hint.text = tr("cutscene.hint")
	_skip.pressed.connect(skip)
	_video.finished.connect(skip)
	_guard.timeout.connect(skip)
	_guard.one_shot = true
	_video.stream = OPENING

## Starts the opening. Every path out of it -- the stream ending, the player skipping, a stream that
## cannot play at all -- ends in `skip()`, so the instance is entered exactly once either way.
func begin() -> void:
	show()
	_skip.grab_focus()
	# The menu bed belongs to the menus; the opening brings its own audio.
	if _audio != null:
		_audio.set_music("")
	if not _playback_enabled or _video.stream == null:
		skip()
		return
	_guard.wait_time = maxf(1.0, _video.get_stream_length() + GUARD_MARGIN)
	_guard.start()
	_video.play()

## Ends the opening once. Idempotent: a skip that arrives after the stream already ended, or a guard
## that fires after a skip, must not advance the entry flow twice.
func skip() -> void:
	if _done:
		return
	_done = true
	_guard.stop()
	if _video.is_playing():
		_video.stop()
	finished.emit()

func _input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode in SKIP_KEYS:
		skip()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		skip()
		get_viewport().set_input_as_handled()
