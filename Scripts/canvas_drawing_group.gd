extends CanvasGroup
class_name CanvasDrawingGroup
## Group together TempDrawingActions & DrawingRegions to blend them together
## and make materials with BLEND_MODE_SUB subtract from the resulting image easily
## CanvasDrawingGroup, TempDrawingAction & DrawingRegion need to all be on the same z_index

@export var brush: CompressedTexture2D
@export var blank_img: CompressedTexture2D
@export var brush_material: ShaderMaterial
@onready var drawing_regions_container: Control = $DrawingRegionsContainer
@onready var temp_drawing_actions_container: Control = $TempDrawingActionsContainer
@onready var brush_sub_viewport: SubViewport = $BrushDrawViewportContainer/BrushSubViewport
@onready var brush_draw_viewport_container: SubViewportContainer = $BrushDrawViewportContainer
@onready var eraser_sub_viewport: SubViewport = $EraserSubViewport
@onready var brush_eraser_texture: TempDrawingAction = $EraserSubViewport/BrushEraserTexture

var current_stroke: TempDrawingAction
var past_drawing_actions: Array[TempDrawingAction]
## When undo-ing, the last TempDrawingAction from past_drawing_actions gets removed and placed here
var future_drawing_actions: Array[TempDrawingAction]
## When past_drawing_actions is full, the front TempDrawingAction gets removed and placed here
var past_actions_overflow: Array[TempDrawingAction]
var regions: Dictionary[Vector2i, DrawingRegion]
var pencil_material: CanvasItemMaterial			## CanvasItemMaterial.BLEND_MODE_MIX set up in init()
var eraser_material: CanvasItemMaterial			## CanvasItemMaterial.BLEND_MODE_SUB set up in init()
var mask_eraser_material: CanvasItemMaterial	## CanvasItemMaterial.BLEND_MODE_MUL set up in init()

var MAX_PAST_ACTIONS: int = 100	## Actions available to undo.
var FORCE_SAVE_REQUEST_KB_LIMIT: float = 512000.0	## When the force_save_request signal will be triggered, (used_temp_data_kb + used_overflow_data_kb is measured currently). A message will be sent using StatusBar via force_save_message signal at 75% of this value.
var temp_drawing_action_scene	## Scene to instantiate for a single drawing stroke / action.
var drawing_region_scene		## Scene to instantiate for a final image (1024x1024) that will get saved to disk.
var folder_path: String = ""	## Folder inside user:// in which the images are stored, created on save_images() inside main.gd or loaded on rebuild_canvas_state() inside planner_canvas.gd
var size: Vector2
var used_temp_data_kb: float = 0.0		## Counts the image sizes of past_drawing_actions
var used_overflow_data_kb: float = 0.0	## Counts the image sizes of past_actions_overflow
var image_load_tasks: Dictionary[int, Vector2i]			## Used to check if the task is finished to then render the texture (can only be done on main thread).
var regions_being_loaded: Dictionary[Vector2i, bool]	## Bool not used, just searching the hash map to not cycle trough all regions or use array search.
var active_brush_shader: ShaderMaterial					## The material of the current_stroke
var complete_json_image_data: Dictionary

## Emits when 75% of FORCE_SAVE_REQUEST_KB_LIMIT is reached to inform the user that they should save.
signal force_save_message
## Emits when FORCE_SAVE_REQUEST_KB_LIMIT is reached to force save in order to save VRAM.
signal force_save_request
@warning_ignore("unused_signal")
## Emits to give a progress message to be displayed when images are saved. Used inside a call_deferred, due to save_all_images_to_folder() being called from a different thread
signal saving_images_to_disk
## Emitted when all regions are visible, used when screenshotting images changes to ensure all are loaded
signal all_drawing_regions_visible


func _process(_delta: float) -> void:
	if image_load_tasks.size() > 0:
		check_image_load_tasks_completed()


# Update the shader brush texture from the brush_sub_viewport to accumulate shader contributions
func _on_post_render() -> void:
	var prev_img: Image = brush_sub_viewport.get_texture().get_image()
	var img_tex: ImageTexture = ImageTexture.create_from_image(prev_img);
	active_brush_shader.set_shader_parameter("prev_img", img_tex)


