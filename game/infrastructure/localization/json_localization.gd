extends RefCounted
const Result = preload("res://shared/result.gd")

static func install(messages: Variant, locale: String) -> RefCounted:
	if not messages is Dictionary or messages.is_empty():
		return Result.failure("LOCALIZATION_INVALID")
	for key: Variant in messages:
		if not key is String or not messages[key] is String or messages[key].is_empty():
			return Result.failure("LOCALIZATION_INVALID")
	var translation := Translation.new()
	translation.locale = locale
	for key: String in messages:
		translation.add_message(key, messages[key])
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(locale)
	return Result.success(translation)
