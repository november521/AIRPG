extends HFlowContainer
## One native label per localized tag. Reused by cards and the large preview.
@export var text_size: int = 26

func present(keys: Array) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for index: int in keys.size():
		if index > 0:
			_add_text(tr("archive.tag_separator"))
		_add_text(tr(keys[index]))

func _add_text(value: String) -> void:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", text_size)
	add_child(label)
