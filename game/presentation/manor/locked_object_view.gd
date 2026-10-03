extends Node3D
## Presentation for a locked container the player opens with a carried tool. It holds no state of its
## own: it asks the handler whether the container is open and moves the aim ray from the container to
## what is inside it. While the container is shut, the content's own ray target is off, so a diary
## behind a locked glass door can be seen but never touched -- and the container cannot be re-locked,
## because the handler's own state has no way back.
##
## It also replaces the panes of the delivered cabinet's glass. The model's own glass material
## renders opaque, which hides the diary the cabinet exists to hold, and the shipped binary is never
## edited: the panes are found by name and material, and a translucent override material is put on
## their surfaces at runtime. The panes carry no collision, so nothing here changes what the aim ray
## can reach.
const Handler = preload("res://application/exploration/interactions/interaction_handler.gd")
const Audio = preload("res://application/ports/audio_port.gd")
const GlassMaterial = preload("res://presentation/manor/cabinet_glass.tres")
## The layer every interactive ray target in this prototype uses.
const TARGET_LAYER: int = 8
## The two panes of the study cabinet as the delivered model names them, and the material all of the
## cabinet's glass parts are authored with. A pane is picked out by either: the name matches the
## doors, and the material matches any other glass the model may grow later.
const GLASS_MESH_PREFIX := "Study_MedicalCabinet_Glass"
const GLASS_MATERIAL_NAME := "DL_glass"
@export var glass_material: Material = GlassMaterial
var _handler: Handler
var _content: CollisionObject3D
var _original_surfaces: Array[Dictionary] = []
## The lock turning is the sound of the state change and not of the command: the container has no way
## back, so this fires exactly once. The first refresh only records that the container started shut.
var _audio: Audio = Audio.new()
var _seen: bool = false
var _was_open: bool = false

func configure(handler: Handler, content_target: CollisionObject3D, glass_source: Node = null) -> void:
	_handler = handler
	_content = content_target
	# The cabinet is one ray target in the scene and its panes are meshes of the delivered manor, so
	# the view is told where to look for them. Left out, no glass is touched at all.
	if glass_source != null:
		_apply_glass(glass_source)
	_handler.changed.connect(_refresh)
	_refresh()

## Injected by bootstrap.
func attach_audio(port: Audio) -> void:
	if port != null:
		_audio = port

## How many panes were found and re-materialised, so bootstrap and the tests can assert that the
## cabinet it handed over really had glass to replace.
func glass_panes() -> int:
	return _original_surfaces.size()

func is_open() -> bool:
	return _handler != null and not bool(_handler.read().get("locked", true))

func _refresh() -> void:
	var open: bool = is_open()
	if open and _seen and not _was_open:
		_audio.play_sfx(Audio.LOCK_OPEN, global_position)
	_was_open = open
	_seen = true
	$Target.collision_layer = 0 if open else TARGET_LAYER
	if _content != null and is_instance_valid(_content):
		_content.collision_layer = TARGET_LAYER if open else 0

## Walks the delivered cabinet and swaps each glass surface's material for the translucent override,
## remembering what was there so the change can be undone when this view leaves the tree.
func _apply_glass(root: Node) -> void:
	if root == null or glass_material == null:
		return
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		if not _is_glass(mesh_node):
			continue
		for surface: int in mesh_node.mesh.get_surface_count():
			_original_surfaces.append({"mesh": mesh_node, "surface": surface,
				"material": mesh_node.mesh.surface_get_material(surface)})
			mesh_node.set_surface_override_material(surface, glass_material)

func _is_glass(mesh_node: MeshInstance3D) -> bool:
	if String(mesh_node.name).begins_with(GLASS_MESH_PREFIX):
		return true
	for surface: int in mesh_node.mesh.get_surface_count():
		var material: Material = mesh_node.mesh.surface_get_material(surface)
		if material != null and String(material.resource_name) == GLASS_MATERIAL_NAME:
			return true
	return false

func _exit_tree() -> void:
	if _handler != null and _handler.changed.is_connected(_refresh):
		_handler.changed.disconnect(_refresh)
	for entry: Dictionary in _original_surfaces:
		var mesh_node: MeshInstance3D = entry.mesh
		if is_instance_valid(mesh_node):
			mesh_node.set_surface_override_material(int(entry.surface), entry.material)
	_original_surfaces.clear()
