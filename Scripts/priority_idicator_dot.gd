@tool
class_name PriorityIndicatorDot extends Control

@export var circle_radius: float = 8.0
@export var circle_thickness: float = 2.0
@export var outer_circle_color: Color = Color.WHITE
@export var inner_circle_color: Color = Color.RED
@export_tool_button("Redraw") var redraw_button = queue_redraw

func _draw() -> void:
	draw_circle(size * 0.5, circle_radius, outer_circle_color, false, circle_thickness, true)
	draw_circle(size * 0.5, circle_radius - circle_thickness * 0.5, inner_circle_color, true, -1.0, true)
