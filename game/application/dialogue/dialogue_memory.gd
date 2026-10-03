extends RefCounted
## Per-speaker short-term dialogue memory (PRD §10.4 "近期记忆").
##
## Memory is owned by the NPC id that will read it back, so one NPC's exchange can never be
## replayed to another. Entries keep the line's speaker id: the NPC's own lines are trusted
## recent dialogue, the player's lines stay untrusted speech on the projector side.
## Nothing here touches StateStore, disk or the model.

const LIMIT: int = 6
const TEXT_LIMIT: int = 4000
const PLAYER_SPEAKER_ID: String = "player"

var _by_owner: Dictionary = {}

func remember(owner_id: String, line_speaker_id: String, text: String) -> void:
	if owner_id.is_empty() or not text is String or text.strip_edges().is_empty():
		return
	var entry: String = text if text.length() <= TEXT_LIMIT else text.substr(0, TEXT_LIMIT)
	var entries: Array = _by_owner.get(owner_id, [])
	# Retries resend the same line; storing it twice would fake a repeated exchange.
	if not entries.is_empty() and entries[entries.size() - 1].text == entry:
		return
	entries.append({"speaker_id": line_speaker_id, "text": entry})
	while entries.size() > LIMIT:
		entries.remove_at(0)
	_by_owner[owner_id] = entries

func recent(owner_id: String) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for entry: Dictionary in _by_owner.get(owner_id, []):
		copied.append(entry.duplicate(true))
	return copied

func forget_all() -> void:
	_by_owner.clear()
