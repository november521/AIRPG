extends RefCounted
## Local preview presence. No story state, knowledge, model calls or persistence.
const RandomSource = preload("res://application/ports/random_source.gd")
const Result = preload("res://shared/result.gd")
const TALK_RANGE: float = 2.4
var _random: RandomSource
var _roster: Array[Dictionary] = []
var _speaker: String = ""

func _init(random: RandomSource, roster: Array[Dictionary]) -> void:
	_random = random
	_roster.assign(roster.duplicate(true))

func roster() -> Array[Dictionary]:
	return _roster.duplicate(true)

func destination(id: String) -> RefCounted:
	var entry := _find(id)
	if entry.is_empty():
		return Result.failure("NPC_UNKNOWN")
	var x := _random.roll(1000)
	var z := _random.roll(1000)
	if not x.ok or not z.ok:
		return Result.failure("NPC_RANDOM_UNAVAILABLE")
	var area: Rect2 = entry.area
	return Result.success(Vector3(area.position.x + area.size.x * float(x.value - 1) / 999.0,
		entry.spawn.y, area.position.y + area.size.y * float(z.value - 1) / 999.0))

func begin_greeting(id: String, distance: float, visible: bool) -> RefCounted:
	if not _speaker.is_empty():
		return Result.failure("NPC_DIALOGUE_BUSY")
	var entry := _find(id)
	if entry.is_empty():
		return Result.failure("NPC_UNKNOWN")
	if not is_finite(distance) or distance < 0 or distance > TALK_RANGE or not visible:
		return Result.failure("NPC_OUT_OF_REACH")
	_speaker = id
	return Result.success({"id": id, "name_key": entry.name_key, "text_key": entry.greeting_key})

func end_greeting() -> void:
	_speaker = ""

func paused(id: String) -> bool:
	return _speaker == id

func _find(id: String) -> Dictionary:
	for entry: Dictionary in _roster:
		if entry.id == id:
			return entry.duplicate(true)
	return {}
