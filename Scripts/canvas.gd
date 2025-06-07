extends Control
class_name PlannerCanvas

## Manages a single file / tab
@onready var connection_container: Control = $ConnectionContainer
@onready var selection_viewer: Panel = $SelectionViewer
@onready var connection_indicator: Panel = $ConnectionIndicator
@onready var background: Panel = $Background

var element_scene
var connection_scene
var priority_colors: Array[Color]
var elements: Dictionary[int, ElementLabel]
var connections: Dictionary[int, Connection]
var connections_p1: Dictionary[int, PackedInt32Array]	## ELEMENT ID key, Array of CONNECTION ID value
var connections_p2: Dictionary[int, PackedInt32Array]	## ELEMENT ID key, Array of CONNECTION ID value
var elements_to_connection: Dictionary[Vector2i, int]	## ELEMENT ID Vector2i(ID1, ID2) key, CONNECTION ID value
var style_presets: Dictionary[String, ElementPresetStyle]	## PRESET ID key (not option_selector like in element_setting.gd)
var drawing_manager: DrawingManager

var element_id_counter: int = 0
var connection_id_counter: int = 0
var connection_candidate_1: int = -1
var connection_candidate_2: int = -1
var checkbox_data: Array[bool]
var priority_filter_value: int = 0

var CHECKBOX_NUMBER: int = 3
var id: int
var tool_id: int
var opened_file_path: String = ""
var file_name_short: String = ""
var selected_element: int = -1
var selected_preset_style: String = "none"

var is_dragging: bool = false
var is_resizing: bool = false
var is_panning: bool = false
var is_adding_elements: bool = false
var is_element_just_created: bool = false
var is_drawing: bool = false
var has_changes: bool = false
var drag_start_mouse_pos: Vector2
var original_elem_size: Vector2
var last_draw_event_position: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0
var zoom_limits: Vector2
var zoom_speed: float
var is_user_input: bool = true

signal done_adding_elements
signal changed_zoom
signal changed_position
signal has_changed
#signal selected_style_changed
signal has_selected_element
signal has_deselected_element

enum Checkbox {
	SHOW_PRIORITIES,
	SHOW_PRIORITY_TOOL,
	SHOW_COMPLETED,
}
enum Tool {
	SELECT,
	ADD_ELEMENT,
	REMOVE_ELEMENT,
	ELEMENT_STYLE_SETTINGS,
	ADD_CONNECTION,
	REMOVE_CONNECTIONS,
	MARK_COMPLETED,
	PENCIL,
	ERASER,
}
enum Priority {
	ACTIVE,
	HIGH,
	MEDIUM,
	LOW,
	NONE,
}
enum DrawTool {
	PENCIL,
	ERASER,
}


func _process(_delta: float) -> void:
	if !Input.is_key_pressed(KEY_CTRL) and is_adding_elements:
		is_adding_elements = false
		done_adding_elements.emit()


func new_canvas() -> void:
	checkbox_data.resize(CHECKBOX_NUMBER)
	for i in CHECKBOX_NUMBER:
		checkbox_data[i] = false
	deselect_element()
	opened_file_path = ""
	file_name_short = "New File"
	position = -size * 0.5 + get_viewport_rect().size * 0.5	# Start from the center on New File
	scale = Vector2(1.0, 1.0)
	priority_filter_value = Priority.NONE
	canvas_changed(true)
	#print("New canvas id %d" % [id])


func canvas_changed(reset: bool = false) -> bool:
	if !is_user_input:
		return false
	if reset:
		if has_changes:
			has_changes = false
			has_changed.emit()
		else:
			has_changes = false
	else:
		if !has_changes:
			has_changes = true
			has_changed.emit()
		else:
			has_changes = true
	return has_changes


func update_all_style_presets(dict: Dictionary[int, ElementPresetStyle]) -> void:
	style_presets.clear()
	for key in dict:
		style_presets[dict[key].id] = dict[key]


