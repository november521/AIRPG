extends "res://infrastructure/audio/godot_audio.gd"
## An audio adapter that records its decisions instead of opening an audio device.
##
## Only the one method that would create a player is overridden, so everything else is the real
## adapter: the same library, the same bus names, the same pool choice and pitch jitter, the same
## loop binding and the same fades. A scene driven with this attached is therefore checked against
## the production routing while the run stays silent and device-free.
var events: Array[Dictionary] = []

## The one seam the production path uses to make sound. Recording here keeps every decision the
## mixer made -- which take, on which bus, where, and how far it was detuned.
func emit_oneshot(kind: String, stream: AudioStream, entry: Dictionary, position: Vector3,
		pitch: float, spatial: bool) -> void:
	events.append({"event": "sound", "kind": kind, "bus": String(entry.bus),
		"file": stream.resource_path.get_file(), "position": position, "pitch": pitch,
		"spatial": spatial})

func set_music(tier: String) -> void:
	events.append({"event": "music", "kind": tier})
	super.set_music(tier)

func set_ambience(kind: String, on: bool) -> void:
	events.append({"event": "ambience", "kind": kind, "on": on})
	super.set_ambience(kind, on)

func attach_loop(kind: String, host: Node) -> void:
	events.append({"event": "attach", "kind": kind})
	super.attach_loop(kind, host)

func clear() -> void:
	events.clear()

func sounds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in events:
		if entry.event == "sound":
			out.append(entry)
	return out

func kinds() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in sounds():
		out.append(String(entry.kind))
	return out

func has_sound(kind: String) -> bool:
	return count_sounds(kind) > 0

func count_sounds(kind: String) -> int:
	var total: int = 0
	for entry: Dictionary in sounds():
		if entry.kind == kind:
			total += 1
	return total

## Every recorded kind that begins with `prefix`, so a caller can ask for a family ("sfx.footstep")
## without naming each member.
func kinds_starting_with(prefix: String) -> Array[String]:
	var out: Array[String] = []
	for kind: String in kinds():
		if kind.begins_with(prefix):
			out.append(kind)
	return out

func files_for(kind: String) -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in sounds():
		if entry.kind == kind:
			out.append(String(entry.file))
	return out

func pitches_for(kind: String) -> Array[float]:
	var out: Array[float] = []
	for entry: Dictionary in sounds():
		if entry.kind == kind:
			out.append(float(entry.pitch))
	return out

func bus_for(kind: String) -> String:
	for entry: Dictionary in sounds():
		if entry.kind == kind:
			return String(entry.bus)
	return ""

func spatial_for(kind: String) -> bool:
	for entry: Dictionary in sounds():
		if entry.kind == kind:
			return bool(entry.spatial)
	return false

func has_event(event_name: String, kind: String) -> bool:
	for entry: Dictionary in events:
		if entry.event == event_name and entry.kind == kind:
			return true
	return false

func count_events(event_name: String, kind: String) -> int:
	var total: int = 0
	for entry: Dictionary in events:
		if entry.event == event_name and entry.kind == kind:
			total += 1
	return total

## The last recorded state of a continuous source, so a caller can assert what it was left as.
func ambience_state(kind: String) -> Variant:
	for index: int in range(events.size() - 1, -1, -1):
		var entry: Dictionary = events[index]
		if entry.event == "ambience" and entry.kind == kind:
			return bool(entry.on)
	return null
