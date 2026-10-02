extends SceneTree
const MAIN = preload("res://bootstrap/main.tscn")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var main := MAIN.instantiate()
	root.add_child(main)
	main._navigate("story_archive")
	await create_timer(0.6).timeout
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 1 and args[1] != "archive":
		var result = main._services.story_archive.request_start("deadlight")
		assert(result.ok)
		var play = main.get_node("SceneHost").get_child(0)
		play.player.place_at(Vector3(-4.9, 0.08, -1.64), -PI / 2)
		await create_timer(0.4).timeout
		if args[1] == "dossier":
			play.character_hud.set_open(true)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var result: Error = root.get_texture().get_image().save_png(args[0])
	print("AIRPG_MAIN_CAPTURE: ", result)
	main.queue_free()
	await process_frame
	quit(result)