func update_single_style_preset(style_preset: ElementPresetStyle) -> void:
	style_presets[style_preset.id] = style_preset


func update_connection_color_by_preset(preset_id: String) -> void:
	for e_id in elements:
		if elements[e_id].has_style_preset and elements[e_id].style_preset_id == preset_id and style_presets.has(preset_id):
			update_connection_color(e_id, style_presets[preset_id].background_color)


func remove_style_preset(style_id: String) -> void:
	if style_presets.has(style_id):
		style_presets.erase(style_id)
		for elem_id in elements:
			if elements[elem_id].style_preset_id == style_id:
				elements[elem_id].unassign_preset_style()


func pan_limits(pos: Vector2) -> Vector2:
	var screen_size: Vector2 = get_viewport_rect().size
	if pos.x > 0.0:
		pos.x = 0.0
	if pos.y > 0.0:
		pos.y = 0.0
	if pos.x < -size.x * scale.x + screen_size.x:
		pos.x = -size.x * scale.x + screen_size.x
	if pos.y < -size.y * scale.y + screen_size.y:
		pos.y = -size.y * scale.y + screen_size.y
	return pos


func add_element_label(at_position: Vector2, id_specified: int = -1) -> void:
	canvas_changed()
	var new_element: ElementLabel = load(element_scene).instantiate()
	var elem_id: int
	if id_specified < 0:
		elem_id = element_id_counter
		element_id_counter += 1
	else:
		elem_id = id_specified
	new_element.id = elem_id
	elements[elem_id] = new_element
	new_element.gui_input.connect(_on_element_label_gui_input.bind(elem_id))
	new_element.resized.connect(_on_element_label_resized.bind(elem_id))
	new_element.became_selected.connect(_on_element_text_box_active.bind(elem_id))
	new_element.changed_priority.connect(_on_element_changed_priority.bind(elem_id))
	add_child(new_element)
	new_element.name = "ElementLabel"
	new_element.position = at_position
	new_element.priority_id = Priority.NONE
	new_element.priority_tool_enabled = checkbox_data[Checkbox.SHOW_PRIORITY_TOOL]
	new_element.set_priority_color(priority_colors[Priority.NONE])
	new_element.set_priority_visible(checkbox_data[Checkbox.SHOW_PRIORITIES])
	new_element.z_index = 1
	if style_presets.has(selected_preset_style):
		new_element.change_style_preset(style_presets[selected_preset_style])
	if id_specified < 0:	# Don't select elements when creating them in bulk by specifying their ids
		elements[elem_id].line_edit.edit()	# NOTE Also signals select_element(elem_id)
		is_element_just_created = true


func add_connection(id_specified: int = -1) -> void:
	canvas_changed()
	if connection_candidate_1 == connection_candidate_2:
		connection_candidate_1 = -1
		connection_candidate_2 = -1
		connection_indicator.visible = false
		return
	if !elements_to_connection.has(Vector2i(connection_candidate_1, connection_candidate_2)) and !elements_to_connection.has(Vector2i(connection_candidate_2, connection_candidate_1)):
		#print("ADDING CONNECTION")
		var new_connection = load(connection_scene).instantiate()
		var conn_id: int
		if id_specified < 0:
			conn_id = connection_id_counter
			connection_id_counter += 1
		else:
			conn_id = id_specified
		connections[conn_id] = new_connection
		if !connections_p1.has(connection_candidate_1):
			connections_p1[connection_candidate_1] = PackedInt32Array()
		if !connections_p2.has(connection_candidate_2):
			connections_p2[connection_candidate_2] = PackedInt32Array()
		connections_p1[connection_candidate_1].append(conn_id)
		connections_p2[connection_candidate_2].append(conn_id)
		elements_to_connection[Vector2i(connection_candidate_1, connection_candidate_2)] = conn_id
		connection_container.add_child(new_connection)
		new_connection.name = "LineConnection"
		new_connection.update_p1(elements[connection_candidate_1].position, elements[connection_candidate_1].size)
		new_connection.update_p2(elements[connection_candidate_2].position, elements[connection_candidate_2].size)
		new_connection.update_p1_color(elements[connection_candidate_1].get_bg_color())
		new_connection.update_p2_color(elements[connection_candidate_2].get_bg_color())
		new_connection.update_positions()
	#else:
		#print("ALREDY EXISTS")
	connection_candidate_1 = -1
	connection_candidate_2 = -1
	connection_indicator.visible = false


