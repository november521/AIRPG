extends Control
## Ink sketches for the three existing preview items; no story-specific art is implied.
var item_id := "":
	set(value):
		item_id = value
		queue_redraw()

func _draw() -> void:
	var ink := Color(0.27, 0.22, 0.17, 0.86)
	var center := size * 0.5
	var scale_factor := minf(size.x, size.y) / 145.0
	match item_id:
		"demo_bandage":
			draw_set_transform(center, -0.45, Vector2.ONE * scale_factor)
			draw_rect(Rect2(-48, -17, 96, 34), ink, false, 2.4)
			draw_rect(Rect2(-12, -17, 24, 34), ink, false, 1.6)
			for x: int in 4:
				draw_circle(Vector2(-7 + (x % 2) * 13, -10 + (x / 2) * 20), 1.5, ink)
		"demo_lamp":
			draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
			draw_line(Vector2(-25, -35), Vector2(25, -35), ink, 2.3, true)
			draw_line(Vector2(-25, -35), Vector2(-35, 38), ink, 2.3, true)
			draw_line(Vector2(25, -35), Vector2(35, 38), ink, 2.3, true)
			draw_line(Vector2(-35, 38), Vector2(35, 38), ink, 2.3, true)
			draw_arc(Vector2.ZERO, 23, PI, TAU, 24, ink, 2.0, true)
			draw_line(Vector2(0, -35), Vector2(0, 32), ink, 1.5, true)
		"demo_token":
			draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
			draw_arc(Vector2.ZERO, 42, 0, TAU, 48, ink, 2.8, true)
			draw_arc(Vector2.ZERO, 33, 0, TAU, 48, ink, 1.1, true)
			draw_line(Vector2(-16, 0), Vector2(16, 0), ink, 2.2, true)
			draw_line(Vector2(0, -16), Vector2(0, 16), ink, 2.2, true)
		_:
			draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
			draw_arc(Vector2.ZERO, 36, 0, TAU, 40, ink, 1.5, true)
