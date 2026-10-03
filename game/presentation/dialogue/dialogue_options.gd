extends RefCounted
## Builds contract-validated option buttons. Owns no selection policy.

var _box: VBoxContainer

func bind(box: VBoxContainer) -> void:
	_box = box

func clear() -> void:
	for child: Node in _box.get_children():
		_box.remove_child(child)
		child.queue_free()

func show_options(options: Array, on_pressed: Callable) -> void:
	clear()
	for item: Variant in options:
		if not item is Dictionary:
			continue
		var button := Button.new()
		button.name = "OptionButton"
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = str(item.text)
		button.pressed.connect(on_pressed.bind(str(item.option_id), str(item.text)))
		_box.add_child(button)

func count() -> int:
	return _box.get_child_count()
