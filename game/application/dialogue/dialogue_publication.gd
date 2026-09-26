extends RefCounted
## Sole publication gate between F1 validation and the dialogue view contract. Only a
## ValidatedReply sealed by ReplyValidator can pass; a plain Dictionary, including one
## carrying a `validated` field, is refused. The produced view event is validated again.

const Result = preload("res://shared/result.gd")
const Contract = preload("res://application/contracts/dialogue_view_contract.gd")
const ValidatedReply = preload("res://domain/dialogue/validated_reply.gd")

const CODE_UNVALIDATED: String = "DIALOGUE_REPLY_UNVALIDATED"
const CODE_VIEW_INVALID: String = "DIALOGUE_VIEW_INVALID"

static func build(request_id: String, speaker_id: String, name_key: String, portrait_id: String,
		validated_reply: Variant) -> RefCounted:
	if not validated_reply is ValidatedReply:
		return Result.failure(CODE_UNVALIDATED)
	var data: Dictionary = validated_reply.data()
	if not data.get("reply_text") is String or not data.get("options") is Array:
		return Result.failure(CODE_UNVALIDATED)
	var event := Contract.verified_reply(request_id, speaker_id, name_key, portrait_id,
		data.reply_text, data.options)
	if not event.ok:
		return Result.failure(CODE_VIEW_INVALID, [event.code])
	return event
