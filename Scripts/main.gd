extends Control

@onready var tool_box: ItemList = $MarginContainer/ToolBox
@onready var element_container: Control = $ElementContainer
@onready var connection_container: Control = $ElementContainer/ConnectionContainer
@onready var zoom_indicator: VBoxContainer = $MarginContainer/ZoomIndicator
@onready var color_picker: ColorPicker = $MarginContainer/ColorPicker
@onready var selection_viewer: Panel = $ElementContainer/SelectionViewer

@export_file("*.tscn") var element_scene
@export_file("*.tscn") var connection_scene
@export var zoom_limits: Vector2 = Vector2(0.25, 4.0)

var elements: Dictionary[int, ElementLabel]
var connections: Dictionary[int, Connection]
var connections_p1: Dictionary[int, PackedInt32Array]	## ELEMENT ID key, CONNECTION ID value
var connections_p2: Dictionary[int, PackedInt32Array]	## ELEMENT ID key, CONNECTION ID value
var elements_to_connection: Dictionary[Vector2i, int]	## ELEMENT ID Vector2i(ID1, ID2) key, CONNECTION ID value
var element_id_counter: int = 0
var connection_id_counter: int = 0
var connection_candidate_1: int = -1
var connection_candidate_2: int = -1

var selected_element: int = -1
var is_dragging: bool = false
var is_resizing: bool = false
var drag_start_mouse_pos: Vector2
var original_size: Vector2
var zoom_level: float = 1.0

enum Tool {
	SELECT,
	ADD_ELEMENT,
	REMOVE,
	PAN,
	BG_COLOR,
	ADD_CONNECTION,
	REMOVE_CONNECTIONS,
}


func _on_element_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if tool_box.is_selected(Tool.ADD_ELEMENT):
				add_element_label(event.position)
			if tool_box.is_selected(Tool.PAN):
				if !is_dragging:
					is_dragging = true
					drag_start_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			if is_dragging:
				is_dragging = false
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and tool_box.is_selected(Tool.PAN):
			zoom_level = clampf(zoom_level * 1.02, zoom_limits.x, zoom_limits.y)
			element_container.scale = Vector2(zoom_level, zoom_level)
			if abs(1.0 - element_container.scale.x) < 0.025:
				element_container.scale = Vector2(1.0, 1.0)
			element_container.position = pan_limits(element_container.position)
			zoom_indicator.update_zoom(element_container.scale.x)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and tool_box.is_selected(Tool.PAN):
			zoom_level = clampf(zoom_level * 0.98, zoom_limits.x, zoom_limits.y)
			element_container.scale = Vector2(zoom_level, zoom_level)
			if abs(1.0 - zoom_level) < 0.025:
				element_container.scale = Vector2(1.0, 1.0)
			element_container.position = pan_limits(element_container.position)
			zoom_indicator.update_zoom(element_container.scale.x)
	if event is InputEventMouseMotion and tool_box.is_selected(Tool.PAN):
		var move = (event.position - drag_start_mouse_pos) * element_container.scale.x
		if is_dragging:
			element_container.position = pan_limits(element_container.position + move)


