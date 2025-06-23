extends CanvasGroup
class_name CanvasDrawingGroup
## Group together TempDrawingRegions & DrawingRegions to blend them together
## and make materials with BLEND_MODE_SUB subtract from the resulting image easily
## CanvasDrawingGroup, TempDrawingRegion & DrawingRegion need to all be on the same z_index

@onready var drawing_regions_container: Control = $DrawingRegionsContainer
@onready var temp_drawing_regions_container: Control = $TempDrawingRegionsContainer

var current_stroke: TempDrawingRegion
var past_drawing_actions: Array[TempDrawingRegion]
## When undo-ing, the last TempDrawingRegion from past_drawing_actions gets removed and placed here
var future_drawing_actions: Array[TempDrawingRegion]
## When past_drawing_actions is full, the front TempDrawingRegion gets removed and placed here
var past_actions_overflow: Array[TempDrawingRegion]
var regions: Dictionary[Vector2i, DrawingRegion]
var pencil_material: CanvasItemMaterial
var eraser_material: CanvasItemMaterial
var mask_eraser_material: CanvasItemMaterial

var MAX_PAST_ACTIONS: int = 50
var SAVE_REQUEST_KB_LIMIT: float = 50000.0
var FORCE_SAVE_REQUEST_KB_LIMIT: float = 500000.0
var temp_drawing_region_scene
var drawing_region_scene
var folder_path: String = ""
var size: Vector2
var used_temp_data_kb: float = 0.0
var used_overflow_data_kb: float = 0.0

signal save_request
signal force_save_request
@warning_ignore("unused_signal")
## Used inside a call_deferred, due to save_all_regions_to_disk() being called from a different thread
signal saving_images_to_disk

enum DrawTool {
	PENCIL,
	ERASER,
}

#func _process(_delta: float) -> void:
	#if Input.is_action_just_pressed("test"):
		#toggle_past_drawing_actions(false)
	#if Input.is_action_just_pressed("test2"):
		#toggle_past_drawing_actions(true)


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
	current_stroke = add_temp_drawing_region()


func has_changes() -> bool:
	if past_drawing_actions.size() > 0:
		return true
	return false


func receive_coords(p1: Vector2, p2: Vector2, draw_tool: int) -> void:
	var to_set_material: bool = true if current_stroke.type != draw_tool else false
	if to_set_material:
		current_stroke.type = draw_tool
	if draw_tool == DrawTool.PENCIL:
		if to_set_material:
			current_stroke.material = pencil_material
		current_stroke.draw_pencil_1px(p1, p2, Color.WHITE)
	elif draw_tool == DrawTool.ERASER:
		if to_set_material:
			current_stroke.material = eraser_material
		current_stroke.eraser_pencil_1px(p1, p2)
	elif draw_tool == 99:	# unused
		if to_set_material:
			current_stroke.material = mask_eraser_material
		if !current_stroke.is_mask:
			current_stroke.make_mask()
		current_stroke.mask_eraser_pencil_1px(p1, p2)


func receive_click(p: Vector2, draw_tool: int) -> void:
	current_stroke.type = draw_tool
	if draw_tool == DrawTool.PENCIL:
		current_stroke.material = pencil_material
		current_stroke.draw_pencil_dot_1px(p, Color.WHITE)
	elif draw_tool == DrawTool.ERASER:
		current_stroke.material = eraser_material
		current_stroke.eraser_pencil_dot_1px(p)
	elif draw_tool == 99:	# unused
		current_stroke.material = mask_eraser_material
		if !current_stroke.is_mask:
			current_stroke.make_mask()
		current_stroke.mask_eraser_pencil_dot_1px(p)


func end_stroke() -> void:
	if past_drawing_actions.size() >= MAX_PAST_ACTIONS:
		var front_action: TempDrawingRegion = past_drawing_actions.pop_front()
		past_actions_overflow.append(front_action)
		used_temp_data_kb -= front_action.data_usage_kb
		used_overflow_data_kb += front_action.data_usage_kb
	current_stroke.is_finished = true
	var to_delete: bool = current_stroke.trim_down()
	if to_delete:
		current_stroke.queue_free()
	else:
		past_drawing_actions.append(current_stroke)
	used_temp_data_kb += current_stroke.data_usage_kb
	check_save_request_needed()
	current_stroke = add_temp_drawing_region()
	# If inputting an action, can't redo anymore
	for i in future_drawing_actions.size():
		var remove: TempDrawingRegion = future_drawing_actions.pop_front()
		used_temp_data_kb -= remove.data_usage_kb
		remove.queue_free()


func check_save_request_needed() -> void:
	print("%03d %0.0fkb actions %03d %0.0fkb overflow actions" % [past_drawing_actions.size(), used_temp_data_kb, past_actions_overflow.size(), used_overflow_data_kb])
	if used_overflow_data_kb > SAVE_REQUEST_KB_LIMIT:
		save_request.emit()
	if used_temp_data_kb + used_overflow_data_kb > FORCE_SAVE_REQUEST_KB_LIMIT:
		force_save_request.emit()


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
		var requests = action.get_drawing_regions_array()
		for r in requests:
			if !all_requests.has(r):
				all_requests.append(r)
	for action in past_actions_overflow:
		var requests = action.get_drawing_regions_array()
		for r in requests:
			if !all_requests.has(r):
				all_requests.append(r)
	return all_requests


