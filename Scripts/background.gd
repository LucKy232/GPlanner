extends Panel
#@export var line_width_px: int = 1
@export var line_spacing_px: int = 40	## Including the line_width
@export var dashed_line: bool = false
@export_color_no_alpha var line_color
@export_color_no_alpha var background_color
#var line_width_under_zoom: int = 1
var stylebox: StyleBoxFlat
var precalculated_x: PackedFloat32Array
var precalculated_y: PackedFloat32Array

func _ready() -> void:
	stylebox = get_theme_stylebox("panel")
	stylebox.bg_color = background_color
	calculate_line_positions()
	#line_width_under_zoom = line_width_px


func _draw() -> void:
	for x in precalculated_x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), line_color, -1.0)
	for y in precalculated_y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), line_color, -1.0)
	#for i in (size.x / line_spacing_px):
		#draw_line(Vector2(i * line_spacing_px, 0.0), Vector2(i * line_spacing_px, size.y), line_color, -1.0)
	#for j in (size.y / line_spacing_px):
		#draw_line(Vector2(0.0, j * line_spacing_px), Vector2(size.x, j * line_spacing_px), line_color, -1.0)


func calculate_line_positions() -> void:
	precalculated_x.clear()
	precalculated_y.clear()
	for i in (size.x / line_spacing_px):
		precalculated_x.append(i * line_spacing_px)
	for j in (size.y / line_spacing_px):
		precalculated_y.append(j * line_spacing_px)


#func redraw(zoom: float) -> void:
	#line_width_under_zoom = ceili(zoom * line_width_px)
	#queue_redraw()
