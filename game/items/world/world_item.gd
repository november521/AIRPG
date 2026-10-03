extends "res://presentation/exploration/interactions/pickup_view.gd"
## Shared world representation; identity comes from ItemData, not this scene.
const InteractionHandler = preload("res://application/exploration/interactions/interaction_handler.gd")
var _item_data: Resource
var _item_id: String = ""

func configure_data(item_data: Resource, handler: InteractionHandler, quantity: int) -> void:
	_item_data = item_data
	_item_id = String(item_data.id)
	configure(handler, item_data.display_name_key, quantity)

func configure_runtime(item_id: String, handler: InteractionHandler, name_key: String, quantity: int) -> void:
	_item_data = null
	_item_id = item_id
	configure(handler, name_key, quantity)

func item_id() -> String:
	return _item_id

func _refresh() -> void:
	super._refresh()
	if not visible and is_inside_tree():
		queue_free()
