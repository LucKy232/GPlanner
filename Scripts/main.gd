extends Control

@onready var tool_box: ItemList = $MarginContainer/ToolBox
@onready var element_container: Control = $ElementContainer
@onready var connection_container: Control = $ElementContainer/ConnectionContainer
@onready var selection_viewer: Panel = $ElementContainer/SelectionViewer
@onready var connection_indicator: Panel = $ElementContainer/ConnectionIndicator
@onready var zoom_indicator: VBoxContainer = $MarginContainer/ZoomIndicator
@onready var color_picker: ColorPicker = $MarginContainer/ColorPicker
@onready var color_picker_bg: Panel = $MarginContainer/ColorPickerBG
@onready var file_dialog_save: FileDialog = $FileDialogSave
@onready var file_dialog_load: FileDialog = $FileDialogLoad
@onready var status_bar: Label = $MarginContainer/StatusBar
@onready var show_completed: CheckBox = $MarginContainer/Settings/Checkboxes/ShowCompleted
@onready var show_priorities: CheckBox = $MarginContainer/Settings/Checkboxes/ShowPriorities
@onready var show_priority_tool: CheckBox = $MarginContainer/Settings/FilterSettings/ShowPriorityTool
@onready var priority_filter: HScrollBar = $MarginContainer/Settings/FilterSettings/PriorityFilter
@onready var priority_filter_label: Label = $MarginContainer/Settings/FilterSettings/PriorityFilterLabel
@onready var filter_settings: VBoxContainer = $MarginContainer/Settings/FilterSettings

@export_file("*.tscn") var element_scene
@export_file("*.tscn") var connection_scene
@export var zoom_limits: Vector2 = Vector2(0.25, 4.0)
@export_range(1.01, 1.2, 0.01) var zoom_speed: float = 1.02
@export var priority_colors: Array[Color]
@export var priority_styleboxes: Array[StyleBoxFlat]
@export var priority_filter_text: Array[String]

var tool_keybinds: Dictionary[int, String] = {}
var CHECKBOX_NUMBER: int = 3
var elements: Dictionary[int, ElementLabel]
var connections: Dictionary[int, Connection]
var connections_p1: Dictionary[int, PackedInt32Array]	## ELEMENT ID key, Array of CONNECTION ID value
var connections_p2: Dictionary[int, PackedInt32Array]	## ELEMENT ID key, Array of CONNECTION ID value
var elements_to_connection: Dictionary[Vector2i, int]	## ELEMENT ID Vector2i(ID1, ID2) key, CONNECTION ID value
var element_id_counter: int = 0
var connection_id_counter: int = 0
var connection_candidate_1: int = -1
var connection_candidate_2: int = -1

var selected_element: int = -1
var is_dragging: bool = false
var is_resizing: bool = false
var is_panning: bool = false
var is_editing_text: bool = false
var is_element_just_created: bool = false
var drag_start_mouse_pos: Vector2
var original_size: Vector2
var zoom_level: float = 1.0
var opened_file_path: String = ""
var app_version: String = ""
var update_checkboxes: bool = false
var checkbox_data: Array[bool]

enum Checkbox {
	SHOW_PRIORITIES,
	SHOW_PRIORITY_TOOL,
	SHOW_COMPLETED,
}
enum Tool {
	SELECT,
	ADD_ELEMENT,
	REMOVE_ELEMENT,
	BG_COLOR,
	ADD_CONNECTION,
	REMOVE_CONNECTIONS,
	MARK_COMPLETED,
}
enum Priority {
	ACTIVE,
	HIGH,
	MEDIUM,
	LOW,
	NONE,
}


func _ready() -> void:
	checkbox_data.resize(CHECKBOX_NUMBER)
	for i in CHECKBOX_NUMBER:
		checkbox_data[i] = false
	app_version = ProjectSettings.get_setting("application/config/version")
	new_file()
	update_zoom_limits(zoom_limits)


