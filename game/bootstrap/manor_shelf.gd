extends RefCounted
## The cellar shelf this round hangs, and everything that sits on it. The workshop furniture the
## delivered cellar is missing -- a tool wall, a shelf, a small box -- now exists: two boards of the
## authored shelf model are bolted to the cellar's east wall, and the five cellar pickups that used
## to hang in mid-air along the south wall rest on the boards instead. The kerosene bottle, which
## used to stand in the south-east corner, joins them. The generator is the one cellar object that
## stays on the floor.
##
## ### Which wall, and why that one
##
## The user asked for "the wall opposite the cellar stairs". Measured, not guessed:
##
##   * The stair mesh `V4_Cellar_Stair` is `x -5.890..-4.410`, `y -3.230..0.000`,
##     `z -11.500..-7.340` -- it fills the room's **west** side, and a floor ray at `x = -5.15`
##     reads `y = 0.0` over `z -12.60..-8.00` and the cellar floor `y = -3.23` over
##     `z -7.00..-6.00`, so the run descends from north (z -12.37) to south (z -6.13).
##   * Standing at the stair foot and firing at each wall: east reaches `x = -1.582`, west reaches
##     `x = -5.898`, south reaches `z = -5.90`, north is the stair itself.
##   * With the stair filling the west side, the wall across the room from it is the **east wall**,
##     `x = -1.582` (its own mesh `V4_Cellar_EastWall` runs `x -1.5820..-1.3820`,
##     `z -12.7960..-5.6960`). That is the wall the boards hang on.
##
## ### The shelf model, measured
##
## The plank is 1.707422 m long, 0.208372 m deep and 0.105379 m tall, its usable top face is at local
## `y = +0.016030` over the footprint `x -0.853711..0.853711, z 0..0.208372`, and its origin is on its
## own back edge. A quarter turn about y carries its long axis onto the room's north-south line and
## its local `+z` onto the room's `+x`, so the board runs from the wall into the room with its root on
## the wall face.
const Model = preload("res://items/models/single_wood_shelf.glb")
const SHELF_YAW: float = -PI / 2
## The east wall's drawn face -- and its collision's, measured ray by ray -- is the plane at
## x = -1.581979, and **the room is the side with the smaller x**: the wall mesh itself occupies
## x -1.5820..-1.3820, which is outside the room. The unit therefore hangs on that face with its
## board running from the face into the room.
const SHELF_WALL_X: float = -1.5820
const SHELF_CENTRE_Z: float = -9.250
## Board length, depth and standing-surface height. The authored plank is 0.208372 m deep. That is
## measurably too shallow for the kerosene bottle: its own aim volume is a 0.28 m frame, and for that
## frame to clear the wall's plane at x = -1.581979 while the bottle's 0.235 m body still stands on
## the board, the board has to be at least 0.258 m deep. Rotating the bottle cannot help -- measured,
## its cross-section is 0.2352 x 0.2352 m, a square -- so the board is stretched along its depth only
## by 1.35x. Length and thickness stay the authored ones. This is a deliberate, minimal stretch and
## reads as a deeper utility plank rather than as a distorted model; the scene tests re-measure all
## three dimensions, so a re-export cannot quietly move what the props stand on.
const BOARD_WIDTH: float = 1.707422
const BOARD_DEPTH: float = 0.281302
const BOARD_DEPTH_SCALE: float = BOARD_DEPTH / 0.208372
## The lower tier's root height, the height of the surface a prop actually stands on in each tier
## (the root lifted by the board's own measured top face), and how many tiers there are.
const TIER_ONE_Y: float = -2.07
const TIER_TWO_Y: float = -1.63
const BOARD_TOP: float = 0.016030
const SURFACE_ONE: float = TIER_ONE_Y + BOARD_TOP
const SURFACE_TWO: float = TIER_TWO_Y + BOARD_TOP
const TIER_COUNT: int = 2
## What each prop has to be lifted by so its own lowest vertex lands on the board. Each prop's world
## scene puts its origin somewhere inside its own geometry, so the offset is measured off the placed
## object rather than assumed: the lantern's scene already stands its base on its origin and needs no
## lift, the bottle's lowest vertex sits 1.1 mm above its origin and the fuse's 3.5 mm above it. The
## wrench carries a 2.47x scale of its own, and it is turned a quarter turn about x to lie down on the
## board, which leaves its lowest vertex 0.1515 below its origin.
const LANTERN_LIFT: float = 0.000000
const KEROSENE_LIFT: float = -0.001058
const FUSE_LIFT: float = -0.003474
const WRENCH_LIFT: float = 0.151549
const WRENCH_PITCH: float = -PI / 2
## How far into the room each prop stands. This one number is a two-sided squeeze: a prop's own aim
## volume reaches 0.14 m behind its centre (the kerosene bottle's frame is the widest), so the centre
## has to stand at least that far plus a margin in front of the wall's plane at x = -1.581979; and the
## prop's own body has to stay on the board's top face. At -1.735 the bottle's frame ends 0.018 m
## clear of the wall and its body ends 0.005 m inside the board's back edge, which are the two
## clearances the scene tests pin down.
const SHELF_PROP_X: float = -1.7350
const SHELF_BOTTLE_X: float = -1.7400
## Along the wall. The aim ray cannot see one prop through another, so each tier's props are spread
## apart and the two tiers do not share a line of sight: a prop on the upper board would be looked at
## through the lower board's props if the two stood at the same place along the wall.
const COPPER_WIRE_COIL_POSITION := Vector3(SHELF_PROP_X, SURFACE_ONE, -8.70)
const LANTERN_POSITION := Vector3(SHELF_PROP_X, SURFACE_ONE + LANTERN_LIFT, -9.40)
const KEROSENE_BOTTLE_POSITION := Vector3(SHELF_BOTTLE_X, SURFACE_ONE + KEROSENE_LIFT, -10.00)
const ELECTRICAL_TAPE_POSITION := Vector3(SHELF_PROP_X, SURFACE_TWO, -8.55)
const FUSE_POSITION := Vector3(SHELF_PROP_X, SURFACE_TWO + FUSE_LIFT, -8.95)
const WRENCH_POSITION := Vector3(SHELF_PROP_X, SURFACE_TWO + WRENCH_LIFT, -9.70)

