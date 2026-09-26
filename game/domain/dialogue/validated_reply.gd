extends RefCounted
## Sealed result of semantic reply validation. DialoguePublication accepts only this type,
## so a caller-built Dictionary cannot carry a forged `validated` field into the view
## contract. `_seal` is called exclusively by ReplyValidator after every check passes;
## an unsealed instance yields an empty payload and is refused by the publication gate.

var _reply: Dictionary = {}

func _seal(reply: Dictionary) -> void:
	_reply = reply.duplicate(true)

func data() -> Dictionary:
	return _reply.duplicate(true)