func _process(_delta):
	if elements.has(selected_element):	# TODO signal if line_edit is selected instead of every frame
		if elements[selected_element].line_edit.is_editing():
			is_editing_text = true
		else:
			is_editing_text = false
	else:
		is_editing_text = false
	if Input.is_action_just_pressed("save_file"):	# Can do while editing text because ctrl+s doesn't insert anything
		if opened_file_path == "":
			file_dialog_save.visible = true
		else:
			save_file(opened_file_path)
	if Input.is_action_just_pressed("edit_element"):
		if elements.has(selected_element):
			if !elements[selected_element].line_edit.is_editing():
				elements[selected_element].line_edit.edit()
	if Input.is_action_just_pressed(tool_keybinds[Tool.SELECT]) and !is_editing_text:
		tool_box.select(Tool.SELECT)
		_on_tool_box_item_selected(Tool.SELECT)
	if Input.is_action_just_pressed(tool_keybinds[Tool.ADD_ELEMENT]) and !is_editing_text:
		tool_box.select(Tool.ADD_ELEMENT)
		_on_tool_box_item_selected(Tool.ADD_ELEMENT)
	if Input.is_action_just_pressed(tool_keybinds[Tool.REMOVE_ELEMENT]) and !is_editing_text:
		tool_box.select(Tool.REMOVE_ELEMENT)
		_on_tool_box_item_selected(Tool.REMOVE_ELEMENT)
	if Input.is_action_just_pressed(tool_keybinds[Tool.BG_COLOR]) and !is_editing_text:
		tool_box.select(Tool.BG_COLOR)
		_on_tool_box_item_selected(Tool.BG_COLOR)
	if Input.is_action_just_pressed(tool_keybinds[Tool.ADD_CONNECTION]) and !is_editing_text:
		tool_box.select(Tool.ADD_CONNECTION)
		_on_tool_box_item_selected(Tool.ADD_CONNECTION)
	if Input.is_action_just_pressed(tool_keybinds[Tool.REMOVE_CONNECTIONS]) and !is_editing_text:
		tool_box.select(Tool.REMOVE_CONNECTIONS)
		_on_tool_box_item_selected(Tool.REMOVE_CONNECTIONS)
	if Input.is_action_just_pressed(tool_keybinds[Tool.MARK_COMPLETED]) and !is_editing_text:
		tool_box.select(Tool.MARK_COMPLETED)
		_on_tool_box_item_selected(Tool.MARK_COMPLETED)
	if update_checkboxes:
		force_update_checkboxes()


func create_tool_keybinds() -> void:
	tool_keybinds[Tool.SELECT] = "select_element"
	tool_keybinds[Tool.ADD_ELEMENT] = "add_element"
	tool_keybinds[Tool.REMOVE_ELEMENT] = "remove_element"
	tool_keybinds[Tool.BG_COLOR] = "element_bg_color"
	tool_keybinds[Tool.ADD_CONNECTION] = "add_connection"
	tool_keybinds[Tool.REMOVE_CONNECTIONS] = "remove_connections"
	tool_keybinds[Tool.MARK_COMPLETED] = "mark_completed"
	for tool in tool_keybinds:
		for event in InputMap.action_get_events(tool_keybinds[tool]):
			tool_box.set_item_text(tool, ("%s (%s)") % [tool_box.get_item_text(tool), event.as_text().split(" ")[0]])


func force_update_checkboxes() -> void:
	if !show_completed.is_pressed() and !checkbox_data[Checkbox.SHOW_COMPLETED]:
		_on_show_completed_toggled(false)
	if !show_priorities.is_pressed() and !checkbox_data[Checkbox.SHOW_PRIORITIES]:
		_on_show_priorities_toggled(false)
	if !show_priority_tool.is_pressed() and !checkbox_data[Checkbox.SHOW_PRIORITY_TOOL]:
		_on_show_priority_tool_toggled(false)
	show_completed.set_pressed(checkbox_data[Checkbox.SHOW_COMPLETED])
	show_priorities.set_pressed(checkbox_data[Checkbox.SHOW_PRIORITIES])
	show_priority_tool.set_pressed(checkbox_data[Checkbox.SHOW_PRIORITY_TOOL])
	update_checkboxes = false


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
	new_element.resized.connect(_on_element_label_resized.bind(id))
	new_element.became_active.connect(_on_element_text_box_active.bind(id))
	new_element.changed_priority.connect(_on_element_changed_priority.bind(id))
	element_container.add_child(new_element)
	new_element.position = at_position
	new_element.priority_id = Priority.NONE
	new_element.priority_tool_enabled = show_priority_tool.is_pressed()
	new_element.set_priority_color(priority_colors[Priority.NONE])
	new_element.set_priority_visible(show_priorities.is_pressed())
	new_element.z_index = element_container.z_index
	if id_specified < 0:	# Don't select elements when creating them in bulk by specifying their ids
		elements[id].line_edit.edit()	# NOTE Also signals select_element(id)
		is_element_just_created = true


