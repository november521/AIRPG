extends RefCounted
## Synthetic greybox layout for the C1 scene. It contains no Dead Light characters,
## scenes, clues or dialogue; every ID is an explicit test placeholder.
## Interaction radii, speed and cooldown are greybox placeholders pending product
## confirmation and must not be treated as final balance values.

const CRATE_TARGET_ID: String = "greybox.crate"
const NPC_TARGET_ID: String = "greybox.npc"
const CRATE_PROMPT_KEY: String = "exploration.prompt.inspect"
const NPC_PROMPT_KEY: String = "exploration.prompt.talk"

const ROOM_SIZE: Vector2 = Vector2(1600.0, 900.0)
const WALL_THICKNESS: float = 40.0
const PLAYER_HALF_EXTENTS: Vector2 = Vector2(16.0, 16.0)
const PLAYER_SPEED: float = 240.0
const INVESTIGATE_COOLDOWN_SECONDS: float = 3.0

static func default_layout() -> Dictionary:
	return {
		"player": {"spawn": Vector2(800, 650), "half_extents": PLAYER_HALF_EXTENTS,
			"speed": PLAYER_SPEED},
		"walls": [
			Rect2(0, 0, ROOM_SIZE.x, WALL_THICKNESS),
			Rect2(0, ROOM_SIZE.y - WALL_THICKNESS, ROOM_SIZE.x, WALL_THICKNESS),
			Rect2(0, 0, WALL_THICKNESS, ROOM_SIZE.y),
			Rect2(ROOM_SIZE.x - WALL_THICKNESS, 0, WALL_THICKNESS, ROOM_SIZE.y),
			Rect2(300, 200, WALL_THICKNESS, 400),
		],
		"interactables": [
			{"target_id": CRATE_TARGET_ID, "prompt_key": CRATE_PROMPT_KEY,
				"position": Vector2(180, 300), "radius": 96.0,
				"solid_half_extents": Vector2(24, 24), "blocks_sight": true},
			{"target_id": NPC_TARGET_ID, "prompt_key": NPC_PROMPT_KEY,
				"position": Vector2(1200, 300), "radius": 72.0,
				"solid_half_extents": Vector2(16, 16), "blocks_sight": false},
		],
	}
