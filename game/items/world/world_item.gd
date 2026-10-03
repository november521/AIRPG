extends "res://presentation/exploration/interactions/pickup_view.gd"
## Shared world representation; identity comes from ItemData, not this scene.
##
## A pickup may carry one narrative line, and how it is told takes two commands: the first has the
## object tell the line and leaves it where it is, the second takes the object and has it fall silent
## again, which is what clears the line off the caption layer. This view owns nothing: it asks the
## handler what that object has actually said and hands any change on. An item placed without a
## layer, or without a key, stays silent.
##
## It follows `narration()`, not `read()["caption_key"]`. The two differ exactly where it matters:
## a pickup is refreshed by every change its inventory port reports -- including one another object
## caused -- and keying off the prompt's field would put this pickup's line on screen every time some
## unrelated item was picked up.
const InteractionHandler = preload("res://application/exploration/interactions/interaction_handler.gd")
const Caption = preload("res://presentation/manor/narrative_caption.gd")
var _item_data: Resource
var _captions: Caption
var _published_key: String = ""

func configure_data(item_data: Resource, handler: InteractionHandler, quantity: int) -> void:
	_item_data = item_data
	configure(handler, item_data.display_name_key, quantity)

## Injected by bootstrap. Left unattached, a claimed item simply disappears with no text.
func attach_captions(captions: Caption) -> void:
	_captions = captions

func item_id() -> String:
	return String(_item_data.id) if _item_data != null else ""

## The only thing that talks is a change in what the handler has said. A freshly placed pickup has
## said nothing, so attaching the layer is silent; the first command makes it speak; the command that
## takes the object makes it fall silent and the line comes off the layer.
func _refresh() -> void:
	if _captions != null:
		var published: String = _handler.narration()
		if published != _published_key:
			_captions.show_key(published)
			_published_key = published
	super._refresh()
	if not visible and is_inside_tree():
		queue_free()