# Update the shader brush texture as before, but invisible to the user, to be used as a subtractive texture
func _on_post_render_eraser() -> void:
	var prev_img: Image = eraser_sub_viewport.get_texture().get_image()
	var img_tex: ImageTexture = ImageTexture.create_from_image(prev_img);
	active_brush_shader.set_shader_parameter("prev_img", img_tex)
	current_stroke.texture = img_tex	# Is set to BlendMode.Subtract


func check_image_load_tasks_completed() -> void:
	var tasks_completed: Array[int] = []
	for task in image_load_tasks:
		if WorkerThreadPool.is_task_completed(task):
			#print("Task %d done" % task)
			regions[image_load_tasks[task]].redraw_existing_image()
			tasks_completed.append(task)
	for task in tasks_completed:
		var reg: Vector2i = image_load_tasks[task]
		# If file tab changed before the tasks were finished. Can't stop threads, so unload the textures after the tasks are finished.
		if !visible:
			regions[reg].unload()
		regions_being_loaded.erase(reg)
		image_load_tasks.erase(task)
	if image_load_tasks.size() == 0:
		all_drawing_regions_visible.emit()


func init(manager_size: Vector2) -> void:
	pencil_material = CanvasItemMaterial.new()
	pencil_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	#pencil_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	eraser_material = CanvasItemMaterial.new()
	eraser_material.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
	#eraser_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mask_eraser_material = CanvasItemMaterial.new()
	mask_eraser_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	#mask_eraser_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	size = manager_size
	current_stroke = add_temp_drawing_action()


func has_changes() -> bool:
	if past_drawing_actions.size() > 0:
		return true
	return false


func receive_coords(p1: Vector2, p2: Vector2, settings: DrawingSettings, pressure: float) -> void:
	var to_set_material: bool = true if current_stroke.type != settings.selected_tool else false
	
	if settings.selected_tool == Enums.DrawingTool.BRUSH:
		if to_set_material:
			position_brush_to_current_stroke()
			setup_shader()
			current_stroke.type = settings.selected_tool
		var pressure_lower_limit: float = (1.0 - settings.brush_settings.pressure)
		# Normalized in range [(1.0-setting); 1.0]
		pressure = clampf(pressure * settings.brush_settings.pressure + pressure_lower_limit, pressure_lower_limit, 1.0)
		# Limited to min_pressure, but using the whole range of input [0.0; 1.0] mapped to [MIN; 1.0]
		pressure = clampf(pressure * (1.0 - settings.brush_settings.min_pressure) + settings.brush_settings.min_pressure, settings.brush_settings.min_pressure, 1.0)
		current_stroke.draw_brush_line(p1, p2, settings.brush_settings.color, settings.brush_settings.size, pressure)
	elif settings.selected_tool == Enums.DrawingTool.ERASER_BRUSH:
		if to_set_material:
			position_eraser_to_current_stroke()
			setup_eraser_shader()
			current_stroke.material = eraser_material.duplicate()
			current_stroke.type = settings.selected_tool
		var pressure_lower_limit: float = (1.0 - settings.eraser_brush_settings.pressure)
		pressure = clampf(pressure * settings.eraser_brush_settings.pressure + pressure_lower_limit, pressure_lower_limit, 1.0)
		pressure = clampf(pressure * (1.0 - settings.eraser_brush_settings.min_pressure) + settings.eraser_brush_settings.min_pressure, settings.eraser_brush_settings.min_pressure, 1.0)
		brush_eraser_texture.draw_brush_line(p1, p2, Color.WHITE, settings.eraser_brush_settings.size, pressure)
	elif settings.selected_tool == Enums.DrawingTool.PENCIL:
		if to_set_material:
			current_stroke.material = pencil_material
			current_stroke.type = settings.selected_tool
		current_stroke.draw_pencil(p1, p2, settings.pencil_settings.color, settings.pencil_settings.size)
	elif settings.selected_tool == Enums.DrawingTool.ERASER_PENCIL:
		if to_set_material:
			current_stroke.material = eraser_material
			current_stroke.type = settings.selected_tool
		current_stroke.draw_pencil(p1, p2, Color.WHITE, settings.eraser_pencil_settings.size)


