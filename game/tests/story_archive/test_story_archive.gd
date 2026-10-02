extends RefCounted
const Catalog = preload("res://domain/content/story_catalog.gd")
const Service = preload("res://application/story_archive/story_archive_service.gd")
const Launcher = preload("res://application/ports/story_launcher.gd")
const Result = preload("res://shared/result.gd")
const JsonFile = preload("res://infrastructure/content/json_file.gd")
const Localization = preload("res://infrastructure/localization/json_localization.gd")
const PAGE = preload("res://presentation/story_archive/story_archive.tscn")
const MAIN = preload("res://bootstrap/main.tscn")
const ArchiveComposition = preload("res://bootstrap/story_archive_composition.gd")

class Spy extends Launcher:
	var calls: Array[String] = []
	var accept: bool = false
	func start_story(story_id: String) -> RefCounted:
		calls.append(story_id)
		return Result.success() if accept else Result.failure("STORY_START_UNAVAILABLE")

func run(check: Callable, tree: SceneTree) -> void:
	var raw: Dictionary = JsonFile.read("res://data/stories/catalog.json").value
	var schema: Dictionary = JsonFile.read("res://data/schemas/story_catalog.schema.json").value
	var messages: Dictionary = JsonFile.read("res://data/localization/zh_CN.json").value
	messages["test.archive.title"] = "测试夹具标题"
	messages["test.archive.description"] = "仅用于切换回归的测试简介。"
	messages["test.archive.tag"] = "测试标签"
	Localization.install(messages, "zh_CN")
	_data(check, raw, schema, messages)
	_placeholders(check)
	await _view(check, tree, raw.stories)
	await _production(check, tree)

func _data(check: Callable, raw: Dictionary, schema: Dictionary, messages: Dictionary) -> void:
	var valid := Catalog.validate(raw, schema, messages)
	check.call(valid.ok and valid.value.size() == 1 and valid.value[0].id == "deadlight", "ARCH: one configured deadlight story")
	for mutation: String in ["unknown", "version", "duplicate", "accent", "keys", "path", "tag", "type"]:
		var bad := raw.duplicate(true)
		match mutation:
			"unknown": bad.stories[0].script = "forbidden"
			"version": bad.schema_version = 2
			"duplicate": bad.stories.append(bad.stories[0].duplicate(true))
			"accent": bad.stories[0].accent = [0.1, 0.2]
			"keys": bad.stories[0].title_key = "missing"
			"path": bad.stories[0].art_key = "res:" + "//arbitrary.gd"
			"tag": bad.stories[0].tag_keys = []
			"type": bad.stories[0].accent = [true, 0, 0]
		check.call(not Catalog.validate(bad, schema, messages).ok, "ARCH: reject " + mutation)
	var extended := raw.duplicate(true)
	var second: Dictionary = raw.stories[0].duplicate(true)
	second.id = "fixture_second"
	extended.stories.append(second)
	check.call(Catalog.validate(extended, schema, messages).ok, "ARCH: config accepts another unique story without UI code")
	var spy := Spy.new()
	var service := Service.new(valid.value, spy)
	var snapshot := service.list_stories()
	snapshot[0].id = "tampered"
	check.call(service.list_stories()[0].id == "deadlight", "ARCH: catalog snapshot deep copied")
	check.call(not service.request_start("tampered").ok and spy.calls.is_empty(), "ARCH: unknown ID never reaches launcher")
	check.call(service.request_start("deadlight").code == "STORY_START_UNAVAILABLE" and spy.calls == ["deadlight"], "ARCH: exact ID forwarded with explicit unavailable result")

