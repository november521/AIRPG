extends RefCounted
## Dialogue UI test double. Events are explicitly created through the view contract.

const Contract = preload("res://application/contracts/dialogue_view_contract.gd")

signal view_event(event: Dictionary)
signal submission_received(submission: Dictionary)

var submissions: Array[Dictionary] = []

func submit_text(request_id: String, text: String) -> RefCounted:
	return _submit(Contract.player_text(request_id, text))

func select_option(request_id: String, option_id: String) -> RefCounted:
	return _submit(Contract.option_selection(request_id, option_id))

func publish(result: RefCounted) -> bool:
	if not result.ok:
		return false
	var validated := Contract.validate_view_event(result.value)
	if not validated.ok:
		return false
	view_event.emit(validated.value.duplicate(true))
	return true

func _submit(result: RefCounted) -> RefCounted:
	if result.ok:
		var submission: Dictionary = result.value.duplicate(true)
		submissions.append(submission)
		submission_received.emit(submission.duplicate(true))
	return result
