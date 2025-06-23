extends Control
class_name DrawingManager

@onready var sub_viewport: SubViewport = $SubViewport
@onready var curtain: Panel = $Curtain
@onready var screenshot_progress_label: Label = $Curtain/CenterContainer/VBoxContainer/ScreenshotProgressLabel

@export_file("*.tscn") var canvas_drawing_group_scene
@export_file("*.tscn") var temp_drawing_region_scene
@export_file("*.tscn") var drawing_region_scene

var canvas_groups: Dictionary[int, CanvasDrawingGroup]
var current_canvas: int = -1
var folder_path: String		## Folder inside user:// in which the images are stored, created on save_images() inside main.gd
var curtain_stylebox: StyleBoxTexture

var screenshot_requests: Array[Vector2i]
var screenshots_done: Dictionary[Vector2i, Image]
var current_screenshot_region: Vector2i = Vector2i(0, 0)
var is_taking_screenshots: bool = false			# Used to disable canvas gui inputs
var needed_screenshot_number: int = 0
var initial_position: Vector2 = Vector2(0.0, 0.0)
var initial_scale: Vector2 = Vector2(1.0, 1.0)
var save_thread: Thread = Thread.new()
var save_thread_running: bool = false
var save_type: SaveType

signal finished_saving
signal requested_status_message
signal requested_save_on_tool_change
signal forced_save_started

enum SaveType {
	NORMAL,		# Screenshot every region with an action and save images to disk
	PARTIAL,	# On tool change, screenshot every region with an overflow action, don't save to disk
	FORCED,		# Immediately, move 50% of the past actions to past_overflow_actions, screenshot every region with an overflow action, don't save to disk
}


func _ready() -> void:
	sub_viewport.world_2d = get_world_2d()
	curtain_stylebox = StyleBoxTexture.new()
	curtain.add_theme_stylebox_override("panel", curtain_stylebox)


func _process(_delta: float) -> void:
	if save_thread_running and !save_thread.is_alive():
		save_thread_running = false
		save_thread.wait_to_finish()
		finished_saving.emit()


func canvas_drawing_group_has_changes(id: int) -> bool:
	if current_canvas != id and canvas_groups.has(id):
		change_active_canvas_drawing_group(id)
	return canvas_groups[current_canvas].has_changes()


func save_if_canvas_drawing_group_has_changes(id: int) -> bool:
	if current_canvas != id and canvas_groups.has(id):
		change_active_canvas_drawing_group(id)
	var changes: bool = canvas_groups[current_canvas].has_changes()
	if !changes:
		finished_saving.emit()
	else:
		save_type = SaveType.NORMAL
		begin_save_sequence()
	return changes


func begin_save_sequence() -> void:
	if save_type == SaveType.NORMAL:
		screenshot_requests = canvas_groups[current_canvas].make_drawing_actions_permanent()
	elif save_type == SaveType.PARTIAL:
		screenshot_requests = canvas_groups[current_canvas].make_past_and_overflow_actions_permanent(0.0)
	elif save_type == SaveType.FORCED:
		screenshot_requests = canvas_groups[current_canvas].make_past_and_overflow_actions_permanent(0.5)
	needed_screenshot_number = screenshot_requests.size()
	begin_screenshot_sequence()


func begin_screenshot_sequence() -> void:
	if screenshot_requests.size() > 0:
		var curtain_image: ImageTexture = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
		curtain_stylebox.texture = curtain_image
		curtain.visible = true
		initial_position = position
		initial_scale = scale
		is_taking_screenshots = true
		
		move_to_region(screenshot_requests[0])
		current_screenshot_region = screenshot_requests.pop_front()
		await get_tree().physics_frame			# Wait for the subviewport to move
		await RenderingServer.frame_post_draw	# Wait for the subviewport to render after moving
		screenshot_progress_label.text = "Screenshot region %d / %d" % [needed_screenshot_number - screenshot_requests.size() + 1, needed_screenshot_number]
		next_screnshot()


# Calls itself until screenshot_requests is empty
func next_screnshot() -> void:
	screenshots_done[current_screenshot_region] = sub_viewport.get_texture().get_image()
	#print("Taking screenshot, canvas %d, position x %05f y %05f, scale x %05f, y %05f" % [current_canvas, position.x, position.y, scale.x, scale.y])
	if screenshot_requests.size() > 0:	# Prepare for the next frame
		move_to_region(screenshot_requests[0])
		current_screenshot_region = screenshot_requests.pop_front()
		await get_tree().physics_frame			# Wait for the subviewport to move
		await RenderingServer.frame_post_draw	# Wait for the subviewport to render after moving
		screenshot_progress_label.text = "Screenshot region %d / %d" % [needed_screenshot_number - screenshot_requests.size() + 1, needed_screenshot_number]
		next_screnshot()
	else:
		if save_type == SaveType.NORMAL:
			finish_saving()		# Save images to disk
		else:
			end_screenshot_sequence()


