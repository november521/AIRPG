extends Control
## AIRPG's celestial frame: golden ellipses, four-point poles and a fine equator.
## Cached geometry; independent materials rotate only the selected orbital layers.
enum Layer { FRAME, INNER, CROSSING, DOTTED }
@export var layer: Layer = Layer.FRAME
const INK := Color(0.94, 0.69, 0.30, 1.0)

func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	match layer:
		Layer.INNER:
			_orbit(Vector2(0.83, 0.79), 0.32, 0.64)
		Layer.CROSSING:
			_orbit(Vector2(0.63, 0.99), -0.32, 0.62)
		Layer.DOTTED:
			_dotted_orbit(Vector2(0.82, 0.76))
			_dotted_orbit(Vector2(0.57, 0.58))
		Layer.FRAME:
			_draw_frame()

func _draw_frame() -> void:
	_orbit(Vector2(0.989, 0.984), 0.0, 0.88)
	_spindle()
	_pole(-1.0)
	_pole(1.0)
	_marks()

func _point(unit: Vector2) -> Vector2:
	return size * 0.5 + unit * size * 0.5

func _stroke(units: Array[Vector2], opacity: float = 1.0, width: float = 1.1) -> void:
	var path := PackedVector2Array()
	for unit: Vector2 in units:
		path.append(_point(unit))
	draw_polyline(path, Color(INK, opacity), width, true)

func _orbit(radii: Vector2, tilt: float, opacity: float) -> void:
	# Nearly complete fine arcs with small gaps for an engraved celestial instrument.
	for section: int in 12:
		var path: Array[Vector2] = []
		var start: float = float(section) * TAU / 12.0 + 0.018
		var end: float = float(section + 1) * TAU / 12.0 - 0.025
		if section % 5 == 2:
			end -= 0.035
		for step: int in 29:
			var angle: float = lerpf(start, end, float(step) / 28.0)
			var wear: float = 1.0 + sin(angle * 37.0 + tilt) * 0.0013
			path.append((Vector2(cos(angle), sin(angle)) * radii * wear).rotated(tilt))
		_stroke(path, opacity, 1.1)

func _spindle() -> void:
	_stroke([Vector2(0.0, -1.0), Vector2(0.0, 1.0)], 0.64)
	_stroke([Vector2(0.0, -1.0), Vector2(-0.37, 0.02), Vector2(0.0, 1.0)], 0.35)
	_stroke([Vector2(0.0, -1.0), Vector2(0.37, 0.02), Vector2(0.0, 1.0)], 0.35)
	_stroke([Vector2(-1.50, 0.11), Vector2(1.50, 0.11)], 0.65)

func _pole(direction: float) -> void:
	var center := Vector2(0.0, direction)
	var points: Array[Vector2] = [
		Vector2(0.0, -0.083), Vector2(0.009, -0.012),
		Vector2(0.042, 0.0), Vector2(0.009, 0.012),
		Vector2(0.0, 0.083), Vector2(-0.009, 0.012),
		Vector2(-0.042, 0.0), Vector2(-0.009, -0.012)]
	var fill := PackedVector2Array()
	for index: int in points.size():
		points[index] += center
		fill.append(_point(points[index]))
	draw_colored_polygon(fill, Color(1.0, 0.89, 0.58, 0.95))
	points.append(points[0])
	_stroke(points, 1.0, 1.0)

func _dotted_orbit(radii: Vector2) -> void:
	for index: int in 144:
		var angle: float = float(index) * TAU / 144.0
		var start := Vector2(cos(angle), sin(angle)) * radii
		var end := Vector2(cos(angle + 0.009), sin(angle + 0.009)) * radii
		_stroke([start, end], 0.48, 1.0)

func _marks() -> void:
	for x: float in [-1.18, -1.10, 1.10, 1.18]:
		_stroke([Vector2(x, 0.088), Vector2(x + 0.015, 0.11), Vector2(x, 0.132),
			Vector2(x - 0.015, 0.11), Vector2(x, 0.088)], 0.95)
