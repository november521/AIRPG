extends RefCounted
## Sole publication gate between F1 validation and the dialogue view contract. A reply
## without the ReplyValidator marker is refused here even if it is a well-formed DTO, and
## the produced view event is validated again before it can be emitted.

const Result = preload("res://shared/result.gd")
const Contract = preload("res://application/contracts/dialogue_view_contract.gd")
const ReplyValidator = preload("res://domain/dialogue/reply_validator.gd")

const CODE_UNVALIDATED: String = "DIALOGUE_REPLY_UNVALIDATED"
const CODE_VIEW_INVALID: String = "DIALOGUE_VIEW_INVALID"

static func build(request_id: String, speaker_id: String, name_key: String, portrait_id: String,
		validated_reply: Dictionary) -> RefCounted:
	if not ReplyValidator.is_validated(validated_reply):
		return Result.failure(CODE_UNVALIDATED)
	var event := Contract.verified_reply(request_id, speaker_id, name_key, portrait_id,
		validated_reply.reply_text, validated_reply.options)
	if not event.ok:
		return Result.failure(CODE_VIEW_INVALID, [event.code])
	return event
