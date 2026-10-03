extends CanvasLayer
## Non-interactive narrative layer for a line that belongs to an action rather than to an object.
##
## A pickup's text cannot be parented to the picked-up node: the receipt frees that node, so the
## line would vanish with it. This layer is created once per scene by bootstrap and outlives every
## object it describes. Following the observed-object caption it reuses, every node here ignores the
## mouse and the layer never touches the walk session, so the pointer stays captured, movement keeps
## working and F is never taken over.
##
## The line stays until it is either replaced by the next one or explicitly cleared. It is never
## taken away by a clock: the two-step pickup clears it on the second press, which is a state change
## the caller can see and assert, not a race with a timer.
const Caption = preload("res://presentation/manor/inspect_caption.gd")
var _caption: Caption

func _ready() -> void:
	_ensure()

func show_key(text_key: String) -> void:
	_ensure()
	if _caption != null:
		_caption.show_key(text_key)

## The localization key currently on screen, so a test can assert the wording an action produced
## without a rendered window.
func shown_key() -> String:
	return _caption.shown_key() if _caption != null else ""

func _ensure() -> void:
	if _caption != null:
		return
	_caption = Caption.new()
	add_child(_caption)
