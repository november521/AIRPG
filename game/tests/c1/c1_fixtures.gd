extends RefCounted
## Synthetic fixtures for the C1 suite. Never shipped as story content.
## The occlusion wall sits between the spawn and the ranged target on purpose.

const UseCase = preload("res://application/exploration/exploration_use_case.gd")
const RecordingSink = preload("res://tests/c1/c1_recording_sink.gd")

const COOLDOWN: float = 2.0

static func recording_sink() -> RecordingSink:
	return RecordingSink.new()

static func build(layout: Variant, sink: RefCounted, cooldown: float = COOLDOWN) -> RefCounted:
	return UseCase.create(layout, sink, cooldown)

static func corridor_layout() -> Dictionary:
	return {
		"player": {"spawn": Vector2(200, 300), "half_extents": Vector2(10, 10),
			"speed": 100.0},
		"walls": [Rect2(0, 0, 20, 580), Rect2(300, 0, 20, 580),
			Rect2(0, 0, 320, 20), Rect2(0, 560, 320, 20)],
		"interactables": [],
	}

static func lab_layout() -> Dictionary:
	return {
		"player": {"spawn": Vector2(200, 500), "half_extents": Vector2(10, 10),
			"speed": 100.0},
		"walls": [Rect2(300, 0, 20, 400)],
		"interactables": [
			{"target_id": "test.crate", "prompt_key": "exploration.prompt.inspect",
				"position": Vector2(200, 300), "radius": 100.0,
				"solid_half_extents": Vector2(10, 10), "blocks_sight": true},
			{"target_id": "test.npc", "prompt_key": "exploration.prompt.talk",
				"position": Vector2(500, 300), "radius": 150.0,
				"solid_half_extents": Vector2(10, 10), "blocks_sight": false},
		],
	}

static func occlusion_layout(spawn: Vector2) -> Dictionary:
	return {
		"player": {"spawn": spawn, "half_extents": Vector2(10, 10), "speed": 100.0},
		"walls": [Rect2(280, 200, 20, 200)],
		"interactables": [
			{"target_id": "test.npc", "prompt_key": "exploration.prompt.talk",
				"position": Vector2(400, 300), "radius": 250.0,
				"solid_half_extents": Vector2(10, 10), "blocks_sight": false},
			{"target_id": "test.crate", "prompt_key": "exploration.prompt.inspect",
				"position": Vector2(200, 420), "radius": 150.0,
				"solid_half_extents": Vector2(10, 10), "blocks_sight": true},
		],
	}

static func tie_layout() -> Dictionary:
	return {
		"player": {"spawn": Vector2(200, 300), "half_extents": Vector2(10, 10),
			"speed": 100.0},
		"walls": [],
		"interactables": [
			{"target_id": "test.beta", "prompt_key": "exploration.prompt.inspect",
				"position": Vector2(200, 400), "radius": 200.0},
			{"target_id": "test.alpha", "prompt_key": "exploration.prompt.inspect",
				"position": Vector2(200, 200), "radius": 200.0},
		],
	}

static func view_layout() -> Dictionary:
	return {
		"player": {"spawn": Vector2(200, 500), "half_extents": Vector2(10, 10),
			"speed": 100.0},
		"walls": [Rect2(0, 0, 20, 600)],
		"interactables": [
			{"target_id": "test.crate", "prompt_key": "exploration.prompt.inspect",
				"position": Vector2(200, 420), "radius": 100.0,
				"solid_half_extents": Vector2(10, 10), "blocks_sight": true},
		],
	}
