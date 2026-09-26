extends RefCounted
## Semantic validation of a structurally valid model reply: speaker identity, facts the
## NPC is authorized to use now, and actions from the pre-declared catalog. Only replies
## that pass carry the validation marker consumed by the publication gate.

const Result = preload("res://shared/result.gd")
const ModelReply = preload("res://domain/dialogue/model_reply.gd")

const VALIDATION_MARKER: String = "validated"

static func validate(data: Variant, expected_speaker_id: String, allowed_fact_ids: Array,
		known_fact_ids: Array, action_catalog) -> RefCounted:
	var structural := ModelReply.validate(data)
	if not structural.ok:
		return structural
	var reply: Dictionary = structural.value
	if reply.speaker_id != expected_speaker_id:
		return Result.failure("REPLY_SPEAKER_MISMATCH", [reply.speaker_id])
	for fact_id: String in reply.used_fact_ids:
		if fact_id not in known_fact_ids:
			return Result.failure("REPLY_UNKNOWN_FACT", [fact_id])
		if fact_id not in allowed_fact_ids:
			return Result.failure("REPLY_FACT_NOT_ALLOWED", [fact_id])
	for action: Dictionary in reply.actions:
		var parameters: RefCounted = action_catalog.validate(action.command_id, action.parameters)
		if not parameters.ok:
			return Result.failure("REPLY_ACTION_INVALID", [parameters.code, action.command_id])
		action.parameters = parameters.value
	reply[VALIDATION_MARKER] = true
	return Result.success(reply)

static func is_validated(reply: Dictionary) -> bool:
	return reply.get(VALIDATION_MARKER) == true