func end_screenshot_sequence() -> void:
	position = initial_position
	scale = initial_scale
	is_taking_screenshots = false
	canvas_groups[current_canvas].update_regions_from_screenshots(screenshots_done)
	if save_type == SaveType.NORMAL:
		canvas_groups[current_canvas].clear_all_drawing_actions()
	else:
		canvas_groups[current_canvas].clear_all_overflow_actions()
	screenshots_done.clear()
	curtain.visible = false


func finish_saving() -> void:
	end_screenshot_sequence()
	#canvas_groups[current_canvas].finished_saving.connect(_on_canvas_group_finished_saving.bind(current_canvas), CONNECT_ONE_SHOT)
	if save_thread.is_alive():
		printerr("Trying to save 2 file's images to disk at the same time!")
		return
	save_thread.start(canvas_groups[current_canvas].save_all_regions_to_disk)
	save_thread_running = true


func move_to_region(region: Vector2i) -> void:
	position = -Vector2(1024.0 * region.x, 1024.0 * region.y)
	scale = Vector2(1.0, 1.0)
	force_update_transform()


func receive_coords(p1: Vector2, p2: Vector2, draw_tool: int) -> void:
	canvas_groups[current_canvas].receive_coords(p1, p2, draw_tool)


func receive_click(p: Vector2, draw_tool: int) -> void:
	canvas_groups[current_canvas].receive_click(p, draw_tool)


func end_stroke() -> void:
	canvas_groups[current_canvas].end_stroke()


func undo_drawing_action() -> bool:
	return canvas_groups[current_canvas].undo_drawing_action()


func redo_drawing_action() -> bool:
	return canvas_groups[current_canvas].redo_drawing_action()


func resize_to_window() -> void:
	canvas_groups[current_canvas].resize(get_viewport_rect().size)


func drawing_region_paths_to_json() -> Dictionary:
	return canvas_groups[current_canvas].drawing_region_paths_to_json()


func rebuild_from_json(canvas_id: int, dict: Dictionary) -> void:
	if canvas_groups.has(canvas_id):
		canvas_groups[canvas_id].rebuild_from_json(dict)


# Repositions the temp drawing region where the drawing takes place
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


func has_folder_path(canvas_id: int) -> bool:
	if !canvas_groups.has(canvas_id):
		return false
	#print("Canvas drawing group has folder path: %s PATH: %s" % [str(!canvas_groups[canvas_id].folder_path == ""), canvas_groups[canvas_id].folder_path])
	return !canvas_groups[canvas_id].folder_path == ""


func add_canvas_drawing_group(canvas_id: int) -> void:
	if canvas_groups.has(canvas_id):
		printerr("Drawing Manager already has a canvas with that ID (on drawing_manager.add_canvas_drawing_group(id)")
		return
	var new_group = load(canvas_drawing_group_scene).instantiate()
	add_child(new_group)
	new_group.temp_drawing_region_scene = temp_drawing_region_scene
	new_group.drawing_region_scene = drawing_region_scene
	new_group.save_request.connect(_on_canvas_drawing_group_save_request.bind(canvas_id))
	new_group.force_save_request.connect(_on_canvas_drawing_group_force_save_request.bind(canvas_id))
	new_group.saving_images_to_disk.connect(_on_canvas_drawing_group_saving_images)
	new_group.init(size)
	canvas_groups[canvas_id] = new_group


func erase_canvas_drawing_group(canvas_id: int) -> void:
	if canvas_groups.has(canvas_id):
		canvas_groups[canvas_id].erase_everything()
		canvas_groups[canvas_id].queue_free()
		canvas_groups.erase(canvas_id)
		current_canvas = -1


func clear_canvas_drawing_group(canvas_id: int) -> void:
	if canvas_groups.has(canvas_id):
		canvas_groups[canvas_id].erase_everything()


func change_active_canvas_drawing_group(canvas_id: int) -> void:
	if canvas_groups.has(current_canvas):
		canvas_groups[current_canvas].visible = false
	if canvas_groups.has(canvas_id):
		current_canvas = canvas_id
		canvas_groups[canvas_id].visible = true
	else:
		printerr("Given canvas ID %d doesn't exist in DrawingManager! (change_active_canvas_drawing_group())" % canvas_id)
		current_canvas = -1


func _on_canvas_drawing_group_save_request(id: int) -> void:
	requested_save_on_tool_change.emit(id)
	print("Saving canvas %d on next tool change" % id)


func _on_canvas_drawing_group_force_save_request(id: int) -> void:
	save_type = SaveType.FORCED
	forced_save_started.emit()
	begin_save_sequence()
	print("Saving canvas %d immediatelly" % id)


func _on_canvas_drawing_group_saving_images(message: String) -> void:
	requested_status_message.emit(message)


#func _on_canvas_group_finished_saving(_id: int) -> void:
	#finished_saving.emit()


#func _on_item_rect_changed() -> void:
	#print("MOVED", get_rect().position)
