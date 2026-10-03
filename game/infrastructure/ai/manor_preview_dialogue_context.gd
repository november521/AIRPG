extends "res://application/dialogue/dialogue_context_source.gd"
## Manor dialogue context. It contributes only what the speaking NPC can perceive right now:
## the scene observation and who else is present. It carries no story facts — those come from
## the reviewed world book through the knowledge projector.
##
## The observer is injected by the composition root and returns observation dictionaries for
## one speaker. It never receives or returns knowledge, and unknown values fail closed.

var _observer: Callable = Callable()

func _init(observer: Callable = Callable()) -> void:
	_observer = observer

func gather(speaker_id: String, _scene_id: String, _topic_id: String) -> RefCounted:
	var observations: Array[Dictionary] = []
	if _observer.is_valid():
		var provided: Variant = _observer.call(speaker_id)
		if not provided is Array:
			return Result.failure("DIALOGUE_CONTEXT_INVALID")
		observations = provided
	return Result.success({"perceptible": observations, "recent_dialogue": [],
		"key_memories": [], "player_notes": [], "rumors": []})
