extends HBoxContainer
## One stepper row of the investigator creation page: name, −/value/+ group and
## the allowed range. Geometry mirrors the approved reference layout.
signal requested(field_id: String, value: int)

const Style = preload("res://presentation/character/creation_style.gd")

## Fixed columns, in design pixels at 1920x1080: the name column and the
## trailing inset pin the stepper group and the range hint to the same x on
## every row of both cards.
const NAME_COLUMN := 212
const RANGE_WIDTH := 62
const TRAILING_GAP := 34

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
	custom_minimum_size.y = 52
	add_theme_constant_override("separation", 18)
	var caption := Style.label(self, title, 27, Style.PAPER)
	# The name column and the trailing gap are what pin the stepper group and
	# the range hint to the same x on every row of both cards.
	caption.custom_minimum_size.x = NAME_COLUMN
	caption.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_minus = Style.step_button(self, "−")
	_entry = Style.value_field(self)
	_plus = Style.step_button(self, "+")
	var flex := Control.new()
	add_child(flex)
	flex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var range_text := Style.label(self, "%d–%d" % [minimum, maximum], 20, Style.DIM)
	range_text.custom_minimum_size.x = RANGE_WIDTH
	range_text.size_flags_horizontal = Control.SIZE_SHRINK_END
	range_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tail := Control.new()
	add_child(tail)
	tail.custom_minimum_size.x = TRAILING_GAP
	tail.size_flags_horizontal = Control.SIZE_SHRINK_END
	_entry.text_submitted.connect(func(_text: String) -> void: _submit())
	_entry.focus_exited.connect(_submit)
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