func remove_connections(elem_id: int) -> void:
	canvas_changed()
	var arr: Array[int] = []
	if connections_p1.has(elem_id):
		for connid in connections_p1[elem_id]:	# Remove reference if elem_id is point1
			if !arr.has(connid):
				arr.append(connid)
		for elem in connections_p2:				# Remove the point2 reference to that connection
			var i: int = 0
			while i < connections_p2[elem].size():
				if arr.has(connections_p2[elem][i]):
					connections_p2[elem].remove_at(i)
					i -= 1
				i += 1
		connections_p1.erase(elem_id)
	if connections_p2.has(elem_id):				# Remove reference if elem_id is point2
		for connid in connections_p2[elem_id]:
			if !arr.has(connid):
				arr.append(connid)
		for elem in connections_p1:				# Remove the point1 reference to that connection
			var i: int = 0
			while i < connections_p1[elem].size():
				if arr.has(connections_p1[elem][i]):
					connections_p1[elem].remove_at(i)
					i -= 1
				i += 1
		connections_p2.erase(elem_id)
	var to_erase: Array[Vector2i] = []
	for pair in elements_to_connection:
		if pair.x == elem_id or pair.y == elem_id:
			to_erase.append(pair)
	for pair in to_erase:
		elements_to_connection.erase(pair)
	for connid in arr:
		connections[connid].queue_free()
		connections.erase(connid)


func select_element(elem_id: int) -> void:
	#printt("Trying", elem_id)
	if elem_id == selected_element:
		#print("Same ID")
		return
	if elements.has(selected_element):	# Deselect previous element
		#print("Deselect previous")
		elements[selected_element].line_edit.apply_ime()
		elements[selected_element].line_edit.deselect()
		elements[selected_element].line_edit.unedit()
		if elements[selected_element].completed:
			elements[selected_element].z_index = elements[selected_element].completed_z_index
		else:
			elements[selected_element].z_index = elements[selected_element].active_z_index
	if elements.has(elem_id):
		#print("Select elem_id")
		selected_element = elem_id
		selection_viewer.visible = true
		selection_viewer.size = elements[elem_id].size
		selection_viewer.position = elements[elem_id].position
		elements[selected_element].z_index = 2
		change_selected_preset_style(elements[selected_element].style_preset_id)
		has_selected_element.emit()
	else:	# Deselect element if elem_id invalid
		#print("ID invalid")
		deselect_element()


func deselect_element() -> void:
	selected_element = -1
	selection_viewer.visible = false
	has_deselected_element.emit()


func reset_adding_connection() -> void:
	connection_candidate_1 = -1
	connection_candidate_2 = -1
	connection_indicator.visible = false


# NOTE called when select_element() changes the selected element
# from main.gd called on switch_main_canvas() with "none"
# from main.gd _on_element_settings_preset_selected() passes the selected preset from the style settings panel
func change_selected_preset_style(style_id: String) -> void:
	if style_id == "none":
		selected_preset_style = "none"
		#selected_style_changed.emit()
	elif selected_preset_style != style_id:
		if style_presets.has(style_id):
			selected_preset_style = style_id
		else:
			selected_preset_style = "none"
		#selected_style_changed.emit()


