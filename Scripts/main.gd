extends Control

@onready var tool_box: ItemList = $MarginContainer/ToolBox
@onready var element_container: Control = $ElementContainer
@onready var connection_container: Control = $ElementContainer/ConnectionContainer
@onready var zoom_indicator: VBoxContainer = $MarginContainer/ZoomIndicator
@onready var color_picker: ColorPicker = $MarginContainer/ColorPicker
@onready var color_picker_bg: Panel = $MarginContainer/ColorPickerBG
@onready var selection_viewer: Panel = $ElementContainer/SelectionViewer
@onready var file_dialog_save: FileDialog = $FileDialogSave
@onready var file_dialog_load: FileDialog = $FileDialogLoad
@onready var status_bar: Label = $MarginContainer/StatusBar
@onready var toggle_completed: CheckBox = $MarginContainer/Settings/ToggleCompleted

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
var opened_file_path: String = ""
var app_version: String = ""
var update_checkboxes: bool = false
var checkbox_data: Array[bool] = [false]


enum Tool {
	SELECT,
	ADD_ELEMENT,
	REMOVE,
	PAN,
	BG_COLOR,
	ADD_CONNECTION,
	REMOVE_CONNECTIONS,
	MARK_COMPLETED,
}


func _ready() -> void:
	app_version = ProjectSettings.get_setting("application/config/version")
	#DisplayServer.window_set_title("GPlanner %s: New File" % [app_version])
	get_tree().root.title = ("GPlanner %s: New File" % [app_version])
	status_bar.update_status("New File")


func _process(_delta):
	if Input.is_action_just_pressed("save_file"):
		if opened_file_path == "":
			file_dialog_save.visible = true
		else:
			save_file(opened_file_path)
	if Input.is_action_just_pressed("-"):
		toggle_completed.set_pressed(true)
	if Input.is_action_just_pressed("+"):
		toggle_completed.set_pressed(false)
	if update_checkboxes:
		toggle_completed.set_pressed(checkbox_data[0])
		update_checkboxes = false


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
					select_element(id)
					#print("FIRST ID CONFIRMED")
				else:
					connection_candidate_2 = id
					add_connection()
			if tool_box.is_selected(Tool.REMOVE_CONNECTIONS):
				remove_connections(id)
			if tool_box.is_selected(Tool.SELECT):
				select_element(id)
				if event.position.distance_to(elements[id].size) < 12.0:
					is_resizing = true
					original_size = elements[id].size
					drag_start_mouse_pos = event.position
				if !is_dragging and !is_resizing:
					is_dragging = true
					drag_start_mouse_pos = event.position
			if tool_box.is_selected(Tool.BG_COLOR):
				select_element(id)
				elements[id].set_bg_color(color_picker.color)
			if tool_box.is_selected(Tool.MARK_COMPLETED):
				elements[id].toggle_completed()
				toggle_element_and_connections(id, toggle_completed.button_pressed)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			if tool_box.is_selected(Tool.REMOVE):
				remove_connections(id)
				elements[id].queue_free()
				selected_element = -1
				elements.erase(id)
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
		select_element(id)
		if tool_box.is_selected(Tool.BG_COLOR):
			elements[id].set_bg_color(color_picker.color)
		if tool_box.is_selected(Tool.MARK_COMPLETED):
			elements[id].toggle_completed()
			toggle_element_and_connections(id, toggle_completed.button_pressed)


func add_element_label(at_position: Vector2, id_specified: int = -1) -> void:
	var new_element = load(element_scene).instantiate()
	var id: int
	if id_specified < 0:
		id = element_id_counter
		element_id_counter += 1
	else:
		id = id_specified
	new_element.id = id
	elements[id] = new_element
	new_element.gui_input.connect(_on_element_label_gui_input.bind(id))
	new_element.became_active.connect(_on_element_text_box_active.bind(id))
	element_container.add_child(new_element)
	new_element.position = at_position
	tool_box.select(Tool.SELECT)


