extends Control
class_name DrawingManager

@onready var sub_viewport: SubViewport = $SubViewport
@onready var curtain: Panel = $Curtain
@onready var greyout_panel: Panel = $Curtain/GreyoutPanel
@onready var screenshot_progress_label: Label = $Curtain/MarginContainer/VBoxContainer/ScreenshotProgressLabel

@export_file("*.tscn") var canvas_drawing_group_scene
@export_file("*.tscn") var temp_drawing_region_scene
@export_file("*.tscn") var drawing_region_scene

var canvas_groups: Dictionary[int, CanvasDrawingGroup]
var current_canvas: int = -1
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

signal finished_saving		## Unlocks the UI in main.gd, emitted from _process() if save_thread is running
signal requested_status_message
signal forced_save_started
signal forced_save_ended

enum SaveType {
	NORMAL,		# Screenshot every region with an action and save images to disk
	FORCED,		# Immediately, move 50% of the past actions to past_overflow_actions, screenshot every region with an overflow action, don't save to disk
	STOPPED,	# Is not saving
	#PARTIAL,	# unused; On tool change, screenshot every region with an overflow action, don't save to disk
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
	elif save_type == SaveType.FORCED:
		screenshot_requests = canvas_groups[current_canvas].make_past_and_overflow_actions_permanent(0.5)
	#elif save_type == SaveType.PARTIAL:
		#screenshot_requests = canvas_groups[current_canvas].make_past_and_overflow_actions_permanent(0.0)
	needed_screenshot_number = screenshot_requests.size()
	
	if canvas_groups[current_canvas].reload_all_drawing_regions_from_path():
		await canvas_groups[current_canvas].all_drawing_regions_visible
	begin_screenshot_sequence()


func begin_screenshot_sequence() -> void:
	if screenshot_requests.size() > 0:
		await get_tree().physics_frame			# Wait for the subviewport to move
		await RenderingServer.frame_post_draw	# Wait for the subviewport to render after moving
		var curtain_image: ImageTexture = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
		curtain_stylebox.texture = curtain_image
		curtain.visible = true
		if needed_screenshot_number > 9:
			greyout_panel.visible = true
		else:
			greyout_panel.visible = false
		initial_position = position
		initial_scale = scale
		is_taking_screenshots = true
		
		move_to_region(screenshot_requests[0])
		await prepare_next_screenshot()
		next_screenshot()


# Calls itself until screenshot_requests is empty
func next_screenshot() -> void:
	screenshots_done[current_screenshot_region] = sub_viewport.get_texture().get_image()
	#print("Taking screenshot, canvas %d, position x %05f y %05f, scale x %05f, y %05f" % [current_canvas, position.x, position.y, scale.x, scale.y])
	if screenshot_requests.size() > 0:	# Prepare for the next frame
		move_to_region(screenshot_requests[0])
		await prepare_next_screenshot()
		next_screenshot()
	else:
		if save_type == SaveType.NORMAL:
			end_screenshot_sequence()
			save_all_images_to_disk()
		elif save_type == SaveType.FORCED:
			end_screenshot_sequence()


func prepare_next_screenshot() -> void:
	current_screenshot_region = screenshot_requests.pop_front()
	screenshot_progress_label.text = "Screenshot region %d / %d" % [needed_screenshot_number - screenshot_requests.size(), needed_screenshot_number]
	await get_tree().physics_frame			# Wait for the subviewport to move
	await RenderingServer.frame_post_draw	# Wait for the subviewport to render after moving


func end_screenshot_sequence() -> void:
	position = initial_position
	scale = initial_scale
	is_taking_screenshots = false
	canvas_groups[current_canvas].update_regions_from_screenshots(screenshots_done)
	if save_type == SaveType.NORMAL:
		canvas_groups[current_canvas].clear_all_drawing_actions()
	elif save_type == SaveType.FORCED:
		canvas_groups[current_canvas].clear_all_overflow_actions()
		canvas_groups[current_canvas].toggle_past_drawing_actions(true)
		forced_save_ended.emit()
	save_type = SaveType.STOPPED
	screenshots_done.clear()
	curtain.visible = false
	greyout_panel.visible = false


func save_all_images_to_disk() -> void:
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


func rebuild_paths_from_json(canvas_id: int, dict: Dictionary) -> void:
	if canvas_groups.has(canvas_id):
		canvas_groups[canvas_id].rebuild_file_paths_from_json(dict)


# Called before starting to draw a new current_stroke (from planner_canvas.gd)
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
	#new_group.save_request.connect(_on_canvas_drawing_group_save_request.bind(canvas_id))
	new_group.force_save_request.connect(_on_canvas_drawing_group_force_save_request)
	new_group.saving_images_to_disk.connect(_on_canvas_drawing_group_saving_images)
	new_group.force_save_message.connect(_on_canvas_drawing_group_force_save_message)
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
		canvas_groups[current_canvas].unload_all_drawing_regions_with_path()
		canvas_groups[current_canvas].visible = false
	if canvas_groups.has(canvas_id):
		current_canvas = canvas_id
		canvas_groups[canvas_id].visible = true
		canvas_groups[canvas_id].reload_all_drawing_regions_from_path()
	else:
		printerr("Given canvas ID %d doesn't exist in DrawingManager! (change_active_canvas_drawing_group())" % canvas_id)
		current_canvas = -1


func reload_all_drawing_regions(canvas_id: int) -> void:
	if !canvas_groups.has(canvas_id):
		return
	canvas_groups[canvas_id].reload_all_drawing_regions_from_path()


func _on_canvas_drawing_group_force_save_request() -> void:
	save_type = SaveType.FORCED
	forced_save_started.emit()
	begin_save_sequence()


func _on_canvas_drawing_group_saving_images(message: String) -> void:
	requested_status_message.emit(message)


func _on_canvas_drawing_group_force_save_message(message: String) -> void:
	requested_status_message.emit(message)


#func _on_item_rect_changed() -> void:
#	print("MOVED", get_rect().position)
