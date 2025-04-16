extends Control

@onready var tool_box: ItemList = $MarginContainer/ToolBox
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
@onready var bottom_bar: HBoxContainer = $BottomBar
@onready var margin_container: MarginContainer = $MarginContainer
@onready var file_tab_bar: TabBar = $BottomBar/FileTabBar

#@onready var canvas: PlannerCanvas = $Canvas

@export_file("*.tscn") var element_scene
@export_file("*.tscn") var connection_scene
@export_file("*.tscn") var canvas_scene
@export var zoom_limits: Vector2 = Vector2(0.25, 4.0)
@export_range(1.01, 1.2, 0.01) var zoom_speed: float = 1.02
@export var priority_colors: Array[Color]
@export var priority_styleboxes: Array[StyleBoxFlat]
@export var priority_filter_text: Array[String]
@export var opened_files_file_name: String

var tool_keybinds: Dictionary[int, String] = {}
var is_editing_text: bool = false
var update_checkboxes: bool = false
var app_version: String = ""
var canvases: Dictionary[int, PlannerCanvas]
var tab_to_canvas: Dictionary[int, int]
var cc: int = -1		## Current Canvas ID

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


func _ready() -> void:
	app_version = ProjectSettings.get_setting("application/config/version")
	for i in priority_styleboxes.size():
		priority_styleboxes[i].bg_color = priority_colors[i]
	create_tool_keybinds()
	load_opened_file_paths(opened_files_file_name)
	if canvases.size() == 0:
		_on_add_file_button_pressed()
	update_zoom_limits(zoom_limits)
	get_tree().set_auto_accept_quit(false)		# Don't automatically quit


func _process(_delta):
	# TODO signal if line_edit is selected instead of every frame
	if selected_element_exists():
		if get_selected_element().line_edit.is_editing():
			is_editing_text = true
		else:
			is_editing_text = false
	else:
		is_editing_text = false
	if Input.is_action_just_pressed("save_file"):	# Can do while editing text because ctrl+s doesn't insert anything
		if canvases[cc].opened_file_path == "":
			file_dialog_save.visible = true
		else:
			save_file(canvases[cc].opened_file_path)
	if Input.is_action_just_pressed("edit_element"):
		if selected_element_exists() and !get_selected_element().line_edit.is_editing():
			get_selected_element().line_edit.edit()
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
	if update_checkboxes and canvases.has(cc):
		force_update_checkboxes()


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_opened_file_paths(opened_files_file_name)
		get_tree().quit() # Default behavior


func get_selected_element() -> ElementLabel:
	if canvases.has(cc) and canvases[cc].elements.has(canvases[cc].selected_element):
		return canvases[cc].elements[canvases[cc].selected_element]
	else:
		return null


func selected_element_exists() -> bool:
	return canvases.has(cc) and canvases[cc].elements.has(canvases[cc].selected_element)


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
	if !show_completed.is_pressed() and !canvases[cc].checkbox_data[Checkbox.SHOW_COMPLETED]:
		_on_show_completed_toggled(false)
	if !show_priorities.is_pressed() and !canvases[cc].checkbox_data[Checkbox.SHOW_PRIORITIES]:
		_on_show_priorities_toggled(false)
	if !show_priority_tool.is_pressed() and !canvases[cc].checkbox_data[Checkbox.SHOW_PRIORITY_TOOL]:
		_on_show_priority_tool_toggled(false)
	show_completed.set_pressed(canvases[cc].checkbox_data[Checkbox.SHOW_COMPLETED])
	show_priorities.set_pressed(canvases[cc].checkbox_data[Checkbox.SHOW_PRIORITIES])
	show_priority_tool.set_pressed(canvases[cc].checkbox_data[Checkbox.SHOW_PRIORITY_TOOL])
	update_checkboxes = false


func update_zoom_limits(limits: Vector2) -> void:
	zoom_indicator.zoom_progress_bar.min_value = limits.x
	zoom_indicator.zoom_progress_bar.max_value = limits.y


func switch_main_canvas(id: int) -> void:
	#print("Switch to %d" % [id])
	if cc == id:
		return
	if canvases.has(cc):	# Disable old canvas visibility
		canvases[cc].visible = false
		#print("%d off" % [cc])
	if canvases.has(id):
		canvases[id].visible = true
		#print("%d on" % [id])
	cc = id
	zoom_indicator.update_zoom(canvases[cc].scale.x)
	priority_filter.value = canvases[cc].priority_filter_value
	_on_priority_filter_value_changed(canvases[cc].priority_filter_value)
	update_checkboxes = true
	if file_tab_bar.tab_count == 0:
		file_tab_bar.add_tab("")
	if canvases[cc].opened_file_path != "":
		set_current_tab_title(canvases[cc].opened_file_path.get_file().get_slice(".", 0), canvases[cc].opened_file_path)
	else:
		set_current_tab_title("New File", "New File")