func update_connections(elem_id: int) -> void:
	if connections_p1.has(elem_id):
		for conn_id in connections_p1[elem_id]:
			connections[conn_id].update_p1(elements[elem_id].position, elements[elem_id].size)
			connections[conn_id].update_positions()
	if connections_p2.has(elem_id):
		for conn_id in connections_p2[elem_id]:
			connections[conn_id].update_p2(elements[elem_id].position, elements[elem_id].size)
			connections[conn_id].update_positions()


func all_elements_to_Json() -> Dictionary:
	var dict: Dictionary = {}
	for elem_id in elements:
		if elements[elem_id] != null:
			dict[elem_id] = elements[elem_id].to_json()
	return dict


func all_presets_to_json() -> Dictionary:
	var dict: Dictionary
	var entry_id: int = 1	# Put the style presets in order, same way they get read in element_settings.gd
	for key in style_presets:
		dict[entry_id] = style_presets[key].to_json()
		entry_id += 1
	return dict


func all_connection_pairs_to_json() -> Dictionary:
	var dict: Dictionary = {}
	for pair in elements_to_connection:
		var entry: Dictionary = {}
		var connid = elements_to_connection[pair]
		entry["id1"] = pair.x
		entry["id2"] = pair.y
		dict[connid] = entry
	return dict


func canvas_state_to_json() -> Dictionary:
	return {
		"position.x": position.x,
		"position.y": position.y,
		"scale.x": scale.x,
		"scale.y": scale.y,
		"zoom_level": zoom_level,
		"show_completed": checkbox_data[Checkbox.SHOW_COMPLETED],
		"show_priorities": checkbox_data[Checkbox.SHOW_PRIORITIES],
		"show_priority_tool": checkbox_data[Checkbox.SHOW_PRIORITY_TOOL],
		"priority_filter_value": priority_filter_value,
		"drawing_folder_path": drawing_manager.get_folder_path(id),
	}


func rebuild_canvas_state(state: Dictionary) -> void:
	canvas_changed(true)
	position = pan_limits(Vector2(state["position.x"], state["position.y"]))
	scale.x = state["scale.x"]
	scale.y = state["scale.y"]
	if state.has("zoom_level"):
		zoom_level = state["zoom_level"]
	if state.has("show_completed"):
		checkbox_data[Checkbox.SHOW_COMPLETED] = bool(state["show_completed"])
	if state.has("show_priorities"):
		checkbox_data[Checkbox.SHOW_PRIORITIES] = bool(state["show_priorities"])
	if state.has("show_priority_tool"):
		checkbox_data[Checkbox.SHOW_PRIORITY_TOOL] = bool(state["show_priority_tool"])
	if state.has("priority_filter_value"):
		priority_filter_value = int(state["priority_filter_value"])
	if state.has("drawing_folder_path"):
		drawing_manager.set_folder_path(id, state["drawing_folder_path"])
	changed_position.emit()


func rebuild_elements(json_elems: Dictionary) -> void:
	is_user_input = false
	var max_id: int = -1
	for i in json_elems:
		if !json_elems[i].is_empty():
			var elem_id: int = int(json_elems[i]["id"])
			var pos: Vector2 = Vector2(json_elems[i]["pos.x"], json_elems[i]["pos.y"])
			add_element_label(pos, elem_id)
			var style_id: String = "none"
			var completed: bool = false
			var has_style: bool = false
			var priority_id: int = Priority.NONE
			if json_elems[i].has("completed"):		# Field only exists at version 0.1.3 or above
				completed = bool(json_elems[i]["completed"])
			if json_elems[i].has("priority_id"):
				priority_id = int(json_elems[i]["priority_id"])
			if json_elems[i].has("priority_id"):
				priority_id = int(json_elems[i]["priority_id"])
			if json_elems[i].has("has_style_preset"):
				has_style = bool(json_elems[i]["has_style_preset"])
			if json_elems[i].has("style_preset_id"):
				style_id = str(json_elems[i]["style_preset_id"])
			elements[elem_id].change_size(Vector2(json_elems[i]["size.x"], json_elems[i]["size.y"]))
			elements[elem_id].priority_id = priority_id
			elements[elem_id].set_priority_color(priority_colors[priority_id])
			if json_elems[i].has("bgcolor.r"):	# Backwards compatibility
				var c: Color = Color(json_elems[i]["bgcolor.r"], json_elems[i]["bgcolor.g"], json_elems[i]["bgcolor.b"], json_elems[i]["bgcolor.a"])
				elements[elem_id].set_bg_color(c)
			elements[elem_id].line_edit.text = json_elems[i]["text"]
			if completed:
				elements[elem_id].toggle_completed()
			if has_style and style_presets.has(style_id):
				elements[elem_id].style_preset_id = style_id
				elements[elem_id].change_style_preset(style_presets[style_id])
			elif json_elems[i].has("individual_style") and !has_style:
				elements[elem_id].individual_style.rebuild_from_json_dict(json_elems[i]["individual_style"])
			if elem_id > max_id:
				max_id = elem_id
			elements[elem_id].manual_resize = false
	element_id_counter = max_id + 1
	is_user_input = true


