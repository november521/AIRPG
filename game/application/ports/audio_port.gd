extends RefCounted
## Semantic audio contract. Callers name a game event -- "the notebook opened", "the generator is
## running" -- and never a bus, a file or an engine player: the adapter resolves every kind through
## its own table, so a re-encode that renames a file touches the adapter alone.
##
## Every method here is silent by default. A scene that was never handed a port therefore has no
## sound rather than a missing dependency, which is what lets the manor be built in a test, in a
## headless run or in a still-life capture with nothing wired at all.
##
## The families, and the split is the whole point:
##   `ui.*` / `menu.*` -- non-positional interface feedback. `menu.*` is deliberately a separate bank:
##       the main menu is synthetic and neutral and must never borrow the manor's wood and metal.
##   `sfx.*` -- one-shots that happen somewhere in the world, played through a spatial player.
##   `loop.*` -- continuous sources. `attach_loop` names the node a 3D source belongs on (the
##       generator's casing, the radio's case), because the sound has to move with the machine it
##       comes out of; `set_ambience` then switches that source on and off.

## Interface feedback, non-positional.
const UI_CLICK := "ui.click"
const UI_CONFIRM := "ui.confirm"
const UI_CANCEL := "ui.cancel"
const UI_SWITCH := "ui.switch"
## Menu buttons, non-positional. Separate from the interface bank on purpose.
const MENU_START := "menu.start"
const MENU_CLICK := "menu.click"
const MENU_BACK := "menu.back"
## One-shots that happen at a place in the world.
const PICKUP := "sfx.pickup"
const PUT := "sfx.put"
const DOOR_OPEN := "sfx.door_open"
const DOOR_CLOSE := "sfx.door_close"
const LOCK_OPEN := "sfx.lock_open"
const LOCK_CLOSE := "sfx.lock_close"
const PRY_WOOD := "sfx.pry_wood"
const PRY_METAL := "sfx.pry_metal"
const POUR_KEROSENE := "sfx.pour_kerosene"
const GENERATOR_CRANK := "sfx.generator_crank"
## Footsteps are asked for by the surface under the player, never by a sample name: the pool and the
## pitch jitter are the adapter's business.
const FOOTSTEP_WOOD := "sfx.footstep_wood"
const FOOTSTEP_STONE := "sfx.footstep_stone"
const FOOTSTEP_WET := "sfx.footstep_wet"
## Continuous sources.
const GENERATOR_LOOP := "loop.generator"
const RADIO_STATIC := "loop.radio_static"
## Music tiers. Only the first is reached this round; the contract exists so a later blackout or
## finale is one call rather than a new port.
const MUSIC_DREAD_LOW := "dread_low"
const MUSIC_BLACKOUT := "blackout"
const MUSIC_FINALE := "finale"

func play_ui(_kind: String) -> void:
	pass

## `position` is world space. A kind the adapter maps as non-positional ignores it.
func play_sfx(_kind: String, _position: Vector3) -> void:
	pass

func set_music(_tier: String) -> void:
	pass

## Switches a continuous source on or off. A kind whose host is 3D plays where `attach_loop` put it;
## any other kind is a non-positional bed. Idempotent: asking for the state a source is already in
## changes nothing, so a view may call this from every refresh.
func set_ambience(_kind: String, _on: bool) -> void:
	pass

## Binds a 3D loop to the node it belongs on. Called by whoever owns that node -- the port builds no
## scene nodes of its own, so it can be swapped for a recording double in a test.
func attach_loop(_kind: String, _host: Node) -> void:
	pass
