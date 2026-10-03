extends RefCounted
const MAIN = preload("res://bootstrap/manor_play.tscn")
const Props = preload("res://bootstrap/manor_props.gd")
const Shelf = preload("res://bootstrap/manor_shelf.gd")
const Inventory = preload("res://application/ports/pickup_inventory.gd")
const Device = preload("res://application/exploration/interactions/device_interaction.gd")
const DeviceState = preload("res://domain/exploration/device_state.gd")
const CaptionHost = preload("res://presentation/manor/narrative_caption.gd")
const GeneratorView = preload("res://presentation/manor/generator.gd")
const InspectView = preload("res://presentation/manor/inspect_object_view.gd")
const LockedView = preload("res://presentation/manor/locked_object_view.gd")
## Wording the scene suite pins down, so a rewording cannot pass unnoticed. The diary's three pages
## and the ten delivered props are transcribed from the delivered text, line breaks included.
const CABINET_LOCKED_TEXT := "上锁了。用什么办法打开呢？"
const FLYLEAF_TEXT := "日记的大部分页面是空的。只有最后几页写满了字。 笔迹工整、克制、没有一丝情绪——像一份病历。"
const PAGE_ONE_TEXT := "它没有名字。我父亲叫它『噬罪者』。我祖父也这么叫。\n用法：以血在预定者的额上画螺纹印记。诵念下列音节。然后打开匣子。\n它会把他吃成骨灰，然后带着骨灰回到匣中。\n代价是：你必须知道你在做什么。"
const PAGE_TWO_TEXT := "后面是十六行条目。每一行只有一个日期，一个三位或四位数字。 日期不规则地散在过去三十年里。最近的一行是：1919 年 11 月 10 日。 最下面还有一行，墨水比别的都新： 「第十七个。还没有编号。」"
const PAGE_THREE_TEXT := "1920年秋。匣子在我手上挣脱过一次。它不肯回去。\n我把它逼进发电机的电线里。它被拉成了线，然后断了。\n烧断它的不是火。是电。稳定的、强的电。"
const RADIO_TEXT := "收音机开着，只有静电。\n三个波段，一个台都没有。外面这种天气，正常。"
const GENERATOR_TEXT := "老式燃油发电机。缸体是铸铁的，配电盘上有一排陶瓷保险丝。\n外壳上有一道焦痕。银白色的，从气缸一直拉到配电盘。\n配电盘的绝缘层被熔开过，又重新包上了布皮。"
## The concealed cellar entrance: where the player stands to pry it, and what the aim lands on. Both
## were measured on V4, where the 17 boards top out at y = 0.0 over x -5.946..-4.354,
## z -11.497..-8.283 and the collision body that covers the stairwell is x -5.8..-4.6, z -11.2..-8.4.
const PRY_ID := "manor.pry.cellar_boards"
const PRY_STAND := Vector3(-5.15, 0.0, -11.0)
const PRY_AIM := Vector3(-5.15, 0.0, -9.89)
## The eight pickups the round delivers, one row each: where the object stands, where the player
## stands to reach it, what the aim is lifted to, which item the notebook must receive, and the one
## line the command has to put on screen. The positions are read from bootstrap/manor_props so a
## stray edit there cannot quietly drop an object through a floor unnoticed.
##
## All eight carry a line and therefore take two commands: the first reads the line out and leaves
## the object where it is, the second pockets it and takes the line away. `tier` marks the six that
## stand on a cellar shelf board rather than on a floor or a worktop.
var pickups: Array[Dictionary] = [
	{"node": "manor_pickup_crowbar", "id": Props.CROWBAR_ID, "item": "crowbar",
		"caption": Props.CROWBAR_CAPTION, "position": Props.CROWBAR_POSITION,
		"stand": Vector3(5.60, Props.PORCH_DECK, 4.70), "aim": Vector3(0, 0.20, 0),
		"text": "前门外的草坪上丢着一根撬棍。\n铁头还没生锈——今晚才落在这里的。\n\n你把它捡了起来。比想象中沉。\n握把上有一圈磨出来的旧痕，不是这只手留下的。"},
	{"node": "manor_pickup_manor_key", "id": Props.MANOR_KEY_ID, "item": "manor_key",
		"caption": Props.MANOR_KEY_CAPTION, "position": Props.MANOR_KEY_POSITION,
		"stand": Vector3(-5.20, Props.GROUND_FLOOR, 3.20), "aim": Vector3(0, 0.04, 0),
		"text": "怀表袋里还有一枚小钥匙。"},
	{"node": "manor_pickup_copper_wire_coil", "id": Props.COPPER_WIRE_COIL_ID,
		"item": "copper_wire_coil", "caption": Props.COPPER_WIRE_COIL_CAPTION,
		"position": Props.COPPER_WIRE_COIL_POSITION, "tier": 0,
		"stand": Vector3(-2.60, Props.CELLAR_FLOOR, -8.60), "aim": Vector3(0, 0.05, 0),
		"text": "整整两卷裸铜线，还有一卷包着布皮的。放在最上层，像是很久没人动过。"},
	{"node": "manor_pickup_electrical_tape", "id": Props.ELECTRICAL_TAPE_ID,
		"item": "electrical_tape", "caption": Props.ELECTRICAL_TAPE_CAPTION,
		"position": Props.ELECTRICAL_TAPE_POSITION, "tier": 1,
		"stand": Vector3(-2.60, Props.CELLAR_FLOOR, -8.60), "aim": Vector3(0, 0.05, 0),
		"text": "工具墙最右边挂着一卷蓝色绝缘胶带，还剩大半。\n你把它塞进外套口袋。\n铺线的时候要用。接火的东西不能省这一层。"},
	{"node": "manor_pickup_lantern", "id": Props.LANTERN_ID, "item": "lantern",
		"caption": Props.LANTERN_CAPTION, "position": Props.LANTERN_POSITION, "tier": 0,
		"stand": Vector3(-2.60, Props.CELLAR_FLOOR, -9.25), "aim": Vector3(0, 0.16, 0),
		"text": "一盏手提灯，一盒火柴，两支备用的蜡烛。"},
	{"node": "manor_pickup_kerosene_bottle", "id": Props.KEROSENE_BOTTLE_ID,
		"item": "kerosene_bottle", "caption": Props.KEROSENE_BOTTLE_CAPTION,
		"position": Props.KEROSENE_BOTTLE_POSITION, "tier": 0,
		"stand": Vector3(-2.60, Props.CELLAR_FLOOR, -9.90), "aim": Vector3(0, 0.23, 0),
		"text": "一罐煤油。发电机要用的那种。"},
	{"node": "manor_pickup_fuse", "id": Props.FUSE_ID, "item": "fuse",
		"caption": Props.FUSE_CAPTION, "position": Props.FUSE_POSITION, "tier": 1,
		"stand": Vector3(-2.60, Props.CELLAR_FLOOR, -9.25), "aim": Vector3(0, 0.075, 0),
		"text": "一盒陶瓷保险丝，粗的。这是给大电流用的。"},
	{"node": "manor_pickup_wrench", "id": Props.WRENCH_ID, "item": "wrench",
		"caption": Props.WRENCH_CAPTION, "position": Props.WRENCH_POSITION, "tier": 1,
		"stand": Vector3(-2.60, Props.CELLAR_FLOOR, -9.90), "aim": Vector3(0, 0.05, 0),
		"text": "挂在墙上，或许可以用它干什么。"},
]