func add_connection(id_specified: int = -1) -> void:
	if connection_candidate_1 == connection_candidate_2:
		connection_candidate_1 = -1
		connection_candidate_2 = -1
		connection_indicator.visible = false
		return
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
	connection_indicator.visible = false


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
	#printt("Trying", id)
	if id == selected_element:
		#print("Same ID")
		return
	if elements.has(selected_element):	# Deselect previous element's line_edit
		#print("Deselect previous")
		elements[selected_element].line_edit.apply_ime()
		elements[selected_element].line_edit.deselect()
		elements[selected_element].line_edit.unedit()
		elements[selected_element].z_index = 0
	if elements.has(id):
		#print("Select id")
		selected_element = id
		selection_viewer.visible = true
		selection_viewer.size = elements[id].size
		selection_viewer.position = elements[id].position
		elements[selected_element].z_index = 1
	else:	# Deselect element if id invalid
		#print("ID invalid")
		selection_viewer.visible = false
		selected_element = -1


func update_connections(elem_id: int) -> void:
	if connections_p1.has(elem_id):
		for conn_id in connections_p1[elem_id]:
			connections[conn_id].update_p1(elements[elem_id].position, elements[elem_id].size)
			connections[conn_id].update_positions()
	if connections_p2.has(elem_id):
		for conn_id in connections_p2[elem_id]:
			connections[conn_id].update_p2(elements[elem_id].position, elements[elem_id].size)
			connections[conn_id].update_positions()


func update_zoom_limits(limits: Vector2) -> void:
	zoom_indicator.zoom_progress_bar.min_value = limits.x
	zoom_indicator.zoom_progress_bar.max_value = limits.y


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


func new_file() -> void:
	erase_everything()
	#DisplayServer.window_set_title("GPlanner %s: New File" % [app_version])
	get_tree().root.title = ("GPlanner %s: New File" % [app_version])
	status_bar.update_status("New File")
	opened_file_path = ""
	# Start from the center on New File
	element_container.position = -element_container.size * 0.5 + get_viewport_rect().size * 0.5
	element_container.scale = Vector2(1.0, 1.0)
	for i in CHECKBOX_NUMBER:
		checkbox_data[i] = false
	update_checkboxes = true
	for i in priority_styleboxes.size():
		priority_styleboxes[i].bg_color = priority_colors[i]
	create_tool_keybinds()
	tool_box.select(Tool.SELECT)
	_on_tool_box_item_selected(Tool.SELECT)


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
		show_completed.button_pressed = false
	else:
		printerr("File doesn't exist @ RoadSegmentDataManager:load_all_data()")


func canvas_state_to_json() -> Dictionary:
	return {
		"position.x": element_container.position.x,
		"position.y": element_container.position.y,
		"scale.x": element_container.scale.x,
		"scale.y": element_container.scale.y,
		"zoom_level": zoom_level,
		"show_completed": show_completed.is_pressed(),
		"show_priorities": show_priorities.is_pressed(),
		"show_priority_tool": show_priority_tool.is_pressed(),
		"priority_filter_value": priority_filter.value,
	}


