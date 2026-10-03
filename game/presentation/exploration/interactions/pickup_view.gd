extends Node3D
const Handler = preload("res://application/exploration/interactions/interaction_handler.gd")
var _handler: Handler

func configure(handler: Handler, name_key: String, quantity: int) -> void:
	_handler = handler
	$Name.text = tr(name_key) + " × " + str(quantity)
	_handler.changed.connect(_refresh)
	_refresh()

func configure_item(handler: Handler, name_key: String, quantity: int) -> void:
	configure(handler, name_key, quantity)

func _refresh() -> void:
	var available: bool = _handler.read().available
	visible = available
	$Target.collision_layer = 8 if available else 0

func _exit_tree() -> void:
	if _handler != null and _handler.changed.is_connected(_refresh):
		_handler.changed.disconnect(_refresh)