func rebuild_connections(json_conns: Dictionary) -> void:
	is_user_input = false
	var max_id: int = -1
	for i in json_conns:
		var conn_id = int(i)
		connection_candidate_1 = int(json_conns[i]["id1"])
		connection_candidate_2 = int(json_conns[i]["id2"])
		add_connection(conn_id)
		if conn_id > max_id:
			max_id = conn_id
	connection_id_counter = max_id + 1
	is_user_input = true


func erase_everything() -> void:
	canvas_changed(true)
	opened_file_path = ""
	file_name_short = "New File"
	selection_viewer.visible = false
	deselect_element()
	has_deselected_element.emit()
	zoom_level = 1.0
	connections_p1 = {}
	connections_p2 = {}
	elements_to_connection = {}
	for i in elements:
		if elements[i] != null:
			elements[i].queue_free()
	elements = {}
	for i in connections:
		if connections[i] != null:
			connections[i].queue_free()
	connections = {}
	element_id_counter = 0
	connection_id_counter = 0
	connection_candidate_1 = -1
	connection_candidate_2 = -1
	is_dragging = false
	is_resizing = false


func toggle_element_and_connections(elem_id: int, state: bool) -> void:
	if selected_element == elem_id:
		deselect_element()
	elements[elem_id].visible = state
	
	if elem_id in connections_p1:
		for conn_id in connections_p1[elem_id]:
			connections[conn_id].visible = state
	if elem_id in connections_p2:
		for conn_id in connections_p2[elem_id]:
			connections[conn_id].visible = state


func toggle_element(elem_id: int, state: bool) -> void:
	if selected_element == elem_id:
		deselect_element()
	elements[elem_id].visible = state


func toggle_connections(elem_id: int) -> void:
	var toggles: Dictionary[int, bool] = {}
	for pair in elements_to_connection:
		if pair.x == elem_id or pair.y == elem_id:
			if !elements[pair.x].visible or !elements[pair.y].visible:
				toggles[elements_to_connection[pair]] = false
			else:
				toggles[elements_to_connection[pair]] = true
	for conn_id in toggles:
		connections[conn_id].visible = toggles[conn_id]


func update_connection_color(elem_id: int, color: Color) -> void:
	for pair in elements_to_connection:
		if pair.x == elem_id:
			connections[elements_to_connection[pair]].update_p1_color(color)
		if pair.y == elem_id:
			connections[elements_to_connection[pair]].update_p2_color(color)


func handle_zoom(old_zoom: float, target: Vector2) -> void:
	if abs(1.0 - zoom_level) < (zoom_speed - 1.0 + 0.005):
		scale = Vector2(1.0, 1.0)
	else:
		scale = Vector2(zoom_level, zoom_level)
	if abs(1.0 - old_zoom) < (zoom_speed - 1.0 + 0.005):
		old_zoom = 1.0
	
	# Keeps the top-left of the screen consistent while scaling the canvas
	var delta_screen_tl: Vector2 = position - (position * scale) / old_zoom
	# Gives you how much to move to go to a screen location after zooming
	var delta_scale = 1.0 - old_zoom / scale.x
	
	position = pan_limits(position - delta_screen_tl - target * delta_scale)
	changed_position.emit()
	changed_zoom.emit()


