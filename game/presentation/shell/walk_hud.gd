extends CanvasLayer

@onready var _status: Label = $Panel/Labels/Status

func _ready() -> void:
	$Panel/Labels/Title.text = tr("walk.title")
	$Panel/Labels/Help.text = tr("walk.help")
	$Panel/Labels/Note.text = tr("walk.note")

func show_location(point: Vector3, active: bool) -> void:
	if not active:
		_status.text = tr("walk.paused")
	elif point.y < -1.2:
		_status.text = tr("walk.cellar")
	else:
		_status.text = tr("walk.outside") if point.y < -0.1 else tr("walk.inside")

func show_ui_state(text_key: String) -> void:
	_status.text = tr(text_key)
