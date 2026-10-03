extends "res://application/dialogue/dialogue_context_source.gd"
## Synthetic preview context only. It contains no Dead Light facts or authored secrets.

var _observation_text: String = ""

func _init(observation_text: String = "") -> void:
	_observation_text = observation_text

func gather(_speaker_id: String, _scene_id: String, _topic_id: String) -> RefCounted:
	var observations: Array[Dictionary] = []
	if not _observation_text.strip_edges().is_empty():
		observations.append({"observation_id": "preview.observation.player_present",
			"text": _observation_text})
	return Result.success({"perceptible": observations, "recent_dialogue": [],
		"key_memories": [], "player_notes": [], "rumors": []})
