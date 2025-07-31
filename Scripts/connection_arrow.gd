extends Control
class_name ConnectionArrow

var color: Color = Color.WHITE
var thickness: float = 4.0
var enabled: bool = false


func _draw() -> void:
	if enabled:
		draw_colored_polygon([Vector2(0.0, size.y * 0.1), Vector2(size.x, size.y * 0.5), Vector2(0.0, size.y * 0.9)], color)
