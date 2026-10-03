extends RefCounted
## Which footstep bank the floor under the player belongs to.
##
## The delivered manor walks on a single collision body (`ManorWalkCollision`): every room floor, the
## cellar and the veranda are one shape, so a ray hit cannot name a material. What the ray *can* prove
## is that there is a surface within a step of the feet at all, which is what keeps footsteps out of
## the air over an opened stairwell; the material itself comes from the room the player is standing
## in, because that is the only distinction the delivered model actually carries.
##
## The mapping is a table, not a guess:
##   cellar / cellar stairs / bathroom -- stone. The cellar floor and its ramp are the model's bare
##       stone and the bathroom is tiled.
##   the veranda (the room map calls it the porch) -- wet. It is the only walkable surface outside
##       the front door and it is exposed to the same rain the story opens in. `outside` maps there
##       too, and a ray that finds no floor at all returns nothing, which is what falling off the
##       veranda should sound like.
##   every interior room -- wood: the ground floor is the model's boarded subfloor and the studies and
##       bedrooms are its oak and walnut floors.
const PORT = preload("res://application/ports/audio_port.gd")
## How far below the feet a surface may be and still count as being stood on.
const REACH: float = 1.2
## The ray starts this far above the feet: the body's origin is its centre, so a ray from exactly
## there begins inside the capsule and can miss the floor the body is standing on.
const LIFT: float = 0.35
const MATERIAL_BY_ROOM: Dictionary = {
	"cellar": "stone", "cellar_stairs": "stone", "bathroom": "stone",
	"porch": "wet", "outside": "wet",
	"reception": "wood", "kitchen": "wood", "hall": "wood",
	"doctor_bedroom": "wood", "doctor_study": "wood",
	"emilia_bedroom": "wood", "emilia_study": "wood",
}
## A room this build has never heard of is treated as the manor's stone rather than going silent: a
## missing footstep is a bug the player hears, while the wrong bank is a nuance they do not.
const DEFAULT_MATERIAL: String = "stone"
## The library resolves kinds to files; this table only turns a surface into the kind that names it.
## Built here rather than as a constant because the port's constants are read at run time.
var _kind_by_material: Dictionary = {
	"stone": PORT.FOOTSTEP_STONE,
	"wood": PORT.FOOTSTEP_WOOD,
	"wet": PORT.FOOTSTEP_WET,
}

## The bank a room's floor is heard as, without touching physics. Exposed so the mapping can be
## checked as the table it is.
func material_for(room_id: String) -> String:
	return String(MATERIAL_BY_ROOM.get(room_id, DEFAULT_MATERIAL))

## The footstep kind for one frame of walking, or "" when there is no floor under `point` within a
## step. `ignore` is the walking body's own RID, so the probe never stands on the player.
func footstep_kind(state: PhysicsDirectSpaceState3D, point: Vector3, room_id: String,
		ignore: Array[RID] = []) -> String:
	if state == null or not point.is_finite():
		return ""
	var query := PhysicsRayQueryParameters3D.create(point + Vector3(0.0, LIFT, 0.0),
		point - Vector3(0.0, REACH, 0.0))
	if not ignore.is_empty():
		query.exclude = ignore
	if state.intersect_ray(query).is_empty():
		return ""
	return String(_kind_by_material.get(material_for(room_id), ""))