func _on_element_label_gui_input(event: InputEvent, id: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if tool_box.is_selected(Tool.ADD_CONNECTION):
				if connection_candidate_1 == -1:
					connection_candidate_1 = id
					#print("FIRST ID CONFIRMED")
				else:
					connection_candidate_2 = id
					add_connection()
			if tool_box.is_selected(Tool.REMOVE_CONNECTIONS):
				remove_connections(id)
			if tool_box.is_selected(Tool.SELECT):
				selected_element = id
				selection_viewer.visible = true
				selection_viewer.size = elements[id].size
				selection_viewer.position = elements[id].position
				if event.position.distance_to(elements[id].size) < 12.0:
					is_resizing = true
					original_size = elements[id].size
					drag_start_mouse_pos = event.position
				if !is_dragging and !is_resizing:
					is_dragging = true
					drag_start_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			if tool_box.is_selected(Tool.REMOVE):
				remove_connections(id)
				elements[id].queue_free()
				selected_element = -1
				selection_viewer.visible = false
			if is_dragging:
				is_dragging = false
			if is_resizing:
				is_resizing = false
	if event is InputEventMouseMotion and tool_box.is_selected(Tool.SELECT):
		var move = event.position - drag_start_mouse_pos
		if is_dragging:
			elements[id].position += move
			selection_viewer.position = elements[id].position
			update_connections(id)
		if is_resizing:
			elements[id].size = original_size + move
			selection_viewer.size = elements[id].size
			update_connections(id)


func _on_element_text_box_active(id: int) -> void:
	if elements.has(id):
		selected_element = id
		selection_viewer.visible = true
		selection_viewer.position = elements[id].position
		selection_viewer.size = elements[id].size


func add_element_label(at_position: Vector2) -> void:
	var new_element = load(element_scene).instantiate()
	new_element.id = element_id_counter
	elements[element_id_counter] = new_element
	new_element.gui_input.connect(_on_element_label_gui_input.bind(element_id_counter))
	new_element.became_active.connect(_on_element_text_box_active.bind(element_id_counter))
	element_container.add_child(new_element)
	new_element.position = at_position
	tool_box.select(Tool.SELECT)
	element_id_counter += 1


func add_connection() -> void:
	if !elements_to_connection.has(Vector2i(connection_candidate_1, connection_candidate_2)) and !elements_to_connection.has(Vector2i(connection_candidate_2, connection_candidate_1)):
		#print("ADDING CONNECTION")
		var new_connection = load(connection_scene).instantiate()
		connections[connection_id_counter] = new_connection
		if !connections_p1.has(connection_candidate_1):
			connections_p1[connection_candidate_1] = PackedInt32Array()
		if !connections_p2.has(connection_candidate_2):
			connections_p2[connection_candidate_2] = PackedInt32Array()
		connections_p1[connection_candidate_1].append(connection_id_counter)
		connections_p2[connection_candidate_2].append(connection_id_counter)
		elements_to_connection[Vector2i(connection_candidate_1, connection_candidate_2)] = connection_id_counter
		connection_container.add_child(new_connection)
		new_connection.update_p1(elements[connection_candidate_1].position, elements[connection_candidate_1].size)
		new_connection.update_p2(elements[connection_candidate_2].position, elements[connection_candidate_2].size)
		new_connection.update_positions()
		connection_id_counter += 1
	#else:
		#print("ALREDY EXISTS")
	connection_candidate_1 = -1
	connection_candidate_2 = -1


func remove_connections(elem_id: int) -> void:
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


func update_connections(elem_id: int) -> void:
	if connections_p1.has(elem_id):
		for conn_id in connections_p1[elem_id]:
			connections[conn_id].update_p1(elements[elem_id].position, elements[elem_id].size)
			connections[conn_id].update_positions()
	if connections_p2.has(elem_id):
		for conn_id in connections_p2[elem_id]:
			connections[conn_id].update_p2(elements[elem_id].position, elements[elem_id].size)
			connections[conn_id].update_positions()


func pan_limits(pos: Vector2) -> Vector2:
	var screen_size: Vector2 = get_viewport_rect().size
	if pos.x > 0.0:
		pos.x = 0.0
	if pos.y > 0.0:
		pos.y = 0.0
	if pos.x < -element_container.size.x * element_container.scale.x + screen_size.x:
		pos.x = -element_container.size.x * element_container.scale.x + screen_size.x
	if pos.y < -element_container.size.y * element_container.scale.y + screen_size.y:
		pos.y = -element_container.size.y * element_container.scale.y + screen_size.y
	return pos


func _on_tool_box_item_selected(index: int) -> void:
	if index == Tool.BG_COLOR:
		color_picker.visible = true
	elif index != Tool.BG_COLOR and color_picker.visible == true:
		color_picker.visible = false
	if index != Tool.ADD_ELEMENT:
		connection_candidate_1 = -1
		connection_candidate_2 = -1


func _on_color_picker_color_changed(color: Color) -> void:
	if tool_box.is_selected(Tool.BG_COLOR) and selected_element >= 0 and elements.has(selected_element):
		elements[selected_element].set_bg_color(color)
