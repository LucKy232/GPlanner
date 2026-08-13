class_name ObjectList extends Control

@export_file("*.tscn") var list_text_entry_scene
@export_file("*.tscn") var div_scene
@onready var object_v_box: VBoxContainer = %ObjectVBox
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var mouse_hover: Area2D = $MouseHover
@onready var mouse_hover_shape: CollisionShape2D = $MouseHover/MouseHoverShape
@onready var margin_container: MarginContainer = %MarginContainer
@onready var drop_visual: Panel = %DropVisualIndicator
@onready var list_name: TextEdit = %ListName
@onready var drag_and_resize_input: DragAndResizeInput = $DragAndResizeInput
var id: int = -1
var entries: Array[ListTextEntry]
var last_edited_entry_id: int = -1
var dragger: ListDragHelper = ListDragHelper.new()
var canvas_scale: float = 1.0
var mouse_inside: bool = false
var top_left_margin: Vector2 = Vector2.ZERO
# Tween add entry buttons on the bottom
var tween_add_buttons: Tween
var buttons_shown: bool = false
@export var add_buttons_hide_delay: float = 1.5
@export var add_buttons_animation_time: float = 0.5
@onready var hide_animation_timer: Timer = $HideAnimationTimer
@onready var add_buttons_margin: MarginContainer = %AddButtonsMargin

signal list_changed
signal filtered_gui_input
signal can_drop
signal remove_element_request
signal text_edit_active
signal dragging


func _ready() -> void:
	scroll_container.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_PASS
	scroll_container.get_v_scroll_bar().scrolling.connect(_on_scroll)
	top_left_margin = Vector2(margin_container.get_theme_constant("margin_left"), margin_container.get_theme_constant("margin_top"))
	_on_scroll_hover(false)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is ListTextEntry:
		# Is dragging child entry
		if dragger.is_dragging_child:
			mouse_filter = Control.MOUSE_FILTER_STOP	# Stop the input going to canvas
			can_drop.emit()
			return false
		else:
			# Start drag from outside
			if !dragger.is_dragging_outside and !entries.has(data):
				dragger.start_drag_from_outside(entries, drop_visual.size.y, scroll_container.scroll_vertical)
				drop_visual.visible = true
				scroll_container.clip_contents = false
				drop_visual.size = Vector2(object_v_box.size.x, 25.0)
				return true
			# Continue drag from outside
			elif dragger.is_dragging_outside:
				var position_in_list: Vector2 = scroll_container.position
				dragger.drag_from_outside(at_position - position_in_list, scroll_container.scroll_vertical)
				position_drop_visual_on_entry(dragger.current - 1)
				can_drop.emit()		# For visual on canvas
				return true
			else:
				return false
	elif data is ElementLabel:
		# Start drag from outside
		if !dragger.is_dragging_outside and mouse_inside:
			dragger.start_drag_from_outside(entries, drop_visual.size.y, scroll_container.scroll_vertical)
			drop_visual.visible = true
			scroll_container.clip_contents = false
			drop_visual.size = Vector2(object_v_box.size.x, 25.0)
			return true
		# Continue drag from outside
		elif dragger.is_dragging_outside:
			var position_in_list: Vector2 = scroll_container.position
			dragger.drag_from_outside(at_position - position_in_list, scroll_container.scroll_vertical)
			position_drop_visual_on_entry(dragger.current - 1)
			return true
		else:
			return false
	else:
		return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is ListTextEntry:
		data.remove_from_list.emit()
		data.reparent(object_v_box, false)
		connect_list_text_entry(data)
		entries.append(data)
		data.id = dragger.current
		object_v_box.move_child(data, dragger.current)
		sort_entries(entries.size() - 1, dragger.current)	# Last entry added move to its id
		reset_entry_ids()
		mouse_filter = Control.MOUSE_FILTER_PASS
		drop_visual.visible = false
		scroll_container.clip_contents = true
		dragger.end_drag()
	if data is ElementLabel:
		add_text_entry(false)
		entries[-1].set_text(data.get_text())
		object_v_box.move_child(entries[-1], dragger.current)
		sort_entries(entries.size() - 1, dragger.current)
		reset_entry_ids()
		mouse_filter = Control.MOUSE_FILTER_PASS
		drop_visual.visible = false
		scroll_container.clip_contents = true
		dragger.end_drag()
		remove_element_request.emit(data.id)


