extends Control

@export_file("*.tscn") var temp_drawing_region_scene
@export_file("*.tscn") var drawing_region_scene
var MAX_PAST_ACTIONS: int = 100
var window_size: Vector2
var current_stroke: TempDrawingRegion
var past_drawing_actions: Array[TempDrawingRegion]
var future_drawing_actions: Array[TempDrawingRegion]
var regions: Dictionary[Vector2i, DrawingRegion]
var folder_path: String		## Folder inside user:// in which the images are stored, only used on save


func _ready() -> void:
	size = get_viewport_rect().size
	current_stroke = add_temp_drawing_region()


func _process(_delta: float) -> void:
	# TODO: move into main.gd or canvas.gd
	if Input.is_action_just_pressed("undo"):
		undo_drawing_action()
	if Input.is_action_just_pressed("redo"):
		redo_drawing_action()


func receive_coords(p1: Vector2, p2: Vector2) -> void:
	current_stroke.draw_pencil_1px(p1, p2)


func end_stroke() -> void:
	if past_drawing_actions.size() >= MAX_PAST_ACTIONS:
		var removed_last_action: TempDrawingRegion = past_drawing_actions.pop_front()
		blit_into_drawing_region(removed_last_action.get_drawing_region_chunks())
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
		blit_into_drawing_region(action.get_drawing_region_chunks())
		action.queue_free()
	past_drawing_actions.clear()


func blit_into_drawing_region(dict: Dictionary[Vector4i, Image]) -> void:
	for key in dict:
		var region_v2i: Vector2i = Vector2i(key.x, key.y)
		if !regions.has(region_v2i):
			add_drawing_region(region_v2i)
		regions[region_v2i].blit_at(Vector2i(key.z, key.w), dict[key])


func add_temp_drawing_region() -> TempDrawingRegion:
	var temp = load(temp_drawing_region_scene).instantiate()
	add_child(temp)
	temp.size = size
	temp.position = position
	temp.init_image(size.x, size.y)
	return temp


func add_drawing_region(region_v2i: Vector2i) -> void:
	var reg = load(drawing_region_scene).instantiate()
	add_child(reg)
	reg.size = Vector2(1024.0, 1024.0)
	reg.position = Vector2(region_v2i.x * 1024.0, region_v2i.y * 1024.0)
	regions[region_v2i] = reg


func update_drawing_position_and_scale(pos: Vector2, scl: Vector2) -> void:
	current_stroke.scale = Vector2(1.0 / scl.x, 1.0 / scl.y)
	current_stroke.position = pos * (1.0 / scl.x)


func resize_to_window() -> void:
	size = get_viewport_rect().size
	current_stroke.size = size


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
