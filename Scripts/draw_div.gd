class_name DrawDiv extends Control

@export var width: float = -1.0
@export var left_margin: float = 0.0
@export var right_margin: float = 0.0
@export var antialiased: bool = false
@export var y_offset: float = 0.0
var color: Color = Color.WHITE

func _draw() -> void:
	draw_line(Vector2(left_margin, y_offset), Vector2(size.x - right_margin, y_offset), color, width, antialiased)