func toggle_add_buttons(toggle_on: bool) -> void:
	if toggle_on and !hide_animation_timer.is_stopped():
		hide_animation_timer.stop()
	if toggle_on and !buttons_shown:
		if tween_add_buttons and tween_add_buttons.is_running():
			tween_add_buttons.stop()
		tween_add_buttons = create_tween()
		tween_add_buttons.set_parallel().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		var distance_mult: float = (add_buttons_margin.size.y - add_buttons_margin.offset_transform_position.y) / add_buttons_margin.size.y
		add_buttons_margin.visible = true
		tween_add_buttons.tween_property(add_buttons_margin, "offset_transform_position:y", add_buttons_margin.size.y, add_buttons_animation_time * distance_mult)
		tween_add_buttons.tween_property(add_buttons_margin, "modulate:a", 1.0, 0.2)
		buttons_shown = true
	elif !toggle_on and buttons_shown:
		if tween_add_buttons and tween_add_buttons.is_running():
			tween_add_buttons.stop()
		tween_add_buttons = create_tween()
		tween_add_buttons.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween_add_buttons.tween_interval(add_buttons_hide_delay)
		tween_add_buttons.tween_property(add_buttons_margin, "offset_transform_position:y", 0.0, add_buttons_animation_time)
		tween_add_buttons.tween_property(add_buttons_margin, "modulate:a", 0.0, 0.2)
		tween_add_buttons.tween_property(add_buttons_margin, "visible", true, 0.0)
		buttons_shown = false


# Will be called by Canvas when selecting list
func select() -> void:
	pass


func deselect() -> void:
	if list_name.has_focus():
		list_name.release_focus()
	exit_text_edit()


func is_editing_text() -> bool:
	if entries.size() > last_edited_entry_id and last_edited_entry_id >= 0:
		return entries[last_edited_entry_id].is_editing_text()
	return false


func enter_text_edit() -> void:
	if entries.size() > last_edited_entry_id and last_edited_entry_id >= 0:
		entries[last_edited_entry_id].enter_text_edit()


func exit_text_edit() -> void:
	if entries.size() > last_edited_entry_id and last_edited_entry_id >= 0:
		entries[last_edited_entry_id].exit_text_edit()


# moving the entire list
func start_dragging() -> void:
	drag_and_resize_input.is_being_dragged = true
	drag_and_resize_input.is_being_resized = false
	set_default_cursor_shape(Control.CURSOR_DRAG)


# resizing the entire list
func start_resizing() -> void:
	drag_and_resize_input.is_being_resized = true
	drag_and_resize_input.is_being_dragged = false
	set_default_cursor_shape(Control.CURSOR_FDIAGSIZE)


# When moving/resizing the entire list
func end_input() -> void:
	drag_and_resize_input.end()
	set_default_cursor_shape(Control.CURSOR_POINTING_HAND)


func position_drop_visual_on_entry(entry_id: int) -> void:
	var after_entry_position: Vector2 = Vector2.ZERO
	# Position on empty list
	if entries.size() == 0:
		after_entry_position = Vector2.ZERO
	# Position on next entry if not after last
	elif entry_id >= 0 and entry_id < entries.size() - 1:
		after_entry_position = (entries[entry_id+1].position
							- Vector2(0.0, object_v_box.get_theme_constant("separation") * 0.5))
	# After last entry, position at last entry + its height
	elif entry_id == entries.size() - 1:
		after_entry_position = (entries[-1].position
							+ Vector2(0.0, entries[-1].size.y))
	drop_visual.position = (after_entry_position
						+ scroll_container.position
						+ top_left_margin
						- Vector2(0.0, scroll_container.scroll_vertical))