func toggle_show_completed(toggled_on: bool) -> void:
	checkbox_data[Checkbox.SHOW_COMPLETED] = toggled_on
	for i in elements:
		if elements[i].completed:
			toggle_element_and_connections(i, toggled_on)


func toggle_show_priorities(toggled_on: bool) -> void:
	checkbox_data[Checkbox.SHOW_PRIORITIES] = toggled_on
	for i in elements:
		elements[i].set_priority_visible(toggled_on)


func toggle_show_priority_tool(toggled_on: bool) -> void:
	checkbox_data[Checkbox.SHOW_PRIORITY_TOOL] = toggled_on
	for i in elements:
		elements[i].priority_tool_enabled = toggled_on


func change_priority_filter(value: int) -> void:
	priority_filter_value = value
	for i in elements:
		if elements[i].priority_id > value or (elements[i].completed and !checkbox_data[Checkbox.SHOW_COMPLETED]):
			toggle_element(i, false)
		else:
			toggle_element(i, true)
	for i in elements:
		toggle_connections(i)


func _on_gui_input(event: InputEvent) -> void:
	if drawing_manager.is_taking_screenshots:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if tool_id == Tool.ADD_ELEMENT:
				add_element_label(event.position)
				is_adding_elements = true
			if (tool_id == Tool.SELECT or tool_id == Tool.ELEMENT_STYLE_SETTINGS):
				if !is_element_just_created:
					select_element(-1)	# Deselect any
				else:
					is_element_just_created = false
				if !is_panning:
					is_panning = true
					drag_start_mouse_pos = event.position
			if tool_id == Tool.PENCIL or tool_id == Tool.ERASER:
				is_drawing = true
				last_draw_event_position = event.position * scale + position
				drawing_manager.resize_to_window()
				drawing_manager.update_drawing_position_and_scale(-position, scale)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			if is_panning:
				is_panning = false
			if is_drawing:
				is_drawing = false
				last_draw_event_position = Vector2.ZERO
				drawing_manager.end_stroke()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and (tool_id == Tool.SELECT or tool_id == Tool.ELEMENT_STYLE_SETTINGS):
			var old_zoom: float = zoom_level
			zoom_level = clampf(zoom_level * zoom_speed, zoom_limits.x, zoom_limits.y)
			handle_zoom(old_zoom, get_window().get_mouse_position())
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and (tool_id == Tool.SELECT or tool_id == Tool.ELEMENT_STYLE_SETTINGS):
			var old_zoom: float = zoom_level
			zoom_level = clampf(zoom_level * (2.0 - zoom_speed), zoom_limits.x, zoom_limits.y)
			handle_zoom(old_zoom, get_viewport_rect().size * 0.5)
	if event is InputEventMouseMotion and is_panning and (tool_id == Tool.SELECT or tool_id == Tool.ELEMENT_STYLE_SETTINGS):
		var move = (event.position - drag_start_mouse_pos) * scale.x
		position = pan_limits(position + move)
		changed_position.emit()
	if event is InputEventMouseMotion and is_drawing and tool_id == Tool.PENCIL:
		canvas_changed()
		var currrent_draw_event_position: Vector2 = event.position * scale + position
		drawing_manager.receive_coords(last_draw_event_position, currrent_draw_event_position, DrawTool.PENCIL)
		last_draw_event_position = currrent_draw_event_position
	if event is InputEventMouseMotion and is_drawing and tool_id == Tool.ERASER:
		canvas_changed()
		var currrent_draw_event_position: Vector2 = event.position * scale + position
		drawing_manager.receive_coords(last_draw_event_position, currrent_draw_event_position, DrawTool.ERASER)
		last_draw_event_position = currrent_draw_event_position


