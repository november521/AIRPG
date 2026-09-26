extends "res://infrastructure/ai/clock_port.gd"
## Production clock backed by SceneTreeTimer. The SceneTree is injected by composition;
## this adapter never locates a tree globally.

var _tree: SceneTree = null
var _callbacks: Dictionary = {}

func _init(tree: SceneTree = null) -> void:
	_tree = tree

func schedule(delay_seconds: float, callback: Callable) -> Variant:
	if _tree == null:
		return null
	var timer := _tree.create_timer(maxf(delay_seconds, 0.001))
	timer.timeout.connect(callback, CONNECT_ONE_SHOT)
	_callbacks[timer] = callback
	return timer

func unschedule(token: Variant) -> void:
	if token == null:
		return
	var callback: Variant = _callbacks.get(token)
	if typeof(token) == TYPE_OBJECT and is_instance_valid(token):
		if callback is Callable and token.timeout.is_connected(callback):
			token.timeout.disconnect(callback)
	_callbacks.erase(token)
