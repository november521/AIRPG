extends RefCounted
## Progressive reveal of an already fully validated reply.
## Knows nothing about requests, state or the model; it only animates a label.

signal finished()

const TICK_SECONDS: float = 0.03
const DEFAULT_SECONDS: float = 2.0

var _timer: Timer
var _label: RichTextLabel
var _text: String = ""
var _visible: int = 0
var _step: int = 1
var _active: bool = false

func attach(label: RichTextLabel, parent: Node) -> void:
	_label = label
	_timer = Timer.new()
	_timer.name = "PlaybackTimer"
	_timer.wait_time = TICK_SECONDS
	_timer.timeout.connect(_on_tick)
	parent.add_child(_timer)

func start(text: String, seconds: float = DEFAULT_SECONDS) -> void:
	if _timer == null:
		return
	_text = text
	_visible = 0
	_active = true
	_label.text = ""
	var ticks: float = max(1.0, seconds / _timer.wait_time)
	_step = maxi(1, int(ceil(float(text.length()) / ticks)))
	_timer.start()

func skip() -> void:
	if _active:
		_visible = _text.length()
		_finish()

func stop() -> void:
	if _timer != null:
		_timer.stop()
	_active = false

func clear() -> void:
	stop()
	_text = ""
	_visible = 0
	if _label != null:
		_label.text = ""

func is_active() -> bool:
	return _active

func full_text() -> String:
	return _text

func visible_length() -> int:
	return _visible

func _on_tick() -> void:
	_visible = mini(_visible + _step, _text.length())
	_label.text = _text.substr(0, _visible)
	if _visible >= _text.length():
		_finish()

func _finish() -> void:
	_active = false
	_timer.stop()
	_label.text = _text
	finished.emit()