func set_current_tab_title(title: String, tooltip: String) -> void:
	file_tab_bar.set_tab_title(file_tab_bar.current_tab, title)
	file_tab_bar.set_tab_tooltip(file_tab_bar.current_tab, tooltip)
	#DisplayServer.window_set_title("GPlanner %s: %s" % [app_version, tooltip])
	get_tree().root.title = ("GPlanner %s: %s" % [app_version, tooltip])


func new_file() -> int:
	var new_canvas = load(canvas_scene).instantiate()
	add_child(new_canvas)
	bottom_bar.move_to_front()
	margin_container.move_to_front()
	new_canvas.id = canvases.size()
	canvases[new_canvas.id] = new_canvas
	new_canvas.new_canvas()
	new_canvas.done_adding_elements.connect(_on_canvas_done_adding_elements)
	new_canvas.changed_zoom.connect(_on_canvas_changed_zoom)
	#DisplayServer.window_set_title("GPlanner %s: New File" % [app_version])
	get_tree().root.title = ("GPlanner %s: New File" % [app_version])
	status_bar.update_status("New File")
	new_canvas.element_scene = element_scene
	new_canvas.connection_scene = connection_scene
	new_canvas.priority_colors = priority_colors
	new_canvas.zoom_limits = zoom_limits
	new_canvas.zoom_speed = zoom_speed
	tool_box.select(Tool.SELECT)
	_on_tool_box_item_selected(Tool.SELECT)
	update_checkboxes = true
	return new_canvas.id


func save_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	var save_data: Dictionary
	if file == null:
		printerr("FileAcces open error: ", FileAccess.get_open_error())
		return
	
	print("SAVING %s" % [path])
	save_data = {
		"State": canvases[cc].canvas_state_to_json(),
		"Elements": canvases[cc].all_elements_to_Json(),
		"Connections": canvases[cc].all_connection_pairs_to_json()
	}
	
	var success: bool = file.store_string(JSON.stringify(save_data, "\t"))
	if success:
		status_bar.update_status("File saved to path: %s" % path)
		#DisplayServer.window_set_title("GPlanner %s: %s" % [app_version, path])
		get_tree().root.title = ("GPlanner %s: %s" % [app_version, path])
		canvases[cc].opened_file_path = path
	else:
		status_bar.update_status("Error when saving file to path: %s" % path)
	file.close()


# NOTE load_file() overwrites currently selected canvas
func load_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			printerr("FileAcces open error: ", FileAccess.get_open_error())
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
				canvases[cc].opened_file_path = path
				canvases[cc].rebuild_canvas_state(state)
			canvases[cc].rebuild_elements(elems)
			canvases[cc].rebuild_connections(conns)
			_on_priority_filter_value_changed(canvases[cc].priority_filter_value)
		
		status_bar.update_status("File loaded: %s" % path)
		#DisplayServer.window_set_title("GPlanner %s: %s" % [app_version, path])
		get_tree().root.title = ("GPlanner %s: %s" % [app_version, path])
		set_current_tab_title(canvases[cc].opened_file_path.get_file().get_slice(".", 0), canvases[cc].opened_file_path)
		canvases[cc].visible = false
		canvases[cc].visible = true
	else:
		printerr("File doesn't exist @ main.gd:load_file()")


func save_opened_file_paths(path: String) -> void:
	var file = FileAccess.open("user://" + path, FileAccess.WRITE)
	var save_data: Dictionary
	var opened_files: Dictionary
	if file == null:
		printerr("FileAcces open error: ", FileAccess.get_open_error())
		return
	for c_id in canvases:
		if canvases[c_id].elements.size() > 0:
			if canvases[c_id].opened_file_path == "":
				switch_main_canvas(c_id)
				canvases[c_id].opened_file_path = "user://unsaved" + Time.get_datetime_string_from_system().replace(":", "") + ".json"
				save_file(canvases[c_id].opened_file_path)
			opened_files[c_id] = canvases[c_id].opened_file_path
			print("Saving canvas %d file location: %s" % [c_id, canvases[c_id].opened_file_path])
	save_data["OpenedFiles"] = opened_files
	save_data["CurrentID"] = cc
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()


