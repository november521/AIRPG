extends RefCounted
## Per-character output policy for validated model replies. The card's rules that can be
## checked soundly live here: no meta exposure, no card-forbidden phrases, and the bubble
## budget the dialogue UI can actually show. Everything else in the card (trust deltas,
## taboo state changes, lie-tell UI) is a later workstream and is deliberately not faked.
##
## These checks are heuristics over text. A rejection is reported as a retryable failure so
## the pipeline resamples instead of showing the player an unvetted line.

const Result = preload("res://shared/result.gd")

## Engineering safety net that applies to every speaker, independent of card data.
const META_PATTERNS: Array[String] = ["作为ai", "作为一个ai", "我是ai", "ai助手", "语言模型",
	"人工智能", "作为一个语言模型", "这是游戏", "这是一款游戏"]
const SENTENCE_ENDINGS: String = "。！？!?"
const ACTION_OPEN: String = "（"
const ACTION_CLOSE: String = "）"

static func validate(policy: Dictionary, text: String) -> RefCounted:
	if not text is String or text.strip_edges().is_empty():
		return Result.failure("REPLY_POLICY_INVALID")
	var lowered := text.to_lower()
	for pattern: String in META_PATTERNS:
		if lowered.contains(pattern):
			return Result.failure("REPLY_META_EXPOSURE", [pattern])
	var forbidden: Array = policy.get("forbidden_phrases", [])
	for phrase: Variant in forbidden:
		if phrase is String and text.contains(phrase):
			return Result.failure("REPLY_FORBIDDEN_PHRASE", [phrase])
	if policy.is_empty():
		return Result.success()
	return _within_budget(policy, text)

static func _within_budget(policy: Dictionary, text: String) -> RefCounted:
	var maximum_lines: int = policy.get("max_dialogue_lines", 2)
	var maximum_length: int = policy.get("max_line_length", 40)
	var dialogue_sentences: int = 0
	var dialogue_lines: int = 0
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty():
			continue
		if line.begins_with(ACTION_OPEN) and line.ends_with(ACTION_CLOSE):
			if line.length() > maximum_length:
				return Result.failure("REPLY_LINE_TOO_LONG", ["action"])
			continue
		dialogue_lines += 1
		for sentence: String in _sentences(line):
			if sentence.length() > maximum_length:
				return Result.failure("REPLY_LINE_TOO_LONG", [str(sentence.length())])
			dialogue_sentences += 1
	if dialogue_lines > maximum_lines or dialogue_sentences > maximum_lines:
		return Result.failure("REPLY_TOO_MANY_LINES",
			["lines:%d sentences:%d" % [dialogue_lines, dialogue_sentences]])
	return Result.success()

static func _sentences(line: String) -> Array[String]:
	var pieces: Array[String] = []
	var current: String = ""
	for index: int in line.length():
		var character := line[index]
		current += character
		if SENTENCE_ENDINGS.contains(character):
			if not current.strip_edges().is_empty():
				pieces.append(current.strip_edges())
			current = ""
	if not current.strip_edges().is_empty():
		pieces.append(current.strip_edges())
	return pieces