func _on_element_label_gui_input(event: InputEvent, elem_id: int) -> void:
	if drawing_manager.is_taking_screenshots:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if tool_id == Tool.ADD_CONNECTION:
				if connection_candidate_1 == -1:
					connection_candidate_1 = elem_id
					select_element(elem_id)
					connection_indicator.visible = true
					connection_indicator.position = elements[selected_element].position - Vector2(20.0, 20.0)
					#print("FIRST ID CONFIRMED")
				else:
					connection_candidate_2 = elem_id
					add_connection()
			if tool_id == Tool.REMOVE_CONNECTIONS:
				remove_connections(elem_id)
			if (tool_id == Tool.SELECT or tool_id == Tool.ELEMENT_STYLE_SETTINGS):
				select_element(elem_id)
				if event.position.distance_to(elements[elem_id].size) < 12.0:
					is_resizing = true
					is_panning = false
					original_elem_size = elements[elem_id].size
					elements[elem_id].set_default_cursor_shape(Control.CURSOR_FDIAGSIZE)
					drag_start_mouse_pos = event.position
				if !is_dragging and !is_resizing:
					is_dragging = true
					is_panning = false
					elements[elem_id].set_default_cursor_shape(Control.CURSOR_DRAG)
					drag_start_mouse_pos = event.position
			if tool_id == Tool.ELEMENT_STYLE_SETTINGS:
				select_element(elem_id)
			if tool_id == Tool.MARK_COMPLETED:
				canvas_changed()
				elements[elem_id].toggle_completed()
				toggle_element_and_connections(elem_id, checkbox_data[Checkbox.SHOW_COMPLETED])
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			elements[elem_id].set_default_cursor_shape(Control.CURSOR_POINTING_HAND)
			if tool_id == Tool.REMOVE_ELEMENT:
				canvas_changed()
				deselect_element()
				remove_connections(elem_id)
				elements[elem_id].queue_free()
				elements.erase(elem_id)
			if is_dragging:
				is_dragging = false
			if is_resizing:
				is_resizing = false
	if event is InputEventMouseMotion and (tool_id == Tool.SELECT or tool_id == Tool.ELEMENT_STYLE_SETTINGS):
		var move = event.position - drag_start_mouse_pos
		if is_dragging:
			elements[elem_id].position += move
			selection_viewer.position = elements[elem_id].position
			update_connections(elem_id)
		if is_resizing:
			elements[elem_id].change_size(original_elem_size + move)
			#selection_viewer.size = elements[elem_id].size
			update_connections(elem_id)


func _on_element_text_box_active(elem_id: int) -> void:
	if elements.has(elem_id):
		select_element(elem_id)
		if tool_id == Tool.MARK_COMPLETED:
			canvas_changed()
			elements[elem_id].toggle_completed()
			toggle_element_and_connections(elem_id, checkbox_data[Checkbox.SHOW_COMPLETED])
		if tool_id == Tool.ADD_CONNECTION:
			if connection_candidate_1 == -1:
				connection_candidate_1 = elem_id
				select_element(elem_id)
				connection_indicator.visible = true
				connection_indicator.position = elements[selected_element].position - Vector2(20.0, 20.0)
				#print("FIRST ID CONFIRMED")
			else:
				connection_candidate_2 = elem_id
				add_connection()
		if tool_id == Tool.REMOVE_CONNECTIONS:
			remove_connections(elem_id)


func _on_element_label_resized(elem_id: int) -> void:
	canvas_changed()
	if selected_element == elem_id:
		selection_viewer.size = elements[elem_id].size


func _on_element_changed_priority(elem_id: int) -> void:
	canvas_changed()
	if elements.has(elem_id):
		var pr_id = elements[elem_id].priority_id
		elements[elem_id].set_priority_color(priority_colors[pr_id])
