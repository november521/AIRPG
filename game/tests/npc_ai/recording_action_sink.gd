extends "res://application/ports/npc_action_sink.gd"

var proposals: Array[Dictionary] = []
var reject: bool = false

func accept(proposal: Dictionary) -> RefCounted:
	if reject:
		return Result.failure("TEST_ACTION_REJECTED")
	proposals.append(proposal.duplicate(true))
	return Result.success()
