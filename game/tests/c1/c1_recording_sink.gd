extends "res://application/exploration/exploration_request_sink.gd"
## Test-only recording sink. It records deep copies of validated intent DTOs and can
## fail on demand to exercise the use case rejection path.

const FAILURE_CODE: String = "EXPLORATION_SINK_TEST_FAILURE"

var commands: Array[Dictionary] = []
var fail_next: bool = false

func submit(command: Dictionary) -> RefCounted:
	if fail_next:
		fail_next = false
		return Result.failure(FAILURE_CODE)
	commands.append(command.duplicate(true))
	return Result.success()
