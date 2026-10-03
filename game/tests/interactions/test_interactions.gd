extends RefCounted
const Result = preload("res://shared/result.gd")
const Preview = preload("res://bootstrap/character_preview.gd")
const State = preload("res://domain/character/character_state.gd")
const DoorState = preload("res://domain/exploration/door_state.gd")
const Door = preload("res://application/exploration/interactions/door_interaction.gd")
const Pickup = preload("res://application/exploration/interactions/pickup_interaction.gd")
const Service = preload("res://application/exploration/interaction_service.gd")

class Aim:
	extends "res://application/ports/interaction_probe.gd"
	var hit: Dictionary = {}
	func observe() -> Outcome:
		return Outcome.failure("NO_TARGET") if hit.is_empty() else Outcome.success(hit.duplicate(true))

class Clearance:
	extends "res://application/ports/door_clearance.gd"
	var clear: bool = true
	func is_clear_pose(_from_open: bool, _to_open: bool, _from_yaw: float, _to_yaw: float) -> bool:
		return clear

func run(check: Callable) -> void:
	var inventory = Preview.build()
	var aim := Aim.new()
	var clearance := Clearance.new()
	var state := DoorState.new()
	var door := Door.new(state, clearance, "interaction.door.side", PI / 2)
	var pickup := Pickup.new(inventory, "manor.pickup.fixture", "demo_bandage", 2, "item.bandage")
	var service := Service.new(aim, 2.4)
	check.call(service.register_target("door", door).ok, "INTERACT: register door")
	check.call(service.register_target("pickup", pickup).ok, "INTERACT: register pickup")
	check.call(not service.register_target("door", door).ok, "INTERACT: duplicate target rejected")
	check.call(not service.register_target("../bad", door).ok, "INTERACT: invalid stable ID rejected")
	check.call(service.interact("door", 0).code == "INTERACTION_DISABLED", "INTERACT: disabled commands rejected")
	service.set_enabled(true)
	check.call(not service.register_target("late", door).ok, "INTERACT: registry sealed before commands")
	service.refresh_focus()
	check.call(service.read_focus().is_empty(), "INTERACT: no sight has no hint")
	aim.hit = {"target_id": "door", "distance": 1.0}
	service.refresh_focus()
	var view: Dictionary = service.read_focus()
	view.name_key = "changed"
	check.call(service.read_focus().name_key == "interaction.door.side", "INTERACT: focus snapshots isolated")
	check.call(service.interact("door", 0).ok and state.snapshot().open, "INTERACT: door opens by use case")
	var before: Dictionary = state.snapshot()
	check.call(door.execute(0).code == "STALE_STATE" and state.snapshot() == before, "INTERACT: stale toggle cannot reverse door")
	check.call(service.interact("door", 1).code == "TARGET_UNAVAILABLE" and not door.read().available,
		"INTERACT: door cannot reverse while opening")
	door.finish_motion()
	clearance.clear = false
	check.call(service.interact("door", 1).code == "DOOR_BLOCKED" and state.snapshot() == before, "INTERACT: blocked sweep leaves door and revision intact")
	clearance.clear = true
	check.call(service.interact("door", 1).ok and not state.snapshot().open, "INTERACT: clear door can close")
	check.call(not door.read().available, "INTERACT: closing door stays unavailable until animation completes")
	door.finish_motion()
	aim.hit.distance = 3.0
	check.call(service.interact("door", 2).code == "TARGET_OUT_OF_RANGE", "INTERACT: range checked on execution")
	aim.hit.distance = NAN
	check.call(service.interact("door", 2).code == "TARGET_OUT_OF_RANGE", "INTERACT: nonfinite range rejected")
	aim.hit.distance = true
	check.call(service.interact("door", 2).code == "INVALID_TARGET_OBSERVATION", "INTERACT: boolean is not distance")
	aim.hit = {"target_id": "pickup", "distance": 1.0}
	check.call(service.interact("door", 2).code == "TARGET_CHANGED", "INTERACT: aim change rejects old UI target")
	aim.hit.clear()
	check.call(service.interact("door", 2).code == "NO_TARGET", "INTERACT: occlusion rejects previously focused target")
	check.call(state.snapshot().revision == 2, "INTERACT: all target failures leave door intact")
	check.call(service.interact("unknown", 0).code == "UNKNOWN_TARGET", "INTERACT: unknown target rejected")
	aim.hit = {"target_id": "pickup", "distance": 1.0}
	var reentrant: Array[String] = []
	var callback := func() -> void:
		reentrant.append(service.interact("pickup", inventory.read_character().revision).code)
	inventory.changed.connect(callback)
	check.call(service.interact("pickup", 0).ok, "INTERACT: pickup accepted")
	view = inventory.read_character()
	check.call(view.inventory.demo_bandage == 5 and view.pickup_receipts.has("manor.pickup.fixture"), "INTERACT: receipt and stack committed together")
	check.call(reentrant == ["INTERACTION_BUSY"], "INTERACT: changed subscriber cannot reenter command")
	inventory.changed.disconnect(callback)
	check.call(not pickup.read().available, "INTERACT: world availability derives from receipt")
	check.call(service.interact("pickup", 1).code == "TARGET_UNAVAILABLE", "INTERACT: duplicate world pickup rejected")
	check.call(inventory.claim_pickup("manor.pickup.fixture", "demo_bandage", 2, 1).code == "PICKUP_ALREADY_CLAIMED", "INTERACT: receipt also guards inventory boundary")
	check.call(inventory.read_character() == view, "INTERACT: duplicate pickup changes nothing")
	inventory.preview_action("reset", 1)
	check.call(not pickup.read().available and inventory.read_character().revision == 2, "INTERACT: preview reset retains receipt and monotonic revision")
	check.call(inventory.claim_pickup("manor.pickup.bad", "unknown", 1, 2).code == "ITEM_UNKNOWN", "INTERACT: unknown item rejected")
	check.call(inventory.claim_pickup("manor.pickup.bad", "demo_bandage", 0, 2).code == "INVALID_PICKUP", "INTERACT: nonpositive pickup rejected")
	check.call(inventory.claim_pickup("../bad", "demo_bandage", 1, 2).code == "INVALID_PICKUP", "INTERACT: invalid source rejected")
	check.call(inventory.claim_pickup("manor.pickup.bad", "demo_bandage", 999, 2).code == "STACK_LIMIT", "INTERACT: overflow pickup rejected")
	check.call(not inventory.read_character().pickup_receipts.has("manor.pickup.bad") and pickup.read().revision == 2, "INTERACT: failed inventory claim cannot hide object or advance revision")
	var snapshot: Dictionary = inventory.read_character()
	snapshot.pickup_receipts.clear()
	check.call(inventory.read_pickup("manor.pickup.fixture").claimed, "INTERACT: receipt view isolated")
	var domain := State.new()
	var initial: Dictionary = inventory.read_character()
	initial.erase("profile")
	initial.erase("definitions")
	initial.erase("held_item")
	initial.revision = 0
	check.call(domain.configure(inventory.read_character().definitions, initial).ok, "INTERACT: v2 domain fixture accepted")
	var candidate: Dictionary = domain.snapshot()
	candidate.pickup_receipts.clear()
	check.call(not domain.commit(0, candidate).ok and domain.snapshot() == initial, "INTERACT: receipts cannot be removed by ordinary transaction")
	candidate = domain.snapshot()
	candidate.pickup_receipts["manor.pickup.invalid"] = 1
	check.call(not domain.commit(0, candidate).ok, "INTERACT: nonboolean receipt rejected")
	candidate = domain.snapshot()
	candidate.schema_version = 1
	check.call(not domain.commit(0, candidate).ok, "INTERACT: old internal state version rejected explicitly")
	service.set_enabled(false)
	check.call(service.read_focus().is_empty() and service.interact("door", 2).code == "INTERACTION_DISABLED", "INTERACT: panel or lost focus blocks commands")
	service.close()
	service.set_enabled(true)
	check.call(service.interact("door", 2).code == "INTERACTION_DISABLED", "INTERACT: exited session cannot resume")
	check.call(not inventory.changed.is_connected(pickup._on_inventory_changed), "INTERACT: session close disconnects inventory subscription")
