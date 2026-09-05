class_name ListDragHelper
## Manages offset transforms to move list entries away visually from the dragged object

var list: Array[ListTextEntry]
var drop_visual: Control
var object_id: int = -1		## Dragging object ID
var current: int = -1		## Current position ID, where object_id will be
var lowest: int = -1		## Lowest position ID
var highest: int = -1		## Highest position ID
var is_dragging_child: bool = false		## Dragging list child inside the list
var is_dragging_outside: bool = false	## Dragging an entry from a different list to this list
var position_data: DragPositionData

class DragPositionData:
	var event_offset: Vector2				## Update
	var scroll_y: int						## Update
	var scroll_offset: Vector2				## Calculate based on scroll_y & initial value
	var initial_scroll_y: int = 0			## Set @ _init
	var top_left_margin: Vector2			## Set @ _init
	var separation: float = 0				## Set @ _init
	var scroll_container_position: Vector2	## Set @ _init
	
	func _init(_top_left_margin: Vector2, _h_box_separation: int, _initial_scroll_y: int, _scroll_container_position: Vector2) -> void:
		event_offset = Vector2.ZERO
		scroll_offset = Vector2.ZERO
		scroll_y = 0
		top_left_margin = _top_left_margin
		separation = float(_h_box_separation) * 0.5
		initial_scroll_y = _initial_scroll_y
		scroll_container_position = _scroll_container_position


func start_drag_child(obj_id: int, entry_list: Array[ListTextEntry], event_position: Vector2, _drop_visual: Control, drag_position_data: DragPositionData) -> void:
	list = entry_list
	drop_visual = _drop_visual
	drop_visual.size = list[obj_id].size
	object_id = obj_id
	current = obj_id
	lowest = obj_id
	highest = obj_id
	position_data = drag_position_data
	list[object_id].offset_transform_position = event_position
	list[object_id].initial_grabber_event = event_position
	is_dragging_child = true
	toggle_all_entries_hover(false)


func start_drag_from_outside(entry_list: Array[ListTextEntry], _drop_visual: Control, drag_position_data: DragPositionData) -> void:
	list = entry_list
	drop_visual = _drop_visual
	object_id = 0
	current = 0
	lowest = 0
	highest = 0
	position_data = drag_position_data
	is_dragging_outside = true
	toggle_all_entries_hover(false)


func end_drag() -> void:
	reset_offset_transforms()
	toggle_all_entries_hover(true)
	reset_data()


func reset_offset_transforms() -> void:
	for entry in list:
		entry.offset_transform_position = Vector2.ZERO


func reset_data() -> void:
	is_dragging_child = false
	is_dragging_outside = false
	list = []
	position_data = null
	object_id = 0
	current = 0
	lowest = 0
	highest = 0


func get_previous_visible_id() -> int:
	if current > 0:
		for i in range(current - 1, -1, -1):	## From previous to 0
			if list[i].visible:
				return i
	return -1


func get_next_visible_id() -> int:
	for i in range(current + 1, list.size()):	## From next to last
		if list[i].visible:
			return i
	return -1


func get_last_visible_id() -> int:
	for i in range(list.size() - 1, -1, -1):	## From last to 0
		if list[i].visible:
			return i
	return -1


func accumulate_position(event_relative: Vector2, new_scroll_y: int) -> void:
	position_data.scroll_y = new_scroll_y
	position_data.scroll_offset = Vector2(0.0, float(position_data.scroll_y - position_data.initial_scroll_y))
	position_data.event_offset += event_relative
	list[object_id].offset_transform_position = (position_data.event_offset + position_data.scroll_offset)


func drag_child() -> void:
	var drag_pos: Vector2 = list[object_id].offset_transform_position + list[object_id].position
	var previous: int = get_previous_visible_id()
	var next: int = get_next_visible_id()
	if previous >= 0 and drag_pos.y < list[previous].position.y + list[previous].size.y:
		current = previous
		if lowest > current:
			lowest = current
		drag_inside_visual_offsets(object_id)
		# Reset offsets if going opposite direction - was going up, now going down
		if current < highest and highest != object_id:
			list[highest].offset_transform_position = Vector2.ZERO
			highest = current
	elif next >= 0 and next < list.size() and drag_pos.y > list[next].position.y:
		current = next
		if highest < current:
			highest = current
		drag_inside_visual_offsets(object_id)
		# Reset offsets if going opposite direction - was going down, now going up
		if current > lowest and lowest != object_id:
			list[lowest].offset_transform_position = Vector2.ZERO
			lowest = current


func drag_from_outside(drag_pos: Vector2, new_scroll_y: int) -> void:
	var last_visible: int = get_last_visible_id()
	if last_visible < 0:
		return
	position_data.scroll_offset = Vector2(0.0, float(new_scroll_y))
	position_data.scroll_y = new_scroll_y
	drag_pos += position_data.scroll_offset
	# Before first entry
	if drag_pos.y < 20.0:
		current = 0
		#return
	for entry in list:
		# After last entry
		if entry.id == last_visible and drag_pos.y > entry.position.y + entry.size.y * 0.4:
			current = last_visible + 1
		elif entry.visible and drag_pos.y > entry.position.y + entry.size.y:
			current = entry.id + 1
	drag_from_outside_visual_offsets()


func drag_from_outside_visual_offsets() -> void:
	for entry in list:
		#printt("%d %d" % [entry.id, current - 1])
		if entry.visible and entry.id > (current - 1):
			entry.offset_transform_position = Vector2(0.0, drop_visual.size.y)
		else:
			entry.offset_transform_position = Vector2.ZERO


func drag_inside_visual_offsets(moving_entry_id: int) -> void:
	for entry in list:
		if entry.id >= current and entry.id < moving_entry_id:
			entry.offset_transform_position = Vector2(0.0, list[moving_entry_id].size.y)
		if entry.id <= current and entry.id > moving_entry_id:
			entry.offset_transform_position = Vector2(0.0, -list[moving_entry_id].size.y)


func position_outside_drop_visual() -> void:
	var after_entry_position: Vector2 = Vector2.ZERO
	var entry_id: int = current - 1
	# Position on empty list
	if list.size() == 0:
		after_entry_position = Vector2.ZERO
	# Position on current entry + its size
	elif entry_id >= 0 and entry_id < list.size():
		after_entry_position = (list[entry_id].position
							+ Vector2(0.0, list[entry_id].size.y))
	drop_visual.position = (after_entry_position
						+ position_data.scroll_container_position
						+ position_data.top_left_margin
						- Vector2(0.0, position_data.scroll_y))


func position_child_drop_visual() -> void:
	if current < 0 or current >= list.size():
		return
	var after_entry_position: Vector2 = Vector2.ZERO
	if current > object_id:		# Going down the list
		after_entry_position = (list[current].offset_transform_position
							+ Vector2(0.0, list[current].size.y)
							+ Vector2(0.0, position_data.separation))
	elif current < object_id:	# Going up the list
		after_entry_position = -Vector2(0.0, position_data.separation)
	drop_visual.position = (list[current].position
						+ after_entry_position
						+ position_data.scroll_container_position
						+ position_data.top_left_margin
						- Vector2(0.0, position_data.scroll_y))


func toggle_all_entries_hover(on: bool) -> void:
	for entry in list:
		entry.can_hover = on
		if !on:
			entry._on_hover(false)
