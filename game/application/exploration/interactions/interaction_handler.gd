extends RefCounted
## Per-target use case. Register implementations at bootstrap, never in a global bus.
const Outcome = preload("res://shared/result.gd")
signal changed()

func read() -> Dictionary:
	return {"available": false}

func execute(_expected_revision: int) -> Outcome:
	return Outcome.failure("INTERACTION_UNAVAILABLE")

func dispose() -> void:
	pass

## The line this target wants the scene's caption layer to be showing right now, or "" for nothing.
## This is deliberately not `read()["caption_key"]`: that field is what the prompt advertises as
## available, while this is what has actually been *said*. The difference matters because a target
## is refreshed by every change its inventory port reports -- including changes another object
## caused -- and a refresh must never be mistaken for the player being told something. Default: a
## target never speaks on its own.
func narration() -> String:
	return ""

## True while this target owns the player's action: movement is frozen, the view keeps turning, and
## the interact key applies to this target directly instead of being resolved by the aim ray. It
## exists so an object held up for inspection can always be put back, whatever the player happens
## to be looking at. Default: no target is exclusive.
func exclusive() -> bool:
	return false

