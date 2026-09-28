extends ScrollContainer
## Long descriptions scroll independently without changing the action area.
func present(text_key: String) -> void:
	$Text.text = tr(text_key)
	scroll_vertical = 0
