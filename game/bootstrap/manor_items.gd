extends RefCounted
## The placement helpers for every runtime object, plus the observed objects of the manor prototype
## with the position, key and visual tables they are measured against. The props that are one simple
## pickup, one observation or one device each live in manor_props; what stays here is the shared
## placement contract and the objects that travel to the player's hand.
const Result = preload("res://shared/result.gd")
const Inventory = preload("res://application/ports/pickup_inventory.gd")
const Audio = preload("res://application/ports/audio_port.gd")
const Pickup = preload("res://application/exploration/interactions/pickup_interaction.gd")
const Inspect = preload("res://application/exploration/interactions/inspect_interaction.gd")
const InspectState = preload("res://domain/exploration/inspect_state.gd")
const InspectView = preload("res://presentation/manor/inspect_object_view.gd")
const LockState = preload("res://domain/exploration/lock_state.gd")
const Unlock = preload("res://application/exploration/interactions/unlock_interaction.gd")
const LockedView = preload("res://presentation/manor/locked_object_view.gd")
const Cabinet = preload("res://presentation/manor/medical_cabinet.tscn")
const PryView = preload("res://presentation/manor/pry_entrance_view.gd")
const Caption = preload("res://presentation/manor/narrative_caption.gd")
const WorldItem = preload("res://items/world/world_item.gd")
const SilverUrn = preload("res://items/data/silver_urn.tres")
const DoctorDiary = preload("res://items/data/doctor_diary.tres")
const Wallet = preload("res://items/data/wallet.tres")
const PolaroidPhoto = preload("res://items/data/polaroid_photo.tres")
## Cropped single frame of the photo sheet's own texture. The shipped sheet is a four-panel atlas,
## so the whole image can never be shown as one photograph; this is the face quadrant, upright.
const PhotoFace = preload("res://items/models/polaroid_photo_face.jpg")
# Placements below are floor-contact: the world scene sits on its own base, so y is the walk
# surface, not the box centre. The reception values were measured on V4: the reception floor is the
# subfloor top at y = -0.025 and its area rug reaches y = 0.0245, so floor items are kept off the
# rug rather than sunk into it. The hearth stone is only decoration and carries no walk collision,
# so the box stands on the walkable reception floor 0.21 m east of the hearth's own AABB.
const SILVER_BOX_POSITION := Vector3(-7.26, -0.025, 0.90)
const SILVER_BOX_ID := "manor.inspect.silver_urn"
const SILVER_BOX_CAPTIONS: Array[String] = ["", "inspect.silver_urn.floor", "inspect.silver_urn.held"]
## The metal box turns its long edge parallel to the west wall; the pose is the same whole-object
## hand pose every observed object starts from.
const SILVER_BOX_VISUAL: Dictionary = {"yaw": PI / 2}
## The wallet is the second observation object and is also not a pickup. It is laid on the reception
## floor: the V4 walk surface here measures -0.025, and with the scene's authored `Model` transform
## (a pure -90X rotation plus a compensating translation, no scale) the imported mesh bottom lands on
## the node origin, so the root simply stands on the floor.
## `Target` is a raised aim column rather than a box hugging the leather: measured in this room, a
## player looking down at a 15 cm object has the ray clip the floor first, so the aim volume is
## lifted above the wallet. It changes no visible geometry. `Name` sits above the column.
const WALLET_POSITION := Vector3(-6.5, -0.025, 2.0)
const WALLET_ID := "manor.inspect.wallet"
const WALLET_CAPTIONS: Array[String] = ["", "inspect.wallet.floor", "inspect.wallet.held"]
## Second interaction draws the photo out; the wallet itself never leaves the floor, so only the
## `Model/Reveal` child travels to the hand at stage 2. Nothing puts the photo back: while it is out
## the only way on is to pocket it, which empties the wallet and returns it to the floor.
const WALLET_ACTION_KEYS: Array[String] = ["interaction.inspect", "interaction.take_photo",
	"interaction.keep_photo"]
## The same wallet once the photo has been pocketed: two steps instead of three, because there is
## nothing left to draw out. The captions stay the same list -- only the first text is ever reached.
const WALLET_EMPTIED_ACTION_KEYS: Array[String] = ["interaction.inspect", "interaction.put_back"]
## Only the photo travels, it is invisible until it is drawn, and it takes the measured card pose.
const WALLET_VISUAL: Dictionary = {"travelling": "Model/Reveal", "pose": "photo", "hidden": true,
	"photo": PhotoFace}