func add_connection(id_specified: int = -1) -> void:
	if !elements_to_connection.has(Vector2i(connection_candidate_1, connection_candidate_2)) and !elements_to_connection.has(Vector2i(connection_candidate_2, connection_candidate_1)):
		#print("ADDING CONNECTION")
		var new_connection = load(connection_scene).instantiate()	
		var id: int
		if id_specified < 0:
			id = connection_id_counter
			connection_id_counter += 1
		else:
			id = id_specified
		connections[id] = new_connection
		if !connections_p1.has(connection_candidate_1):
			connections_p1[connection_candidate_1] = PackedInt32Array()
		if !connections_p2.has(connection_candidate_2):
			connections_p2[connection_candidate_2] = PackedInt32Array()
		connections_p1[connection_candidate_1].append(id)
		connections_p2[connection_candidate_2].append(id)
		elements_to_connection[Vector2i(connection_candidate_1, connection_candidate_2)] = id
		connection_container.add_child(new_connection)
		new_connection.update_p1(elements[connection_candidate_1].position, elements[connection_candidate_1].size)
		new_connection.update_p2(elements[connection_candidate_2].position, elements[connection_candidate_2].size)
		new_connection.update_positions()
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


func select_element(id: int) -> void:
	selected_element = id
	selection_viewer.visible = true
	selection_viewer.size = elements[id].size
	selection_viewer.position = elements[id].position


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
		color_picker_bg.visible = true
	elif index != Tool.BG_COLOR and color_picker.visible == true:
		color_picker.visible = false
		color_picker_bg.visible = false
	if index != Tool.ADD_ELEMENT:
		connection_candidate_1 = -1
		connection_candidate_2 = -1


func _on_color_picker_color_changed(color: Color) -> void:
	if tool_box.is_selected(Tool.BG_COLOR) and selected_element >= 0 and elements.has(selected_element):
		elements[selected_element].set_bg_color(color)


func _on_file_dialog_save_file_selected(path: String) -> void:
	save_file(path)


func _on_file_dialog_load_file_selected(path: String) -> void:
	erase_everything()
	load_file(path)


func _on_new_button_pressed() -> void:
	erase_everything()
	#DisplayServer.window_set_title("GPlanner %s: New File" % [app_version])
	get_tree().root.title = ("GPlanner %s: New File" % [app_version])
	status_bar.update_status("New File")
	opened_file_path = ""


func _on_save_button_pressed() -> void:
	if opened_file_path == "":
		file_dialog_save.visible = true
	else:
		save_file(opened_file_path)


func _on_save_as_button_pressed() -> void:
	file_dialog_save.visible = true


func _on_load_button_pressed() -> void:
	file_dialog_load.visible = true


func save_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	var save_data: Dictionary
	if file == null:
		print(FileAccess.get_open_error())
		return
	
	save_data = {
		"State": canvas_state_to_json(),
		"Elements": all_elements_to_Json(),
		"Connections": all_connection_pairs_to_json()
	}
	
	var success: bool = file.store_string(JSON.stringify(save_data, "\t"))
	if success:
		status_bar.update_status("File saved to path: %s" % path)
		#DisplayServer.window_set_title("GPlanner %s: %s" % [app_version, path])
		get_tree().root.title = ("GPlanner %s: %s" % [app_version, path])
		opened_file_path = path
	else:
		status_bar.update_status("Error when saving file to path: %s" % path)
	file.close()


func load_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			print(FileAccess.get_open_error())
			return
		
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		
		if data == null:
			status_bar.update_status("Can't load file / Can't parse JSON string: %s" % path)
			printerr("Can't parse JSON string @ main.gd:load_file()")
			return
		else:
			var elems = data["Elements"]
			var conns = data["Connections"]
			if data.has("State"):
				var state = data["State"]
				rebuild_canvas_state(state)
			rebuild_elements(elems)
			rebuild_connections(conns)
		
		status_bar.update_status("File loaded: %s" % path)
		#DisplayServer.window_set_title("GPlanner %s: %s" % [app_version, path])
		get_tree().root.title = ("GPlanner %s: %s" % [app_version, path])
		opened_file_path = path
		toggle_completed.button_pressed = false
	else:
		printerr("File doesn't exist @ RoadSegmentDataManager:load_all_data()")	


