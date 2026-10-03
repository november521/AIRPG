extends HBoxContainer
signal requested(field_id: String, value: int)
var field_id: String
var _value: int
var _minimum: int
var _maximum: int
var _minus: Button
var _plus: Button
var _entry: LineEdit

func configure(id: String, title: String, minimum: int, maximum: int) -> void:
	field_id = id
	_minimum = minimum
	_maximum = maximum
	custom_minimum_size.y = 54
	add_theme_constant_override("separation", 10)
	var name := Label.new()
	add_child(name)
	name.text = title
	name.custom_minimum_size.x = 130
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 20)
	_minus = _button("−")
	_entry = LineEdit.new()
	add_child(_entry)
	_entry.custom_minimum_size = Vector2(72, 44)
	_entry.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_entry.max_length = 3
	_entry.add_theme_font_size_override("font_size", 20)
	_entry.text_submitted.connect(func(_text: String) -> void: _submit())
	_entry.focus_exited.connect(_submit)
	_plus = _button("+")
	var range_text := Label.new()
	add_child(range_text)
	range_text.text = "%d–%d" % [minimum, maximum]
	range_text.custom_minimum_size.x = 64
	range_text.add_theme_color_override("font_color", Color(0.65, 0.59, 0.49))
	_minus.pressed.connect(func() -> void: requested.emit(field_id, _value - 1))
	_plus.pressed.connect(func() -> void: requested.emit(field_id, _value + 1))

func display(value: int, remaining: int, locked: bool) -> void:
	_value = value
	_entry.text = str(value)
	_entry.editable = not locked
	_minus.disabled = locked or value <= _minimum
	_plus.disabled = locked or value >= _maximum or remaining <= 0

func _submit() -> void:
	if not _entry.editable:
		return
	var raw_text := _entry.text.strip_edges()
	if not raw_text.is_valid_int():
		_entry.text = str(_value)
		return
	var parsed := int(raw_text)
	if parsed == _value:
		_entry.text = str(_value)
		return
	requested.emit(field_id, parsed)

func _button(title: String) -> Button:
	var button := Button.new()
	add_child(button)
	button.text = title
	button.custom_minimum_size = Vector2(44, 44)
	button.add_theme_font_size_override("font_size", 23)
	return button