## The delivered V4 manor bakes a static lead casket next to the hearth as `Clue_LeadCasket`
## (nine `LeadCasket_*` meshes) and a static diary on a desk in the doctor's study as
## `Clue_DoctorDiary`. The observation objects replace both, so those props are removed at runtime
## and the shipped .glb stays untouched. A reshuffle that flattens a group is still caught by the
## mesh sweep.
const LEAD_CASKET_GROUP := "Clue_LeadCasket"
const LEAD_CASKET_MESHES := "LeadCasket*"
const DIARY_PROP := "Clue_DoctorDiary"
const DIARY_PROP_MESHES := "DoctorDiary*"
## The locked medical cabinet of the doctor's study, and the diary it holds. Both were measured in
## the delivered V4 manor: the cabinet root stands at (7.56, 0, -0.29) with a 180 degree yaw and its
## mesh AABB is x 6.845..8.275, y 0.025..2.0125, z -0.548..-0.105, back against the east wall
## (x 8.328) and the north wall (z -0.112), on a study floor that measures -0.025. Its sides, two
## glass doors and five shelves are flat sibling meshes with no pivot node and no grouping, so there
## is nothing to swing or slide: opening it is a state change plus the refusal line, not an
## animation. The diary rests on the middle shelf, whose top face is y = 1.0325 and whose footprint
## is x 6.85..8.27, z -0.475..-0.105; the 0.253 x 0.329 m cover fits with the glass clear of it.
const CABINET_ID := "manor.cabinet.medical"
const CABINET_POSITION := Vector3(7.56, 0.0, -0.29)
const CABINET_NAME_KEY := "interaction.cabinet.medical"
const CABINET_ACTION_KEY := "interaction.unlock"
## Either of these opens it; neither is consumed. A real lock would name the key alone, but the
## prototype has no lockpicking and the crowbar is already the manor's universal pry tool.
const CABINET_ACCEPTED_ITEMS: Array[String] = ["manor_key", "crowbar"]
const DIARY_ID := "manor.inspect.doctor_diary"
const DIARY_POSITION := Vector3(7.56, 1.0325, -0.29)
## The opened book travels; the closed cover steps aside while it is out, so the diary never looks
## like two copies of itself.
const DIARY_VISUAL: Dictionary = {"travelling": "Book", "pose": "book", "hidden": true,
	"stowed": "Model"}
const DIARY_STAGE_COUNT: int = 5
const DIARY_EMPTY_STAGE_COUNT: int = 3
const DIARY_HELD_FROM: int = 2
const DIARY_EMPTY_HELD_FROM: int = 1
## Five stages: shut in the cabinet, the line on the flyleaf, then the opened first, second and third
## page. The last one is also the hand-over stage, so the fourth press pockets the diary.
const DIARY_CAPTIONS: Array[String] = ["", "inspect.doctor_diary.flyleaf", "inspect.doctor_diary.page1",
	"inspect.doctor_diary.page2", "inspect.doctor_diary.page3"]
const DIARY_ACTION_KEYS: Array[String] = ["interaction.inspect", "interaction.open_diary",
	"interaction.turn_page", "interaction.turn_page", "interaction.keep_diary"]
## Once the notebook has it: look at the shut diary, open it again on the first page, then turn to a
## page that stays blank. No text is left to give, and nothing is handed over twice.
const DIARY_EMPTIED_ACTION_KEYS: Array[String] = ["interaction.inspect", "interaction.turn_page",
	"interaction.put_back"]
const DIARY_EMPTIED_CAPTIONS: Array[String] = ["", "inspect.doctor_diary.page1", ""]
## The concealed cellar entrance. The delivered V4 model leaves a hole in the walk mesh where the new
## stairwell is and covers it with its own 17 boards and 3 battens (`V4_PryFloorboards`) plus one
## separate collision body (`V4_PryFloorCollision`, collision layer 1), exactly as its metadata says
## (`required_tool: crowbar`). Prying is therefore only ever "stop drawing the boards and take that
## body off every layer": the shipped .glb is not edited and the walk mesh is not touched.
##
## Measured on V4: the boards top out at y = 0.0 over x -5.946..-4.354, z -11.497..-8.283; the hole
## that opens underneath them is x -5.8..-4.6, z -11.2..-8.4; the ramp below descends from y -0.23
## at the far end to -2.41 at the near end. The stand point that reaches the boards is on them.
const PRY_ID := "manor.pry.cellar_boards"
const PRY_BOARDS := "V4_PryFloorboards"
const PRY_BLOCKER := "V4_PryFloorCollision"
const PRY_NAME_KEY := "interaction.pry.cellar"
const PRY_ACTION_KEY := "interaction.pry"
## Refusal code, so the notice goes through the same failed-command path a blocked door uses.
const PRY_NEEDS_CROWBAR := "PRY_NEEDS_CROWBAR"
## The one line the entrance tells as the boards come up. It is reached only after a successful pry,
## and the entrance has no way back, so it is said once and never again.
const PRY_DONE_CAPTION := "interaction.pry.done"
const PRY_TOOLS: Array[String] = ["crowbar"]
const PRY_POSITION := Vector3(-5.15, 0.0, -9.89)

## The diary's own cycle, built where its stage numbers are declared.
static func diary_state() -> InspectState:
	return InspectState.new(DIARY_STAGE_COUNT, DIARY_EMPTY_STAGE_COUNT, DIARY_HELD_FROM,
		DIARY_EMPTY_HELD_FROM)

## Removes a static prop the delivered model baked in, so the runtime object can take its place.
static func remove_baked(model: Node3D, prop_name: String, mesh_pattern: String) -> void:
	var prop: Node = model.find_child(prop_name, true, false)
	if prop != null:
		prop.queue_free()
	for mesh: Node in model.find_children(mesh_pattern, "MeshInstance3D", true, false):
		mesh.queue_free()

