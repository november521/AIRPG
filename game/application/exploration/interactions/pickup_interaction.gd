extends "res://application/exploration/interactions/interaction_handler.gd"
const Inventory = preload("res://application/ports/pickup_inventory.gd")
var _inventory: Inventory
var _source_id: String
var _item_id: String
var _quantity: int
var _name_key: String

func _init(inventory: Inventory, source_id: String, item_id: String, quantity: int, name_key: String) -> void:
	_inventory = inventory
	_source_id = source_id
	_item_id = item_id
	_quantity = quantity
	_name_key = name_key
	_inventory.changed.connect(_on_inventory_changed)

func read() -> Dictionary:
	var receipt: Dictionary = _inventory.read_pickup(_source_id)
	return {"available": not receipt.get("claimed", true), "revision": receipt.get("revision", -1),
		"name_key": _name_key, "action_key": "interaction.pickup", "quantity": _quantity}

func execute(expected_revision: int) -> Outcome:
	return _inventory.claim_pickup(_source_id, _item_id, _quantity, expected_revision)

func _on_inventory_changed() -> void:
	changed.emit()

func dispose() -> void:
	if _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)