func canvas_state_to_json() -> Dictionary:
	return {
		"position.x": element_container.position.x,
		"position.y": element_container.position.y,
		"scale.x": element_container.scale.x,
		"scale.y": element_container.scale.y,
		"zoom_level": zoom_level,
		"toggle_completed": toggle_completed.is_pressed(),
	}


func single_element_to_json(id: int) -> Dictionary:
	var e = elements[id]
	var bgc: Color = elements[id].get_bg_color()
	return {
		"id": e.id,
		"completed": e.completed,
		"pos.x": e.position.x,
		"pos.y": e.position.y,
		"size.x": e.size.x,
		"size.y": e.size.y,
		"text": e.line_edit.text,
		"bgcolor.r": bgc.r,
		"bgcolor.g": bgc.g,
		"bgcolor.b": bgc.b,
		"bgcolor.a": bgc.a,
	}


func all_elements_to_Json() -> Dictionary:
	var dict: Dictionary = {}
	for id in elements:
		if elements[id] != null:
			dict[id] = single_element_to_json(id)
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


func rebuild_canvas_state(state: Dictionary) -> void:
	element_container.position = pan_limits(Vector2(state["position.x"], state["position.y"]))
	element_container.scale.x = state["scale.x"]
	element_container.scale.y = state["scale.y"]
	zoom_indicator.update_zoom(element_container.scale.x)
	if state.has("zoom_level"):
		zoom_level = state["zoom_level"]
	update_checkboxes = true
	checkbox_data[0] = bool(state["toggle_completed"])


func rebuild_elements(json_elems: Dictionary) -> void:
	var max_id: int = -1
	for i in json_elems:
		if !json_elems[i].is_empty():
			var id: int = int(json_elems[i]["id"])
			var completed: bool = false
			if json_elems[i].has("completed"):		# Field only exists at version 0.1.3 or above
				completed = bool(json_elems[i]["completed"])
			var pos: Vector2 = Vector2(json_elems[i]["pos.x"], json_elems[i]["pos.y"])
			add_element_label(pos, id)
			elements[id].size = Vector2(json_elems[i]["size.x"], json_elems[i]["size.y"])
			var c: Color = Color(json_elems[i]["bgcolor.r"], json_elems[i]["bgcolor.g"], json_elems[i]["bgcolor.b"], json_elems[i]["bgcolor.a"])
			elements[id].set_bg_color(c)
			elements[id].line_edit.text = json_elems[i]["text"]
			if completed:
				elements[id].toggle_completed()
			if id > max_id:
				max_id = id
	element_id_counter = max_id + 1


func rebuild_connections(json_conns: Dictionary) -> void:
	var max_id: int = -1
	for i in json_conns:
		var id = int(i)
		connection_candidate_1 = int(json_conns[i]["id1"])
		connection_candidate_2 = int(json_conns[i]["id2"])
		add_connection(id)
		if id > max_id:
			max_id = id
	connection_id_counter = max_id + 1


func erase_everything() -> void:
	selection_viewer.visible = false
	selected_element = -1
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


func _on_toggle_completed_toggled(toggled_on: bool) -> void:
	for i in elements:
		if elements[i].completed:
			toggle_element_and_connections(i, toggled_on)


func toggle_element_and_connections(id: int, off: bool) -> void:
	if selected_element == id:
		selected_element = -1
		selection_viewer.visible = false
		
	elements[id].visible = !off
	for elem_id in connections_p1:	# Hide / Show connections
		if elem_id == id:
			for conn_id in connections_p1[elem_id]:
				connections[conn_id].visible = !off
	for elem_id in connections_p2:
		if elem_id == id:
			for conn_id in connections_p2[elem_id]:
				connections[conn_id].visible = !off