func _view(check: Callable, tree: SceneTree, entries: Array) -> void:
	var multiple := entries.duplicate(true)
	for index: int in 2:
		var entry: Dictionary = entries[0].duplicate(true)
		entry.id = "fixture_%d" % index
		entry.title_key = "test.archive.title"
		entry.description_key = "test.archive.description"
		entry.tag_keys = ["test.archive.tag"]
		multiple.append(entry)
	var spy := Spy.new()
	var view := PAGE.instantiate()
	tree.root.add_child(view)
	view.configure(Service.new(multiple, spy), {})
	await tree.process_frame
	check.call(view._cards.size() == 3, "ARCH: UI renders every configured story")
	check.call(view._selected_id == "deadlight" and view._preview.current_id == "deadlight", "ARCH: default selection matches preview")
	check.call(view._preview.get_node("Missing").visible, "ARCH: missing artwork has safe localized fallback")
	check.call(view._cards[0].has_focus(), "ARCH: initial keyboard focus is first story")
	check.call(view._cards[0].get_node("Content/Title").text.contains("死光"), "ARCH: card title localized")
	view._cards[1].grab_focus()
	await tree.process_frame
	check.call(view._selected_id == "fixture_0", "ARCH: keyboard focus selects next story")
	check.call(view._enter.disabled, "ARCH: launch disabled until preview and metadata match")
	await tree.create_timer(0.55).timeout
	check.call(view._preview.get_node("Info/Title").text == "测试夹具标题", "ARCH: switch updates distinct title")
	check.call(view._preview.get_node("Info/Description/Text").text == "仅用于切换回归的测试简介。", "ARCH: switch updates distinct description")
	check.call(view._preview.get_node("Info/Tags").get_child(0).text == "测试标签", "ARCH: switch updates distinct tags")
	view._select("fixture_1")
	view._select("deadlight")
	await tree.create_timer(0.55).timeout
	check.call(view._preview.current_id == "deadlight" and not view._enter.disabled, "ARCH: rapid switches settle latest selection")
	check.call(view._preview.get_node("Info/Title").text == "死光", "ARCH: latest title synchronized")
	view._cards[1].mouse_entered.emit()
	await tree.create_timer(0.25).timeout
	check.call(view._cards[1].get_node("Shade").modulate.a > 0.99, "ARCH: hover fades highlight in")
	check.call(view._selected_id == "deadlight", "ARCH: hover alone does not replace selection")
	view._cards[1].mouse_exited.emit()
	view._cards[0].grab_focus()
	await tree.create_timer(0.25).timeout
	check.call(view._cards[1].get_node("Shade").modulate.a < 0.01, "ARCH: hover fades highlight out")
	for dimensions: Vector2 in [Vector2(1920, 1080), Vector2(1280, 720), Vector2(2560, 1080), Vector2(1280, 800)]:
		view.set_anchors_preset(Control.PRESET_TOP_LEFT)
		view.size = dimensions
		view._fit()
		var design: Control = view.get_node("%Design")
		var extent: Vector2 = design.position + design.size * design.scale
		check.call(design.position.x >= -0.01 and design.position.y >= -0.01 and extent.x <= dimensions.x + 0.01 and extent.y <= dimensions.y + 0.01, "ARCH: layout fits " + str(dimensions))
	view._start()
	view._start()
	view._return_home()
	check.call(spy.calls.is_empty(), "ARCH: launcher waits for departure animation")
	await tree.create_timer(0.8).timeout
	check.call(spy.calls == ["deadlight"], "ARCH: double press calls launcher exactly once with selected ID")
	check.call(not view._busy and not view._enter.disabled and view._design.modulate.a > 0.99, "ARCH: unavailable launch restores interactive page")
	check.call(not view.get_node("%Status").text.is_empty(), "ARCH: unavailable launch is visible, not a fake game")
	var routed: Array[String] = []
	view.route_requested.connect(func(id: String) -> void: routed.append(id))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	view._unhandled_key_input(escape)
	view._return_home()
	await tree.create_timer(0.35).timeout
	check.call(routed == ["home"], "ARCH: Escape and repeated back route only once")
	view.queue_free()
	await tree.process_frame
	var abandoned := PAGE.instantiate()
	tree.root.add_child(abandoned)
	var late := Spy.new()
	abandoned.configure(Service.new(entries, late), {})
	abandoned._start()
	tree.root.remove_child(abandoned)
	abandoned.queue_free()
	await tree.create_timer(0.55).timeout
	check.call(late.calls.is_empty(), "ARCH: exit during departure cancels launch callback")
	var switching := PAGE.instantiate()
	tree.root.add_child(switching)
	switching.configure(Service.new(multiple, Spy.new()), {})
	var stale: Array[String] = []
	switching._preview.settled.connect(func(id: String) -> void: stale.append(id))
	switching._select("fixture_0")
	tree.root.remove_child(switching)
	switching.queue_free()
	await tree.create_timer(0.55).timeout
	check.call(stale.is_empty(), "ARCH: removed preview cannot finish a stale transition")
	var empty := PAGE.instantiate()
	tree.root.add_child(empty)
	empty.configure(Service.new([], Spy.new(), "STORY_CATALOG_INVALID"), {})
	check.call(empty._enter.disabled and empty.get_node("%Empty").visible and empty._back.has_focus(), "ARCH: invalid or empty catalog is recoverable")
	empty.queue_free()
	await tree.process_frame
	var accepted := PAGE.instantiate()
	tree.root.add_child(accepted)
	var success := Spy.new()
	success.accept = true
	accepted.configure(Service.new(entries, success), {})
	accepted._start()
	await tree.create_timer(0.5).timeout
	accepted._start()
	check.call(success.calls == ["deadlight"] and accepted._busy, "ARCH: accepted launch transfers ownership without repeated dispatch")
	accepted.queue_free()
	await tree.process_frame

