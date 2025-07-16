extends Panel
@export_category("Grid Lines")
@export var toggle_grid_lines: bool = true
@export var line_spacing_px: int = 40	## Including the line_width
@export_color_no_alpha var line_color

@export_category("Background")
@export_color_no_alpha var background_color

@export_category("Drawing Region Limits Visual")
@export var toggle_drawing_region_limits: bool = false
@export_range(-1.0, 10.0, 1.0) var drawing_region_limits_thickness = 5.0
@export_color_no_alpha var drawing_region_limits_color = Color.RED
@export_range(0.0, 1.0, 0.01) var drawing_region_limits_color_alpha = 1.0

var stylebox: StyleBoxFlat
var precalculated_x: PackedFloat32Array
var precalculated_y: PackedFloat32Array

func _ready() -> void:
	stylebox = get_theme_stylebox("panel")
	stylebox.bg_color = background_color
	calculate_line_positions()


func _draw() -> void:
	if toggle_grid_lines:
		for x in precalculated_x:
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), line_color, -1.0)
		for y in precalculated_y:
			draw_line(Vector2(0.0, y), Vector2(size.x, y), line_color, -1.0)
	if toggle_drawing_region_limits:
		for x in (size.x / 1024.0):
			var c: Color = Color(drawing_region_limits_color.r, drawing_region_limits_color.g, drawing_region_limits_color.b, drawing_region_limits_color_alpha)
			draw_line(Vector2(x * 1024.0, 0.0), Vector2(x * 1024.0, size.y), c, drawing_region_limits_thickness)
		for y in (size.y / 1024.0):
			var c: Color = Color(drawing_region_limits_color.r, drawing_region_limits_color.g, drawing_region_limits_color.b, drawing_region_limits_color_alpha)
			draw_line(Vector2(0.0, y * 1024.0), Vector2(size.x, y * 1024.0), c, drawing_region_limits_thickness)


func calculate_line_positions() -> void:
	precalculated_x.clear()
	precalculated_y.clear()
	for i in (size.x / line_spacing_px):
		precalculated_x.append(i * line_spacing_px)
	for j in (size.y / line_spacing_px):
		precalculated_y.append(j * line_spacing_px)


#func redraw() -> void:
	#queue_redraw()
