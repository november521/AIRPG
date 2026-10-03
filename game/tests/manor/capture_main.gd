extends SceneTree
const MAIN = preload("res://bootstrap/main.tscn")
const PLAY = preload("res://bootstrap/manor_play.tscn")
const JsonFile = preload("res://infrastructure/content/json_file.gd")
const Localization = preload("res://infrastructure/localization/json_localization.gd")
const LOCALIZATION_PATH := "res://data/localization/zh_CN.json"
## Where the diary's still is posed: in front of the study's medical cabinet, on the walkable study
## floor measured at -0.025, facing the cabinet's open front.
const DIARY_STAND := Vector3(7.56, -0.025, -1.6)
## Camera pitch for the still. The opened book is held 0.20 m below and 0.42 m in front of the eye,
## which is about 25 degrees below the view axis, so the view tips down to frame it.
const DIARY_PITCH_DEG: float = -24.0
## Where to stand and what to aim at for the prop stills. Each stand point and aim point was measured
## against the delivered V4 model and matches the placements in `bootstrap/manor_props.gd` /
## `bootstrap/manor_shelf.gd`. The cellar view stands in the middle of the room facing the east wall,
## which is where the shelf hangs: the six props run along z -10.10..-8.40 at x = -1.74, about 1.5 m
## from the stand point, and the aim lands on the middle of the lower board so the prompt line shows
## one of the pickups.
const PROPS_VIEWS: Dictionary = {
	"cellar": {"stand": Vector3(-3.40, -3.23, -9.40), "aim": Vector3(-1.70, -1.86, -9.40)},
	"generator": {"stand": Vector3(-3.20, -3.23, -6.40), "aim": Vector3(-3.20, -1.35, -9.40)},
	"kitchen": {"stand": Vector3(1.60, -0.025, 6.90), "aim": Vector3(1.60, 1.06, 7.80)},
	"porch": {"stand": Vector3(5.60, 0.020, 5.20), "aim": Vector3(5.60, 0.45, 3.40)},
	"reception": {"stand": Vector3(-6.10, -0.025, 2.35), "aim": Vector3(-5.20, 0.005, 1.60)},
	# The concealed cellar entrance: the shut boards, and the same view after prying them up with a
	# crowbar claimed into the notebook. The boards top out at y = 0.0 over z -11.497..-8.283.
	"pry": {"stand": Vector3(-5.15, 0.0, -11.50), "aim": Vector3(-5.15, -0.10, -9.90)},
	"pry_open": {"stand": Vector3(-5.15, 0.0, -11.50), "aim": Vector3(-5.15, -0.90, -9.90)},
}
## Where the prying itself is posed from: standing on the boards, looking down their length.
const PRY_STAND := Vector3(-5.15, 0.0, -11.00)
const PRY_AIM := Vector3(-5.15, 0.0, -9.89)
## NPC stills: mode -> [npc_id, hold greeting pose]. Study is the doctor's study, reception is the
## manor reception; the *_talk variants also open the greeting so the caption layer is visible.
const NPC_MODES: Dictionary = {"study": ["emilia", false], "study_talk": ["emilia", true],
	"reception": ["mary", false], "reception_talk": ["mary", true]}

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 1 and args[1] == "diary":
		await _capture_diary(args[0], args[2] if args.size() > 2 else "open")
		return
	if args.size() > 1 and args[1] == "props":
		await _capture_props(args[0], args[2] if args.size() > 2 else "cellar")
		return
	var main := MAIN.instantiate()
	root.add_child(main)
	var mode: String = args[1] if args.size() > 1 else "archive"
	if mode == "settings":
		# The AI connection overlay sits on the home screen, so no route is entered for it.
		var home: Control = main.get_node("SceneHost").get_child(0)
		home._open_settings()
	else:
		main._navigate("story_archive")
		await create_timer(0.6).timeout
		if mode != "archive":
			var result = main._services.story_archive.request_start("deadlight")
			assert(result.ok)
			var play = main.get_node("SceneHost").get_child(0)
			play.player.place_at(Vector3(-4.9, 0.08, -1.64), -PI / 2)
			if NPC_MODES.has(mode):
				# Stand in front of the named actor; the *_talk modes also hold its greeting pose.
				await create_timer(0.3).timeout
				var npc_id: String = NPC_MODES[mode][0]
				var target: Node3D = null
				for actor: Node3D in play.npc_actors:
					if actor.npc_id == npc_id:
						target = actor
				assert(target != null)
				play.player.place_at(target.position + Vector3(-1.8, 0, 0), -PI / 2)
				await create_timer(0.3).timeout
				if NPC_MODES[mode][1]:
					play._open_greeting()
			await create_timer(0.4).timeout
			if mode == "dossier":
				play.character_hud.set_open(true)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(args[0])
	print("AIRPG_MAIN_CAPTURE: ", result)
	main.queue_free()
	await process_frame
	quit(result)

