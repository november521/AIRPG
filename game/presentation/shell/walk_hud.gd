extends CanvasLayer
const RoomMap = preload("res://presentation/shell/manor_room_map.gd")

@onready var _location: Label = $Layout/Location
@onready var _note: Label = $Layout/Note
@onready var _status: Label = $Layout/Status
var _room_id := ""

func _ready() -> void:
	$Layout/Eyebrow.text = tr("ui.location_eyebrow")
	_note.text = ""
	_status.text = ""

func show_location(point: Vector3, active: bool) -> void:
	if not active:
		_status.text = tr("walk.paused")
		return
	_status.text = ""
	var next_id: String = RoomMap.room_id(point)
	if next_id == _room_id:
		return
	_room_id = next_id
	_location.text = tr("ui.room." + next_id)
	_note.text = tr("ui.room_note." + next_id)
	_location.modulate.a = 0.0
	_note.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_location, "modulate:a", 1.0, 0.25)
	tween.tween_property(_note, "modulate:a", 1.0, 0.4)

func show_ui_state(text_key: String) -> void:
	_status.text = tr(text_key)