func _production(check: Callable, tree: SceneTree) -> void:
	var main := MAIN.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	check.call(main.boot_ready, "ARCH: production boots without network or key")
	var state_before: Dictionary = main._services.session.read_state()
	var host := main.get_node("SceneHost")
	var menu: Control = host.get_child(0)
	menu.get_node("%StartButton").pressed.emit()
	await tree.create_timer(0.6).timeout
	var archive: Control = host.get_child(0)
	check.call(archive.name == "StoryArchive" and host.get_child_count() == 1, "ARCH: real Start button reaches archive")
	check.call(archive._preview.get_node("Art").texture != null, "ARCH: production artwork bundled and resolved")
	check.call(archive._cards[0].get_node("Content/Title").text == "死光", "ARCH: card has no ordinal prefix")
	check.call(archive._cards.size() == 4, "ARCH: development composition displays three placeholders")
	archive._cards[3].grab_focus()
	await tree.create_timer(0.55).timeout
	check.call(archive._preview_only and archive._enter.disabled, "ARCH: placeholder shows but cannot launch from UI")
	check.call(archive._preview.get_node("Placeholder").visible, "ARCH: placeholder art clearly labeled")
	check.call(archive._cards[3].has_focus() and archive._cards[3].get_parent().get_parent().scroll_vertical > 0, "ARCH: keyboard scroll follows last placeholder")
	archive._select("deadlight")
	await tree.create_timer(0.55).timeout
	archive.get_node("%Enter").pressed.emit()
	await tree.create_timer(0.8).timeout
	check.call(main._services.session.read_state() == state_before, "ARCH: rejected launch does not mutate gameplay state")
	var manor: Node = host.get_child(0)
	check.call(manor.name == "ManorStructureExperience", "ARCH: main launch enters integrated manor prototype")
	check.call(host.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ARCH: scene host passes mouse events to first person")
	manor.route_requested.emit("story_archive")
	await tree.process_frame
	archive = host.get_child(0)
	await tree.create_timer(0.6).timeout
	archive.get_node("%Back").pressed.emit()
	await tree.create_timer(0.3).timeout
	var returned: Control = host.get_child(0)
	check.call(returned.name == "Home" and host.get_child_count() == 1, "ARCH: back restores one menu")
	check.call(returned.get_node("%Artwork").modulate.a == 1.0 and returned.get_node("%Menu").modulate.a == 1.0, "ARCH: return skips long menu opening animation")
	check.call(not is_instance_valid(archive), "ARCH: previous archive and effects released")
	await tree.create_timer(0.3).timeout
	returned.get_node("%StartButton").pressed.emit()
	await tree.create_timer(0.55).timeout
	check.call(host.get_child(0)._selected_id == "deadlight", "ARCH: reentry starts clean")
	main.queue_free()
	await tree.process_frame

func _placeholders(check: Callable) -> void:
	var official := ArchiveComposition.build(false)
	var preview := ArchiveComposition.build(true)
	check.call(official.service.list_stories().size() == 1, "ARCH: default composition contains no preview entries")
	check.call(preview.service.list_stories().size() == 4, "ARCH: preview entries loaded from separate config")
	var spy := Spy.new()
	var service := Service.new(preview.service.list_stories(), spy)
	for entry: Dictionary in service.list_stories():
		if entry.get("preview_only", false):
			check.call(service.request_start(entry.id).code == "STORY_PREVIEW_ONLY", "ARCH: preview entry denied by application " + entry.id)
	check.call(spy.calls.is_empty(), "ARCH: placeholder IDs never reach real launch port")