func load_opened_file_paths(path: String) -> void:
	if FileAccess.file_exists("user://" + path):
		var file = FileAccess.open("user://" + path, FileAccess.READ)
		if file == null:
			printerr("FileAcces open error: ", FileAccess.get_open_error())
			return
		
		var content = file.get_as_text()
		file.close()
		var data = JSON.parse_string(content)
		if data == null:
			status_bar.update_status("Can't load file / Can't parse JSON string: %s" % path)
			printerr("Can't parse JSON string @ main.gd:load_file()")
			return
		else:
			var files = data["OpenedFiles"]
			for f in files:
				if files[f] != "":
					_on_add_file_button_pressed()	# new_file(), new tab, switch tab -> switch_main_canvas()
					load_file(files[f])
			var current = int(data["CurrentID"])
			if canvases.has(current):
				file_tab_bar.current_tab = current
			else:
				file_tab_bar.current_tab = file_tab_bar.tab_count - 1
	else:
		# Create empty file on first time load
		var file = FileAccess.open("user://" + path, FileAccess.WRITE)
		var save_data: Dictionary = { 0: "" }
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()


func _on_tool_box_item_selected(index: int) -> void:
	if canvases.has(cc):
		canvases[cc].tool_id = index
		if index != Tool.ADD_CONNECTION:
			canvases[cc].reset_adding_connection()
	if index == Tool.BG_COLOR:
		color_picker.visible = true
		color_picker_bg.visible = true
	elif index != Tool.BG_COLOR and color_picker.visible == true:
		color_picker.visible = false
		color_picker_bg.visible = false


func _on_color_picker_color_changed(color: Color) -> void:
	canvases[cc].color_picker_color = color
	if tool_box.is_selected(Tool.BG_COLOR) and selected_element_exists():
		get_selected_element().set_bg_color(color)
		canvases[cc].update_connection_color(get_selected_element().id, color)


func _on_file_dialog_save_file_selected(path: String) -> void:
	save_file(path)


func _on_file_dialog_load_file_selected(path: String) -> void:
	if canvases.has(cc):
		canvases[cc].erase_everything()
	else:
		_on_add_file_button_pressed()
	load_file(path)


func _on_new_button_pressed() -> void:
	new_file()
	# TODO dialogue box before


func _on_save_button_pressed() -> void:
	if canvases[cc].opened_file_path == "":
		file_dialog_save.visible = true
	else:
		save_file(canvases[cc].opened_file_path)


func _on_save_as_button_pressed() -> void:
	file_dialog_save.visible = true


func _on_load_button_pressed() -> void:
	file_dialog_load.visible = true


func _on_show_completed_toggled(toggled_on: bool) -> void:
	canvases[cc].toggle_show_completed(toggled_on)


func _on_show_priorities_toggled(toggled_on: bool) -> void:
	canvases[cc].toggle_show_priorities(toggled_on)
	filter_settings.visible = toggled_on


func _on_priority_filter_value_changed(value: float) -> void:
	var filter = int(value)
	canvases[cc].change_priority_filter(filter)
	priority_filter_label.text = ("Priority: %s" % priority_filter_text[filter])


func _on_show_priority_tool_toggled(toggled_on: bool) -> void:
	canvases[cc].toggle_show_priority_tool(toggled_on)


func _on_canvas_done_adding_elements() -> void:
	tool_box.select(Tool.SELECT)
	_on_tool_box_item_selected(Tool.SELECT)


func _on_canvas_changed_zoom() -> void:
	zoom_indicator.update_zoom(canvases[cc].scale.x)


func _on_file_tab_bar_tab_changed(tab: int) -> void:
	if tab_to_canvas.has(tab):
		switch_main_canvas(tab_to_canvas[tab])


func _on_add_file_button_pressed() -> void:
	var canvas_id: int = new_file()
	tab_to_canvas[file_tab_bar.tab_count] = canvas_id
	file_tab_bar.add_tab("New File")
	file_tab_bar.current_tab = file_tab_bar.tab_count - 1	# Also switches to the new tab & calls switch_main_canvas(tab)


func _on_file_tab_bar_tab_close_pressed(tab: int) -> void:
	if file_tab_bar.tab_count >= 1:
		canvases[tab_to_canvas[tab]].queue_free()
		canvases.erase(tab_to_canvas[tab])
		var tab_id = tab
		while tab_id < file_tab_bar.tab_count - 1:
			tab_to_canvas[tab_id] = tab_to_canvas[tab_id + 1]
			tab_id += 1
		file_tab_bar.remove_tab(tab)
	if file_tab_bar.tab_count <= 0:
		_on_add_file_button_pressed()