# Called when setting up the material for the current_stroke
func position_brush_to_current_stroke() -> void:
	brush_draw_viewport_container.size = current_stroke.size
	brush_sub_viewport.size = current_stroke.size
	current_stroke.reparent(brush_sub_viewport)
	current_stroke.position = Vector2.ZERO


func position_eraser_to_current_stroke() -> void:
	brush_eraser_texture.size = size
	brush_eraser_texture.position = position
	brush_eraser_texture.init_image(int(size.x), int(size.y))
	eraser_sub_viewport.size = current_stroke.size
	brush_eraser_texture.size = current_stroke.size
	brush_eraser_texture.position = Vector2.ZERO


func setup_shader() -> void:
	current_stroke.material = brush_material.duplicate()
	current_stroke.set_visibility_layer_bit(2, false)# 	Only layers 1 & 8 active - Only one that the BrushSubViewport can see
	current_stroke.set_visibility_layer_bit(7, true)
	active_brush_shader = current_stroke.material
	active_brush_shader.set_shader_parameter("brush", brush)
	active_brush_shader.set_shader_parameter("prev_img", blank_img)
	if !RenderingServer.frame_post_draw.is_connected(_on_post_render):
		RenderingServer.frame_post_draw.connect(_on_post_render)


func setup_eraser_shader() -> void:
	brush_eraser_texture.material = brush_material.duplicate()
	active_brush_shader = brush_eraser_texture.material
	active_brush_shader.set_shader_parameter("brush", brush)
	active_brush_shader.set_shader_parameter("prev_img", blank_img)
	active_brush_shader.set_shader_parameter("brush_color", Vector4(1.0, 1.0, 1.0, 1.0))
	if !RenderingServer.frame_post_draw.is_connected(_on_post_render_eraser):
		RenderingServer.frame_post_draw.connect(_on_post_render_eraser)


func end_stroke() -> void:
	if past_drawing_actions.size() >= MAX_PAST_ACTIONS:
		var front_action: TempDrawingAction = past_drawing_actions.pop_front()
		past_actions_overflow.append(front_action)
		used_temp_data_kb -= front_action.data_usage_kb
		used_overflow_data_kb += front_action.data_usage_kb
	
	if RenderingServer.frame_post_draw.is_connected(_on_post_render):
		end_brush_stroke()
	if RenderingServer.frame_post_draw.is_connected(_on_post_render_eraser):
		end_eraser_brush_stroke()
	current_stroke.is_finished = true
	var to_delete: bool = current_stroke.trim_down()
	if to_delete:
		current_stroke.queue_free()
	else:
		past_drawing_actions.append(current_stroke)
	used_temp_data_kb += current_stroke.data_usage_kb
	check_save_request_needed()
	
	current_stroke = add_temp_drawing_action()
	# If inputting an action, can't redo anymore
	for i in future_drawing_actions.size():
		var remove: TempDrawingAction = future_drawing_actions.pop_front()
		used_temp_data_kb -= remove.data_usage_kb
		remove.queue_free()


func end_brush_stroke() -> void:
	RenderingServer.frame_post_draw.disconnect(_on_post_render)
	active_brush_shader.set_shader_parameter("can_draw", false)
	var prev_img: Image = brush_sub_viewport.get_texture().get_image()
	current_stroke.set_final_texture(prev_img)
	current_stroke.material = Material.new()
	current_stroke.reparent(temp_drawing_actions_container)
	current_stroke.set_visibility_layer_bit(2, true)	# Only layers 1 & 3 active
	current_stroke.set_visibility_layer_bit(7, false)


func end_eraser_brush_stroke() -> void:
	RenderingServer.frame_post_draw.disconnect(_on_post_render_eraser)
	active_brush_shader.set_shader_parameter("can_draw", false)
	var prev_img: Image = eraser_sub_viewport.get_texture().get_image()
	current_stroke.set_final_texture(prev_img)


