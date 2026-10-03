extends "res://application/exploration/interactions/interaction_handler.gd"
## Observe handler for a placed object that can be read, held up and put back. It commits the
## object's own stage and nothing else, so an observed object is never carried away as a whole.
##
## An object may instead carry something that the player pockets. That is the one case where the
## object talks to the pickup port, and the port is injected: the handler still owns no inventory
## state of its own. The receipt and the stage change are committed together, so a refused claim
## leaves the object exactly as it was. The hand-over happens at the stage the state calls its last
## one, so an object with more than three stages can offer several pages before it gives anything up.
##
## Every player-visible key is injected by bootstrap: the display name, one caption per stage and
## the action offered at each stage. Nothing is shared between two observed objects, so a second
## object cannot inherit the first one's prompts. An object that has been emptied gets its own
## caption and action lists, because its remaining loop is no longer the same one.
const State = preload("res://domain/exploration/inspect_state.gd")
const Inventory = preload("res://application/ports/pickup_inventory.gd")
const DEFAULT_ACTION_KEYS: Array[String] = ["interaction.inspect", "interaction.hold_to_look",
	"interaction.put_back"]
var _state: State
var _name_key: String
var _caption_keys: Array[String] = []
var _action_keys: Array[String] = []
var _emptied_action_keys: Array[String] = []
var _emptied_caption_keys: Array[String] = []
var _inventory: Inventory
var _keep_source_id: String = ""
var _keep_item_id: String = ""
var _keep_quantity: int = 1

func _init(state: State, name_key: String, caption_keys: Array[String],
		action_keys: Array[String] = DEFAULT_ACTION_KEYS,
		emptied_action_keys: Array[String] = [],
		emptied_caption_keys: Array[String] = []) -> void:
	_state = state
	_name_key = name_key
	_caption_keys.assign(caption_keys)
	_action_keys.assign(action_keys)
	_emptied_action_keys.assign(emptied_action_keys)
	_emptied_caption_keys.assign(emptied_caption_keys)

## Wires the object to the pickup port and names what it hands over. Left unwired, the object
## never produces a receipt, so a plain observation object cannot reach the notebook at all.
func enable_keep(inventory: Inventory, source_id: String, item_id: String, quantity: int) -> void:
	_inventory = inventory
	_keep_source_id = source_id
	_keep_item_id = item_id
	_keep_quantity = quantity

func read() -> Dictionary:
	var view: Dictionary = _state.snapshot()
	var stage: int = view.stage
	var emptied: bool = bool(view.get("emptied", false))
	var keys: Array[String] = _emptied_action_keys if emptied and _emptied_action_keys.size() > stage else _action_keys
	var captions: Array[String] = _emptied_caption_keys if emptied and _emptied_caption_keys.size() > stage else _caption_keys
	view.merge({"available": true, "name_key": _name_key,
		"action_key": keys[stage] if stage < keys.size() else "",
		"caption_key": captions[stage] if stage < captions.size() else ""})
	return view

func execute(expected_revision: int) -> Outcome:
	if _inventory != null and _state.hands_over():
		return _hand_over(expected_revision)
	var result: Outcome = _state.advance(expected_revision)
	if result.ok:
		changed.emit()
	return result

## Last stage of an object with something inside: the claim is checked before anything moves, so
## a refused claim cannot leave the object emptied with nothing in the notebook.
func _hand_over(expected_revision: int) -> Outcome:
	if not _state.accepts(expected_revision):
		return Outcome.failure("STALE_STATE")
	var receipt: Dictionary = _inventory.read_pickup(_keep_source_id)
	var claim: Outcome = _inventory.claim_pickup(_keep_source_id, _keep_item_id, _keep_quantity,
		int(receipt.get("revision", -1)))
	if not claim.ok:
		return claim
	var result: Outcome = _state.empty_out(expected_revision)
	if result.ok:
		changed.emit()
	return result

## Out-of-the-world stages: the object is off the world's aim, so it takes over the player's action.
## Movement freezes, looking around stays free, and the interact key applies to this object without
## the ray having to land on its world target again. That is what makes the way out discoverable.
## An emptied object with a short cycle never returns to those stages, so it stops owning the key.
func exclusive() -> bool:
	return _state.held()
