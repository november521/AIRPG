extends "res://application/exploration/interactions/interaction_handler.gd"
## Start/stop handler for a placed device. It commits the device's own state and
## nothing else: no power grid, no power supply and no story flag.
##
## A gated device is inspected before it can be operated: the first command commits the first look,
## the prompt then moves on to start/stop, and the first look's text is published until the device
## is actually run. Ungated, the handler behaves exactly as it always did.
##
## A device may also require one carried item before it runs. The question goes to the read-only
## side of the inventory port, so asking never claims, spends or consumes anything, and a refused
## start leaves the device exactly as it was -- not running, and with its first-look text still on
## screen, because the refusal is not an operation.
const Inventory = preload("res://application/ports/pickup_inventory.gd")
const State = preload("res://domain/exploration/device_state.gd")
const INSPECT_ACTION_KEY := "interaction.device.inspect"
## Failure code a refused start returns when the required item is not carried.
const NEEDS_ITEM := "DEVICE_NEEDS_ITEM"
var _state: State
var _name_key: String
var _inspect_caption_key: String
var _inventory: Inventory
var _required_item_id: String = ""
var _refused_code: String = NEEDS_ITEM

func _init(state: State, name_key: String, inspect_caption_key: String = "",
		inventory: Inventory = null, required_item_id: String = "",
		refused_code: String = NEEDS_ITEM) -> void:
	_state = state
	_name_key = name_key
	_inspect_caption_key = inspect_caption_key
	_inventory = inventory
	_required_item_id = required_item_id
	_refused_code = refused_code

func read() -> Dictionary:
	var view: Dictionary = _state.snapshot()
	var action_key: String = "interaction.device.start"
	var caption_key: String = ""
	if not _state.inspected():
		action_key = INSPECT_ACTION_KEY
	else:
		if bool(view.get("running", false)):
			action_key = "interaction.device.stop"
		if not _state.operated():
			caption_key = _inspect_caption_key
	view.merge({"available": true, "name_key": _name_key, "action_key": action_key,
		"caption_key": caption_key, "requires": _required_item_id})
	return view

## The whole fuel rule: the item has to be in the notebook. It does not have to be equipped, and it
## is never spent, so this round only asks whether the player is carrying it.
func carried() -> bool:
	if _required_item_id.is_empty():
		return true
	if _inventory == null:
		return false
	return _inventory.holds(_required_item_id)

func execute(expected_revision: int) -> Outcome:
	var result: Outcome
	if _state.inspected():
		if not carried():
			return Outcome.failure(_refused_code)
		result = _state.toggle(expected_revision)
	else:
		result = _state.inspect(expected_revision)
	if result.ok:
		changed.emit()
	return result
