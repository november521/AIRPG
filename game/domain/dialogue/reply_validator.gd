extends RefCounted
## Semantic validation of a structurally valid model reply: speaker identity, facts the
## NPC is authorized to use now, and actions from the pre-declared catalog. A passing
## reply is sealed inside a ValidatedReply capability; plain dictionaries never qualify.

const Result = preload("res://shared/result.gd")
const ModelReply = preload("res://domain/dialogue/model_reply.gd")
const ValidatedReply = preload("res://domain/dialogue/validated_reply.gd")
const Policy = preload("res://domain/dialogue/reply_policy.gd")

## `policy` is the speaking character's reviewed output policy (empty when nothing is
## configured). Structure, speaker identity and facts are checked first; the policy runs
## last so a policy rejection never masks an identity or knowledge-boundary failure.
static func validate(data: Variant, expected_speaker_id: String, allowed_fact_ids: Array,
		known_fact_ids: Array, action_catalog, policy: Dictionary = {}) -> RefCounted:
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
	# The first NPC control slice is atomic for at most one semantic action.
	if reply.actions.size() > 1:
		return Result.failure("REPLY_ACTION_COUNT")
	for action: Dictionary in reply.actions:
		var parameters: RefCounted = action_catalog.validate(action.command_id, action.parameters)
		if not parameters.ok:
			return Result.failure("REPLY_ACTION_INVALID", [parameters.code, action.command_id])
		action.parameters = parameters.value
	var in_character := Policy.validate(policy, reply.reply_text)
	if not in_character.ok:
		return in_character
	var sealed := ValidatedReply.new()
	sealed._seal(reply)
	return Result.success(sealed)

static func is_validated(value: Variant) -> bool:
	return value is ValidatedReply
