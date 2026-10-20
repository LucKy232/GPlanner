class_name ListDragHelper
## Manages offset transforms to move list entries away visually from the dragged object

var entries: Dictionary[int, ListTextEntry]
var order_array: Array[int]
var drop_visual: Control
var entry_order_id: int = -1	## Dragging entry order ID
var current: int = -1			## Current position ID, where entry_order_id will be
var lowest: int = -1			## Lowest position ID
var highest: int = -1			## Highest position ID
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


func pass_references(entries_dict: Dictionary[int, ListTextEntry], order_arr: Array[int], _drop_visual: Control) -> void:
	entries = entries_dict
	order_array = order_arr
	drop_visual = _drop_visual


func start_drag_child(entry_id: int, event_position: Vector2, drag_position_data: DragPositionData) -> void:
	drop_visual.size = entries[entry_id].size
	entry_order_id = entries[entry_id].order_id
	current = entries[entry_id].order_id
	lowest = entries[entry_id].order_id
	highest = entries[entry_id].order_id
	position_data = drag_position_data
	entries[entry_id].offset_transform_position = event_position
	is_dragging_child = true


func start_drag_from_outside(drag_position_data: DragPositionData) -> void:
	entry_order_id = 0
	current = 0
	lowest = 0
	highest = 0
	position_data = drag_position_data
	is_dragging_outside = true


func end_drag() -> void:
	reset_offset_transforms()
	reset_data()


func reset_offset_transforms() -> void:
	for entry in entries:
		entries[entry].offset_transform_position = Vector2.ZERO


func reset_data() -> void:
	is_dragging_child = false
	is_dragging_outside = false
	position_data = null
	entries = {}
	order_array = []
	entry_order_id = 0
	current = 0
	lowest = 0
	highest = 0


func get_previous_visible_id() -> int:
	if current > 0:
		for i in range(current - 1, -1, -1):	## From previous to 0
			var entry_id: int = order_array[i]
			if entries[entry_id].visible:
				return i
	return -1


func get_next_visible_id() -> int:
	for i in range(current + 1, order_array.size()):	## From next to last
		var entry_id: int = order_array[i]
		if entries[entry_id].visible:
			return i
	return -1


func get_last_visible_id() -> int:
	for i in range(order_array.size() - 1, -1, -1):	## From last to 0
		var entry_id: int = order_array[i]
		if entries[entry_id].visible:
			return i
	return -1


func accumulate_position(event_relative: Vector2, new_scroll_y: int) -> void:
	position_data.scroll_y = new_scroll_y
	position_data.scroll_offset = Vector2(0.0, float(position_data.scroll_y - position_data.initial_scroll_y))
	position_data.event_offset += event_relative
	var entry_id: int = order_array[entry_order_id]
	entries[entry_id].offset_transform_position = (position_data.event_offset + position_data.scroll_offset)


func drag_child() -> void:
	var entry_id: int = order_array[entry_order_id]
	var drag_pos: Vector2 = entries[entry_id].offset_transform_position + entries[entry_id].position
	var previous: int = get_previous_visible_id()
	var next: int = get_next_visible_id()
	var previous_entry_id: int = order_array[previous]
	var next_entry_id: int = order_array[next]
	if previous >= 0 and drag_pos.y < entries[previous_entry_id].position.y + entries[previous_entry_id].size.y:
		current = previous
		if lowest > current:
			lowest = current
		drag_inside_visual_offsets(entry_id)
		# Reset offsets if going opposite direction - was going up, now going down
		if current < highest and highest != entry_order_id:
			var highest_entry_id: int = order_array[highest]
			entries[highest_entry_id].offset_transform_position = Vector2.ZERO
			highest = current
	elif next >= 0 and next < entries.size() and drag_pos.y > entries[next_entry_id].position.y:
		current = next
		if highest < current:
			highest = current
		drag_inside_visual_offsets(entry_id)
		# Reset offsets if going opposite direction - was going down, now going up
		if current > lowest and lowest != entry_order_id:
			var lowest_entry_id: int = order_array[lowest]
			entries[lowest_entry_id].offset_transform_position = Vector2.ZERO
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
	for entry_id in order_array:
		# After last entry
		if entries[entry_id].order_id == last_visible and drag_pos.y > entries[entry_id].position.y + entries[entry_id].size.y * 0.4:
			current = last_visible + 1
		elif entries[entry_id].visible and drag_pos.y > entries[entry_id].position.y + entries[entry_id].size.y:
			current = entries[entry_id].order_id + 1
	drag_from_outside_visual_offsets()


func drag_from_outside_visual_offsets() -> void:
	print("ID: ", current)
	for entry_id in entries:
		#printt("%d %d" % [entry.id, current - 1])
		if entries[entry_id].visible and entries[entry_id].order_id > (current - 1):
			entries[entry_id].offset_transform_position = Vector2(0.0, drop_visual.size.y)
		else:
			entries[entry_id].offset_transform_position = Vector2.ZERO


func drag_inside_visual_offsets(moving_entry_id: int) -> void:
	if !entries.has(moving_entry_id):
		push_error("Bad entry ID %d passed to ListDragHelper: drag_inside_visual_offsets()!" % [moving_entry_id])
		return
	for entry_id in entries:
		if entries[entry_id].order_id >= current and entries[entry_id].order_id < entries[moving_entry_id].order_id:
			entries[entry_id].offset_transform_position = Vector2(0.0, entries[moving_entry_id].size.y)
		if entries[entry_id].order_id <= current and entries[entry_id].order_id > entries[moving_entry_id].order_id:
			entries[entry_id].offset_transform_position = Vector2(0.0, -entries[moving_entry_id].size.y)


func position_outside_drop_visual() -> void:
	var after_entry_position: Vector2 = Vector2.ZERO
	var order_id: int = current - 1
	# Position on empty list
	if order_array.size() == 0:
		after_entry_position = Vector2.ZERO
	# Position on current entry + its size
	elif order_id >= 0 and order_id < order_array.size():
		var entry_id: int = order_array[order_id]
		after_entry_position = (entries[entry_id].position
							+ Vector2(0.0, entries[entry_id].size.y))
	drop_visual.position = (after_entry_position
						+ position_data.scroll_container_position
						+ position_data.top_left_margin
						- Vector2(0.0, position_data.scroll_y))


func position_child_drop_visual() -> void:
	if current < 0 or current >= order_array.size():
		return
	var after_entry_position: Vector2 = Vector2.ZERO
	var entry_id: int = order_array[current]
	if current > entry_order_id:		# Going down the list
		after_entry_position = (entries[entry_id].offset_transform_position
							+ Vector2(0.0, entries[entry_id].size.y)
							+ Vector2(0.0, position_data.separation))
	elif current < entry_order_id:	# Going up the list
		after_entry_position = -Vector2(0.0, position_data.separation)
	drop_visual.position = (entries[entry_id].position
						+ after_entry_position
						+ position_data.scroll_container_position
						+ position_data.top_left_margin
						- Vector2(0.0, position_data.scroll_y))