func run(check: Callable, tree: SceneTree) -> void:
	var play := MAIN.instantiate()
	tree.root.add_child(play)
	play.set_physics_process(false)
	play.player.set_physics_process(false)
	play.player.place_at(Vector3(-7.2, 0.08, -1.64), -PI / 2)
	for frame: int in 3:
		await tree.physics_frame
	var service = play.interaction_service
	service.set_enabled(true)
	service.refresh_focus()
	var focus: Dictionary = service.read_focus()
	check.call(focus.get("target_id") == "manor.door.side", "INTERACT SCENE: real ray focuses closed side door")
	var side: AnimatableBody3D = play.find_child("manor_door_side", true, false)
	check.call(side != null and is_equal_approx(side.rotation.y, -PI / 2), "INTERACT SCENE: visible door and collision initially closed")
	check.call(service.interact("manor.door.side", 0).ok, "INTERACT SCENE: real physics allows door opening outside sweep")
	for frame: int in 30:
		await tree.physics_frame
	var door_view: Node = side.get_child(side.get_child_count() - 1)
	var open_yaw: float = door_view._handler.read().open_yaw
	check.call(is_equal_approx(side.rotation.y, open_yaw), "INTERACT SCENE: collider reaches animated door model pose")
	play.player.place_at(Vector3(-5.75, 0.08, -1.65), 0)
	play.camera.look_at(side.to_global(Vector3(0.55, 1.1, 0)))
	for frame: int in 2:
		await tree.physics_frame
	var blocked = door_view._handler.execute(1) # Check swept clearance independent of aim.
	check.call(blocked.code == "DOOR_BLOCKED", "INTERACT SCENE: actor in swept volume blocks closing")
	check.call(is_equal_approx(side.rotation.y, open_yaw), "INTERACT SCENE: failed close leaves geometry open")
	play.player.place_at(Vector3(-5.0, 0.08, -1.6), 0)
	var pickup: Node3D = play.find_child("manor_pickup_hall_bandage", true, false)
	play.camera.look_at(pickup.global_position)
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.pickup.hall_bandage", "INTERACT SCENE: aim can focus floor pickup")
	check.call(service.interact("manor.pickup.hall_bandage", 0).ok, "INTERACT SCENE: pickup commits by shared service")
	check.call(not pickup.visible and pickup.get_node("Target").collision_layer == 0, "INTERACT SCENE: receipt disables visual and ray target together")
	check.call(play.character_service.read_character().inventory.demo_bandage == 5, "INTERACT SCENE: inventory quantity increases by two")
	play.character_service.preview_action("reset", 1)
	check.call(not pickup.visible, "INTERACT SCENE: preview reset cannot respawn claimed object")
	var box: Node3D = play.find_child("manor_inspect_silver_urn", true, false)
	check.call(box != null, "INTERACT SCENE: reception observation box is placed and bound")
	check.call(box != null and box.get_node("Model").visible,
		"INTERACT SCENE: the observation box is drawn while it sits on the floor")
	check.call(play.find_child("Clue_LeadCasket", true, false) == null
		and play.find_child("LeadCasket_Base", true, false) == null,
		"INTERACT SCENE: the baked lead casket group is gone at runtime")
	check.call(play.find_child("manor_pickup_silver_urn", true, false) == null,
		"INTERACT SCENE: the observation box is not registered as a pickup")
	play.player.place_at(Vector3(-6.2, -0.025, 0.9), PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(box.global_position + Vector3(0, 0.11, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.inspect.silver_urn", "INTERACT SCENE: aim can focus the observation box")
	check.call(focus.get("stage") == 0 and focus.get("action_key") == "interaction.inspect",
		"INTERACT SCENE: an unread box offers the first look")
	check.call(service.interact("manor.inspect.silver_urn", focus.get("revision", -1)).ok,
		"INTERACT SCENE: the first look commits by shared service")
	check.call(box.caption_key() == "inspect.silver_urn.floor", "INTERACT SCENE: the first look surfaces the floor text")
	check.call(service.read_focus().get("action_key") == "interaction.hold_to_look",
		"INTERACT SCENE: a read box offers to be held")
	focus = service.read_focus()
	check.call(service.interact("manor.inspect.silver_urn", focus.get("revision", -1)).ok,
		"INTERACT SCENE: the second interaction takes the box in hand")
	check.call(play.player.get_node("Camera/HandSocket").get_node_or_null("Model") != null
		and box.get_node_or_null("Model") == null,
		"INTERACT SCENE: the held box hangs on the hand socket, not on the floor")
	check.call(box.caption_key() == "inspect.silver_urn.held", "INTERACT SCENE: the held box surfaces the hand text")
	var box_in_hand: Node3D = play.player.get_node("Camera/HandSocket").get_node_or_null("Model")
	check.call(box_in_hand != null and box_in_hand.visible
		and box_in_hand.position.is_equal_approx(Vector3(0.02, -0.12, -0.45)),
		"INTERACT SCENE: the held box is drawn at its own hand pose, not the photograph's")
	# Held up, the object owns the player's action: the way out must not depend on where they look.
	var held: Dictionary = service.read_exclusive()
	check.call(held.get("target_id") == "manor.inspect.silver_urn"
		and held.get("action_key") == "interaction.put_back",
		"INTERACT SCENE: a held box takes over the interact key")
	check.call(play._observing(), "INTERACT SCENE: manor play reports the held box as owning the action")
	check.call(not play._controls.blocked(),
		"INTERACT SCENE: holding freezes movement without blocking the look path")
	play.session.set_movement(Vector2(1.0, 0.0))
	play._physics_process(0.016)
	check.call(play.session.movement().is_zero_approx(),
		"INTERACT SCENE: a held box freezes the walk session")
	service.set_enabled(true)
	play.camera.look_at(Vector3(-7.26, 9.0, 0.9))
	for frame: int in 2:
		await tree.physics_frame
	check.call(service.read_exclusive().get("action_key") == "interaction.put_back",
		"INTERACT SCENE: looking away still offers the way out")
	check.call(service.interact_exclusive(service.read_exclusive().get("revision", -1)).ok,
		"INTERACT SCENE: the box goes back without aiming at it")
	check.call(box.get_node_or_null("Model") != null
		and box.get_node("Model").position.is_equal_approx(Vector3.ZERO),
		"INTERACT SCENE: the box model returns to its own floor slot")
	check.call(box.global_position.is_equal_approx(Vector3(-7.26, -0.025, 0.9)),
		"INTERACT SCENE: the box never leaves its authored placement")
	check.call(box.caption_key().is_empty(), "INTERACT SCENE: putting the box back clears the caption")
	check.call(not play.character_service.read_character().inventory.has("silver_urn"),
		"INTERACT SCENE: the observation box never reaches the notebook")
	# The doctor's diary left the desk: the shipped static diary prop is removed at runtime, and the
	# diary itself is an observation object that sits inside the study's locked medical cabinet, so
	# its ray target stays off until that cabinet is open. Nothing here carries the key or the
	# crowbar yet, which is exactly the state the refusal is about.
	check.call(play.find_child("Clue_DoctorDiary", true, false) == null,
		"INTERACT SCENE: the baked doctor diary prop is gone at runtime")
	check.call(play.find_child("manor_pickup_doctor_diary", true, false) == null,
		"INTERACT SCENE: the diary is no longer registered as a pickup")
	var cabinet: LockedView = play.find_child("manor_cabinet_medical", true, false) as LockedView
	check.call(cabinet != null, "INTERACT SCENE: study medical cabinet is placed and bound")
	var diary: InspectView = play.find_child("manor_inspect_doctor_diary", true, false) as InspectView
	check.call(diary != null and diary.get_node("Model").visible,
		"INTERACT SCENE: the shut diary is drawn inside the cabinet")
	check.call(diary != null and diary.get_node("Target").collision_layer == 0,
		"INTERACT SCENE: a diary behind a locked cabinet cannot be aimed at")
	play.player.place_at(Vector3(7.56, -0.025, -1.6), PI)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(diary.global_position + Vector3(0, 0.1, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.cabinet.medical"
		and focus.get("action_key") == "interaction.unlock",
		"INTERACT SCENE: the locked cabinet, not the diary, is what the aim ray finds")
	check.call(service.interact("manor.cabinet.medical", focus.get("revision", -1)).code == "CABINET_LOCKED",
		"INTERACT SCENE: a cabinet with no key and no crowbar refuses to open")
	check.call(cabinet != null and not cabinet.is_open(), "INTERACT SCENE: a refused cabinet stays shut")
	check.call(diary.get_node("Target").collision_layer == 0,
		"INTERACT SCENE: a refused cabinet still hides the diary from the aim ray")
	play._interaction_hud.show_result("CABINET_LOCKED")
	check.call(play._interaction_hud.feedback_key() == "interaction.cabinet_locked"
		and TranslationServer.translate("interaction.cabinet_locked") == CABINET_LOCKED_TEXT,
		"INTERACT SCENE: the refusal reaches the screen with its own wording")
	check.call(play.find_child("manor_pickup_wallet", true, false) == null,
		"INTERACT SCENE: the wallet is no longer registered as a pickup")
	var wallet: Node3D = play.find_child("manor_inspect_wallet", true, false)
	check.call(wallet != null, "INTERACT SCENE: reception wallet is placed and bound")
	var wallet_rest: Transform3D = wallet.get_node("Model").transform
	play.player.place_at(Vector3(-5.5, -0.025, 2.0), PI / 2)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(wallet.global_position + Vector3(0, 0.6, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.inspect.wallet", "INTERACT SCENE: aim can focus the wallet")
	check.call(focus.get("stage") == 0 and focus.get("action_key") == "interaction.inspect",
		"INTERACT SCENE: an unread wallet offers the first look")
	check.call(service.interact("manor.inspect.wallet", focus.get("revision", -1)).ok,
		"INTERACT SCENE: the first look at the wallet commits by shared service")
	check.call(wallet.caption_key() == "inspect.wallet.floor",
		"INTERACT SCENE: the first look surfaces the wallet floor text")
	check.call(not wallet.photo_shown(),
		"INTERACT SCENE: a wallet that is still closed shows no centred photograph")
	check.call(service.read_focus().get("action_key") == "interaction.take_photo",
		"INTERACT SCENE: a read wallet offers to give up its photo")
	focus = service.read_focus()
	check.call(service.interact("manor.inspect.wallet", focus.get("revision", -1)).ok,
		"INTERACT SCENE: the second interaction draws the photo out")
	var hand: Node3D = play.player.get_node("Camera/HandSocket")
	check.call(hand.get_node_or_null("Reveal") != null and wallet.get_node_or_null("Model/Reveal") == null,
		"INTERACT SCENE: the drawn photo hangs on the hand socket")
	var photo: Node3D = hand.get_node_or_null("Reveal")
	var offset: Vector3 = photo.position if photo != null else Vector3.ZERO
	var hand_point: Vector3 = play.camera.global_transform * offset
	var eye_distance: float = photo.global_position.distance_to(hand_point) if photo != null else 99.0
	check.call(photo != null and eye_distance < 0.6
		and photo.global_position.distance_to(play.camera.global_position) <= offset.length() + 0.6,
		"INTERACT SCENE: the held photo is carried to the hand, not left at the wallet's spot")
	check.call(photo != null and photo.scale.is_equal_approx(Vector3.ONE * 0.0125),
		"INTERACT SCENE: the held photo is scaled to a printed card, not to the raw model")
	check.call(wallet.get_node_or_null("Model") != null,
		"INTERACT SCENE: the wallet itself stays in the floor slot while the photo is held")
	check.call(wallet.get_node("Model").transform.is_equal_approx(wallet_rest),
		"INTERACT SCENE: the wallet keeps its authored transform while the photo is out")
	check.call(wallet.caption_key() == "inspect.wallet.held",
		"INTERACT SCENE: the held photo surfaces the second text")
	check.call(wallet.photo_shown(),
		"INTERACT SCENE: the drawn photo is shown centred on the screen")
	# Same contract as the box, with a different way out: the drawn photo owns the action, and the
	# only action left is to pocket it. Looking away must not trap the run.
	var wallet_held: Dictionary = service.read_exclusive()
	check.call(wallet_held.get("target_id") == "manor.inspect.wallet"
		and wallet_held.get("action_key") == "interaction.keep_photo",
		"INTERACT SCENE: the drawn photo takes over the interact key")
	check.call(wallet_held.get("stage") == 2,
		"INTERACT SCENE: the drawn photo is exclusive only while it is out")
	play.camera.look_at(Vector3(-6.5, 9.0, 2.0))
	for frame: int in 2:
		await tree.physics_frame
	check.call(service.read_exclusive().get("action_key") == "interaction.keep_photo",
		"INTERACT SCENE: looking away still offers to pocket the photo")
	check.call(service.interact_exclusive(service.read_exclusive().get("revision", -1)).ok,
		"INTERACT SCENE: the photo is pocketed without aiming at the wallet again")
	check.call(play.character_service.read_character().inventory.polaroid_photo == 1,
		"INTERACT SCENE: the pocketed photo reaches the notebook")
	check.call(service.read_exclusive().is_empty(),
		"INTERACT SCENE: an emptied wallet stops owning the interact key")
	check.call(wallet.get_node_or_null("Model/Reveal") != null
		and play.player.get_node("Camera/HandSocket").get_node_or_null("Reveal") == null,
		"INTERACT SCENE: the photo returns to the wallet")
	check.call(not wallet.get_node("Model/Reveal").visible,
		"INTERACT SCENE: the photo is hidden again once it is back")
	check.call(not wallet.photo_shown(),
		"INTERACT SCENE: pocketing the photo clears the centred view")
	check.call(wallet.global_position.is_equal_approx(Vector3(-6.5, -0.025, 2.0)),
		"INTERACT SCENE: the wallet never leaves its authored placement")
	check.call(wallet.caption_key().is_empty(), "INTERACT SCENE: pocketing the photo clears the caption")
	check.call(not play.character_service.read_character().inventory.has("wallet"),
		"INTERACT SCENE: the observation wallet never reaches the notebook")
	# The emptied wallet keeps two steps instead of three: look, then put back. Nothing is drawn out
	# a second time, so the second text and the centred photograph must never come back.
	play.camera.look_at(wallet.global_position + Vector3(0, 0.6, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.inspect.wallet" and focus.get("stage") == 0
		and focus.get("action_key") == "interaction.inspect",
		"INTERACT SCENE: an emptied wallet is back at the first look")
	check.call(service.interact("manor.inspect.wallet", focus.get("revision", -1)).ok,
		"INTERACT SCENE: the first look at an emptied wallet commits by shared service")
	focus = service.read_focus()
	check.call(focus.get("stage") == 1 and focus.get("action_key") == "interaction.put_back",
		"INTERACT SCENE: an emptied wallet offers to put itself back instead")
	check.call(wallet.caption_key() == "inspect.wallet.floor"
		and focus.get("caption_key") == "inspect.wallet.floor",
		"INTERACT SCENE: an emptied wallet only ever shows the first text")
	check.call(not wallet.photo_shown() and not wallet.get_node("Model/Reveal").visible,
		"INTERACT SCENE: an emptied wallet never shows the photo again")
	check.call(service.interact("manor.inspect.wallet", focus.get("revision", -1)).ok,
		"INTERACT SCENE: the emptied wallet goes back by shared service")
	check.call(wallet.caption_key().is_empty() and wallet.get_node_or_null("Model/Reveal") != null,
		"INTERACT SCENE: the emptied wallet returns to the floor with no text")
	check.call(play.character_service.read_character().inventory.polaroid_photo == 1,
		"INTERACT SCENE: a second pass cannot pocket the same photo twice")
	var key_bounds: AABB = _mesh_bounds(play.find_child("manor_pickup_manor_key", true, false))
	check.call(key_bounds.size.length() > 0.1 and key_bounds.position.y > -0.02
		and key_bounds.end.y < 0.2 and key_bounds.get_center().length() < 0.15,
		"INTERACT SCENE: manor key geometry is visible beside its pickup target")
	# The concealed cellar entrance. The delivered model leaves the stairwell open in the walk mesh and
	# covers it with its own boards plus one collision body, so prying is a state change over those two
	# nodes -- the shipped .glb and the walk mesh are never edited. At this point the crowbar is still
	# on the veranda, which is exactly the state the refusal is about.
	var boards: Node3D = play.find_child("V4_PryFloorboards", true, false)
	var blocker: CollisionObject3D = play.find_child("V4_PryFloorCollision", true, false)
	var pry: Node3D = play.find_child("manor_pry_cellar_boards", true, false)
	check.call(pry != null, "INTERACT SCENE: the concealed cellar entrance is placed and bound")
	check.call(boards != null and boards.visible and blocker != null and blocker.collision_layer == 1,
		"INTERACT SCENE: the shut entrance draws its boards and still blocks the stairwell")
	check.call(not play.character_service.read_character().inventory.has("crowbar"),
		"INTERACT SCENE: the crowbar is still on the veranda at this point")
	play.player.place_at(PRY_STAND, 0.0)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(PRY_AIM)
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == PRY_ID and focus.get("action_key") == "interaction.pry",
		"INTERACT SCENE: aim can focus the boards and offers to pry them")
	check.call(service.interact(PRY_ID, focus.get("revision", -1)).code == "PRY_NEEDS_CROWBAR",
		"INTERACT SCENE: prying without the crowbar is refused")
	check.call(boards.visible and blocker.collision_layer == 1,
		"INTERACT SCENE: a refused pry leaves boards and collision exactly as they were")
	play._interaction_hud.show_result("PRY_NEEDS_CROWBAR")
	check.call(play._interaction_hud.feedback_key() == "interaction.need_crowbar"
		and TranslationServer.translate("interaction.need_crowbar") == "徒手好像打不开呢",
		"INTERACT SCENE: the refusal reaches the screen with its own wording")
	# The props this round delivers. Each one is aimed at from its own measured stand point, taken by
	# the shared service, and has to reach the notebook and put its own line on the scene's caption
	# layer -- which is exactly the layer that has to outlive the node the receipt frees.
	var captions: CaptionHost = play.find_child(Props.CAPTION_HOST_NAME, true, false) as CaptionHost
	check.call(captions != null, "INTERACT SCENE: the scene owns one caption layer for pickup lines")
	check.call(captions != null and captions.shown_key().is_empty(),
		"INTERACT SCENE: the caption layer starts silent")
	# The cellar shelf. It hangs on the east wall -- the wall opposite the cellar stairs -- and the
	# five props that used to hang in mid-air stand on it, so each one's own footprint has to rest on
	# a board's measured top face rather than merely being near a wall. The boards are measured from
	# the placed model, not from the constants, so a re-import that changes the shelf's size is caught
	# here. Depth runs along x (the wall is on x) and length runs along z.
	var shelf_boards: Array[Node3D] = []
	var board_boxes: Array[AABB] = []
	for index: int in Shelf.TIER_COUNT:
		var board: Node3D = play.find_child("manor_shelf_board_%d" % (index + 1), true, false)
		check.call(board != null, "INTERACT SCENE: cellar shelf board %d is placed" % (index + 1))
		if board == null:
			continue
		shelf_boards.append(board)
		var measured: AABB = _world_bounds(board)
		board_boxes.append(measured)
		var surface: AABB = Shelf.tier_surface(index)
		check.call(is_equal_approx(measured.size.z, Shelf.BOARD_WIDTH)
			and is_equal_approx(measured.size.x, Shelf.BOARD_DEPTH),
			"INTERACT SCENE: shelf board %d keeps the measured board footprint" % (index + 1))
		# The board's usable top face is exactly the surface the props are placed against: the board
		# and the constants that carry its tier have to agree, or the props float or sink.
		check.call(absf(measured.end.y - surface.position.y) < 0.003,
			"INTERACT SCENE: shelf board %d top face is its tier's standing surface" % (index + 1))
		# The board hangs on the wall at x = -1.582 and its depth runs into the room, so its near edge
		# is the surface's near edge and its far edge is that minus the board's depth.
		check.call(absf(measured.end.x - surface.end.x) < 0.003
			and absf(measured.position.x - (surface.end.x - Shelf.BOARD_DEPTH)) < 0.003,
			"INTERACT SCENE: shelf board %d runs from the wall into the room" % (index + 1))
		check.call(absf(measured.position.z - surface.position.z) < 0.003
			and absf(measured.end.z - surface.end.z) < 0.003,
			"INTERACT SCENE: shelf board %d spans the wall run its tier claims" % (index + 1))
	# The east wall is the wall opposite the stairs: the stair mesh covers the room's west side
	# (x -5.890..-4.410) while the boards hang on x = -1.582, which is the wall a player standing at
	# the stair foot looks straight at, and the board runs from there into the room.
	check.call(absf(Shelf.SHELF_WALL_X - (-1.5820)) < 0.02
		and board_boxes.size() == Shelf.TIER_COUNT
		and board_boxes[0].end.x > board_boxes[0].position.x
		and board_boxes[0].position.x < -1.5820,
		"INTERACT SCENE: the shelf hangs on the east wall, opposite the cellar stairs")
	# Every cellar prop but the generator stands on a board: its own lowest point is the board's top
	# face, and its footprint sits over the board it stands on. The prop's box is measured in world
	# space, because two of these props are posed and their local boxes say nothing about where they
	# actually are.
	var manor_boxes: Array[AABB] = _manor_boxes(play.get_node("World/Model"), shelf_boards)
	for spec: Dictionary in pickups:
		if not spec.has("tier"):
			continue
		var prop: Node3D = play.find_child(spec.node, true, false)
		if prop == null:
			continue
		var surface: AABB = Shelf.tier_surface(spec.tier)
		var prop_box: AABB = _world_bounds(prop)
		check.call(absf(prop_box.position.y - surface.position.y) < 0.002,
			"INTERACT SCENE: " + spec.id + " sits on its shelf board, not above or inside it")
		# The board's back edge is on the wall at x = -1.582 and its depth runs into the room, so a
		# prop standing on it must sit between the wall and the board's front lip. A prop may overhang
		# that lip by a few centimetres -- a wide object on a narrow plank -- but its back must not
		# reach past the wall's face, where there is nothing but masonry.
		check.call(prop_box.end.x <= surface.end.x - 0.002
			and prop_box.position.x >= surface.position.x - 0.04
			and prop_box.position.z >= surface.position.z - 0.02
			and prop_box.end.z <= surface.end.z + 0.02,
			"INTERACT SCENE: " + spec.id + " fits inside the board it stands on")
		# A prop rests *on* the board, so its lowest face is the board's top face exactly: the boxes
		# are tangent and their shared volume is zero. That is why the support is checked against the
		# board's measured top face rather than by a volume overlap, which only ever proves that two
		# boxes are cutting into each other.
		var prop_board: AABB = board_boxes[spec.tier]
		check.call(prop_box.end.x <= prop_board.end.x - 0.002
			and prop_box.position.x >= prop_board.position.x - 0.04
			and prop_box.position.z >= prop_board.position.z - 0.02
			and prop_box.end.z <= prop_board.end.z + 0.02
			and absf(prop_box.position.y - prop_board.end.y) < 0.002,
			"INTERACT SCENE: " + spec.id + " actually rests on shelf board %d" % (spec.tier + 1))
		# A wall-mounted shelf touches its wall, so the boards themselves are expected to overlap it.
		# What matters is that the props do not: a prop whose own geometry reaches into the wall's box
		# would be half buried in masonry.
		check.call(_overlaps(prop_box, manor_boxes) == 0,
			"INTERACT SCENE: " + spec.id + " does not intersect the manor meshes")
	# Each board hangs flush on the wall it was given. The wall's collision box is thicker than its
	# drawn face, so the meaningful check is the real one: some wall-like piece of the manor -- one
	# running at least a metre along a wall -- has its room-facing side within a few millimetres of
	# the board's back edge, and its run overlaps the board's.
	var other_boxes: Array[AABB] = _manor_boxes(play.get_node("World/Model"), shelf_boards)
	for index: int in board_boxes.size():
		var board: AABB = board_boxes[index]
		var flush: bool = false
		for other: AABB in other_boxes:
			if other.size.z < 1.0:
				continue
			if absf(board.end.x - other.position.x) < 0.005 \
					and board.position.z < other.end.z and board.end.z > other.position.z:
				flush = true
		check.call(flush, "INTERACT SCENE: shelf board %d hangs flush on its wall" % (index + 1))
	for spec: Dictionary in pickups:
		var node: Node3D = play.find_child(spec.node, true, false)
		check.call(node != null and node.global_position.is_equal_approx(spec.position),
			"INTERACT SCENE: " + spec.id + " stands on its measured surface")
		if node == null:
			continue
		play.player.place_at(spec.stand, 0.0)
		for frame: int in 4:
			await tree.physics_frame
		play.camera.look_at(node.global_position + spec.aim)
		for frame: int in 2:
			await tree.physics_frame
		service.refresh_focus()
		focus = service.read_focus()
		check.call(focus.get("target_id") == spec.id, "INTERACT SCENE: aim can focus " + spec.id)
		check.call(focus.get("caption_key") == spec.caption,
			"INTERACT SCENE: " + spec.id + " carries its own line before it is taken")
		var has_line: bool = not String(spec.text).is_empty()
		# All eight props tell a line and therefore take two commands. The first one reads the line
		# out and must leave both the object and the notebook exactly as they were; only the second
		# command pockets the object, and it is the same command that retires the line.
		check.call(has_line and focus.get("action_key") == "interaction.inspect",
			"INTERACT SCENE: " + spec.id + " offers its first look before the take")
		check.call(service.interact(spec.id, focus.get("revision", -1)).ok,
			"INTERACT SCENE: " + spec.id + " first look commits by shared service")
		check.call(not play.character_service.read_character().inventory.has(spec.item),
			"INTERACT SCENE: the first look at " + spec.id + " pockets nothing")
		check.call(node.visible and node.get_node("Target").collision_layer == 8,
			"INTERACT SCENE: the first look at " + spec.id + " leaves it in the world")
		var dbg_shown: String = captions.shown_key() if captions != null else "<no host>"
		var dbg_text: String = TranslationServer.translate(spec.caption)
		if dbg_shown != spec.caption or dbg_text != spec.text:
			print("DIAG ", spec.id, " shown='", dbg_shown, "' expected_key='", spec.caption,
				"' translated_eq=", dbg_text == spec.text, " shown_eq=", dbg_shown == spec.caption)
		check.call(captions != null and captions.shown_key() == spec.caption
			and TranslationServer.translate(spec.caption) == spec.text,
			"INTERACT SCENE: " + spec.id + " tells its delivered line, word for word")
		focus = service.read_focus()
		check.call(focus.get("target_id") == spec.id
			and focus.get("action_key") == "interaction.pickup",
			"INTERACT SCENE: " + spec.id + " offers the take on its second command")
		check.call(service.interact(spec.id, focus.get("revision", -1)).ok,
			"INTERACT SCENE: " + spec.id + " second command commits the receipt")
		check.call(play.character_service.read_character().inventory.has(spec.item),
			"INTERACT SCENE: " + spec.id + " reaches the notebook")
		check.call(captions != null and captions.shown_key().is_empty(),
			"INTERACT SCENE: taking " + spec.id + " clears the line it told")
	# The receipt frees the node it was taken from, so the line has to live somewhere that is not
	# parented to it. Deletion is deferred to the end of the frame, hence the extra step.
	await tree.process_frame
	check.call(play.find_child("manor_pickup_crowbar", true, false) == null
		and play.find_child("manor_pickup_wrench", true, false) == null,
		"INTERACT SCENE: a taken pickup is freed together with its own node")
	# The key is not a special case: it tells its glove-box line like every other prop in this round
	# and it, too, only reaches the notebook on the second command.
	check.call(play.character_service.read_character().inventory.manor_key == 1,
		"INTERACT SCENE: the key reached the notebook on its second command")
	# With the crowbar in the notebook -- carried, not equipped -- the same command opens the entrance:
	# the boards stop being drawn and their collision body leaves every layer. That is the whole
	# change; the stairwell the walk mesh already leaves open underneath is what the player then walks
	# down, which is why a ray straight down now reaches the cellar floor.
	check.call(play.character_service.read_character().inventory.has("crowbar"),
		"INTERACT SCENE: the crowbar reached the notebook on the veranda")
	play.player.place_at(PRY_STAND, 0.0)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(PRY_AIM)
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == PRY_ID, "INTERACT SCENE: the shut boards can be aimed at again")
	check.call(service.interact(PRY_ID, focus.get("revision", -1)).ok,
		"INTERACT SCENE: carrying the crowbar pries the entrance open")
	check.call(not boards.visible, "INTERACT SCENE: a pried-open entrance stops drawing its boards")
	check.call(blocker.collision_layer == 0,
		"INTERACT SCENE: a pried-open entrance leaves every collision layer")
	# The ramp below measures -1.79 at z = -9.2, so anything clear of the boards' own top face at
	# y = 0.0 proves the drop is open.
	var drop := PhysicsRayQueryParameters3D.create(Vector3(-5.15, 1.0, -9.2), Vector3(-5.15, -6.0, -9.2))
	var fallen: Dictionary = play.get_world_3d().direct_space_state.intersect_ray(drop)
	check.call(not fallen.is_empty() and (fallen.position as Vector3).y < -1.5,
		"INTERACT SCENE: prying the boards open uncovers the stairwell down to the cellar")
	service.refresh_focus()
	check.call(service.read_focus().get("target_id") != PRY_ID,
		"INTERACT SCENE: an opened entrance stops claiming the aim ray")
	check.call(not service.interact(PRY_ID, 1).ok,
		"INTERACT SCENE: an opened entrance refuses a second command")
	play.visit_cellar()
	check.call(play.player.position.y < -2.6 and play.player.position.z < -7.0,
		"INTERACT SCENE: the B cellar shortcut still works after the pry")
	# Back in the study with the key: the cabinet opens, hands the aim ray to the diary, and the
	# diary runs its own read -- flyleaf, first page, second page, third page -- before the notebook
	# takes it. Each page is pinned to its delivered wording, line breaks included.
	play.player.place_at(Vector3(7.56, -0.025, -1.6), PI)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(diary.global_position + Vector3(0, 0.1, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.cabinet.medical", "INTERACT SCENE: the cabinet can be aimed at again")
	check.call(service.interact("manor.cabinet.medical", focus.get("revision", -1)).ok,
		"INTERACT SCENE: carrying the manor key opens the cabinet")
	check.call(cabinet.is_open(), "INTERACT SCENE: the opened cabinet reports itself open")
	check.call(diary.get_node("Target").collision_layer == 8,
		"INTERACT SCENE: opening the cabinet hands the aim ray to the diary")
	check.call(cabinet.get_node("Target").collision_layer == 0,
		"INTERACT SCENE: the opened cabinet stops claiming the aim ray")
	check.call(diary.get_node("Model").visible and not diary.get_node("Book").visible,
		"INTERACT SCENE: the diary is still shut when the cabinet opens")
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.inspect.doctor_diary"
		and focus.get("stage") == 0 and focus.get("action_key") == "interaction.inspect",
		"INTERACT SCENE: the diary behind the open door offers the first look")
	check.call(service.interact("manor.inspect.doctor_diary", focus.get("revision", -1)).ok,
		"INTERACT SCENE: the first look at the diary commits by shared service")
	check.call(diary.caption_key() == "inspect.doctor_diary.flyleaf"
		and TranslationServer.translate("inspect.doctor_diary.flyleaf") == FLYLEAF_TEXT,
		"INTERACT SCENE: the first look surfaces the flyleaf line, word for word")
	check.call(not diary.get_node("Book").visible and diary.get_node("Model").visible,
		"INTERACT SCENE: a diary read inside the cabinet is still shut")
	focus = service.read_focus()
	check.call(focus.get("action_key") == "interaction.open_diary",
		"INTERACT SCENE: a read diary offers to be opened")
	check.call(service.interact("manor.inspect.doctor_diary", focus.get("revision", -1)).ok,
		"INTERACT SCENE: the second interaction opens the diary in hand")
	var socket: Node3D = play.player.get_node("Camera/HandSocket")
	var book: Node3D = socket.get_node_or_null("Book") as Node3D
	check.call(book != null and book.visible and diary.get_node_or_null("Book") == null,
		"INTERACT SCENE: the opened book hangs on the hand socket")
	check.call(book != null and book.scale.is_equal_approx(Vector3.ONE * InspectView.BOOK_HAND_SCALE),
		"INTERACT SCENE: the opened book takes its measured hand scale, not the authored one")
	check.call(not diary.get_node("Model").visible,
		"INTERACT SCENE: the shut cover steps aside while the opened book is out")
	check.call(diary.caption_key() == "inspect.doctor_diary.page1"
		and TranslationServer.translate("inspect.doctor_diary.page1") == PAGE_ONE_TEXT,
		"INTERACT SCENE: the opened diary shows its first page, word for word")
	var diary_held: Dictionary = service.read_exclusive()
	check.call(diary_held.get("target_id") == "manor.inspect.doctor_diary"
		and diary_held.get("action_key") == "interaction.turn_page" and play._observing(),
		"INTERACT SCENE: an opened diary takes over the interact key")
	check.call(service.interact_exclusive(diary_held.get("revision", -1)).ok,
		"INTERACT SCENE: the page turns without aiming at the cabinet again")
	check.call(diary.caption_key() == "inspect.doctor_diary.page2"
		and TranslationServer.translate("inspect.doctor_diary.page2") == PAGE_TWO_TEXT,
		"INTERACT SCENE: the second page is the delivered ledger text, word for word")
	play.camera.look_at(Vector3(7.56, 9.0, -0.29))
	for frame: int in 2:
		await tree.physics_frame
	diary_held = service.read_exclusive()
	check.call(diary_held.get("action_key") == "interaction.turn_page"
		and service.interact_exclusive(diary_held.get("revision", -1)).ok,
		"INTERACT SCENE: looking away still turns to the third page")
	check.call(diary.caption_key() == "inspect.doctor_diary.page3"
		and TranslationServer.translate("inspect.doctor_diary.page3") == PAGE_THREE_TEXT,
		"INTERACT SCENE: the third page is the delivered 1920 text, word for word")
	diary_held = service.read_exclusive()
	check.call(diary_held.get("action_key") == "interaction.keep_diary",
		"INTERACT SCENE: the last page offers the notebook")
	check.call(service.interact_exclusive(diary_held.get("revision", -1)).ok,
		"INTERACT SCENE: the diary is pocketed straight from the hand")
	check.call(play.character_service.read_character().inventory.doctor_diary == 1,
		"INTERACT SCENE: the pocketed diary reaches the notebook")
	check.call(service.read_exclusive().is_empty(),
		"INTERACT SCENE: a pocketed diary stops owning the interact key")
	check.call(socket.get_node_or_null("Book") == null and diary.get_node_or_null("Book") != null,
		"INTERACT SCENE: the opened book returns to the cabinet")
	check.call(diary.get_node("Model").visible and diary.get_node_or_null("Book") != null
		and not diary.get_node("Book").visible,
		"INTERACT SCENE: the cover is shut again and back in the cabinet")
	check.call(diary.caption_key().is_empty(), "INTERACT SCENE: pocketing the diary clears the caption")
	# What is left is the shortened loop: look, open on the first page, turn to a page with nothing
	# written on it, put it back. The notebook must not receive a second copy.
	play.camera.look_at(diary.global_position + Vector3(0, 0.1, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == "manor.inspect.doctor_diary" and focus.get("stage") == 0
		and focus.get("action_key") == "interaction.inspect",
		"INTERACT SCENE: a pocketed diary is back at the first look")
	check.call(service.interact("manor.inspect.doctor_diary", focus.get("revision", -1)).ok,
		"INTERACT SCENE: the first look at a pocketed diary commits by shared service")
	check.call(diary.caption_key() == "inspect.doctor_diary.page1"
		and socket.get_node_or_null("Book") != null and not diary.get_node("Model").visible,
		"INTERACT SCENE: a pocketed diary opens again on its first page")
	diary_held = service.read_exclusive()
	check.call(diary_held.get("action_key") == "interaction.turn_page"
		and service.interact_exclusive(diary_held.get("revision", -1)).ok,
		"INTERACT SCENE: the shortened loop turns to a blank page")
	check.call(diary.caption_key().is_empty() and socket.get_node_or_null("Book") != null,
		"INTERACT SCENE: the shortened loop shows an opened diary with no text")
	diary_held = service.read_exclusive()
	check.call(diary_held.get("action_key") == "interaction.put_back"
		and service.interact_exclusive(diary_held.get("revision", -1)).ok,
		"INTERACT SCENE: the shortened loop puts the diary back by shared service")
	check.call(diary.get_node("Model").visible and diary.get_node_or_null("Book") != null
		and not diary.get_node("Book").visible and diary.caption_key().is_empty(),
		"INTERACT SCENE: the shortened loop ends with the diary shut and silent")
	check.call(play.character_service.read_character().inventory.doctor_diary == 1,
		"INTERACT SCENE: a second pass cannot pocket the same diary twice")
	# The radio is fixed to the kitchen worktop beside the stove and is never a pickup: it is only
	# ever observed, so one text is all it has and the notebook must never receive it.
	check.call(play.find_child("manor_pickup_radio", true, false) == null,
		"INTERACT SCENE: the radio is no longer registered as a pickup")
	var radio: InspectView = play.find_child("manor_inspect_radio", true, false) as InspectView
	check.call(radio != null and radio.global_position.is_equal_approx(Props.RADIO_POSITION),
		"INTERACT SCENE: the radio stands on the kitchen worktop")
	# The radio used to stand over the open gap where the stove's run meets the counter's, and its own
	# scene lifts the case onto the root, so the root's height *is* the height of the case's bottom.
	# The ray straight down through the case must therefore land on the worktop the placement names,
	# and the worktop must be under the case's whole footprint rather than under part of it.
	var case_bottom: float = radio.global_position.y
	var support := PhysicsRayQueryParameters3D.create(
		Vector3(radio.global_position.x, case_bottom + 0.4, radio.global_position.z),
		Vector3(radio.global_position.x, case_bottom - 0.4, radio.global_position.z))
	support.collision_mask = 1
	var under: Dictionary = play.get_world_3d().direct_space_state.intersect_ray(support)
	check.call(not under.is_empty()
		and is_equal_approx((under.position as Vector3).y, Props.KITCHEN_WORKTOP),
		"INTERACT SCENE: the kitchen worktop is under the radio's case, at the measured height")
	var corners_ok: bool = true
	for dx: float in [-0.19, 0.19]:
		for dz: float in [-0.097, 0.097]:
			var corner := PhysicsRayQueryParameters3D.create(
				Vector3(radio.global_position.x + dx, case_bottom + 0.4, radio.global_position.z + dz),
				Vector3(radio.global_position.x + dx, case_bottom - 0.4, radio.global_position.z + dz))
			corner.collision_mask = 1
			var hit: Dictionary = play.get_world_3d().direct_space_state.intersect_ray(corner)
			if hit.is_empty() or absf((hit.position as Vector3).y - Props.KITCHEN_WORKTOP) > 0.001:
				corners_ok = false
	check.call(corners_ok,
		"INTERACT SCENE: the worktop reaches under every corner of the radio's case")
	check.call(radio != null and radio.get_node("Model").visible,
		"INTERACT SCENE: the radio is drawn on the worktop")
	check.call(radio != null and radio.caption_key().is_empty(),
		"INTERACT SCENE: the radio says nothing until it is looked at")
	play.player.place_at(Vector3(1.60, Props.GROUND_FLOOR, 6.90), 0.0)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(radio.global_position)
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == Props.RADIO_ID
		and focus.get("action_key") == "interaction.inspect",
		"INTERACT SCENE: aim can focus the fixed radio on its worktop")
	check.call(service.interact(Props.RADIO_ID, focus.get("revision", -1)).ok,
		"INTERACT SCENE: the first look at the radio commits by shared service")
	check.call(radio.caption_key() == "inspect.radio.stage_one"
		and TranslationServer.translate("inspect.radio.stage_one") == RADIO_TEXT,
		"INTERACT SCENE: the radio surfaces its stage-one text, word for word")
	check.call(service.read_exclusive().is_empty(),
		"INTERACT SCENE: an observed radio never takes over the interact key")
	check.call(not play.character_service.read_character().inventory.has("radio"),
		"INTERACT SCENE: the observed radio never reaches the notebook")
	# The generator moved into the cellar this round: its case fits the room's long axis, and it is a
	# device, so its first command is its own first look and only then does it start and stop.
	var generator: GeneratorView = play.find_child("manor_device_generator", true, false)
	check.call(generator != null and generator.global_position.is_equal_approx(Props.GENERATOR_POSITION),
		"INTERACT SCENE: the generator stands in the cellar")
	# The generator's case now fills the cellar's centre, so the greybox token moved in front of its
	# south face -- measured at z = -7.752 -- instead of being buried inside the machine.
	var token: Node3D = play.find_child("manor_pickup_cellar_token", true, false)
	check.call(token != null and token.global_position.z > -7.752,
		"INTERACT SCENE: the greybox cellar token stands clear of the generator case")
	play.player.place_at(Vector3(-3.20, Props.CELLAR_FLOOR, -7.00), 0.0)
	for frame: int in 4:
		await tree.physics_frame
	play.camera.look_at(generator.global_position + Vector3(0, 1.2, 0))
	for frame: int in 2:
		await tree.physics_frame
	service.refresh_focus()
	focus = service.read_focus()
	check.call(focus.get("target_id") == Props.GENERATOR_ID, "INTERACT SCENE: aim can focus the generator")
	check.call(not generator.is_running() and not generator.get_node("Running").visible,
		"INTERACT SCENE: generator starts idle")
	check.call(focus.get("action_key") == "interaction.device.inspect",
		"INTERACT SCENE: an unexamined generator offers its first look")
	check.call(service.interact(Props.GENERATOR_ID, focus.get("revision", -1)).ok,
		"INTERACT SCENE: the first look at the generator commits by shared service")
	check.call(generator.caption_key() == Props.GENERATOR_INSPECT_CAPTION
		and TranslationServer.translate(Props.GENERATOR_INSPECT_CAPTION) == GENERATOR_TEXT,
		"INTERACT SCENE: the generator surfaces its inspection text, word for word")
	check.call(not generator.is_running(), "INTERACT SCENE: the first look does not start the generator")
	check.call(service.read_focus().get("action_key") == "interaction.device.start",
		"INTERACT SCENE: an examined generator now offers to start")
	# The fuel gate, stated where an empty notebook is easy to assert: the cellar run that takes the
	# kerosene off the shelf happens later in this suite, so this device is built here with the
	# inventory port's own default, which carries nothing at all. A refused start must leave the
	# machine stopped, its first-look text on screen and its revision untouched, because a refused
	# command is not an operation.
	var empty_inventory := Inventory.new()
	var gated := Device.new(DeviceState.new(false, true), Props.GENERATOR_NAME_KEY,
		Props.GENERATOR_INSPECT_CAPTION, empty_inventory, Props.GENERATOR_FUEL_ITEM,
		Props.GENERATOR_NEEDS_FUEL)
	check.call(gated.execute(0).ok and gated.read().get("action_key") == "interaction.device.start",
		"INTERACT SCENE: the gated generator still inspects first")
	check.call(not gated.carried(),
		"INTERACT SCENE: nothing is carried for the generator to run on")
	check.call(gated.execute(1).code == Props.GENERATOR_NEEDS_FUEL,
		"INTERACT SCENE: starting the generator without kerosene is refused")
	check.call(not bool(gated.read().get("running", false)),
		"INTERACT SCENE: a refused start leaves the generator stopped")
	check.call(gated.read().get("caption_key") == Props.GENERATOR_INSPECT_CAPTION,
		"INTERACT SCENE: a refused start leaves the inspection text where it was")
	check.call(gated.read().get("revision") == 1,
		"INTERACT SCENE: a refused start does not advance the device's revision")
	play._interaction_hud.show_result(Props.GENERATOR_NEEDS_FUEL)
	check.call(play._interaction_hud.feedback_key() == "interaction.need_kerosene"
		and TranslationServer.translate("interaction.need_kerosene") == "似乎没有机油了呢",
		"INTERACT SCENE: the refusal reaches the screen with its own wording")
	# With the notebook's port answering that the bottle is carried, the same command starts it. The
	# scene's own generator is used for this half, because by now the cellar run has taken the
	# kerosene off the shelf: the gate opens on what the player is carrying, without equipping it.
	check.call(play.character_service.read_character().inventory.has("kerosene_bottle"),
		"INTERACT SCENE: the cellar run put the kerosene in the notebook")
	focus = service.read_focus()
	check.call(service.interact(Props.GENERATOR_ID, focus.get("revision", -1)).ok,
		"INTERACT SCENE: carrying the kerosene starts the generator by shared service")
	check.call(play.character_service.read_character().inventory.has("kerosene_bottle"),
		"INTERACT SCENE: starting the generator does not spend the kerosene")
	check.call(generator.is_running() and generator.get_node("Running").visible,
		"INTERACT SCENE: running generator shows its lamp")
	check.call(generator.caption_key().is_empty(),
		"INTERACT SCENE: running the generator retires its inspection text")
	focus = service.read_focus()
	check.call(service.interact(Props.GENERATOR_ID, focus.get("revision", -1)).ok
		and not generator.is_running(), "INTERACT SCENE: generator stops again")
	service.set_enabled(false)
	check.call(service.read_focus().is_empty(), "INTERACT SCENE: blocked input clears focus")
	play.queue_free()
	await tree.process_frame

static func _mesh_bounds(scene: Node3D) -> AABB:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for child: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		var relative: Transform3D = scene.global_transform.affine_inverse() * mesh_node.global_transform
		for surface: int in mesh_node.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var placed: Vector3 = relative * vertex
				low = low.min(placed)
				high = high.max(placed)
	return AABB(low, high - low)

## Every mesh box in the delivered manor, measured once, minus the subtrees the caller names as
## standing surfaces. The engine's own box is good enough for this coarse "does the new prop cut into
## the building" sweep, and reading 5167 of them once is far cheaper than transforming every vertex
## of all of them per prop.
static func _manor_boxes(model: Node3D, standing_on: Array[Node3D]) -> Array[AABB]:
	var boxes: Array[AABB] = []
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var skip: bool = false
		for board: Node3D in standing_on:
			if board != null and is_instance_valid(board) and board.is_ancestor_of(child):
				skip = true
				break
		if skip:
			continue
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		boxes.append(mesh_node.global_transform * mesh_node.get_aabb())
	return boxes

## A node's own geometry as a world box. The engine box is used rather than a vertex walk: the props
## and the boards this checks are unposed or posed at right angles, so their local box is exact, and
## a vertex walk over tens of thousands of vertices per prop would not fit the suite's budget.
static func _world_bounds(scene: Node3D) -> AABB:
	var first: bool = true
	var merged := AABB()
	for child: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = child as MeshInstance3D
		var box: AABB = mesh_node.global_transform * mesh_node.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	return merged

## How many of those boxes a placed object's world box overlaps. Two boxes that only touch are not
## an overlap: a prop standing against a wall's mesh touches the wall's box in the same way a prop
## standing on a board touches the board's, and the engine reports that as zero depth rather than
## zero volume. The tolerance is the same order as the placement measurements themselves, so a prop
## sunk half a centimetre into masonry still fails.
const TOUCH_DEPTH: float = 0.005

static func _overlaps(box: AABB, boxes: Array[AABB]) -> int:
	var hits: int = 0
	for other: AABB in boxes:
		if not box.intersects(other):
			continue
		var shared: AABB = box.intersection(other)
		var depth: float = minf(shared.size.x, minf(shared.size.y, shared.size.z))
		if depth > TOUCH_DEPTH:
			hits += 1
	return hits
