extends RefCounted
## Physics adapter owns geometry; application owns whether a change is committed.
func is_clear(_from_open: bool, _to_open: bool) -> bool:
	return false

func is_clear_pose(from_open: bool, to_open: bool, _from_yaw: float, _to_yaw: float) -> bool:
	return is_clear(from_open, to_open)