func make_past_and_overflow_actions_permanent(past_ratio: float) -> Array[Vector2i]:
	past_ratio = clampf(past_ratio, 0.0, 1.0)
	var past_action_count: int = int(past_ratio * past_drawing_actions.size())
	for count in range(past_action_count):
		var front_action: TempDrawingRegion = past_drawing_actions.pop_front()
		past_actions_overflow.append(front_action)
		used_temp_data_kb -= front_action.data_usage_kb
		used_overflow_data_kb += front_action.data_usage_kb
	toggle_past_drawing_actions(false)
	var all_requests: Array[Vector2i] = []
	for action in past_actions_overflow:
		var requests = action.get_drawing_regions_array()
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


#func blit_into_drawing_region(dict: Dictionary[Vector4i, Image], draw_tool: int) -> void:
	#for key in dict:
		#var region_v2i: Vector2i = Vector2i(key.x, key.y)
		#if !regions.has(region_v2i):
			#add_drawing_region(region_v2i)
		#if draw_tool == DrawTool.PENCIL:
			# regions[region_v2i].blit_at(Vector2i(key.z, key.w), dict[key])
		#if draw_tool == DrawTool.ERASER:
			# regions[region_v2i].mask_at(Vector2i(key.z, key.w), dict[key])


func add_temp_drawing_region() -> TempDrawingRegion:
	var temp = load(temp_drawing_region_scene).instantiate()
	temp_drawing_regions_container.add_child(temp)
	temp.name = "TempDrawingRegion"
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


# Repositions the temp drawing region where the drawing takes place
func update_drawing_position_and_scale(pos: Vector2, scl: Vector2) -> void:
	var new_scale_x: float = 1.0 / scl.x
	var new_scale_y: float = 1.0 / scl.x
	# Clamping to 1.0 minimum scale so the pixels on the TempDrawingRegion 
	# Won't be smaller than the pixels in the final DrawingRegion
	var clamped_scale_x: float = clampf(1.0 / scl.x, 1.0, 100.0)
	var clamped_scale_y: float = clampf(1.0 / scl.x, 1.0, 100.0)
	current_stroke.scale = Vector2(clamped_scale_x, clamped_scale_y)
	current_stroke.position = pos * Vector2(new_scale_x, new_scale_y)
	current_stroke.capped_zoom = new_scale_x if new_scale_x < 1.0 else 1.0


func drawing_region_paths_to_json() -> Dictionary:
	var dict: Dictionary = {}
	for r in regions:
		if !regions[r].is_invisible:
			dict["%02d-%02d"%[r.x, r.y]] = "user://%s/%02d-%02d.png" % [folder_path, r.x, r.y]
	return dict


func save_all_regions_to_disk() -> void:
	var saved_num: int = 0
	var regions_to_save: Array[Vector2i]
	if !DirAccess.dir_exists_absolute("user://%s" % folder_path):
		DirAccess.make_dir_absolute("user://%s" % folder_path)
	call_deferred("emit_signal", "saving_images_to_disk", "Preparing to save images")
	for r in regions:
		if regions[r].prepare_image_to_save():
			regions_to_save.append(r)
	
	for save_r in regions_to_save:
		regions[save_r].save_image("user://%s/%02d-%02d.png" % [folder_path, save_r.x, save_r.y])
		saved_num += 1
		call_deferred("emit_signal", "saving_images_to_disk", "Saving images to disk: %d / %d" % [saved_num, regions_to_save.size()])
	
	# If images get fully erased, they don't get saved in place of the old one,
	# The old image needs to be deleted because it is outdated
	for r in regions:
		if regions[r].image.is_invisible() and regions[r].has_changes:
			DirAccess.remove_absolute("user://%s/%02d-%02d.png" % [folder_path, r.x, r.y])
		regions[r].free_image()
	#print("Saved %d images" % saved_num)


func rebuild_from_json(dict: Dictionary) -> void:
	for key in dict:
		var reg_v2i: Vector2i = Vector2i(int(key.get_slice("-", 0)), int(key.get_slice("-", 1)))
		var image_path: String = dict[key]
		if FileAccess.file_exists(image_path):
			var image: Image = Image.load_from_file(image_path)
			add_drawing_region(reg_v2i)
			regions[reg_v2i].update_from_image(image, false)
			#image = Image.new()
		else:
			printerr("Drawing region (%d, %d) image file doesn't exist, check user:// folder or JSON save file" % [reg_v2i.x, reg_v2i.y])


func resize(s: Vector2) -> void:
	size = s
	if !current_stroke.is_finished:
		current_stroke.size = s
		current_stroke.init_image(int(s.x), int(s.y))
