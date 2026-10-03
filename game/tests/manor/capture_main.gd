extends SceneTree
## Captures a real window screenshot. Modes: settings, archive, dossier, manor,
## study / study_talk (Emilia in the doctor study) and reception / reception_talk (Mary).
const MAIN = preload("res://bootstrap/main.tscn")
## Screenshot mode -> [npc_id, hold greeting pose].
const NPC_MODES: Dictionary = {"study": ["emilia", false], "study_talk": ["emilia", true],
	"reception": ["mary", false], "reception_talk": ["mary", true]}

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[1] if args.size() > 1 else "archive"
	if mode == "settings":
		var home: Control = main.get_node("SceneHost").get_child(0)
		home._open_settings()
	elif mode == "archive":
		main._navigate("story_archive")
	else:
		main._navigate("story_archive")
		await create_timer(0.6).timeout
		var result = main._services.story_archive.request_start("deadlight")
		assert(result.ok)
		var play = main.get_node("SceneHost").get_child(0)
		play.player.place_at(Vector3(-4.9, 0.08, -1.64), -PI / 2)
		if NPC_MODES.has(mode):
			# Stand in front of the named NPC; *_talk modes also hold its greeting pose.
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