func single_element_to_json(id: int) -> Dictionary:
	var e = elements[id]
	var bgc: Color = elements[id].get_bg_color()
	return {
		"id": e.id,
		"priority_id": e.priority_id,
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
	if state.has("show_completed"):
		checkbox_data[Checkbox.SHOW_COMPLETED] = bool(state["show_completed"])
	if state.has("show_priorities"):
		checkbox_data[Checkbox.SHOW_PRIORITIES] = bool(state["show_priorities"])
	if state.has("show_priority_tool"):
		checkbox_data[Checkbox.SHOW_PRIORITY_TOOL] = bool(state["show_priority_tool"])
	if state.has("priority_filter_value"):
		priority_filter.value = int(state["priority_filter_value"])


func rebuild_elements(json_elems: Dictionary) -> void:
	var max_id: int = -1
	for i in json_elems:
		if !json_elems[i].is_empty():
			var id: int = int(json_elems[i]["id"])
			var completed: bool = false
			if json_elems[i].has("completed"):		# Field only exists at version 0.1.3 or above
				completed = bool(json_elems[i]["completed"])
			var priority_id: int = Priority.NONE
			if json_elems[i].has("priority_id"):
				priority_id = int(json_elems[i]["priority_id"])
			var pos: Vector2 = Vector2(json_elems[i]["pos.x"], json_elems[i]["pos.y"])
			add_element_label(pos, id)
			elements[id].size = Vector2(json_elems[i]["size.x"], json_elems[i]["size.y"])
			elements[id].priority_id = priority_id
			elements[id].set_priority_color(priority_colors[priority_id])
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


func toggle_element_and_connections(id: int, state: bool) -> void:
	if selected_element == id:
		selected_element = -1
		selection_viewer.visible = false
	elements[id].visible = state
	
	if id in connections_p1:
		for conn_id in connections_p1[id]:
			connections[conn_id].visible = state
	if id in connections_p2:
		for conn_id in connections_p2[id]:
			connections[conn_id].visible = state


func toggle_element(id: int, state: bool) -> void:
	if selected_element == id:
		selected_element = -1
		selection_viewer.visible = false
	elements[id].visible = state


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


func handle_zoom(old_zoom: float, target: Vector2) -> void:
	if abs(1.0 - zoom_level) < (zoom_speed - 1.0 + 0.005):
		element_container.scale = Vector2(1.0, 1.0)
	else:
		element_container.scale = Vector2(zoom_level, zoom_level)
	if abs(1.0 - old_zoom) < (zoom_speed - 1.0 + 0.005):
		old_zoom = 1.0
	
	# Keeps the top-left of the screen consistent while scaling the canvas
	var delta_screen_tl: Vector2 = element_container.position - (element_container.position * element_container.scale) / old_zoom
	# Gives you how much to move to go to a screen location after zooming
	var delta_scale = 1.0 - old_zoom / element_container.scale.x
	
	element_container.position = pan_limits(element_container.position - delta_screen_tl - target * delta_scale)
	zoom_indicator.update_zoom(element_container.scale.x)


func _on_tool_box_item_selected(index: int) -> void:
	if index == Tool.BG_COLOR:
		color_picker.visible = true
		color_picker_bg.visible = true
	elif index != Tool.BG_COLOR and color_picker.visible == true:
		color_picker.visible = false
		color_picker_bg.visible = false
	if index != Tool.ADD_CONNECTION:
		connection_candidate_1 = -1
		connection_candidate_2 = -1
		connection_indicator.visible = false


func _on_element_container_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if tool_box.is_selected(Tool.ADD_ELEMENT):
				add_element_label(event.position)
				if !Input.is_key_pressed(KEY_CTRL):
					tool_box.select(Tool.SELECT)
			if tool_box.is_selected(Tool.SELECT):
				if !is_element_just_created:
					select_element(-1)	# Deselect any
				else:
					is_element_just_created = false
				if !is_panning:
					is_panning = true
					drag_start_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			if is_panning:
				is_panning = false
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and tool_box.is_selected(Tool.SELECT):
			var old_zoom: float = zoom_level
			zoom_level = clampf(zoom_level * zoom_speed, zoom_limits.x, zoom_limits.y)
			handle_zoom(old_zoom, get_window().get_mouse_position())
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and tool_box.is_selected(Tool.SELECT):
			var old_zoom: float = zoom_level
			zoom_level = clampf(zoom_level * (2.0 - zoom_speed), zoom_limits.x, zoom_limits.y)
			handle_zoom(old_zoom, get_viewport_rect().size * 0.5)
	if event is InputEventMouseMotion and (tool_box.is_selected(Tool.SELECT) and is_panning):
		var move = (event.position - drag_start_mouse_pos) * element_container.scale.x
		element_container.position = pan_limits(element_container.position + move)


func _on_element_label_gui_input(event: InputEvent, id: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if tool_box.is_selected(Tool.ADD_CONNECTION):
				if connection_candidate_1 == -1:
					connection_candidate_1 = id
					select_element(id)
					connection_indicator.visible = true
					connection_indicator.position = elements[selected_element].position - Vector2(20.0, 20.0)
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
					is_panning = false
					original_size = elements[id].size
					drag_start_mouse_pos = event.position
				if !is_dragging and !is_resizing:
					is_dragging = true
					is_panning = false
					drag_start_mouse_pos = event.position
			if tool_box.is_selected(Tool.BG_COLOR):
				select_element(id)
				elements[id].set_bg_color(color_picker.color)
			if tool_box.is_selected(Tool.MARK_COMPLETED):
				elements[id].toggle_completed()
				toggle_element_and_connections(id, show_completed.button_pressed)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			if tool_box.is_selected(Tool.REMOVE_ELEMENT):
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
			elements[id].change_size(original_size + move)
			#selection_viewer.size = elements[id].size
			update_connections(id)


func _on_element_text_box_active(id: int) -> void:
	if elements.has(id):
		select_element(id)
		if tool_box.is_selected(Tool.BG_COLOR):
			elements[id].set_bg_color(color_picker.color)
		if tool_box.is_selected(Tool.MARK_COMPLETED):
			elements[id].toggle_completed()
			toggle_element_and_connections(id, show_completed.button_pressed)
		if tool_box.is_selected(Tool.ADD_CONNECTION):
			if connection_candidate_1 == -1:
				connection_candidate_1 = id
				select_element(id)
				connection_indicator.visible = true
				connection_indicator.position = elements[selected_element].position - Vector2(20.0, 20.0)
				#print("FIRST ID CONFIRMED")
			else:
				connection_candidate_2 = id
				add_connection()
		if tool_box.is_selected(Tool.REMOVE_CONNECTIONS):
			remove_connections(id)


func _on_element_label_resized(id: int) -> void:
	if selected_element == id:
		selection_viewer.size = elements[id].size


func _on_element_changed_priority(id: int) -> void:
	if elements.has(id):
		var pr_id = elements[id].priority_id
		elements[id].set_priority_color(priority_colors[pr_id])


func _on_color_picker_color_changed(color: Color) -> void:
	if tool_box.is_selected(Tool.BG_COLOR) and selected_element >= 0 and elements.has(selected_element):
		elements[selected_element].set_bg_color(color)


func _on_file_dialog_save_file_selected(path: String) -> void:
	save_file(path)


func _on_file_dialog_load_file_selected(path: String) -> void:
	erase_everything()
	load_file(path)


func _on_new_button_pressed() -> void:
	new_file()
	# TODO dialogue box before


func _on_save_button_pressed() -> void:
	if opened_file_path == "":
		file_dialog_save.visible = true
	else:
		save_file(opened_file_path)


func _on_save_as_button_pressed() -> void:
	file_dialog_save.visible = true


func _on_load_button_pressed() -> void:
	file_dialog_load.visible = true


func _on_show_completed_toggled(toggled_on: bool) -> void:
	for i in elements:
		if elements[i].completed:
			toggle_element_and_connections(i, toggled_on)


func _on_show_priorities_toggled(toggled_on: bool) -> void:
	for i in elements:
		elements[i].set_priority_visible(toggled_on)
	filter_settings.visible = toggled_on


func _on_priority_filter_value_changed(value: float) -> void:
	var filter = int(value)
	for i in elements:
		if elements[i].priority_id > value or (elements[i].completed and !show_completed.is_pressed()):
			toggle_element(i, false)
		else:
			toggle_element(i, true)
	for i in elements:
		toggle_connections(i)
	
	priority_filter_label.text = ("Priority: %s" % priority_filter_text[filter])


func _on_show_priority_tool_toggled(toggled_on: bool) -> void:
	for i in elements:
		elements[i].priority_tool_enabled = toggled_on
