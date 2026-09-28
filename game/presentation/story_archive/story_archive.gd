extends Control
const Service = preload("res://application/story_archive/story_archive_service.gd")
const Card = preload("res://presentation/story_archive/story_card.gd")
const CARD = preload("res://presentation/story_archive/story_card.tscn")
const Preview = preload("res://presentation/story_archive/story_preview.gd")
signal route_requested(route_id: String)
var _service: Service
var _art: Dictionary = {}
var _stories: Array = []
var _cards: Array[Card] = []
var _selected_id: String = ""
var _busy: bool = false
var _ready_to_start: bool = false
var _preview_only: bool = false
var _transition: Tween
@onready var _design: Control = %Design
@onready var _preview: Preview = %Preview
@onready var _enter: Button = %Enter
@onready var _back: Button = %Back

func _ready() -> void:
	resized.connect(_fit)
	_fit()
	_enter.pressed.connect(_start)
	_back.pressed.connect(_return_home)
	_preview.settled.connect(_preview_settled)
	_design.modulate.a = 0.0
	_transition = create_tween()
	_transition.tween_property(_design, "modulate:a", 1.0, 0.25)

func configure(service: Service, artwork: Dictionary) -> void:
	if _service != null:
		return
	_service = service
	_art = artwork.duplicate()
	_stories = service.list_stories()
	var has_previews: bool = _stories.any(func(story: Dictionary) -> bool: return story.get("preview_only", false))
	%Count.text = tr("archive.preview_count" if has_previews else "archive.count").format({"count": _stories.size()})
	for story: Dictionary in _stories:
		var card: Card = CARD.instantiate()
		%List.add_child(card)
		card.configure(story, _art.get(story.art_key) as Texture2D)
		card.chosen.connect(_select)
		_cards.append(card)
	_link_focus()
	if _stories.is_empty():
		%Empty.text = tr("archive.empty" if service.catalog_error().is_empty() else "archive.unavailable")
		%Empty.show()
		_enter.disabled = true
		_preview.hide()
		_back.grab_focus()
	else:
		_select(_stories[0].id, true)
		_cards[0].grab_focus()

func _select(story_id: String, immediate: bool = false) -> void:
	if _busy or not is_inside_tree() or story_id == _selected_id:
		return
	for story: Dictionary in _stories:
		if story.id != story_id:
			continue
		_selected_id = story_id
		_preview_only = story.get("preview_only", false)
		_ready_to_start = false
		_enter.disabled = true
		%Status.text = tr("archive.preview_notice") if _preview_only else ""
		_enter.text = tr("archive.preview_only" if _preview_only else "archive.enter")
		for card: Card in _cards:
			card.set_selected(card.story_id == story_id)
		_preview.show_story(story, _art.get(story.art_key) as Texture2D, immediate)
		return

func _preview_settled(story_id: String) -> void:
	if not _busy and story_id == _selected_id:
		_ready_to_start = not _preview_only
		_enter.disabled = _preview_only
		_link_focus()

func _start() -> void:
	if _busy or not _ready_to_start or _service == null or not is_inside_tree():
		return
	_lock()
	var requested_id := _selected_id
	_transition = create_tween()
	_transition.tween_property(_enter, "modulate", Color(0.78, 0.72, 0.58), 0.08)
	_transition.tween_property(_design, "modulate:a", 0.0, 0.32)
	_transition.tween_callback(_dispatch.bind(requested_id))

func _dispatch(story_id: String) -> void:
	if not is_inside_tree():
		return
	var result := _service.request_start(story_id)
	if result.ok:
		return # The injected launcher owns the accepted flow; do not create a fake game here.
	%Status.text = tr("archive.start_unavailable" if result.code == "STORY_START_UNAVAILABLE" else "archive.start_failed")
	_enter.modulate = Color.WHITE
	_transition = create_tween()
	_transition.tween_property(_design, "modulate:a", 1.0, 0.25)
	_transition.tween_callback(_unlock)

func _unlock() -> void:
	if not is_inside_tree():
		return
	_busy = false
	_back.disabled = false
	_enter.disabled = not _ready_to_start
	for card: Card in _cards:
		card.disabled = false
	_enter.grab_focus()

func _return_home() -> void:
	if _busy or not is_inside_tree():
		return
	_lock()
	_transition = create_tween()
	_transition.tween_property(_design, "modulate:a", 0.0, 0.25)
	_transition.tween_callback(func() -> void:
		if is_inside_tree():
			route_requested.emit("home"))

func _lock() -> void:
	_busy = true
	if _transition != null:
		_transition.kill()
	_back.disabled = true
	_enter.disabled = true
	for card: Card in _cards:
		card.disabled = true

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		_return_home()
		get_viewport().set_input_as_handled()

func _fit() -> void:
	var factor := minf(size.x / _design.size.x, size.y / _design.size.y)
	_design.scale = Vector2.ONE * factor
	_design.position = (size - _design.size * factor) * 0.5

func _link_focus() -> void:
	var controls: Array[Control] = []
	for card: Card in _cards:
		controls.append(card)
	if not _enter.disabled:
		controls.append(_enter)
	controls.append(_back)
	for index: int in controls.size():
		var item: Control = controls[index]
		var previous: Control = controls[posmod(index - 1, controls.size())]
		var following: Control = controls[(index + 1) % controls.size()]
		item.focus_neighbor_top = item.get_path_to(previous)
		item.focus_neighbor_bottom = item.get_path_to(following)
		item.focus_previous = item.get_path_to(previous)
		item.focus_next = item.get_path_to(following)
		item.focus_neighbor_right = item.get_path_to(_enter if item != _enter and not _enter.disabled else _back)
		item.focus_neighbor_left = item.get_path_to(_cards[0] if not _cards.is_empty() else _back)

func _exit_tree() -> void:
	_busy = true
	if _transition != null:
		_transition.kill()
