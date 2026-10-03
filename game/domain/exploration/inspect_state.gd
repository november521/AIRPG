extends RefCounted
## Local state for a fixed scene object that can be looked at, held up and put back. Same shape as
## DeviceState: one stable revision per accepted change, no gameplay effect beyond the object
## itself. The stage wraps from the last stage back to the floor, so the object never leaves the
## world and never needs an inventory entry.
##
## Two cycles live in one object, and neither is hard-coded to three stages. The full cycle runs
## floor -> ... -> last stage -> floor; its last stage is where the object hands its carried content
## over. The shortened cycle is entered only through empty_out(), and an object may name a different
## hand window for it: the diary is held from its very first page once there is nothing left to give.
##
## `held` is the one derived flag presentation reads. While it is true the object owns the player's
## action and is drawn in the hand socket instead of its slot in the world, so the way out of the
## observation never depends on the aim ray landing on it again.
const Result = preload("res://shared/result.gd")
const STAGE_FLOOR: int = 0
const STAGE_READ: int = 1
const STAGE_HELD: int = 2
const STAGE_COUNT: int = 3
const EMPTY_STAGE_COUNT: int = 2
var _stage_count: int = STAGE_COUNT
var _empty_stage_count: int = EMPTY_STAGE_COUNT
var _held_from: int = STAGE_HELD
var _empty_held_from: int = STAGE_HELD
var _stage: int = STAGE_FLOOR
var _revision: int = 0
var _emptied: bool = false

## The defaults reproduce the original three-stage observation object exactly. `held_from` and
## `empty_held_from` are stage indices, not counts: a stage at or past them is out of the world.
func _init(stage_count: int = STAGE_COUNT, empty_stage_count: int = EMPTY_STAGE_COUNT,
		held_from: int = STAGE_HELD, empty_held_from: int = STAGE_HELD) -> void:
	_stage_count = maxi(stage_count, 1)
	_empty_stage_count = maxi(empty_stage_count, 1)
	_held_from = held_from
	_empty_held_from = empty_held_from

func snapshot() -> Dictionary:
	return {"stage": _stage, "revision": _revision, "emptied": _emptied, "held": held()}

## True when the caller holds the revision this state is currently at. The handler checks this
## before it touches anything else, so a stale interaction cannot half-commit.
func accepts(expected_revision: int) -> bool:
	return expected_revision == _revision

## True while the object is out of the world: in the player's hand and owning the interact key.
func held() -> bool:
	return _stage >= (_empty_held_from if _emptied else _held_from)

## True at the stage that hands the carried content over. The shortened cycle is always shorter than
## that stage, so an emptied object can never hand anything over twice.
func hands_over() -> bool:
	return _stage == _stage_count - 1

func advance(expected_revision: int) -> Result:
	if not accepts(expected_revision):
		return Result.failure("STALE_STATE")
	_stage = (_stage + 1) % (_empty_stage_count if _emptied else _stage_count)
	_revision += 1
	return Result.success(snapshot())

## Marks the object as emptied and puts it straight back on the floor. This is its own accepted
## change -- the object gave up what it carried -- and it is the only way into the shortened cycle,
## so the wrap-around never has to guess why the stage count changed.
func empty_out(expected_revision: int) -> Result:
	if not accepts(expected_revision):
		return Result.failure("STALE_STATE")
	_emptied = true
	_stage = STAGE_FLOOR
	_revision += 1
	return Result.success(snapshot())