func check_save_request_needed() -> void:
	#print("%03d %0.0fkb actions %03d %0.0fkb overflow actions" % [past_drawing_actions.size(), used_temp_data_kb, past_actions_overflow.size(), used_overflow_data_kb])
	if used_temp_data_kb + used_overflow_data_kb > FORCE_SAVE_REQUEST_KB_LIMIT:
		force_save_request.emit()
	elif used_temp_data_kb + used_overflow_data_kb > FORCE_SAVE_REQUEST_KB_LIMIT * 0.75:
		force_save_message.emit("Consider saving to free %0.0fMb VRAM. WIll force save changes at %0.0fMb" % [(used_temp_data_kb + used_overflow_data_kb) / 1024.0, FORCE_SAVE_REQUEST_KB_LIMIT / 1024.0])


func undo_drawing_action() -> bool:
	if past_drawing_actions.size() == 0:
		return false
	past_drawing_actions[-1].visible = false
	future_drawing_actions.append(past_drawing_actions.pop_back())
	return true


func redo_drawing_action() -> bool:
	if future_drawing_actions.size() == 0:
		return false
	future_drawing_actions[-1].visible = true
	past_drawing_actions.append(future_drawing_actions.pop_back())
	return true


func toggle_past_drawing_actions(toggled_on: bool) -> void:
	for act in past_drawing_actions:
		act.visible = toggled_on


func make_drawing_actions_permanent() -> Array[Vector2i]:
	var all_requests: Array[Vector2i] = []
	for action in past_drawing_actions:
		var requests = action.occupied_regions
		for r in requests:
			if !all_requests.has(r):
				all_requests.append(r)
	for action in past_actions_overflow:
		var requests = action.occupied_regions
		for r in requests:
			if !all_requests.has(r):
				all_requests.append(r)
	return all_requests


func make_past_and_overflow_actions_permanent(past_ratio: float) -> Array[Vector2i]:
	past_ratio = clampf(past_ratio, 0.0, 1.0)
	var past_action_count: int = int(past_ratio * past_drawing_actions.size())
	for count in range(past_action_count):
		var front_action: TempDrawingAction = past_drawing_actions.pop_front()
		past_actions_overflow.append(front_action)
		used_temp_data_kb -= front_action.data_usage_kb
		used_overflow_data_kb += front_action.data_usage_kb
	toggle_past_drawing_actions(false)
	var all_requests: Array[Vector2i] = []
	for action in past_actions_overflow:
		var requests = action.occupied_regions
		for r in requests:
			if !all_requests.has(r):
				all_requests.append(r)
	return all_requests


func clear_all_drawing_actions() -> void:
	for action in past_drawing_actions:
		action.queue_free()
	past_drawing_actions.clear()
	for action in future_drawing_actions:
		action.queue_free()
	future_drawing_actions.clear()
	for action in past_actions_overflow:
		action.queue_free()
	past_actions_overflow.clear()
	used_overflow_data_kb = 0.0
	used_temp_data_kb = 0.0


func clear_all_overflow_actions() -> void:
	for action in future_drawing_actions:
		action.queue_free()
	future_drawing_actions.clear()
	for action in past_actions_overflow:
		action.queue_free()
	past_actions_overflow.clear()
	used_overflow_data_kb = 0.0


func erase_everything() -> void:
	clear_all_drawing_actions()
	for r in regions:
		regions[r].queue_free()
	regions.clear()


func update_regions_from_screenshots(screenshots: Dictionary[Vector2i, Image]) -> void:
	for r in screenshots:
		if !regions.has(r):
			add_drawing_region(r)
		regions[r].update_from_image(screenshots[r])


func add_temp_drawing_action() -> TempDrawingAction:
	var temp = load(temp_drawing_action_scene).instantiate()
	temp_drawing_actions_container.add_child(temp)
	temp.name = "TempDrawingAction"
	temp.size = size
	temp.position = position
	temp.init_image(size.x, size.y)
	return temp


