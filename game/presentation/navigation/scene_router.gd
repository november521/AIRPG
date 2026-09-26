extends Node
## Local scene host, not a global scene tree service. Keep old scene on invalid route.
const Result = preload("res://shared/result.gd")
var _host: Node
var _routes: Dictionary = {}
var _active: Node

func configure(host: Node, routes: Dictionary) -> void:
	_host = host
	_routes = routes.duplicate()

func navigate(route_id: String) -> RefCounted:
	if not is_instance_valid(_host) or not _routes.get(route_id) is PackedScene:
		return Result.failure("ROUTE_UNAVAILABLE")
	var candidate: Node = _routes[route_id].instantiate()
	if is_instance_valid(_active):
		_host.remove_child(_active)
		_active.queue_free()
	_active = candidate
	_host.add_child(candidate)
	return Result.success(candidate)
