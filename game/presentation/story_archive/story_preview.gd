extends Control
signal settled(story_id: String)
var current_id: String = ""
var _transition: Tween
var _revision: int = 0

func show_story(story: Dictionary, artwork: Texture2D, immediate: bool = false) -> void:
	_revision += 1
	var revision := _revision
	if _transition != null:
		_transition.kill()
	if immediate:
		_apply(story, artwork)
		modulate.a = 1.0
		settled.emit(current_id)
		return
	_transition = create_tween()
	_transition.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.tween_property(self, "modulate:a", 0.0, 0.22)
	_transition.tween_callback(func() -> void:
		if revision == _revision and is_inside_tree():
			_apply(story, artwork))
	_transition.tween_property(self, "modulate:a", 1.0, 0.23)
	_transition.tween_callback(func() -> void:
		if revision == _revision and is_inside_tree():
			settled.emit(current_id))

func _apply(story: Dictionary, artwork: Texture2D) -> void:
	current_id = story.id
	$Art.texture = artwork
	$Missing.visible = artwork == null
	$Placeholder.visible = story.get("preview_only", false)
	$Info.present(story)

func _exit_tree() -> void:
	_revision += 1
	if _transition != null:
		_transition.kill()