func add_drawing_region(region_v2i: Vector2i) -> void:
	var reg = load(drawing_region_scene).instantiate()
	drawing_regions_container.add_child(reg)
	reg.name = "DrawingRegion (%02d %02d)" % [region_v2i.x, region_v2i.y]
	reg.size = Vector2(1024.0, 1024.0)
	reg.position = Vector2(region_v2i.x * 1024.0, region_v2i.y * 1024.0)
	regions[region_v2i] = reg
	reg.move_to_front()


## Repositions the current_stroke TempDrawingAction to the current viewport
func update_drawing_position_and_scale(pos: Vector2, scl: Vector2) -> void:
	var new_scale_x: float = 1.0 / scl.x
	var new_scale_y: float = 1.0 / scl.x
	# Clamping to 1.0 minimum scale so the pixels on the TempDrawingAction 
	# Won't be smaller than the pixels in the final DrawingRegion
	var clamped_scale_x: float = clampf(1.0 / scl.x, 1.0, 100.0)
	var clamped_scale_y: float = clampf(1.0 / scl.x, 1.0, 100.0)
	current_stroke.scale = Vector2(clamped_scale_x, clamped_scale_y)
	current_stroke.position = pos * Vector2(new_scale_x, new_scale_y)
	current_stroke.capped_zoom = new_scale_x if new_scale_x < 1.0 else 1.0
	brush_eraser_texture.scale = Vector2(clamped_scale_x, clamped_scale_y)
	brush_eraser_texture.position = pos * Vector2(new_scale_x, new_scale_y)
	brush_eraser_texture.capped_zoom = new_scale_x if new_scale_x < 1.0 else 1.0
	brush_draw_viewport_container.scale = Vector2(clamped_scale_x, clamped_scale_y)
	brush_draw_viewport_container.position = pos * Vector2(new_scale_x, new_scale_y)


func resize(s: Vector2) -> void:
	size = s
	brush_eraser_texture.size = s
	eraser_sub_viewport.size = s
	if !current_stroke.is_finished:
		current_stroke.size = s
		current_stroke.init_image(int(s.x), int(s.y))


# -------- .json save method: Saving all images directly inside the .json file -------- 
# SAVE .PNG DATA IN JSON DICTIONARY
func save_all_images_to_json() -> void:
	var dict: Dictionary
	var regions_to_save: Array[Vector2i]
	call_deferred("emit_signal", "saving_images_to_disk", "Preparing to save image data")
	
	for r in regions:
		# Has changes, not invisible
		if regions[r].prepare_image_to_save():
			regions_to_save.append(r)
		# if old data exists but doesn't have changes also write it
		elif regions[r].serialized_data != "":
			dict["%02d-%02d"%[r.x, r.y]] = regions[r].serialized_data
	
	var saved_num: int = 0
	for r in regions_to_save:
		dict["%02d-%02d"%[r.x, r.y]] = regions[r].get_serialized_image_data()
		saved_num += 1
		call_deferred("emit_signal", "saving_images_to_disk", "Saving image data: %d / %d" % [saved_num, regions_to_save.size()])
	
	# If images get fully erased, they don't get saved in place of the old one,
	# The old image needs to be deleted because it is outdated
	var to_remove: Array[Vector2i] = []
	for r in regions:
		var remove_region: bool = false
		if regions[r].image.is_invisible() and regions[r].has_changes:
			regions[r].is_invisible = true
			regions[r].has_changes = false
			regions[r].is_loaded = false
			regions[r].file_path = ""
			dict.erase("%02d-%02d"%[r.x, r.y])
			remove_region = true
		
		regions[r].free_image()
		if remove_region:
			to_remove.append(r)
	complete_json_image_data = dict


# LOAD .PNG FROM JSON DICTIONARY DATA
func rebuild_images_from_json(dict: Dictionary) -> void:
	for key in dict:
		var reg_v2i: Vector2i = Vector2i(int(key.get_slice("-", 0)), int(key.get_slice("-", 1)))
		var image_data: String = dict[key]
		add_drawing_region(reg_v2i)
		regions[reg_v2i].serialized_data = image_data
		regions[reg_v2i].load_from_data()


