extends RefCounted
const World = preload("res://presentation/manor/world.tscn")
const Preview = preload("res://bootstrap/npc_preview.gd")
const Actor = preload("res://presentation/manor/npc_actor.gd")
var checks: int = 0
var failures: int = 0
var _verify: Callable
var _tree: SceneTree

func _check(condition: bool, message: String) -> void:
	checks += 1
	_verify.call(condition, message)
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _frames(count: int) -> void:
	for index: int in count:
		await _tree.physics_frame

func run(verify: Callable, tree: SceneTree) -> void:
	_verify = verify
	_tree = tree
	var world: Node3D = World.instantiate()
	_tree.root.add_child(world)
	var presence = Preview.build()
	var roster: Array[Dictionary] = presence.roster()
	var actor = Actor.new()
	_check(actor.configure(presence, roster[0]), "rigged actor accepts validated preview asset")
	world.add_child(actor)
	await _frames(4)
	var skeleton := actor.get_node_or_null("NpcVisual/PreviewHumanoid/Skeleton3D") as Skeleton3D
	var body := actor.get_node_or_null("NpcVisual/PreviewHumanoid/Skeleton3D/PreviewBody") as MeshInstance3D
	_check(actor.visual_ready() and skeleton != null and skeleton.get_bone_count() == 17, "skinned humanoid has 17 bones")
	_check(body != null and body.skin != null, "visible mesh is bound to skeleton")
	_check(actor.current_clip() == "idle", "stationary actor breathes in idle")
	var start: Vector3 = actor.position
	actor._target = start + Vector3(0.7, 0, 0)
	actor._wait = 0
	await _frames(20)
	_check(actor.position.distance_to(start) > 0.1 and actor.current_clip() == "walk", "physical travel drives walk clip")
	var heading: float = actor.rotation.y
	_check(absf(angle_difference(heading, PI / 2)) < 0.7, "model turns toward physical travel")
	_check(presence.begin_greeting(actor.npc_id, 1.0, true).ok, "valid greeting starts")
	actor.set_greeting_target(actor.global_position + Vector3(0, 0, 2))
	var paused: Vector3 = actor.position
	await _frames(20)
	_check(actor.current_clip() == "talk" and actor._animation.current_animation == "talk", "greeting drives talk clip")
	_check(actor.position.distance_to(paused) < 0.03, "speaker does not slide during talk")
	_check(absf(angle_difference(actor.rotation.y, 0)) < absf(angle_difference(heading, 0)), "speaker faces player")
	var head_index: int = skeleton.find_bone("Head")
	_check(head_index >= 0 and skeleton.get_bone_pose_rotation(head_index).get_angle() > 0.01, "talk animation drives head bone")
	presence.end_greeting()
	actor.clear_greeting_target()
	actor._target = actor.position
	actor._wait = 1.0
	await _frames(3)
	_check(actor.current_clip() == "idle", "closing greeting returns to idle")
	world.queue_free()
	await _tree.process_frame
	print("AIRPG_NPC_RIG_SUITE: %d checks, %d failures" % [checks, failures])
