extends RefCounted
## How far the player has walked since the last footstep, and nothing else: it turns a per-frame
## distance into "how many steps have landed since I was last asked". Kept out of the scene so the
## cadence can be checked without a player, a floor or a room.
##
## A teleport is not a walk. The manor's shortcuts (back to the side entry, down to the cellar) move
## the body metres in one frame, and so does every test that repositions the player; without the
## guard each of those would fire a burst of footsteps.
const STRIDE: float = 0.78
const TELEPORT: float = 2.0
var _walked: float = 0.0

## Records how far the body moved this frame and answers how many steps it has now earned. A
## distance that is not a finite number, is negative, or is longer than any stride the body could
## have walked in one frame is discarded and clears the accumulator.
func advance(distance: float) -> int:
	if not is_finite(distance) or distance < 0.0 or distance > TELEPORT:
		_walked = 0.0
		return 0
	_walked += distance
	var steps: int = int(_walked / STRIDE)
	_walked -= float(steps) * STRIDE
	return steps

func reset() -> void:
	_walked = 0.0