# UNLOAD IMAGES THAT HAVE SERIALIZED DATA
func unload_all_drawing_regions_with_data() -> void:
	for r in regions:
		if regions[r].serialized_data != "" and regions[r].is_loaded:
			regions[r].unload()


# RELOAD FROM PATHS THREADED
func reload_all_drawing_regions_from_data() -> bool:
	for r in regions:
		if regions[r].serialized_data != "" and !regions[r].is_loaded and !regions_being_loaded.has(r):
			var task_id = WorkerThreadPool.add_task(regions[r].load_from_data, false)
			image_load_tasks[task_id] = r
			regions_being_loaded[r] = true
	if image_load_tasks.size() == 0:
		return false
	return true


# -------- Folder save method: Saving all images inside user:// folder -------- 
# SAVE FILES
func save_all_images_to_folder() -> void:
	var saved_num: int = 0
	var regions_to_save: Array[Vector2i]
	if !DirAccess.dir_exists_absolute("user://%s" % folder_path):
		DirAccess.make_dir_absolute("user://%s" % folder_path)
	call_deferred("emit_signal", "saving_images_to_disk", "Preparing to save images")
	for r in regions:
		if regions[r].prepare_image_to_save():
			regions_to_save.append(r)
	for save_r in regions_to_save:
		var image_path: String = "user://%s/%02d-%02d.png" % [folder_path, save_r.x, save_r.y]
		regions[save_r].save_image(image_path)
		regions[save_r].file_path = image_path
		saved_num += 1
		call_deferred("emit_signal", "saving_images_to_disk", "Saving images to disk: %d / %d" % [saved_num, regions_to_save.size()])
	
	# If images get fully erased, they don't get saved in place of the old one,
	# The old image needs to be deleted because it is outdated
	var to_remove: Array[Vector2i] = []
	for r in regions:
		var remove_region: bool = false
		if regions[r].image.is_invisible() and regions[r].has_changes:
			#print("DrawingRegion erased ", r)
			regions[r].is_invisible = true
			regions[r].has_changes = false
			regions[r].is_loaded = false
			regions[r].file_path = ""
			remove_region = true
			DirAccess.remove_absolute("user://%s/%02d-%02d.png" % [folder_path, r.x, r.y])
		regions[r].free_image()
		if remove_region:
			to_remove.append(r)
	
	for r in to_remove:
		regions[r].queue_free()
		regions.erase(r)


# SAVE IMAGE PATHS
func drawing_region_paths_to_json() -> Dictionary:
	var dict: Dictionary = {}
	for r in regions:
		if !regions[r].is_invisible:
			dict["%02d-%02d"%[r.x, r.y]] = "user://%s/%02d-%02d.png" % [folder_path, r.x, r.y]
	return dict


# LOAD IMAGE PATHS
func rebuild_file_paths_from_json(dict: Dictionary) -> void:
	for key in dict:
		var reg_v2i: Vector2i = Vector2i(int(key.get_slice("-", 0)), int(key.get_slice("-", 1)))
		var image_path: String = dict[key]
		if FileAccess.file_exists(image_path):
			add_drawing_region(reg_v2i)
			regions[reg_v2i].file_path = image_path
		else:
			printerr("Drawing region (%d, %d) image file doesn't exist, check user:// folder or JSON save file" % [reg_v2i.x, reg_v2i.y])


# RELOAD FROM PATHS THREADED
func reload_all_drawing_regions_from_path() -> bool:
	for r in regions:
		if regions[r].file_path != "" and !regions[r].is_loaded and !regions_being_loaded.has(r):
			var task_id = WorkerThreadPool.add_task(regions[r].load_from_path, false)
			image_load_tasks[task_id] = r
			regions_being_loaded[r] = true
	if image_load_tasks.size() == 0:
		return false
	return true


# UNLOAD IMAGES THAT HAVE A FILE PATH
func unload_all_drawing_regions_with_path() -> void:
	for r in regions:
		if regions[r].file_path != "" and regions[r].is_loaded:
			regions[r].unload()
