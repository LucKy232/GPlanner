extends Panel
@export var line_spacing_px: int = 40	## Including the line_width
@export var drawing_regions: bool = false
@export_color_no_alpha var line_color
@export_color_no_alpha var background_color
var stylebox: StyleBoxFlat
var precalculated_x: PackedFloat32Array
var precalculated_y: PackedFloat32Array

func _ready() -> void:
	stylebox = get_theme_stylebox("panel")
	stylebox.bg_color = background_color
	calculate_line_positions()


func _draw() -> void:
	for x in precalculated_x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), line_color, -1.0)
	for y in precalculated_y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), line_color, -1.0)
	if drawing_regions:
		for x in (size.x / 1024.0):
			draw_line(Vector2(x * 1024.0, 0.0), Vector2(x * 1024.0, size.y), Color(1.0, 0.0, 0.0, 0.5), 5.0)
		for y in (size.y / 1024.0):
			draw_line(Vector2(0.0, y * 1024.0), Vector2(size.x, y * 1024.0), Color(1.0, 0.0, 0.0, 0.5), 5.0)
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


#func redraw() -> void:
	#queue_redraw()
