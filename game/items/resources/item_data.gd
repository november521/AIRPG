extends Resource
## One reusable definition. Runtime location is owned by inventory/equipment/world systems.
@export var id: StringName
@export var display_name_key: String = ""
@export var description_key: String = ""
@export var world_scene: PackedScene
@export var held_scene: PackedScene
@export var stackable: bool = false
@export var max_stack: int = 1
@export var equippable: bool = false
@export var droppable: bool = true
@export var weight: float = 0.0
@export var tags: Array[StringName] = []

func to_runtime_view() -> Dictionary:
	return {
		"id": String(id),
		"name_key": display_name_key,
		"description_key": description_key,
		"world_scene": world_scene,
		"held_scene": held_scene,
		"stackable": stackable,
		"max_stack": max_stack,
		"equippable": equippable,
		"droppable": droppable,
		"weight": weight,
		"tags": tags.duplicate(),
	}
