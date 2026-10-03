extends "res://presentation/exploration/interactions/pickup_view.gd"
## Shared world representation; identity comes from ItemData, not this scene.
const InteractionHandler = preload("res://application/exploration/interactions/interaction_handler.gd")
var _item_data: Resource

func configure_data(item_data: Resource, handler: InteractionHandler, quantity: int) -> void:
	_item_data = item_data
	configure(handler, item_data.display_name_key, quantity)

func item_id() -> String:
	return String(_item_data.id) if _item_data != null else ""

func _refresh() -> void:
	super._refresh()
	if not visible and is_inside_tree():
		queue_free()
