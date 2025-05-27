extends Control
class_name DrawingManager

#@onready var camera_2d: Camera2D = $SubViewport/Camera2D
@onready var sub_viewport: SubViewport = $SubViewport
@onready var timer: Timer = $Timer

@export_file("*.tscn") var canvas_drawing_group_scene
@export_file("*.tscn") var temp_drawing_region_scene
@export_file("*.tscn") var drawing_region_scene

var canvas_groups: Dictionary[int, CanvasDrawingGroup]
var current_canvas: int = -1
var folder_path: String		## Folder inside user:// in which the images are stored, created on save_file() inside main.gd

var screenshot_requests: Array[Vector2i]
var screenshots_done: Dictionary[Vector2i, Image]
var current_screenshot_region: Vector2i = Vector2i(0, 0)
var is_taking_screenshots: bool = false
var initial_position: Vector2 = Vector2(0.0, 0.0)
var initial_scale: Vector2 = Vector2(1.0, 1.0)

signal finished_saving


func _ready() -> void:
	sub_viewport.world_2d = get_world_2d()


func _process(_delta: float) -> void:
	# TODO: move into main.gd or canvas.
	if Input.is_action_just_pressed("undo"):
		undo_drawing_action()
	if Input.is_action_just_pressed("redo"):
		redo_drawing_action()
	if Input.is_action_just_pressed("test"):
		screenshot_requests = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)]
		begin_screenshot_sequence()


func take_screenshot() -> void:
	screenshots_done[current_screenshot_region] = sub_viewport.get_texture().get_image()
	#print(position, scale, camera_2d.position, camera_2d.scale, camera_2d.zoom)
	#print("POSITION X %f Y %f SCALE X %f Y %f" % [position.x, position.y, scale.x, scale.y])
	#sub_viewport.get_texture().get_image().save_png("user://ss(%d %d).png" % [current_screenshot_region.x, current_screenshot_region.y])
	#screenshots_done[current_screenshot_region].save_png("user://ss(%d %d).png" % [current_screenshot_region.x, current_screenshot_region.y])
	#sub_viewport.get_texture().get_image().save_png("user://test%d.png" % img_count)


func canvas_drawing_group_has_changes(id: int) -> bool:
	if current_canvas != id and canvas_groups.has(id):
		change_active_canvas_drawing_group(id)
	var has: bool = canvas_groups[current_canvas].has_changes()
	var s: String = "has" if has else "doesn't have"
	print("Canvas drawing ground %s changes" % s)
	return canvas_groups[current_canvas].has_changes()


func begin_complete_save_sequence() -> void:
	screenshot_requests = canvas_groups[current_canvas].make_drawing_actions_permanent()
	begin_screenshot_sequence()


# TODO hide stuff to not flash images quickly
func begin_screenshot_sequence() -> void:
	if screenshot_requests.size() > 0:
		initial_position = position
		initial_scale = scale
		is_taking_screenshots = true
		move_to_region(screenshot_requests[0])
		current_screenshot_region = screenshot_requests.pop_front()
		timer.start()


func next_screnshot() -> void:
	take_screenshot()
	if screenshot_requests.size() > 0:	# Prepare for the next frame
		move_to_region(screenshot_requests[0])
		current_screenshot_region = screenshot_requests.pop_front()
		timer.start()
	else:
		end_screenshot_sequence()


func end_screenshot_sequence() -> void:
	position = initial_position
	scale = initial_scale
	is_taking_screenshots = false
	canvas_groups[current_canvas].update_regions_from_screenshots(screenshots_done)
	canvas_groups[current_canvas].clear_all_drawing_actions()
	screenshots_done.clear()
	finished_saving.emit()


func move_to_region(region: Vector2i) -> void:
	position = -Vector2(1024.0 * region.x, 1024.0 * region.y)
	scale = Vector2(1.0, 1.0)
	force_update_transform()


func receive_coords(p1: Vector2, p2: Vector2, draw_tool: int) -> void:
	canvas_groups[current_canvas].receive_coords(p1, p2, draw_tool)


func end_stroke() -> void:
	canvas_groups[current_canvas].end_stroke()


func undo_drawing_action() -> void:
	canvas_groups[current_canvas].undo_drawing_action()


func redo_drawing_action() -> void:
	canvas_groups[current_canvas].redo_drawing_action()


func make_drawing_actions_permanent() -> void:
	screenshot_requests = canvas_groups[current_canvas].make_drawing_actions_permanent()


func resize_to_window() -> void:
	canvas_groups[current_canvas].resize(get_viewport_rect().size)


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


func _on_timer_timeout() -> void:
	next_screnshot()


#func _on_item_rect_changed() -> void:
	#print("MOVED", get_rect().position)