## The height of one tier's standing surface, written once as data and once as a lookup so the prop
## positions above and the checks below cannot drift apart.
static func tier_top(tier: int) -> float:
	return SURFACE_ONE if tier == 0 else SURFACE_TWO

## The two boards. Each is one instance of the authored plank, stood on the wall face and lifted to
## its own tier height. A board carries no handler and no ray target: a shelf is scenery, and the
## props standing on it stay the only things the aim ray can find.
static func place(world: Node3D) -> Array[Node3D]:
	var placed: Array[Node3D] = []
	for tier: int in TIER_COUNT:
		var board: Node3D = Model.instantiate()
		board.name = "manor_shelf_board_%d" % (tier + 1)
		board.rotation.y = SHELF_YAW
		board.scale = Vector3(1.0, 1.0, BOARD_DEPTH_SCALE)
		board.position = Vector3(SHELF_WALL_X, TIER_ONE_Y if tier == 0 else TIER_TWO_Y,
			SHELF_CENTRE_Z)
		world.add_child(board)
		placed.append(board)
	return placed

## One tier's standing surface as a box in world space: its top face, its run along the wall and its
## depth into the room. The board's back edge hangs on the wall at x = SHELF_WALL_X and its depth runs
## towards smaller x, so that is the corner the box starts from. A caller can check that a prop's own
## footprint really rests on it instead of hovering near it.
static func tier_surface(tier: int) -> AABB:
	return AABB(Vector3(SHELF_WALL_X - BOARD_DEPTH, tier_top(tier), SHELF_CENTRE_Z - BOARD_WIDTH * 0.5),
		Vector3(BOARD_DEPTH, 0.0, BOARD_WIDTH))
