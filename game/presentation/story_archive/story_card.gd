extends Button
signal chosen(story_id: String)
var story_id: String = ""
var _selected: bool = false
var _hovered: bool = false
var _glow: Tween

func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(story_id))
	focus_entered.connect(_focused)
	focus_exited.connect(_refresh)
	mouse_entered.connect(func() -> void: _hovered = true; _refresh())
	mouse_exited.connect(func() -> void: _hovered = false; _refresh())

func configure(story: Dictionary, artwork: Texture2D) -> void:
	story_id = story.id
	$Content/Cover.texture = artwork
	$Content/Cover/Placeholder.visible = story.get("preview_only", false)
	$Content/Title.present(story.title_key)
	$Content/Tags.present(story.tag_keys)
	tooltip_text = tr(story.title_key)

func set_selected(value: bool) -> void:
	_selected = value
	_refresh()

func _focused() -> void:
	chosen.emit(story_id)
	_refresh()

func _refresh() -> void:
	if not is_inside_tree():
		return
	if _glow != null:
		_glow.kill()
	_glow = create_tween().set_parallel(true)
	_glow.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_glow.tween_property($Marker, "modulate:a", 1.0 if _selected else 0.0, 0.22)
	_glow.tween_property($Shade, "modulate:a", 1.0 if _selected or _hovered or has_focus() else 0.0, 0.22)
	_glow.tween_property($Content/Cover, "modulate", Color.WHITE if _selected or _hovered else Color(0.72, 0.72, 0.72), 0.22)

func _exit_tree() -> void:
	if _glow != null:
		_glow.kill()