func position_child_drop_visual(entry_id: int, dragging_id: int) -> void:
	if entry_id < 0 or entry_id >= entries.size():
		return
	var after_entry_position: Vector2 = Vector2.ZERO
	if entry_id > dragging_id:		# Going down the list
		after_entry_position = (entries[entry_id].offset_transform_position
							+ Vector2(0.0, entries[entry_id].size.y)
							+ Vector2(0.0, object_v_box.get_theme_constant("separation") * 0.5))
	elif entry_id < dragging_id:	# Going up the list
		after_entry_position = -Vector2(0.0, object_v_box.get_theme_constant("separation") * 0.5)
	drop_visual.position = (entries[entry_id].position
						+ after_entry_position
						+ scroll_container.position
						+ top_left_margin
						- Vector2(0.0, scroll_container.scroll_vertical))


func add_text_entry(is_user_input: bool) -> void:
	var new_list_text_entry: ListTextEntry = load(list_text_entry_scene).instantiate()
	object_v_box.add_child(new_list_text_entry)
	new_list_text_entry.id = entries.size()
	new_list_text_entry.name = "ListTextEntry"
	entries.append(new_list_text_entry)
	connect_list_text_entry(new_list_text_entry)
	if is_user_input:
		list_changed.emit()


func remove_text_entry(entry: ListTextEntry) -> void:
	disconnect_list_text_entry(entry)
	entries.erase(entry)
	if last_edited_entry_id > entries.size() - 1:
		last_edited_entry_id = entries.size() - 1
	reset_entry_ids()
	list_changed.emit()


func connect_list_text_entry(entry: ListTextEntry) -> void:
	entry.erase_button.pressed.connect(_on_list_text_entry_erase.bind(entry))
	entry.grabber_moved.connect(_on_list_text_entry_grabber_moved)
	entry.grabber_started_move.connect(_on_list_text_entry_grabber_started_move)
	entry.grabber_ended_move.connect(_on_list_text_entry_grabber_ended_move)
	entry.text_changed.connect(_on_list_text_entry_text_changed)
	entry.text_edit_active.connect(_on_list_text_entry_text_entry_active)
	entry.remove_from_list.connect(_on_list_text_entry_remove_from_list.bind(entry))


func disconnect_list_text_entry(entry: ListTextEntry) -> void:
	entry.erase_button.pressed.disconnect(_on_list_text_entry_erase)
	entry.grabber_moved.disconnect(_on_list_text_entry_grabber_moved)
	entry.grabber_started_move.disconnect(_on_list_text_entry_grabber_started_move)
	entry.grabber_ended_move.disconnect(_on_list_text_entry_grabber_ended_move)
	entry.text_changed.disconnect(_on_list_text_entry_text_changed)
	entry.remove_from_list.disconnect(_on_list_text_entry_remove_from_list)


func change_size(new_size: Vector2) -> void:
	size = new_size


func sort_entries(move_entry_id: int, to_id: int) -> void:
	var reference: ListTextEntry = entries[move_entry_id]
	if move_entry_id > to_id:	# Moving entry down
		var idx: int = move_entry_id
		while idx > to_id:
			entries[idx] = entries[idx - 1]
			idx -= 1
	if move_entry_id < to_id:	# Moving entry up
		for idx in range(move_entry_id, to_id):
			entries[idx] = entries[idx + 1]
	entries[to_id] = reference
	reset_entry_ids()


# Set new IDs in list index (ascending) order
func reset_entry_ids() -> void:
	for i in range(0, entries.size()):
		entries[i].id = i


func rebuild_from_dict(dict: Dictionary) -> void:
	id = dict["id"]
	size = Vector2(dict["size.x"], dict["size.y"])
	position = Vector2(dict["pos.x"], dict["pos.y"])
	for entry_id in dict["entries"]:
		add_text_entry(false)
		entries[-1].rebuild_from_dict(dict["entries"][entry_id])
		#print("Added ", entry_id)
	# TODO sort in entry.id order if they don't get saved in order in the .json???


