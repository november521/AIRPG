extends VBoxContainer
## Coordinates field components; owns neither catalog loading nor launch behavior.
func present(story: Dictionary) -> void:
	$Title.present(story.title_key)
	$Tags.present(story.tag_keys)
	$Description.present(story.description_key)
