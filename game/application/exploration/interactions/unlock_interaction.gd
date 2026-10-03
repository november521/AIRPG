extends "res://application/exploration/interactions/interaction_handler.gd"
## Unlock handler for a fixed container: it opens when the player carries one of the tools the
## manifest names, and otherwise refuses. It commits the container's own state and nothing else --
## no tool is consumed, no check is rolled and no story flag is written.
##
## The carried-tool question goes through the same injected pickup port the notebook uses, through
## its read-only side. Left unwired, the port answers that nothing is carried, so an unconfigured
## container can never be opened by accident.
##
## An opening that is worth a line of its own can name one: `done_key` is published by `read()` only
## once the container has actually been opened, so a refused command never reaches it and an already
## open container never repeats it. The line is a key, not a rendering: the caller decides where it
## appears.
const State = preload("res://domain/exploration/lock_state.gd")
const Inventory = preload("res://application/ports/pickup_inventory.gd")
## Returned to the caller, which owns the wording: the refusal is a failed command, exactly like a
## door that cannot close because somebody is standing in the sweep. A caller whose refusal means
## something else -- prying boards away rather than unlocking a cabinet -- injects its own code.
const REFUSED: String = "CABINET_LOCKED"
var _state: State
var _inventory: Inventory
var _name_key: String
var _action_key: String
var _accepted_items: Array[String] = []
var _refused_code: String = REFUSED
var _done_key: String = ""

func _init(state: State, inventory: Inventory, name_key: String, action_key: String,
		accepted_items: Array[String], refused_code: String = REFUSED,
		done_key: String = "") -> void:
	_state = state
	_inventory = inventory
	_name_key = name_key
	_action_key = action_key
	_accepted_items.assign(accepted_items)
	_refused_code = refused_code
	_done_key = done_key

func read() -> Dictionary:
	var view: Dictionary = _state.snapshot()
	# Once it is open the container stops claiming the aim ray. What is inside has to become the
	# thing the player can point at, and the ray only ever reports its nearest target.
	view.merge({"available": bool(view.locked), "name_key": _name_key, "action_key": _action_key,
		"caption_key": _done_key if pried() else ""})
	return view

func execute(expected_revision: int) -> Outcome:
	if not bool(_state.snapshot().get("locked", false)):
		return Outcome.failure("ALREADY_UNLOCKED")
	if not carries_accepted_item():
		return Outcome.failure(_refused_code)
	var result: Outcome = _state.unlock(expected_revision)
	if result.ok:
		changed.emit()
	return result

## True once this container has really been opened. A refusal leaves it false, and the state it
## reads has no way back, so the one opening line can only ever be reached once.
func pried() -> bool:
	return not bool(_state.snapshot().get("locked", true))

## The line this opening tells, empty for a container that says nothing when it gives way.
func done_key() -> String:
	return _done_key

## Read-only inventory question, so the container never consumes the key or the crowbar.
func carries_accepted_item() -> bool:
	if _inventory == null:
		return false
	for item_id: String in _accepted_items:
		if _inventory.holds(item_id):
			return true
	return false