# Map order to entry
func to_json() -> Dictionary:
	var dict: Dictionary
	dict["entries"] = {}
	for entry in entries:
		var entry_id: int = entry.id
		dict["entries"][entry_id] = entry.to_json()
	dict["id"] = id
	dict["pos.x"] = position.x
	dict["pos.y"] = position.y
	dict["size.x"] = size.x
	dict["size.y"] = size.y
	return dict


func _on_scroll_hover(on: bool) -> void:
	mouse_inside = on
	if !on and dragger.is_dragging_outside:
		mouse_filter = Control.MOUSE_FILTER_PASS
		drop_visual.visible = false
		scroll_container.clip_contents = true
		dragger.end_drag()
	if dragger.is_dragging_child:
		if on:
			mouse_filter = Control.MOUSE_FILTER_STOP
			drop_visual.visible = on
		if !on:
			mouse_filter = Control.MOUSE_FILTER_PASS
			drop_visual.visible = on


func _on_scroll() -> void:
	if dragger.is_dragging_child:
		position_child_drop_visual(dragger.current, dragger.object_id)
	if dragger.is_dragging_outside:
		position_drop_visual_on_entry(dragger.current - 1)


func _on_scroll_mouse_entered() -> void:
	_on_scroll_hover(true)


func _on_scroll_mouse_exited() -> void:
	_on_scroll_hover(false)


func _on_list_text_entry_erase(entry: ListTextEntry) -> void:
	entries.erase(entry)
	reset_entry_ids()
	entry.queue_free()
	list_changed.emit()


func _on_list_text_entry_remove_from_list(entry: ListTextEntry) -> void:
	remove_text_entry(entry)


func _on_resized() -> void:
	if !is_node_ready():
		return
	mouse_hover_shape.shape.size = size
	mouse_hover.position = size * 0.5


func _on_list_text_entry_text_changed() -> void:
	list_changed.emit()


func _on_list_text_entry_grabber_started_move(entry_id: int, event_pos: Vector2) -> void:
	if entries.size() <= entry_id:
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	dragger.start_drag_child(entry_id, entries, event_pos, drop_visual.size.y, scroll_container.scroll_vertical)
	dragging.emit(true)
	drop_visual.visible = true
	drop_visual.size = entries[entry_id].size
	scroll_container.clip_contents = false


func _on_list_text_entry_grabber_moved(event: InputEventMouseMotion, entry_id: int) -> void:
	if entries.size() <= entry_id:
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	entries[entry_id].offset_transform_position = dragger.accumulate_position(event.relative / canvas_scale, scroll_container.scroll_vertical)
	if mouse_inside:
		dragger.drag_child()
		position_child_drop_visual(dragger.current, dragger.object_id)


func _on_list_text_entry_grabber_ended_move(entry_id: int) -> void:
	if entries.size() <= entry_id:
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	if dragger.object_id != entry_id:
		push_error("Wrong drag ID")
		return
	var move_to: int = dragger.current
	mouse_filter = Control.MOUSE_FILTER_PASS
	drop_visual.visible = false
	dragger.end_drag()
	dragging.emit(false)
	scroll_container.clip_contents = true
	if entry_id != move_to:
		object_v_box.move_child(entries[entry_id], move_to)
		sort_entries(entry_id, move_to)
		list_changed.emit()


func _on_list_text_entry_text_entry_active(entry_id: int) -> void:
	last_edited_entry_id = entry_id
	text_edit_active.emit(id)


func _on_gui_input(event: InputEvent) -> void:
	if dragger.is_dragging_child:
		return
	filtered_gui_input.emit(event, id)


func _on_list_name_focus_entered() -> void:
	text_edit_active.emit(id)


func _on_mouse_hover_mouse_entered() -> void:
	toggle_add_buttons(true)


func _on_mouse_hover_mouse_exited() -> void:
	toggle_add_buttons(false)


func _on_add_text_entry_button_pressed() -> void:
	add_text_entry(true)


func _on_add_link_entry_button_pressed() -> void:
	pass # Replace with function body.
