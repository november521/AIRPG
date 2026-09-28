extends Label
## Localized title only; styling belongs to the scene/theme.
func present(text_key: String) -> void:
	text = tr(text_key)