## The prop stills are posed on their own manor instance, for the same reason as the diary still:
## they are about one room's props, not about the archive route. Physics is stopped before the pose
## so nothing drifts between it and the frame that is written out.
func _capture_props(path: String, view: String) -> void:
	var messages := JsonFile.read(LOCALIZATION_PATH)
	assert(messages.ok)
	assert(Localization.install(messages.value, "zh_CN").ok)
	var play: Node = PLAY.instantiate()
	root.add_child(play)
	await create_timer(0.4).timeout
	play.set_physics_process(false)
	# The player's own tick re-applies the walk session's yaw and pitch every frame, which would undo
	# the pose's `look_at` before the frame is written. Both ticks are stopped so the still is exactly
	# the pose that was asked for.
	play.player.set_physics_process(false)
	if view.begins_with("pry"):
		await _pose_pry(play, view == "pry_open")
	var pose: Dictionary = PROPS_VIEWS.get(view, PROPS_VIEWS.cellar)
	play.player.place_at(pose.stand, 0.0)
	for frame: int in 4:
		await physics_frame
	play.camera.look_at(pose.aim)
	# The walk tick is off, so the HUD and the aim prompt are driven by hand: without this the still
	# would carry the location and the prompt left over from the spawn point.
	play._hud.show_location(pose.stand, true)
	play.interaction_service.set_enabled(true)
	play.interaction_service.refresh_focus()
	play._interaction_hud.refresh(true)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(path)
	print("AIRPG_MAIN_CAPTURE: ", result)
	play.queue_free()
	await process_frame
	quit(result)

## Poses the cellar entrance for a still. "shut" leaves the boards exactly as the model ships them;
## "open" claims a crowbar into the notebook, stands on the boards and pries them up through the
## shared interaction service, so the still shows the uncovered stairwell the model already has.
func _pose_pry(play: Node, open: bool) -> void:
	if not open:
		return
	var service = play.interaction_service
	var revision: int = play.character_service.read_character().revision
	play.character_service.claim_pickup("capture.crowbar", "crowbar", 1, revision)
	play.player.place_at(PRY_STAND, 0.0)
	for frame: int in 4:
		await physics_frame
	play.camera.look_at(PRY_AIM)
	for frame: int in 2:
		await physics_frame
	service.set_enabled(true)
	service.refresh_focus()
	var focus: Dictionary = service.read_focus()
	if not focus.is_empty():
		service.interact(focus.target_id, focus.revision)

## The diary still is posed on its own manor instance rather than through the archive route: that
## route runs the character-creation step first, which is another workstream's screen and is not
## touched from here. Only localization is installed by hand, exactly as the boot scene does.
func _capture_diary(path: String, phase: String) -> void:
	var messages := JsonFile.read(LOCALIZATION_PATH)
	assert(messages.ok)
	var localized := Localization.install(messages.value, "zh_CN")
	assert(localized.ok)
	var play: Node = PLAY.instantiate()
	root.add_child(play)
	await create_timer(0.4).timeout
	await _pose_diary(play, phase)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(path)
	print("AIRPG_MAIN_CAPTURE: ", result)
	play.queue_free()
	await process_frame
	quit(result)

## Poses the doctor's diary for a still. Physics is stopped first, so nothing moves between the pose
## and the frame that is written out.
##   "locked" -- the cabinet as it ships: the shut diary on its shelf behind the glass, and the
##               cabinet itself holding the aim ray.
##   "open"   -- a key is claimed into the notebook, the cabinet is unlocked through the shared
##               interaction service, and the diary is walked to its first opened page, so the
##               opened book hangs on the hand socket with the delivered text on screen.
func _pose_diary(play: Node, phase: String) -> void:
	play.set_physics_process(false)
	var service = play.interaction_service
	var diary: Node3D = play.find_child("manor_inspect_doctor_diary", true, false)
	play.player.place_at(DIARY_STAND, PI)
	for frame: int in 4:
		await physics_frame
	play.camera.look_at(diary.global_position + Vector3(0, 0.1, 0))
	for frame: int in 2:
		await physics_frame
	service.set_enabled(true)
	if phase == "locked":
		service.refresh_focus()
		play._interaction_hud.refresh(true)
		return
	var revision: int = play.character_service.read_character().revision
	play.character_service.claim_pickup("capture.manor_key", "manor_key", 1, revision)
	# Unlock the cabinet, then keep pressing until the opened book is what the player is holding.
	for press: int in 4:
		service.refresh_focus()
		var focus: Dictionary = service.read_focus()
		if focus.is_empty():
			break
		service.interact(focus.target_id, focus.revision)
		if not service.read_exclusive().is_empty():
			break
	play.camera.rotation.x = deg_to_rad(DIARY_PITCH_DEG)
	play._interaction_hud.refresh(true)