## One stable source id per placed instance; identity comes from ItemData, not the node name.
## `caption_key` is the single line this pickup tells when it is taken, and `captions` is the scene
## layer that survives the node; either left out, the pickup is simply silent. The node is returned
## so a caller can pose it (a wrench hung upright, for instance) after it stands where it belongs.
## `audio` is the scene's port: every pickup is placed through this one helper, so no pickup can be
## created without the chance to sound.
static func place_item(world: Node3D, item: Resource, source_id: String, position: Vector3,
		inventory: Inventory, handlers: Dictionary, bindings: Dictionary, caption_key: String = "",
		captions: Caption = null, audio: Audio = null) -> WorldItem:
	var handler := Pickup.new(inventory, source_id, String(item.id), 1, item.display_name_key,
		caption_key)
	var node: WorldItem = item.world_scene.instantiate()
	node.name = source_id.replace(".", "_")
	world.add_child(node)
	node.position = position
	node.configure_data(item, handler, 1)
	node.attach_captions(captions)
	if audio != null:
		node.attach_audio(audio)
	handlers[source_id] = handler
	bindings[node.get_node("Target")] = source_id
	return node

## Every observed object supplies its own caption and action keys, so two of them never share a
## prompt, and its own visual table, so the view never guesses which node travels, how it is held or
## what steps aside while it is out. The handler is returned through the view for the one caller
## that also wires the notebook port.
static func place_inspect(world: Node3D, item: Resource, source_id: String, position: Vector3,
		player: CollisionObject3D, handlers: Dictionary, bindings: Dictionary,
		captions: Array[String], action_keys: Array[String], state: InspectState = null,
		emptied_action_keys: Array[String] = [], emptied_captions: Array[String] = [],
		visual: Dictionary = {}, audio: Audio = null) -> InspectView:
	var handler := Inspect.new(state if state != null else InspectState.new(), item.display_name_key,
		captions, action_keys, emptied_action_keys, emptied_captions)
	var node: InspectView = item.world_scene.instantiate()
	node.name = source_id.replace(".", "_")
	world.add_child(node)
	node.position = position
	node.rotation.y = float(visual.get("yaw", 0.0))
	node.configure(handler, player.get_node("Camera/HandSocket"),
		String(visual.get("travelling", "Model")),
		String(visual.get("pose", InspectView.POSE_WHOLE_OBJECT)),
		bool(visual.get("hidden", false)), String(visual.get("stowed", "")),
		visual.get("photo", null) as Texture2D)
	if audio != null:
		node.attach_audio(audio)
	handlers[source_id] = handler
	bindings[node.get_node("Target")] = source_id
	return node

## The locked cabinet. `content` is the observed object inside it: while the cabinet is shut that
## object's ray target stays off, so it can be seen through the glass but not touched, and opening
## the cabinet hands the aim ray over to it. `glass_source` is the delivered model the cabinet's own
## glass panes belong to: the view re-materialises them so the diary inside is actually visible.
static func place_cabinet(world: Node3D, inventory: Inventory, content: CollisionObject3D,
		glass_source: Node, handlers: Dictionary, bindings: Dictionary,
		audio: Audio = null) -> LockedView:
	var handler := Unlock.new(LockState.new(true), inventory, CABINET_NAME_KEY, CABINET_ACTION_KEY,
		CABINET_ACCEPTED_ITEMS)
	var node: LockedView = Cabinet.instantiate()
	node.name = CABINET_ID.replace(".", "_")
	world.add_child(node)
	node.position = CABINET_POSITION
	node.configure(handler, content, glass_source)
	if audio != null:
		node.attach_audio(audio)
	handlers[CABINET_ID] = handler
	bindings[node.get_node("Target")] = CABINET_ID
	return node

## The concealed cellar entrance, as its own locked-gate: the boards and the collision body are the
## model's own nodes, so the view is handed both of them and the body doubles as the entrance's ray
## target. Prying is one-way -- `LockState` has no way back -- so a second command can neither
## re-close the hole nor hide the stairwell again.
static func place_pry_entrance(world: Node3D, model: Node3D, inventory: Inventory,
		handlers: Dictionary, bindings: Dictionary, captions: Caption = null,
		audio: Audio = null) -> PryView:
	var boards: Node3D = model.find_child(PRY_BOARDS, true, false) as Node3D
	var blocker: CollisionObject3D = model.find_child(PRY_BLOCKER, true, false) as CollisionObject3D
	var handler := Unlock.new(LockState.new(true), inventory, PRY_NAME_KEY, PRY_ACTION_KEY, PRY_TOOLS,
		PRY_NEEDS_CROWBAR, PRY_DONE_CAPTION)
	var node := PryView.new()
	node.name = PRY_ID.replace(".", "_")
	world.add_child(node)
	node.position = PRY_POSITION
	node.configure(handler, boards, blocker, captions)
	if audio != null:
		node.attach_audio(audio)
	handlers[PRY_ID] = handler
	if blocker != null:
		bindings[blocker] = PRY_ID
	return node
