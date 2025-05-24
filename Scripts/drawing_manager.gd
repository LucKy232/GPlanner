extends Control
class_name DrawingManager

@onready var camera_2d: Camera2D = $SubViewport/Camera2D
@onready var sub_viewport: SubViewport = $SubViewport

@export_file("*.tscn") var canvas_drawing_group_scene
@export_file("*.tscn") var temp_drawing_region_scene
@export_file("*.tscn") var drawing_region_scene

var canvas_groups: Dictionary[int, CanvasDrawingGroup]
var current_canvas: int = -1
var folder_path: String		## Folder inside user:// in which the images are stored, created on save_file() inside main.gd


func _ready() -> void:
	sub_viewport.world_2d = get_world_2d()


func _process(_delta: float) -> void:
	# TODO: move into main.gd or canvas.gd
	if Input.is_action_just_pressed("test"):
		print(position, scale, camera_2d.position, camera_2d.scale)
		camera_2d.position = -position * scale
		camera_2d.zoom = Vector2(1.0 / scale.x, 1.0 / scale.y)
		sub_viewport.get_texture().get_image().save_png("user://test%d.png" % Time.get_ticks_msec())
	if Input.is_action_just_pressed("undo"):
		undo_drawing_action()
	if Input.is_action_just_pressed("redo"):
		redo_drawing_action()


func receive_coords(p1: Vector2, p2: Vector2, draw_tool: int) -> void:
	canvas_groups[current_canvas].receive_coords(p1, p2, draw_tool)


func end_stroke() -> void:
	canvas_groups[current_canvas].end_stroke()


func undo_drawing_action() -> void:
	canvas_groups[current_canvas].undo_drawing_action()


func redo_drawing_action() -> void:
	canvas_groups[current_canvas].redo_drawing_action()


func make_drawing_actions_permanent() -> void:
	canvas_groups[current_canvas].make_drawing_actions_permanent()


func resize_to_window() -> void:
	canvas_groups[current_canvas].size = get_viewport_rect().size


func drawing_region_paths_to_json() -> Dictionary:
	return canvas_groups[current_canvas].drawing_region_paths_to_json()


func rebuild_from_json(canvas_id: int, dict: Dictionary) -> void:
	if canvas_groups.has(canvas_id):
		canvas_groups[canvas_id].rebuild_from_json(dict)


func update_drawing_position_and_scale(pos: Vector2, scl: Vector2) -> void:
	canvas_groups[current_canvas].update_drawing_position_and_scale(pos, scl)


func set_folder_path(canvas_id: int, path: String) -> void:
	if !canvas_groups.has(canvas_id):
		return
	canvas_groups[canvas_id].folder_path = path


func get_folder_path(canvas_id: int) -> String:
	if !canvas_groups.has(canvas_id):
		return ""
	return canvas_groups[canvas_id].folder_path


func has_folder_path() -> bool:
	if !canvas_groups.has(current_canvas):
		return false
	print("Canvas drawing group has folder path: %s PATH: %s" % [str(!canvas_groups[current_canvas].folder_path == ""), canvas_groups[current_canvas].folder_path])
	return !canvas_groups[current_canvas].folder_path == ""


func add_canvas_drawing_group(canvas_id: int) -> void:
	if canvas_groups.has(canvas_id):
		printerr("Drawing Manager already has a canvas with that ID (on drawing_manager.add_canvas_drawing_group(id)")
		return
	var new_group = load(canvas_drawing_group_scene).instantiate()
	add_child(new_group)
	new_group.temp_drawing_region_scene = temp_drawing_region_scene
	new_group.drawing_region_scene = drawing_region_scene
	new_group.init(size)
	canvas_groups[canvas_id] = new_group


func erase_canvas_drawing_group(canvas_id: int) -> void:
	if canvas_groups.has(canvas_id):
		canvas_groups[canvas_id].queue_free()
		canvas_groups.erase(canvas_id)
		current_canvas = -1


func change_active_canvas_drawing_group(canvas_id: int) -> void:
	if canvas_groups.has(current_canvas):
		canvas_groups[current_canvas].visible = false
	current_canvas = canvas_id
	if canvas_groups.has(current_canvas):
		canvas_groups[current_canvas].visible = true
