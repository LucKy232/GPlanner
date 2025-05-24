extends CanvasGroup
class_name CanvasDrawingGroup

var current_stroke: TempDrawingRegion
var past_drawing_actions: Array[TempDrawingRegion]
var future_drawing_actions: Array[TempDrawingRegion]
var regions: Dictionary[Vector2i, DrawingRegion]
var pencil_material: CanvasItemMaterial
var eraser_material: CanvasItemMaterial

var temp_drawing_region_scene
var drawing_region_scene
var folder_path: String = ""
var size: Vector2
var MAX_PAST_ACTIONS: int = 100

enum DrawTool {
	PENCIL,
	ERASER,
}


func init(manager_size: Vector2) -> void:
	pencil_material = CanvasItemMaterial.new()
	pencil_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	eraser_material = CanvasItemMaterial.new()
	eraser_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	size = manager_size
	current_stroke = add_temp_drawing_region()


func receive_coords(p1: Vector2, p2: Vector2, draw_tool: int) -> void:
	if draw_tool == DrawTool.ERASER and current_stroke.type != DrawTool.ERASER:
		current_stroke.make_mask()
	current_stroke.type = draw_tool
	if draw_tool == DrawTool.PENCIL:
		current_stroke.material = pencil_material
		current_stroke.draw_pencil_1px(p1, p2)
	elif draw_tool == DrawTool.ERASER:
		current_stroke.material = eraser_material
		current_stroke.eraser_pencil_1px(p1, p2)


func end_stroke() -> void:
	print(past_drawing_actions.size())
	if past_drawing_actions.size() >= MAX_PAST_ACTIONS:
		var removed_last_action: TempDrawingRegion = past_drawing_actions.pop_front()
		blit_into_drawing_region(removed_last_action.get_drawing_region_chunks(), removed_last_action.type)
		removed_last_action.queue_free()
	past_drawing_actions.append(current_stroke)
	current_stroke = add_temp_drawing_region()
	for i in future_drawing_actions.size():
		future_drawing_actions.pop_front().queue_free()


func undo_drawing_action() -> void:
	if past_drawing_actions.size() == 0:
		return
	past_drawing_actions[-1].visible = false
	future_drawing_actions.append(past_drawing_actions.pop_back())


func redo_drawing_action() -> void:
	if future_drawing_actions.size() == 0:
		return
	future_drawing_actions[-1].visible = true
	past_drawing_actions.append(future_drawing_actions.pop_back())


func make_drawing_actions_permanent() -> void:
	printt("Actions: %d" % past_drawing_actions.size())
	for action in past_drawing_actions:
		blit_into_drawing_region(action.get_drawing_region_chunks(), action.type)
		action.queue_free()
	past_drawing_actions.clear()


func blit_into_drawing_region(dict: Dictionary[Vector4i, Image], draw_tool: int) -> void:
	for key in dict:
		var region_v2i: Vector2i = Vector2i(key.x, key.y)
		if !regions.has(region_v2i):
			add_drawing_region(region_v2i)
		if draw_tool == DrawTool.PENCIL:
			regions[region_v2i].blit_at(Vector2i(key.z, key.w), dict[key])
		if draw_tool == DrawTool.ERASER:
			regions[region_v2i].mask_at(Vector2i(key.z, key.w), dict[key])


func add_temp_drawing_region() -> TempDrawingRegion:
	var temp = load(temp_drawing_region_scene).instantiate()
	add_child(temp)
	temp.name = "TempDrawingRegion"
	temp.size = size
	temp.position = position
	temp.init_image(size.x, size.y)
	return temp


func add_drawing_region(region_v2i: Vector2i) -> void:
	var reg = load(drawing_region_scene).instantiate()
	add_child(reg)
	reg.name = "DrawingRegion (%02d %02d)" % [region_v2i.x, region_v2i.y]
	reg.size = Vector2(1024.0, 1024.0)
	reg.position = Vector2(region_v2i.x * 1024.0, region_v2i.y * 1024.0)
	regions[region_v2i] = reg


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
	var saved_num: int = 0
	var dict: Dictionary = {}
	if !DirAccess.dir_exists_absolute("user://%s" % folder_path):
		DirAccess.make_dir_absolute("user://%s" % folder_path)
	for r in regions:
		if !regions[r].image.is_invisible():
			dict["%02d-%02d"%[r.x, r.y]] = "user://%s/%02d-%02d.png" % [folder_path, r.x, r.y]
			if regions[r].has_changes:
				regions[r].image.save_png("user://%s/%02d-%02d.png" % [folder_path, r.x, r.y])
				regions[r].has_changes = false
				saved_num += 1
		# If images get fully erased, they don't get saved in place of the old one,
		# The old image needs to be deleted because it is outdated
		if regions[r].image.is_invisible() and regions[r].has_changes:
			DirAccess.remove_absolute("user://%s/%02d-%02d.png" % [folder_path, r.x, r.y])
	print("Saved %d images" % saved_num)
	return dict


func rebuild_from_json(dict: Dictionary) -> void:
	for key in dict:
		var reg_v2i: Vector2i = Vector2i(int(key.get_slice("-", 0)), int(key.get_slice("-", 1)))
		var image_path: String = dict[key]
		if FileAccess.file_exists(image_path):
			var image: Image = Image.load_from_file(image_path)
			add_drawing_region(reg_v2i)
			regions[reg_v2i].update_texture(image)
		else:
			printerr("Drawing region image file doesn't exist, check user:// folder or JSON save file")
