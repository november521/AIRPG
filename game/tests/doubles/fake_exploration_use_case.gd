extends RefCounted
## UI test double. It records valid intent DTOs without touching story state.

const Contract = preload("res://application/contracts/exploration_contract.gd")

signal command_received(command: Dictionary)

var commands: Array[Dictionary] = []

func move(axis: Vector2) -> RefCounted:
	return _record(Contract.move(axis))

func interact(target_id: String) -> RefCounted:
	return _record(Contract.interact(target_id))

func investigate() -> RefCounted:
	return _record(Contract.investigate())

func _record(result: RefCounted) -> RefCounted:
	if result.ok:
		var command: Dictionary = result.value.duplicate(true)
		commands.append(command)
		command_received.emit(command.duplicate(true))
	return result
