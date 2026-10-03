extends "res://application/exploration/interactions/interaction_handler.gd"
## Floor pickup handler. It commits the receipt and nothing else: the item definition, its quantity
## and its notebook entry all belong to the inventory port.
##
## `caption_key` is optional and is the one narrative line the pickup puts on screen. When it is
## given, the pickup takes two commands instead of one: the first only reads the line out and leaves
## the object where it is, and only the second commits the receipt. That is why the flag lives here
## and not in the view -- "have I told this line yet" is the same fact as "is this still only being
## looked at". A pickup placed without a key keeps the original single-command behaviour exactly, so
## nothing that has no line to tell changes shape.
##
## The handler only publishes keys through `read()`; it renders nothing, so no UI lives in the use
## case and bootstrap decides which items speak.
##
## `narration()` is the second, separate question: not "what could be said about this object" but
## "what has this object already said". A pickup is refreshed by every change its inventory port
## reports, including one another object caused, so the layer must key off the telling itself rather
## than off a refresh.
const Inventory = preload("res://application/ports/pickup_inventory.gd")
## The two action names a pickup can offer. A pickup that has a line to tell spends its first
## command on `EXAMINE_ACTION_KEY`, the same wording the observed objects use for their first look,
## and its second on the ordinary take; one without a line only ever offers the take.
const EXAMINE_ACTION_KEY := "interaction.inspect"
const TAKE_ACTION_KEY := "interaction.pickup"
var _inventory: Inventory
var _source_id: String
var _item_id: String
var _quantity: int
var _name_key: String
var _caption_key: String
var _examined: bool = false
var _taken: bool = false

func _init(inventory: Inventory, source_id: String, item_id: String, quantity: int, name_key: String,
		caption_key: String = "") -> void:
	_inventory = inventory
	_source_id = source_id
	_item_id = item_id
	_quantity = quantity
	_name_key = name_key
	_caption_key = caption_key
	_inventory.changed.connect(_on_inventory_changed)

func read() -> Dictionary:
	var receipt: Dictionary = _inventory.read_pickup(_source_id)
	var claimed: bool = bool(receipt.get("claimed", true))
	if claimed:
		_taken = true
	var told: bool = _caption_key.is_empty() or _examined
	return {"available": not claimed, "revision": receipt.get("revision", -1),
		"name_key": _name_key, "action_key": TAKE_ACTION_KEY if told else EXAMINE_ACTION_KEY,
		"quantity": _quantity, "caption_key": _caption_key}

## What this pickup has actually said. Silent until the player's first command on it, because being
## placed in the world is not the same as having been looked at; silent again once it has been taken,
## because the line goes with the object. This is what the scene's caption layer follows.
func narration() -> String:
	return "" if _taken or not _examined else _caption_key

## The line this pickup offers to tell. Empty for an item that stays silent, and for one that has
## already told it.
func caption_key() -> String:
	return _caption_key if not _examined else ""

## True once the line has been read out, which is also when the prompt moves on from looking to
## taking. A pickup with no line is never in the looking stage.
func examined() -> bool:
	return _examined

func execute(expected_revision: int) -> Outcome:
	# A pickup with nothing to say has no first stage: it commits the receipt straight away.
	if not _caption_key.is_empty() and not _examined:
		var receipt: Dictionary = _inventory.read_pickup(_source_id)
		if bool(receipt.get("claimed", true)):
			return Outcome.failure("TARGET_UNAVAILABLE")
		# Reading the line commits nothing: no receipt, no notebook entry, no revision.
		_examined = true
		changed.emit()
		return Outcome.success(read())
	var result: Outcome = _inventory.claim_pickup(_source_id, _item_id, _quantity, expected_revision)
	if result.ok:
		# The inventory announces its own change before this handler knows the object is gone, so the
		# view has to be told once more now that it is: that second announcement is what takes the
		# line off the caption layer.
		_taken = true
		changed.emit()
	return result

func _on_inventory_changed() -> void:
	changed.emit()

func dispose() -> void:
	if _inventory.changed.is_connected(_on_inventory_changed):
		_inventory.changed.disconnect(_on_inventory_changed)
