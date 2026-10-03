extends StyleBox
## Plate with 45-degree cut corners.
##
## `StyleBoxFlat` can only round corners, so the reference layout's chamfered
## plates (outer frame, section cards, text entry boxes, buttons) need a hand-drawn
## stylebox. Drawing happens inside the owning control's own draw pass, which
## keeps the plate behind that control's text instead of covering it.

var fill: Color = Color(0.067, 0.082, 0.086, 0.92)
var line: Color = Color(0.22, 0.2, 0.176)
var cut: float = 14.0
var line_width: float = 1.0

func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	var inset := minf(line_width, minf(rect.size.x, rect.size.y) * 0.25)
	_plate(to_canvas_item, rect, cut, line)
	if inset <= 0.0:
		_plate(to_canvas_item, rect, cut, fill)
		return
	var inner := Rect2(rect.position + Vector2(inset, inset),
		rect.size - Vector2(inset, inset) * 2.0)
	_plate(to_canvas_item, inner, maxf(cut - inset, 0.0), fill)

func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect

func _get_minimum_size() -> Vector2:
	return Vector2.ZERO

func _plate(to_canvas_item: RID, rect: Rect2, corner: float, color: Color) -> void:
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.end.x
	var bottom := rect.end.y
	var c := minf(corner, minf(rect.size.x, rect.size.y) * 0.45)
	var points := PackedVector2Array([
		Vector2(left + c, top), Vector2(right - c, top),
		Vector2(right, top + c), Vector2(right, bottom - c),
		Vector2(right - c, bottom), Vector2(left + c, bottom),
		Vector2(left, bottom - c), Vector2(left, top + c)])
	var colors := PackedColorArray()
	for _index: int in points.size():
		colors.append(color)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, points, colors)
