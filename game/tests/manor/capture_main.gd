extends SceneTree
## Captures a real window screenshot. Modes: settings, archive, dossier, manor,
## study (stand in front of the study NPC) and study_talk (same, holding its greeting pose).
const MAIN = preload("res://bootstrap/main.tscn")

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
		if mode == "study" or mode == "study_talk":
			# Doctor study: stand in front of the wandering study NPC.
			await create_timer(0.3).timeout
			var study: Node3D = null
			for actor: Node3D in play.npc_actors:
				if actor.npc_id == "preview_study":
					study = actor
			assert(study != null)
			play.player.place_at(study.position + Vector3(-2.0, 0, 0), -PI / 2)
			await create_timer(0.3).timeout
			if mode == "study_talk":
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
