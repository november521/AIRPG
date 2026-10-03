extends RefCounted
## The held item and what happens when it leaves the hand: the visual instance parented to the hand
## socket, and the flow that puts an item back into the world as a runtime pickup. It owns exactly two
## pieces of state -- that visual and the serial that names dropped items -- so the manor orchestrator
## keeps only wiring.
const WorldItemInteraction = preload("res://application/exploration/interactions/world_item_interaction.gd")
const WorldItem = preload("res://items/world/world_item.gd")
const Audio = preload("res://application/ports/audio_port.gd")
var _character_service: Object
var _player: Node3D
var _world: Node3D
var _interactions: Object
var _sound: Audio
var _held_visual: Node3D
var _drop_serial: int = 0

## `interactions` is the shared interaction service, which owns the runtime target the dropped item
## registers; `sound` is the manor's already-started audio port.
func configure(character_service: Object, player: Node3D, world: Node3D, interactions: Object,
		sound: Audio) -> void:
	_character_service = character_service
	_player = player
	_world = world
	_interactions = interactions
	_sound = sound

## Rebuilds the hand visual from the inventory's held item. Called on every inventory change, because
## a pickup, a drop and a holster all have to leave the hand holding what the notebook says it holds.
func sync() -> void:
	if not is_instance_valid(_player):
		return
	if is_instance_valid(_held_visual):
		_held_visual.queue_free()
		_held_visual = null
	var item_id: String = _character_service.read_character().held_item
	if item_id.is_empty():
		return
	var definition: Dictionary = _character_service.read_character().definitions[item_id]
	if definition.held_scene == null:
		return
	_held_visual = definition.held_scene.instantiate()
	_player.get_node("Camera/HandSocket").add_child(_held_visual)

func held_visual() -> Node3D:
	return _held_visual

func drop(item_id: String) -> void:
	var definition: Dictionary = _character_service.read_character().definitions[item_id]
	var dropped: WorldItem = definition.world_scene.instantiate()
	var source_id: String = "manor.drop.%d" % _drop_serial
	_drop_serial += 1
	var handler := WorldItemInteraction.new(_character_service, source_id, item_id, 1,
		definition.name_key)
	dropped.name = source_id.replace(".", "_")
	_world.add_child(dropped)
	dropped.position = _player.position - _player.global_basis.z * 0.8
	dropped.position.y = _player.position.y + 0.24
	dropped.configure_runtime(item_id, handler, definition.name_key, 1)
	# The notebook's own command is quiet for this one action: this is where the item actually leaves
	# the hand, so this is where it is heard.
	_sound.item_dropped(dropped.global_position)
	_interactions.register_runtime_target(source_id, handler, dropped.get_node("Target"))
