class_name ListDragHelper
## Manages offset transforms to move entries away visually from the dragged object

var object_id: int	## Dragging object ID
var current: int	## Current position ID, where object_id will be
var lowest: int		## Lowest position ID
var highest: int	## Highest position ID
var list: Array[ListTextEntry]
var is_dragging_child: bool = false		## Dragging list child inside the list
var is_dragging_outside: bool = false	## Dragging an entry from a different list to this list
var initial_scroll_y: int = 0
var indicator_size_y: float = 25.0
var scroll_diff: Vector2 = Vector2.ZERO
var offset: Vector2 = Vector2.ZERO


func start_drag_child(obj_id: int, _list: Array[ListTextEntry], _event_position: Vector2, indicator_size: float, init_scroll: int) -> void:
	list = _list
	object_id = obj_id
	current = obj_id
	lowest = obj_id
	highest = obj_id
	list[object_id].offset_transform_position = _event_position
	indicator_size_y = indicator_size
	initial_scroll_y = init_scroll
	is_dragging_child = true
	scroll_diff = Vector2.ZERO
	offset = Vector2.ZERO
	toggle_entry_hover(false)


func start_drag_from_outside(_list: Array[ListTextEntry], indicator_size: float, init_scroll: int) -> void:
	list = _list
	object_id = 0
	current = 0
	lowest = 0
	highest = 0
	indicator_size_y = indicator_size
	initial_scroll_y = init_scroll
	is_dragging_outside = true
	scroll_diff = Vector2.ZERO
	offset = Vector2.ZERO
	toggle_entry_hover(false)


func end_drag() -> void:
	for entry in list:
		entry.offset_transform_position = Vector2.ZERO
	toggle_entry_hover(true)
	list = []
	object_id = 0
	current = 0
	lowest = 0
	highest = 0
	is_dragging_child = false
	is_dragging_outside = false


func drag_child() -> void:
	var drag_pos: Vector2 = list[object_id].offset_transform_position + list[object_id].position
	var previous: int = get_previous_visible_id()
	var next: int = get_next_visible_id()
	if previous >= 0 and drag_pos.y < list[previous].position.y + list[previous].size.y:
		current = previous
		print("LOWER")
		if lowest > current:
			lowest = current
		drag_inside_visual_offsets(object_id)
		# Reset offsets if going opposite direction - was going up, now going down
		if current < highest and highest != object_id:
			list[highest].offset_transform_position = Vector2.ZERO
			highest = current
	elif next >= 0 and next < list.size() and drag_pos.y > list[next].position.y:
		current = next
		print("HIGHER")
		if highest < current:
			highest = current
		drag_inside_visual_offsets(object_id)
		# Reset offsets if going opposite direction - was going down, now going up
		if current > lowest and lowest != object_id:
			list[lowest].offset_transform_position = Vector2.ZERO
			lowest = current


# TODO optimize return early, without a var
func get_previous_visible_id() -> int:
	var prev: int = -1
	if current > 0:
		for i in range(0, current):
			if list[i].visible:
				prev = i
	return prev


func get_next_visible_id() -> int:
	for i in range(current + 1, list.size()):
		if list[i].visible:
			return i
	return -1



func accumulate_position(event_relative: Vector2, new_scroll_y: int) -> Vector2:
	scroll_diff = Vector2(0.0, float(new_scroll_y - initial_scroll_y))
	offset += event_relative
	return offset + scroll_diff


# TODO work with hidden entries
func drag_from_outside(drag_pos: Vector2, new_scroll_y: int) -> void:
	scroll_diff = Vector2(0.0, float(new_scroll_y))
	drag_pos += scroll_diff
	# Before first entry
	if drag_pos.y < 20.0:
		current = 0
		return
	for entry in list:
		# After last entry
		if entry.id == list.size() - 1 and drag_pos.y > entry.position.y + entry.size.y * 0.4:
			current = list.size() # TODO return last visible ID
		elif entry.visible and drag_pos.y > entry.position.y + entry.size.y:
			current = entry.id + 1
	drag_from_outside_visual_offsets()


func drag_from_outside_visual_offsets() -> void:
	for entry in list:
		#printt("%d %d" % [entry.id, current - 1])
		if entry.id > (current - 1):
			entry.offset_transform_position = Vector2(0.0, indicator_size_y)
		else:
			entry.offset_transform_position = Vector2.ZERO


func drag_inside_visual_offsets(moving_entry_id: int) -> void:
	for entry in list:
		if entry.id >= current and entry.id < moving_entry_id:
			entry.offset_transform_position = Vector2(0.0, list[moving_entry_id].size.y)
		if entry.id <= current and entry.id > moving_entry_id:
			entry.offset_transform_position = Vector2(0.0, -list[moving_entry_id].size.y)


func toggle_entry_hover(on: bool) -> void:
	for entry in list:
		#if !on and !entry.grabber_clicked:
			#entry._on_hover(false)
		entry.can_hover = on
