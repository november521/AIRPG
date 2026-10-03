extends Control
## Small line-art book icon for the exploration HUD button.

func _draw() -> void:
	var ink := Color(0.84, 0.71, 0.51)
	draw_polyline(PackedVector2Array([Vector2(12, 4), Vector2(4, 2), Vector2(2, 5), Vector2(2, 21), Vector2(12, 22)]), ink, 1.7, true)
	draw_polyline(PackedVector2Array([Vector2(12, 4), Vector2(20, 2), Vector2(22, 5), Vector2(22, 21), Vector2(12, 22)]), ink, 1.7, true)
	draw_line(Vector2(12, 4), Vector2(12, 22), ink, 1.3, true)
	draw_line(Vector2(5, 6), Vector2(10, 7), ink.darkened(0.18), 1.0, true)
	draw_line(Vector2(14, 7), Vector2(19, 6), ink.darkened(0.18), 1.0, true)
