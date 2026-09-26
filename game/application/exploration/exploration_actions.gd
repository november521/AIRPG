extends RefCounted
## Action names consumed by the greybox exploration slice.
## Bindings live outside this module (data/config/app.json); no key codes here.

const MOVE_LEFT: String = "move_left"
const MOVE_RIGHT: String = "move_right"
const MOVE_UP: String = "move_up"
const MOVE_DOWN: String = "move_down"
const INTERACT: String = "interact"
const INVESTIGATE: String = "investigate"

const MOVEMENT: Array[String] = [MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN]
const COMMANDS: Array[String] = [INTERACT, INVESTIGATE]
