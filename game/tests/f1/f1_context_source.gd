extends "res://application/dialogue/dialogue_context_source.gd"
## F1 test double: records gather calls and returns synthetic context. Test-only.

var calls: Array[Dictionary] = []
var fail_next: bool = false
var extra: Dictionary = {}

func gather(speaker_id: String, scene_id: String, topic_id: String) -> RefCounted:
	calls.append({"speaker_id": speaker_id, "scene_id": scene_id, "topic_id": topic_id})
	if fail_next:
		fail_next = false
		return Result.failure("TEST_CONTEXT_UNAVAILABLE")
	var context := {
		"perceptible": [{"observation_id": "test.observation.rain", "text": "合成现场信息"}],
		"recent_dialogue": [
			{"speaker_id": speaker_id, "text": "合成 NPC 台词"},
			{"speaker_id": "test.player", "text": "合成玩家台词"},
		],
		"key_memories": [{"source": "witnessed", "text": "合成记忆"}],
		"player_notes": ["合成玩家笔记"],
		"rumors": ["合成传闻"],
	}
	for key: Variant in extra:
		context[key] = extra[key]
	return Result.success(context)
