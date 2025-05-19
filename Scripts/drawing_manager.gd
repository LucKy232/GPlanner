extends Control

@export_file("*.tscn") var temp_drawing_region_scene
@export_file("*.tscn") var drawing_region_scene
var MAX_PAST_ACTIONS: int = 100
var window_size: Vector2
var current_stroke: TempDrawingRegion
var past_drawing_actions: Array[TempDrawingRegion]
var future_drawing_actions: Array[TempDrawingRegion]
var regions: Dictionary[Vector2i, DrawingRegion]


func _ready() -> void:
	size = get_viewport_rect().size
	current_stroke = add_temp_drawing_region()


func _process(_delta: float) -> void:
	# TODO move to main.gd
	if Input.is_action_just_pressed("save_file"):
		for action in past_drawing_actions:
			blit_into_drawing_region(action.get_drawing_region_chunks())
			action.queue_free()
		past_drawing_actions.clear()
	if Input.is_action_just_pressed("undo"):
		#undo_drawing_action()
		current_stroke.get_drawing_region_chunks()
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


func blit_into_drawing_region(dict: Dictionary[Vector2i, Image]) -> void:
	for key in dict:
		if !regions.has(key):
			add_drawing_region(key)
		regions[key].blit_at(key, dict[key])


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
