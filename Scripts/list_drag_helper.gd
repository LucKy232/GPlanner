class_name ListDragHelper

var object_id: int	## Dragging object ID
var current: int	## Current position ID, where object_id will be
var lowest: int		## Lowest position ID
var highest: int	## Highest position ID
var list: Array[ListTextEntry]
var is_dragging_child: bool = false		## Dragging list child inside the list
var is_dragging_outside: bool = false	## Dragging an entry from a different list to this list


func start_drag_child(obj_id: int, _list: Array[ListTextEntry], _event_position: Vector2) -> void:
	list = _list
	object_id = obj_id
	current = obj_id
	lowest = obj_id
	highest = obj_id
	list[object_id].offset_transform_position = _event_position
	is_dragging_child = true


func start_drag_from_outside(_list: Array[ListTextEntry]) -> void:
	list = _list
	object_id = 0
	current = 0
	lowest = 0
	highest = 0
	is_dragging_outside = true


func end_drag() -> void:
	for entry in list:
		entry.offset_transform_position = Vector2.ZERO
	list = []
	object_id = 0
	current = 0
	lowest = 0
	highest = 0
	is_dragging_child = false
	is_dragging_outside = false


func drag_child() -> void:
	var drag_pos: Vector2 = list[object_id].offset_transform_position + list[object_id].position
	if current - 1 >= 0 and drag_pos.y < list[current - 1].position.y:
		current -= 1
		if lowest > current:
			lowest = current
		drag_inside_visual_offsets(object_id)
		# Reset offsets if going opposite direction - was going up, now going down
		if current < highest and highest != object_id:
			list[highest].offset_transform_position = Vector2.ZERO
			highest = current
	elif current + 1 < list.size() and drag_pos.y > list[current + 1].position.y + list[current + 1].size.y * 0.5:
		current += 1
		if highest < current:
			highest = current
		drag_inside_visual_offsets(object_id)
		# Reset offsets if going opposite direction - was going down, now going up
		if current > lowest and lowest != object_id:
			list[lowest].offset_transform_position = Vector2.ZERO
			lowest = current


func drag_from_outside(drag_pos: Vector2) -> void:
	for entry in list:
		if drag_pos.y < 5.0:
			current = 0
		elif drag_pos.y > entry.position.y + entry.size.y:
			current = entry.id + 1
	drag_from_outside_visual_offsets()


func drag_from_outside_visual_offsets() -> void:
	for entry in list:
		if entry.id > (current - 1):
			entry.offset_transform_position = Vector2(0.0, entry.size.y)
		else:
			entry.offset_transform_position = Vector2.ZERO


func drag_inside_visual_offsets(moving_entry_id: int) -> void:
	for entry in list:
		if entry.id >= current and entry.id < moving_entry_id:
			entry.offset_transform_position = Vector2(0.0, list[moving_entry_id].size.y)
		if entry.id <= current and entry.id > moving_entry_id:
			entry.offset_transform_position = Vector2(0.0, -list[moving_entry_id].size.y)
