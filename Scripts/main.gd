extends Control

@onready var toggle_mode_button: CheckButton = $MarginContainer/ToolVBox/ToolArea/ToggleMode
@onready var tool_box: ItemList = $MarginContainer/ToolVBox/ToolArea/PlannerToolBox
@onready var drawing_tool_box: ItemList = $MarginContainer/ToolVBox/ToolArea/DrawingToolBox
@onready var drawing_tool_bar: DrawingToolBar = $MarginContainer/ToolVBox/DrawingToolBar
@onready var settings_drawer: SettingsDrawer = $SettingsDrawer
@onready var element_settings: ElementSettings = $MarginContainer/ElementSettings
@onready var zoom_indicator: ZoomIndicator = $MarginContainer/ZoomIndicator
@onready var pan_indicator_camera: PanIndicatorCamera = $MarginContainer/PanIndicatorCamera
@onready var status_bar: Label = $StatusBar
@onready var margin_container: MarginContainer = $MarginContainer
@onready var file_dialog_save: FileDialog = $FileDialogSave
@onready var file_dialog_load: FileDialog = $FileDialogLoad
@onready var new_file_confirmation: AcceptDialog = $NewFileConfirmation
@onready var load_file_confirmation: AcceptDialog = $LoadFileConfirmation
@onready var close_tab_confirmation: AcceptDialog = $CloseTabConfirmation
@onready var exit_tab_confirmation: AcceptDialog = $ExitTabConfirmation
@onready var bottom_bar: ScrollContainer = $BottomBar
@onready var file_tab_bar: TabBar = $BottomBar/HBoxContainer/FileTabBar
@onready var drawing_manager: DrawingManager = $DrawingManager
@onready var input_repeat_timer: Timer = $InputRepeatTimer
@onready var cursor_big_brush: TextureRect = $CursorBigBrush

@export_category("Scenes")
@export_file("*.tscn") var element_scene
@export_file("*.tscn") var connection_scene
@export_file("*.tscn") var canvas_scene
@export_category("Themes")
@export_color_no_alpha var accent_color_planning
@export_color_no_alpha var accent_color_drawing
@export var button_theme: Theme
@export var popup_dialog_theme: Theme
@export var priority_colors: Array[Color]
@export var priority_styleboxes: Array[StyleBoxFlat]
@export_category("Settings")
@export var zoom_limits: Vector2 = Vector2(0.2, 2.0)
@export_range(1.01, 1.2, 0.01) var zoom_speed: float = 1.02
@export var opened_files_file_name: String
@export var pencil_cursor: Texture2D
@export var eraser_pencil_cursor: Texture2D

var draw_tool_keybinds: Dictionary[int, String] = {}
var tool_keybinds: Dictionary[int, String] = {}
var is_editing_element_text: bool = false
var is_editing_preset_name: bool = false
var is_saving_images: bool = false
var app_version: String = ""
var canvases: Dictionary[int, PlannerCanvas]
var tab_to_canvas: Dictionary[int, int]
var cc: int = -1		## Current Canvas ID
var max_canvas_id: int = 0
var show_load_dialog: bool = false
var close_this_tab: bool = false
var exiting_app: bool = false
var need_to_save_images_on_tool_change = false
var first_input_repeat: bool = true
var using_cursor_image: bool = false
var last_window_mode: Window.Mode = Window.Mode.MODE_WINDOWED		## When going to borderless fullscreen, remember the last Window.Mode


func _ready() -> void:
	#Performance.add_custom_monitor("Request Action Type", func(): return int(canvases[cc].get_requested_save_action()))
	get_tree().set_auto_accept_quit(false)		# Don't automatically quit
	var window_size: Vector2 = get_viewport_rect().size
	pan_indicator_camera.set_world_2d(get_world_2d())
	pan_indicator_camera.set_window_size(window_size)
	app_version = ProjectSettings.get_setting("application/config/version")
	for i in priority_styleboxes.size():
		priority_styleboxes[i].bg_color = priority_colors[i]
	create_tool_keybinds()
	create_drawing_tool_keybinds()
	load_opened_file_paths(opened_files_file_name)
	if canvases.size() == 0:
		_on_add_file_button_pressed()
	update_zoom_limits(zoom_limits)
	connect_signals()
	new_file_confirmation.add_button("     No     ", true, "no_save")
	new_file_confirmation.add_cancel_button(" Cancel ")
	load_file_confirmation.add_button("     No     ", true, "no_save")
	load_file_confirmation.add_cancel_button(" Cancel ")
	close_tab_confirmation.add_button("     No     ", true, "no_save")
	close_tab_confirmation.add_cancel_button(" Cancel ")
	exit_tab_confirmation.add_button("     No     ", true, "no_save")
	exit_tab_confirmation.add_cancel_button(" Cancel ")


func _process(_delta):
	if selected_element_exists():
		if get_selected_element().line_edit.is_editing():
			is_editing_element_text = true
		else:
			is_editing_element_text = false
	else:
		is_editing_element_text = false
	if use_mouse_cursor_big_brush():
		cursor_big_brush.position = get_viewport().get_mouse_position() - cursor_big_brush.size * 0.5
	if Input.is_action_just_pressed("fullscreen_borderless") and !is_saving_images:
		toggle_borderless_window()
	if Input.is_action_just_pressed("exit_fullscreen_borderless") and get_window().mode == Window.MODE_FULLSCREEN and !is_saving_images:
		toggle_borderless_window()
	if Input.is_action_just_pressed("save_file"):	# Can do while editing text because ctrl+s doesn't insert anything
		_on_save_button_pressed()
	if Input.is_action_just_pressed("edit_element") and !tool_box.is_selected(Enums.Tool.MARK_COMPLETED):
		if selected_element_exists() and !disable_input() and !Input.is_key_pressed(KEY_CTRL):
			get_selected_element().line_edit.edit()
	if Input.is_action_pressed("undo", true) and !disable_input() and (input_repeat_timer.is_stopped() or first_input_repeat):
		if drawing_manager.undo_drawing_action():	# Check + action
			input_repeat_timer.start(0.5 if first_input_repeat else 0.1)
			first_input_repeat = false
			canvases[cc].drawings_changed()	# A bit redundant since it already has changes if there's something that you can undo / redo
	if Input.is_action_pressed("redo", true) and !disable_input() and (input_repeat_timer.is_stopped() or first_input_repeat):
		if drawing_manager.redo_drawing_action():	# Check + action
			input_repeat_timer.start(0.5 if first_input_repeat else 0.1)
			first_input_repeat = false
			canvases[cc].drawings_changed()	# A bit redundant since it already has changes if there's something that you can undo / redo
	if Input.is_action_just_released("undo") or Input.is_action_just_released("redo"):
		first_input_repeat = true
	
	if canvases[cc].settings.app_mode == Enums.AppMode.DRAWING:
		if Input.is_action_just_pressed(draw_tool_keybinds[Enums.DrawingTool.PENCIL], true):
			drawing_tool_box.select(Enums.DrawingTool.PENCIL)
			_on_drawing_tool_box_item_selected(Enums.DrawingTool.PENCIL)
		if Input.is_action_just_pressed(draw_tool_keybinds[Enums.DrawingTool.BRUSH], true):
			drawing_tool_box.select(Enums.DrawingTool.BRUSH)
			_on_drawing_tool_box_item_selected(Enums.DrawingTool.BRUSH)
		if Input.is_action_just_pressed(draw_tool_keybinds[Enums.DrawingTool.ERASER_PENCIL], true):
			drawing_tool_box.select(Enums.DrawingTool.ERASER_PENCIL)
			_on_drawing_tool_box_item_selected(Enums.DrawingTool.ERASER_PENCIL)
		if Input.is_action_just_pressed(draw_tool_keybinds[Enums.DrawingTool.ERASER_BRUSH], true):
			drawing_tool_box.select(Enums.DrawingTool.ERASER_BRUSH)
			_on_drawing_tool_box_item_selected(Enums.DrawingTool.ERASER_BRUSH)
	
	if canvases[cc].settings.app_mode == Enums.AppMode.PLANNING:
		if Input.is_action_just_pressed(tool_keybinds[Enums.Tool.SELECT]) and !disable_input() and !Input.is_key_pressed(KEY_CTRL):
			tool_box.select(Enums.Tool.SELECT)
			_on_tool_box_item_selected(Enums.Tool.SELECT)
		if Input.is_action_just_pressed(tool_keybinds[Enums.Tool.ADD_ELEMENT]) and !disable_input() and !Input.is_key_pressed(KEY_CTRL):
			tool_box.select(Enums.Tool.ADD_ELEMENT)
			_on_tool_box_item_selected(Enums.Tool.ADD_ELEMENT)
		if Input.is_action_just_pressed(tool_keybinds[Enums.Tool.REMOVE_ELEMENT]) and !disable_input() and !Input.is_key_pressed(KEY_CTRL):
			tool_box.select(Enums.Tool.REMOVE_ELEMENT)
			_on_tool_box_item_selected(Enums.Tool.REMOVE_ELEMENT)
		if Input.is_action_just_pressed(tool_keybinds[Enums.Tool.ELEMENT_STYLE_SETTINGS]) and !disable_input() and !Input.is_key_pressed(KEY_CTRL):
			tool_box.select(Enums.Tool.ELEMENT_STYLE_SETTINGS)
			_on_tool_box_item_selected(Enums.Tool.ELEMENT_STYLE_SETTINGS)
		if Input.is_action_just_pressed(tool_keybinds[Enums.Tool.ADD_CONNECTION]) and !disable_input() and !Input.is_key_pressed(KEY_CTRL):
			tool_box.select(Enums.Tool.ADD_CONNECTION)
			_on_tool_box_item_selected(Enums.Tool.ADD_CONNECTION)
		if Input.is_action_just_pressed(tool_keybinds[Enums.Tool.REMOVE_CONNECTIONS]) and !disable_input() and !Input.is_key_pressed(KEY_CTRL):
			tool_box.select(Enums.Tool.REMOVE_CONNECTIONS)
			_on_tool_box_item_selected(Enums.Tool.REMOVE_CONNECTIONS)
		if Input.is_action_just_pressed(tool_keybinds[Enums.Tool.MARK_COMPLETED]) and !disable_input() and !Input.is_key_pressed(KEY_CTRL):
			tool_box.select(Enums.Tool.MARK_COMPLETED)
			_on_tool_box_item_selected(Enums.Tool.MARK_COMPLETED)


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_saving_images:
			return
		exiting_app = true
		confirmation_tab_save(0)
		#get_tree().quit() # Default behavior


func connect_signals() -> void:
	settings_drawer.show_completed.toggled.connect(_on_show_completed_toggled)
	settings_drawer.show_priorities.toggled.connect(_on_show_priorities_toggled)
	settings_drawer.show_priority_tool.toggled.connect(_on_show_priority_tool_toggled)
	settings_drawer.priority_filter.value_changed.connect(_on_priority_filter_value_changed)
	
	drawing_manager.requested_status_message.connect(_on_drawing_manager_status_message)
	drawing_manager.forced_save_started.connect(_on_drawing_manager_forced_save_started)
	drawing_manager.forced_save_ended.connect(_on_drawing_manager_forced_save_ended)
	
	drawing_tool_bar.color_picker_toggled.connect(_on_drawing_tool_bar_color_picker_toggled)
	drawing_tool_bar.brush_size_changed.connect(change_drawing_tool_cursor)
	drawing_tool_bar.brush_color_changed.connect(change_drawing_tool_cursor)


func create_tool_keybinds() -> void:
	tool_keybinds[Enums.Tool.SELECT] = "select_element"
	tool_keybinds[Enums.Tool.ADD_ELEMENT] = "add_element"
	tool_keybinds[Enums.Tool.REMOVE_ELEMENT] = "remove_element"
	tool_keybinds[Enums.Tool.ELEMENT_STYLE_SETTINGS] = "element_style_settings"
	tool_keybinds[Enums.Tool.ADD_CONNECTION] = "add_connection"
	tool_keybinds[Enums.Tool.REMOVE_CONNECTIONS] = "remove_connections"
	tool_keybinds[Enums.Tool.MARK_COMPLETED] = "mark_completed"
	for tool in tool_keybinds:
		for event in InputMap.action_get_events(tool_keybinds[tool]):
			tool_box.set_item_text(tool, ("%s (%s)") % [tool_box.get_item_text(tool), event.as_text().split(" ")[0]])


func create_drawing_tool_keybinds() -> void:
	draw_tool_keybinds[Enums.DrawingTool.PENCIL] = "pencil"
	draw_tool_keybinds[Enums.DrawingTool.BRUSH] = "brush"
	draw_tool_keybinds[Enums.DrawingTool.ERASER_PENCIL] = "eraser_pencil"
	draw_tool_keybinds[Enums.DrawingTool.ERASER_BRUSH] = "eraser_brush"
	
	for tool in draw_tool_keybinds:
		for event in InputMap.action_get_events(draw_tool_keybinds[tool]):
			drawing_tool_box.set_item_text(tool, ("%s (%s)") % [drawing_tool_box.get_item_text(tool), event.as_text().split(" ")[0]])
	set_toggle_mode_button_tooltip("Change to Drawing Mode")


func set_toggle_mode_button_tooltip(tooltip: String) -> void:
	toggle_mode_button.tooltip_text = tooltip
	for event in InputMap.action_get_events("switch_app_mode"):
		toggle_mode_button.tooltip_text = "%s (%s)" % [toggle_mode_button.tooltip_text, event.as_text().split(" ")[0]]
	toggle_mode_button.shortcut = Shortcut.new()
	toggle_mode_button.shortcut.events = InputMap.action_get_events("switch_app_mode")


func update_zoom_limits(limits: Vector2) -> void:
	zoom_indicator.zoom_progress_bar.min_value = limits.x
	zoom_indicator.zoom_progress_bar.max_value = limits.y


func toggle_borderless_window() -> void:
	if get_window().mode == Window.Mode.MODE_WINDOWED or get_window().mode == Window.Mode.MODE_MAXIMIZED:
		last_window_mode = get_window().mode
		get_window().mode = Window.MODE_FULLSCREEN
		get_window().borderless = true
	elif get_window().mode == Window.MODE_FULLSCREEN:
		get_window().mode = last_window_mode
		get_window().borderless = false


func get_selected_element() -> ElementLabel:
	if canvases.has(cc) and canvases[cc].elements.has(canvases[cc].selected_element):
		return canvases[cc].elements[canvases[cc].selected_element]
	else:
		return null


func selected_element_exists() -> bool:
	return canvases.has(cc) and canvases[cc].elements.has(canvases[cc].selected_element)


func switch_main_canvas(id: int) -> void:
	if is_saving_images:
		return
	if cc == id:
		return
	if canvases.has(cc):	# Disable old canvas visibility
		canvases[cc].visible = false
	if canvases.has(id):
		canvases[id].visible = true
	cc = id
	pan_indicator_camera.set_canvas_size(canvases[cc].size)
	if file_tab_bar.tab_count == 0:
		file_tab_bar.add_tab("")
	set_tab_name_and_title_from_canvas(cc)
	canvases[cc].change_selected_preset_style("none")
	element_settings.erase_everything()
	element_settings.rebuild_options_and_dictionary_from_canvas(canvases[cc].style_presets)
	drawing_manager.change_active_canvas_drawing_group(cc)
	drawing_tool_bar.change_settings(canvases[cc].drawing_settings)
	drawing_tool_box.select(canvases[cc].drawing_settings.selected_tool)
	_on_drawing_tool_box_item_selected(canvases[cc].drawing_settings.selected_tool)
	call_deferred("_on_canvas_changed_zoom")
	call_deferred("_on_canvas_changed_position")
	if canvases[cc].save_state.is_loaded:
		settings_drawer.update_data(canvases[cc].settings)
	if canvases[cc].settings.app_mode == Enums.AppMode.DRAWING:
		_on_toggle_mode_toggled(true)
		toggle_mode_button.set_pressed_no_signal(true)
	else:
		_on_toggle_mode_toggled(false)
		toggle_mode_button.set_pressed_no_signal(false)


func set_current_tab_title(title: String, tooltip: String, token: String) -> void:
	file_tab_bar.set_tab_title(file_tab_bar.current_tab, "%s%s" % [title, token])
	file_tab_bar.set_tab_tooltip(file_tab_bar.current_tab, "%s%s" % [token, tooltip])
	#DisplayServer.window_set_title("GPlanner %s: %s" % [app_version, tooltip])
	get_tree().root.title = ("GPlanner %s: %s%s" % [app_version, tooltip, token])


func set_tab_name_and_title_from_canvas(c_id: int) -> void:
	var token: String = "(*)" if canvases[c_id].has_changes() else ""
	if canvases[c_id].opened_file_path == "":
		set_current_tab_title("New File", "New File", token)
	else:
		set_current_tab_title(canvases[c_id].file_name_short, canvases[c_id].opened_file_path, token)


func new_file(add_canvas: bool) -> int:
	var new_canvas: PlannerCanvas
	if add_canvas:
		new_canvas = load(canvas_scene).instantiate()
		add_child(new_canvas)
		margin_container.move_to_front()
		element_settings.move_to_front()
		settings_drawer.move_to_front()
		bottom_bar.move_to_front()
		new_canvas.id = max_canvas_id
		max_canvas_id += 1
		canvases[new_canvas.id] = new_canvas
		new_canvas.done_adding_elements.connect(_on_canvas_done_adding_elements)
		new_canvas.changed_zoom.connect(_on_canvas_changed_zoom)
		new_canvas.changed_position.connect(_on_canvas_changed_position)
		new_canvas.has_changed.connect(_on_canvas_has_changed.bind(new_canvas.id))
		new_canvas.has_selected_element.connect(_on_canvas_has_selected_element)
		new_canvas.has_deselected_element.connect(_on_canvas_has_deselected_element)
		new_canvas.element_scene = element_scene
		new_canvas.connection_scene = connection_scene
		new_canvas.priority_colors = priority_colors
		new_canvas.zoom_limits = zoom_limits
		new_canvas.zoom_speed = zoom_speed
		drawing_manager.add_canvas_drawing_group(new_canvas.id)
		new_canvas.drawing_manager = drawing_manager
	elif canvases.has(cc):
		new_canvas = canvases[cc]
		new_canvas.erase_everything()
		drawing_manager.clear_canvas_drawing_group(cc)
	else:
		return -1
	
	new_canvas.new_canvas()
	#DisplayServer.window_set_title("GPlanner %s: New File" % [app_version])
	get_tree().root.title = ("GPlanner %s: New File" % [app_version])
	status_bar.update_status("New File")
	tool_box.select(Enums.Tool.SELECT)
	if canvases[new_canvas.id].save_state.is_loaded:
		settings_drawer.update_data(canvases[new_canvas.id].settings)
	_on_tool_box_item_selected(Enums.Tool.SELECT)
	_on_canvas_changed_position()
	_on_canvas_changed_zoom()
	return new_canvas.id


# DrawingManager screenshots & saves the images & sends a signal when it's done
func save_images() -> void:
	var file_name_short: String = canvases[cc].get_file_name_short()
	if !drawing_manager.has_folder_path(cc):
		drawing_manager.set_folder_path(cc, str("%s %s" % [file_name_short, Time.get_datetime_string_from_system().replace(":", "")]))
	
	drawing_manager.finished_saving.connect(_on_drawing_manager_finished_saving.bind(cc), CONNECT_ONE_SHOT)
	var needs_save: bool = drawing_manager.save_if_canvas_drawing_group_has_changes(cc)
	if needs_save:
		prepare_to_save_images_lock_UI()


# is_saving_images & the DrawingManager Curtain block most of the user input that interfere with image screenshotting
func prepare_to_save_images_lock_UI() -> void:
	is_saving_images = true
	file_tab_bar.visible = false
	get_window().unresizable = true
	# Maybe not necessary, the drawing tool can't input on canvas with the curtain up
	# and doesn't interfere with the image saving afterwards
	#tool_box.select(Enums.Tool.SELECT)
	#_on_tool_box_item_selected(Enums.Tool.SELECT)


func finish_saving_images_unlock_UI() -> void:
	is_saving_images = false
	file_tab_bar.visible = true
	get_window().unresizable = false


func save_file(path: String) -> void:
	if !canvases.has(cc):
		return
	if is_saving_images:
		return
	
	canvases[cc].set_file_names(path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	var save_data: Dictionary
	if file == null:
		printerr("FileAcces open error: ", FileAccess.get_open_error())
		return
	
	save_data = {
		"State": canvases[cc].canvas_state_to_json(),
		"StylePresets": canvases[cc].all_presets_to_json(),
		"Elements": canvases[cc].all_elements_to_Json(),
		"Connections": canvases[cc].all_connection_pairs_to_json(),
		"DrawingRegions": drawing_manager.drawing_region_paths_to_json(),
		"DrawingSettings": canvases[cc].drawing_settings.to_json(),
	}
	
	var success: bool = file.store_string(JSON.stringify(save_data, "\t"))
	if success:
		status_bar.update_status("File saved to path: %s" % path, Color(0.3, 0.55, 0.3, 0.5))
		#DisplayServer.window_set_title("GPlanner %s: %s" % [app_version, path])
		get_tree().root.title = ("GPlanner %s: %s" % [app_version, path])
		# If drawing in the time between saving the images and saving the file
		if !drawing_manager.canvas_drawing_group_has_changes(cc):
			canvases[cc].reset_save_state()
		set_tab_name_and_title_from_canvas(cc)
		print("Saved %s" % path)
	else:
		status_bar.update_status("Error when saving file to path: %s" % path, Color(0.55, 0.3, 0.3, 0.5))
	file.close()


func load_file(path: String, app_startup: bool = false) -> void:
	if is_saving_images:
		return
	var file
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			printerr("FileAcces open error: ", FileAccess.get_open_error())
			return
	else:
		printerr("File doesn't exist @ main.gd:load_file()")
		return
	
	var content = file.get_as_text()
	file.close()
	var data = JSON.parse_string(content)
	
	if data == null:
		status_bar.update_status("Can't load file / Can't parse JSON string: %s" % path, Color(0.55, 0.3, 0.3, 0.5))
		printerr("Can't parse JSON string @ main.gd:load_file()")
		return
	
	var elems = data["Elements"]
	var conns = data["Connections"]
	var presets
	if data.has("StylePresets"):
		presets = data["StylePresets"]
	if data.has("State"):
		var state = data["State"]
		canvases[cc].opened_file_path = path
		canvases[cc].file_name_short = path.get_file().get_slice(".", 0)	# For tab name or referring to the file in general
		canvases[cc].rebuild_canvas_state(state)
		if data.has("StylePresets"):
			element_settings.erase_everything()
			element_settings.rebuild_options_and_dictionary_from_json(presets)
			canvases[cc].update_all_style_presets(element_settings.presets)
	canvases[cc].rebuild_elements(elems)
	canvases[cc].rebuild_connections(conns)
	drawing_manager.clear_canvas_drawing_group(cc)
	if data.has("DrawingSettings"):
		canvases[cc].drawing_settings.rebuild_from_json(data["DrawingSettings"])
	if data.has("DrawingRegions"):
		#print("Load drawing %d %s" % [cc, "at app startup" if app_startup else ""])
		drawing_manager.rebuild_paths_from_json(cc, data["DrawingRegions"])
		if !app_startup:
			drawing_manager.reload_all_drawing_regions(cc)
	
	status_bar.update_status("File loaded: %s" % path, Color(0.3, 0.55, 0.3, 0.5))
	canvases[cc].canvas_changed(true)
	canvases[cc].save_state.is_loaded = true
	settings_drawer.update_data(canvases[cc].settings)
	set_tab_name_and_title_from_canvas(cc)
	_on_canvas_changed_position()
	_on_canvas_changed_zoom()


# NOTE Also saves window state, will eventually save more global settings (independent of files) and get renamed
func save_opened_file_paths_and_quit(path: String) -> void:
	var file = FileAccess.open("user://" + path, FileAccess.WRITE)
	var save_data: Dictionary
	var opened_files: Dictionary
	if file == null:
		printerr("FileAcces open error: ", FileAccess.get_open_error())
		return
	for c_id in canvases:
		if canvases[c_id].opened_file_path != "":
			opened_files[c_id] = canvases[c_id].opened_file_path
			print("Saving canvas %d file location: %s" % [c_id, canvases[c_id].opened_file_path])
	save_data["OpenedFiles"] = opened_files
	# Canvas IDs will change at startup, aren't consistent between sessions because they aren't saved
	# Tabs will be in the range [0 ~ tabs-1] and so will canvas IDs corresponding 1:1 with tabs (until a tab gets closed, but tab_to_canvas dictionary will be accurate)
	save_data["CurrentID"] = file_tab_bar.current_tab
	save_data["WindowState"] = get_window_state_json()
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	get_tree().quit()


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
			status_bar.update_status("Can't load file / Can't parse JSON string: %s" % path, Color(0.55, 0.3, 0.3, 0.5))
			printerr("Can't parse JSON string @ main.gd:load_file()")
			return
		else:
			var files = data["OpenedFiles"]
			if data.has("WindowState"):
				restore_window_state(data["WindowState"])
			for f in files:
				if files[f] != "":
					_on_add_file_button_pressed()	# new_file(), new tab, switch tab -> switch_main_canvas()
					load_file(files[f], true)
			
			# After loading all files, go to the active file that was in use when the last session ended
			var current = int(data["CurrentID"])
			if canvases.has(current):
				if file_tab_bar.current_tab == current:
					drawing_manager.reload_all_drawing_regions(current)
					drawing_tool_bar.change_tool()
					drawing_tool_box.select(canvases[current].drawing_settings.selected_tool)
					_on_drawing_tool_box_item_selected(canvases[current].drawing_settings.selected_tool)
				else:
					file_tab_bar.current_tab = current
				if canvases[current].settings.app_mode == Enums.AppMode.DRAWING:
					_on_toggle_mode_toggled(true)
					toggle_mode_button.set_pressed_no_signal(true)
			else:	# Select last tab (if any exist, it will be valid)
				printerr("Tab indicated at startup doesn't exist / have a planner canvas file corresponding to it.")
				file_tab_bar.current_tab = file_tab_bar.tab_count - 1
	else:
		# Create empty file on first time load
		var file = FileAccess.open("user://" + path, FileAccess.WRITE)
		var save_data: Dictionary = { 0: "" }
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()


func get_window_state_json() -> Dictionary:
	var dict: Dictionary
	var win_position: Vector2i = DisplayServer.window_get_position()
	var win_size: Vector2i = DisplayServer.window_get_size()
	dict["current_screen"] = DisplayServer.window_get_current_screen()
	dict["window_position_x"] = win_position.x
	dict["window_position_y"] = win_position.y
	dict["window_size_x"] = win_size.x
	dict["window_size_y"] = win_size.y
	dict["window_mode"] = get_window().mode
	return dict


func restore_window_state(dict: Dictionary) -> void:
	var screen: int = dict["current_screen"]
	var win: Window = get_window()
	var win_mode: Window.Mode = dict["window_mode"] as Window.Mode
	
	DisplayServer.window_set_current_screen(screen)
	if win_mode == Window.MODE_MAXIMIZED:
		win.mode = Window.MODE_MAXIMIZED
	elif win_mode == Window.MODE_FULLSCREEN:
		win.mode = Window.MODE_FULLSCREEN
	elif win_mode == Window.MODE_WINDOWED:
		var win_position: Vector2i = Vector2i(dict["window_position_x"], dict["window_position_y"])
		var win_size: Vector2i = Vector2i(dict["window_size_x"], dict["window_size_y"])
		win.mode = Window.MODE_WINDOWED
		win.position = win_position
		win.size = win_size


func close_tab(tab: int) -> void:
	if is_saving_images:
		return
	
	if file_tab_bar.tab_count >= 1:
		canvases[tab_to_canvas[tab]].queue_free()
		canvases.erase(tab_to_canvas[tab])
		drawing_manager.erase_canvas_drawing_group(tab_to_canvas[tab])
		var tab_id = tab
		while tab_id < file_tab_bar.tab_count - 1:
			tab_to_canvas[tab_id] = tab_to_canvas[tab_id + 1]
			tab_id += 1
		tab_to_canvas.erase(file_tab_bar.tab_count - 1)
		file_tab_bar.remove_tab(tab)
	if file_tab_bar.tab_count <= 0:
		_on_add_file_button_pressed()


# Increments the tab from 0 to tab_count, checking if the file in the tab has changes 
# And showing a dialog box "exit_tab_confirmation" to confirm the save
# exit_tab_confirmation dialog or _on_drawing_manager_finished_saving also calls confirmation_tab_save(current_tab + 1) after
# either on file save / no save or after saving images + file (as the canvas.save_state.set_requested_action() to be executed later in execute_file_action(), because saving images is asynchronous)
func confirmation_tab_save(tab: int) -> void:
	if is_saving_images:
		return
	
	if tab == file_tab_bar.tab_count:	# If past the last tab, finish cycling and quit app / return
		if exiting_app:
			save_opened_file_paths_and_quit(opened_files_file_name)
		return
	if !tab_to_canvas.has(tab):
		printerr("Tab not found in main.gd:confirmation_tab_save() %d" % tab)
		return
	if canvases[tab_to_canvas[tab]].has_changes():
		file_tab_bar.current_tab = tab		# Also calls switch_main_canvas()
		exit_tab_confirmation.dialog_text = ("Save %s?" % [canvases[tab_to_canvas[tab]].file_name_short])
		exit_tab_confirmation.visible = true
	else:
		confirmation_tab_save(tab + 1)


func execute_file_action(act: Enums.RequestedActionType) -> void:
	match act:
		Enums.RequestedActionType.NEW_BUTTON:
			canvases[cc].reset_save_state()
			_on_new_button_pressed()
		Enums.RequestedActionType.LOAD_BUTTON:
			_on_load_button_pressed()
		Enums.RequestedActionType.CLOSE_TAB_BUTTON:
			var tab: int = tab_from_canvas_id(cc)
			if tab >= 0:
				_on_file_tab_bar_tab_close_pressed(tab)
		Enums.RequestedActionType.CONFIRMATION_TAB:
			var tab: int = tab_from_canvas_id(cc)
			if tab >= 0:
				confirmation_tab_save(tab)


func tab_from_canvas_id(c_id: int) -> int:
	if !canvases.has(c_id):
		return -1
	for tab in tab_to_canvas:
		if tab_to_canvas[tab] == c_id:
			return tab
	return -1


func disable_input() -> bool:
	return is_editing_element_text or is_editing_preset_name or is_saving_images


# Cursor size limit 256x256, on web 128x128; Switching to a TextureRect based cursor beyond that
func change_drawing_tool_cursor() -> void:
	if !canvases.has(cc):
		return
	var tool: Enums.DrawingTool = drawing_tool_bar.settings.selected_tool as Enums.DrawingTool
	
	if canvases[cc].settings.app_mode == Enums.AppMode.PLANNING:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		using_cursor_image = false
	else:
		if tool == Enums.DrawingTool.PENCIL:
			Input.set_custom_mouse_cursor(pencil_cursor, Input.CURSOR_ARROW, Vector2(2.0, 26.0))
			using_cursor_image = false
		if tool == Enums.DrawingTool.ERASER_PENCIL:
			Input.set_custom_mouse_cursor(eraser_pencil_cursor, Input.CURSOR_ARROW, Vector2(4.5, 26.0))
			using_cursor_image = false
		if tool == Enums.DrawingTool.BRUSH:
			var img = Image.new()
			var b_size: float = canvases[cc].drawing_settings.brush_settings.size * canvases[cc].scale.x
			if b_size > 127.0:
				using_cursor_image = true
				img.load_svg_from_string(get_2circle_svg(b_size, ceilf(b_size / 40.0 + 1.0), canvases[cc].drawing_settings.brush_settings.color, 0.5))
				cursor_big_brush.texture = ImageTexture.create_from_image(img)
				cursor_big_brush.size = Vector2(b_size, b_size)
			else:
				using_cursor_image = false
				b_size = clampf(b_size, 4.0, 127.0)
				img.load_svg_from_string(get_circle_svg(b_size, ceilf(b_size / 40.0 + 1.0), canvases[cc].drawing_settings.brush_settings.color, 0.5))
				Input.set_custom_mouse_cursor(img, Input.CURSOR_ARROW, img.get_size() * 0.5)
		if tool == Enums.DrawingTool.ERASER_BRUSH:
			var img = Image.new()
			var b_size: float = canvases[cc].drawing_settings.eraser_brush_settings.size * canvases[cc].scale.x
			if b_size > 127.0:
				using_cursor_image = true
				img.load_svg_from_string(get_2circle_svg(b_size, ceilf(b_size / 40.0 + 1.0), Color(1.0, 1.0, 1.0), 0.5))
				cursor_big_brush.texture = ImageTexture.create_from_image(img)
				cursor_big_brush.size = Vector2(b_size, b_size)
			else:
				using_cursor_image = false
				b_size = clampf(b_size, 4.0, 127.0)
				img.load_svg_from_string(get_circle_svg(b_size, ceilf(b_size / 40.0 + 1.0), Color(1.0, 1.0, 1.0), 0.5))
				Input.set_custom_mouse_cursor(img, Input.CURSOR_ARROW, img.get_size() * 0.5)
	use_mouse_cursor_big_brush()


# Toggles between replacing CursorArrow with TextureRect and default CursorArrow and returns true or false if TextureRect position needs to be updated
func use_mouse_cursor_big_brush() -> bool:
	if using_cursor_image and Input.get_current_cursor_shape() == Input.CURSOR_ARROW:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			cursor_big_brush.visible = true
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		return true
	else:
		if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
			cursor_big_brush.visible = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return false


func get_circle_svg(img_size: float, stroke_width: float, color: Color, transparency: float) -> String:
	return "<svg width=%d height=%d>
			<circle r=%0.2f cx=%0.2f cy=%0.2f fill=none stroke=#%s stroke-width=%0.2f stroke-opacity=%0.2f/>
			</svg>" % [
		int(img_size), int(img_size), 
		(img_size * 0.5 - stroke_width * 0.5), (img_size * 0.5), (img_size * 0.5), color.to_html(false), stroke_width, transparency
	]


func get_2circle_svg(img_size: float, stroke_width: float, color: Color, transparency: float) -> String:
	var original_color: Color = color
	if color.v > 0.5:
		color = color.darkened(0.25)
	else:
		color = color.lightened(0.25)
	return "<svg width=%d height=%d>
	<circle r=%0.2f cx=%0.2f cy=%0.2f fill=none stroke=#%s stroke-width=%0.2f stroke-opacity=%0.2f/>
	<circle r=%0.2f cx=%0.2f cy=%0.2f fill=none stroke=#%s stroke-width=%0.2f stroke-opacity=%0.2f/>
	</svg>" % [
		int(img_size), int(img_size), 
		(img_size * 0.5 - stroke_width * 0.75), (img_size * 0.5), (img_size * 0.5), original_color.to_html(false), stroke_width * 0.5, transparency,
		(img_size * 0.5 - stroke_width * 0.25), (img_size * 0.5), (img_size * 0.5), color.to_html(false), stroke_width * 0.5, transparency
	]


func change_accent_color(c: Color) -> void:
	if !canvases.has(cc):
		return
	if canvases[cc].settings.app_mode == Enums.AppMode.PLANNING:
		tool_box.theme.get_stylebox("panel", "ItemList").border_color = c
		element_settings.set_accent_color(c)
	if canvases[cc].settings.app_mode == Enums.AppMode.DRAWING:
		drawing_tool_box.theme.get_stylebox("panel", "ItemList").border_color = c
		drawing_tool_bar.set_accent_color(c)
	settings_drawer.set_accent_color(c)
	zoom_indicator.set_accent_color(c)
	button_theme.get_stylebox("focus", "Button").border_color = c
	button_theme.get_stylebox("hover", "Button").border_color = c
	button_theme.get_stylebox("hover_pressed", "Button").border_color = c
	button_theme.get_stylebox("normal", "Button").border_color = c
	button_theme.get_stylebox("pressed", "Button").border_color = c
	popup_dialog_theme.get_stylebox("panel", "AcceptDialog").border_color = c
	popup_dialog_theme.get_stylebox("embedded_border", "AcceptDialog").border_color = c
	popup_dialog_theme.get_stylebox("embedded_unfocused_border", "AcceptDialog").border_color = c
	popup_dialog_theme.get_stylebox("embedded_border", "Window").border_color = c
	popup_dialog_theme.get_stylebox("embedded_unfocused_border", "Window").border_color = c


func _on_tool_box_item_selected(index: Enums.Tool) -> void:
	if canvases.has(cc):
		canvases[cc].tool_id = index
		if index != Enums.Tool.ADD_CONNECTION:
			canvases[cc].reset_adding_connection()
	if index == Enums.Tool.ELEMENT_STYLE_SETTINGS:
		element_settings.toggle_visible(true)
	elif index != Enums.Tool.ELEMENT_STYLE_SETTINGS and element_settings.is_panel_visible():
		element_settings.toggle_visible(false)


func _on_new_button_pressed() -> void:
	if is_saving_images:
		return
	if canvases.size() == 0:
		new_file(true)
		set_current_tab_title("New File", "New File", "")
	if canvases.has(cc) and !canvases[cc].has_changes():
		new_file(false)
		set_current_tab_title("New File", "New File", "")
	else:
		new_file_confirmation.visible = true
		new_file_confirmation.dialog_text = ("This will erase any unsaved changes.\nSave %s?" % [canvases[cc].file_name_short])


func _on_new_file_confirmation_confirmed() -> void:
	canvases[cc].set_requested_save_action(Enums.RequestedActionType.NEW_BUTTON)
	_on_save_button_pressed()


func _on_new_file_confirmation_custom_action(action: StringName) -> void:
	if action == "no_save":
		new_file(false)
		set_current_tab_title("New File", "New File", "")
	new_file_confirmation.visible = false


func _on_save_button_pressed() -> void:
	if is_saving_images:
		return
	if canvases[cc].opened_file_path == "":
		file_dialog_save.visible = true
	# Not currently saving images, but needs to
	elif !canvases[cc].is_ready_for_action():
		if close_this_tab:
			close_this_tab = false
			canvases[cc].set_requested_save_action(Enums.RequestedActionType.CLOSE_TAB_BUTTON)
		if exiting_app:
			canvases[cc].set_requested_save_action(Enums.RequestedActionType.CONFIRMATION_TAB)
		save_images()
	else:
		var new_file_requested: bool = true if canvases[cc].get_requested_save_action() == Enums.RequestedActionType.NEW_BUTTON else false
		save_file(canvases[cc].opened_file_path)
		if show_load_dialog:
			file_dialog_save.visible = false
			file_dialog_load.visible = true
			show_load_dialog = false
		if close_this_tab:
			close_this_tab = false
			close_tab(file_tab_bar.current_tab)
		if new_file_requested:
			new_file(false)
			set_current_tab_title("New File", "New File", "")
		if exiting_app:
			confirmation_tab_save(file_tab_bar.current_tab + 1)


func _on_save_as_button_pressed() -> void:
	if is_saving_images:
		return
	file_dialog_save.visible = true


func _on_file_dialog_save_file_selected(path: String) -> void:
	if !canvases[cc].is_ready_for_action():
		canvases[cc].set_file_names(path)
		if close_this_tab:
			close_this_tab = false
			canvases[cc].set_requested_save_action(Enums.RequestedActionType.CLOSE_TAB_BUTTON)
		if exiting_app:
			canvases[cc].set_requested_save_action(Enums.RequestedActionType.CONFIRMATION_TAB)
		save_images()
	else:
		var new_file_requested: bool = true if canvases[cc].get_requested_save_action() == Enums.RequestedActionType.NEW_BUTTON else false
		save_file(path)
		if show_load_dialog:
			file_dialog_save.visible = false
			file_dialog_load.visible = true
			show_load_dialog = false
		elif close_this_tab:
			close_this_tab = false
			close_tab(file_tab_bar.current_tab)
		if new_file_requested:
			new_file(false)
			set_current_tab_title("New File", "New File", "")
		if exiting_app:
			file_dialog_save.visible = false	# FileDialogSave is still showing as an exclusive window, need to show ExitTabConfirmation instead
			confirmation_tab_save(file_tab_bar.current_tab + 1)


func _on_file_dialog_save_canceled() -> void:
	show_load_dialog = false


func _on_load_button_pressed() -> void:
	if is_saving_images:
		return
	if canvases.has(cc) and canvases[cc].has_changes():
		load_file_confirmation.dialog_text = ("This will erase any unsaved changes.\nSave %s?" % [canvases[cc].file_name_short])
		load_file_confirmation.visible = true
	else:	# If empty file, load a new one without confirmation
		file_dialog_load.visible = true
		show_load_dialog = false


func _on_load_file_confirmation_confirmed() -> void:
	canvases[cc].set_requested_save_action(Enums.RequestedActionType.LOAD_BUTTON)
	if canvases[cc].opened_file_path == "":
		file_dialog_save.visible = true
		# Delay showing load file dialog until after closing save file dialog: _on_file_dialog_save_file_selected()
		show_load_dialog = true
	else:
		show_load_dialog = true
		_on_save_button_pressed()


func _on_load_file_confirmation_custom_action(action: StringName) -> void:
	if action == "no_save":
		load_file_confirmation.visible = false
		file_dialog_load.visible = true
		show_load_dialog = false


func _on_file_dialog_load_file_selected(path: String) -> void:
	if canvases.has(cc):
		canvases[cc].erase_everything()
	else:
		_on_add_file_button_pressed()
	load_file(path)


func _on_show_completed_toggled(toggled_on: bool) -> void:
	canvases[cc].toggle_show_completed(toggled_on)


func _on_show_priorities_toggled(toggled_on: bool) -> void:
	canvases[cc].toggle_show_priorities(toggled_on)


func _on_priority_filter_value_changed(value: float) -> void:
	canvases[cc].change_priority_filter(int(value))


func _on_show_priority_tool_toggled(toggled_on: bool) -> void:
	canvases[cc].toggle_show_priority_tool(toggled_on)


func _on_canvas_done_adding_elements() -> void:
	tool_box.select(Enums.Tool.SELECT)
	_on_tool_box_item_selected(Enums.Tool.SELECT)


func _on_canvas_changed_zoom() -> void:
	if !canvases.has(cc):
		return
	zoom_indicator.update_zoom(canvases[cc].scale.x)
	pan_indicator_camera.update_zoom(canvases[cc].position, canvases[cc].scale.x)
	drawing_manager.scale = canvases[cc].scale
	if canvases[cc].settings.app_mode == Enums.AppMode.DRAWING:
		change_drawing_tool_cursor()


func _on_canvas_changed_position() -> void:
	if !canvases.has(cc):
		return
	pan_indicator_camera.move_camera_and_highlight(canvases[cc].position)
	drawing_manager.position = canvases[cc].position


func _on_file_tab_bar_tab_changed(tab: int) -> void:
	if is_saving_images:
		return
	if tab_to_canvas.has(tab):
		switch_main_canvas(tab_to_canvas[tab])


func _on_add_file_button_pressed() -> void:
	if is_saving_images:
		return
	var canvas_id: int = new_file(true)
	tab_to_canvas[file_tab_bar.tab_count] = canvas_id
	file_tab_bar.add_tab("New File")
	file_tab_bar.current_tab = file_tab_bar.tab_count - 1	# Also switches to the new tab & calls switch_main_canvas(tab)


func _on_file_tab_bar_tab_close_pressed(tab: int) -> void:
	if is_saving_images:
		#if queued_file_action.is_empty():
			#queued_file_action.new_tab_action(FileActionType.CLOSE_TAB_BUTTON, tab)
		return
	if canvases[tab_to_canvas[tab]].has_changes():
		close_tab_confirmation.dialog_text = ("This will erase any unsaved changes.\nSave %s?" % [canvases[cc].file_name_short])
		close_tab_confirmation.visible = true
	else:
		close_tab(file_tab_bar.current_tab)


func _on_close_tab_confirmation_confirmed() -> void:
	# Delay after save dialog closed: _on_save_button_pressed() & _on_file_dialog_save_file_selected()
	close_this_tab = true
	_on_save_button_pressed()


func _on_close_tab_confirmation_custom_action(action: StringName) -> void:
	if action == "no_save":
		close_tab(file_tab_bar.current_tab)
		close_tab_confirmation.visible = false


func _on_exit_tab_confirmation_confirmed() -> void:
	if file_tab_bar.current_tab < file_tab_bar.tab_count:
		_on_save_button_pressed()


func _on_exit_tab_confirmation_custom_action(action: StringName) -> void:
	if action == "no_save":
		exit_tab_confirmation.visible = false
		if file_tab_bar.current_tab < file_tab_bar.tab_count:
			confirmation_tab_save(file_tab_bar.current_tab + 1)


func _on_exit_tab_confirmation_canceled() -> void:
	exiting_app = false


func _on_canvas_has_changed(id: int) -> void:
	#print("Canvas %d changed to %s" % [id, canvases[id].has_changes()])
	if canvases.has(id):
		set_tab_name_and_title_from_canvas(id)


func _on_element_settings_preset_added() -> void:
	if !canvases.has(cc):
		return
	var style_preset: ElementPresetStyle = element_settings.get_selected_preset()
	canvases[cc].update_single_style_preset(style_preset)


func _on_element_settings_preset_changed() -> void:
	if !canvases.has(cc):
		return
	canvases[cc].canvas_changed()


func _on_element_settings_preset_color_changed() -> void:
	if !canvases.has(cc):
		return
	var style_preset: ElementPresetStyle = element_settings.get_selected_preset()
	if style_preset.id == "individual":
		var selected_elem: ElementLabel = get_selected_element()
		if selected_elem != null:
			canvases[cc].update_connection_color(selected_elem.id, style_preset.background_color)
		else:
			printerr("Null element %d in canvas %d at main.gd:func _on_element_settings_preset_color_changed" % [selected_elem, cc])
	else:
		canvases[cc].update_connection_color_by_preset(style_preset.id)


func _on_element_settings_preset_removed(preset_id: String) -> void:
	if !canvases.has(cc):
		return
	canvases[cc].canvas_changed()
	canvases[cc].remove_style_preset(preset_id)


func _on_element_settings_preset_selected() -> void:
	if !canvases.has(cc):
		return
	var style_preset: ElementPresetStyle = element_settings.get_selected_preset()
	var selected_element: ElementLabel = get_selected_element()
	if element_settings.preset_options.selected > 0:
		if canvases[cc].selected_preset_style != style_preset.id:
			canvases[cc].change_selected_preset_style(style_preset.id)
			if selected_element != null:
				canvases[cc].canvas_changed()
				canvases[cc].update_connection_color(selected_element.id, style_preset.background_color)
				selected_element.change_style_preset(style_preset)
	elif element_settings.preset_options.selected == 0:
		canvases[cc].change_selected_preset_style("none")
		if selected_element != null:
			if selected_element.has_style_preset:
				canvases[cc].canvas_changed()
				selected_element.unassign_preset_style()
				canvases[cc].update_connection_color(selected_element.id, selected_element.get_bg_color())
			element_settings.none_preset = selected_element.individual_style
		else:
			element_settings.toggle_none_preset_inputs(false)


func _on_canvas_has_selected_element() -> void:
	#print("Selected element %d" % get_selected_element().id)
	if !canvases.has(cc):
		return
	
	if canvases[cc].selected_preset_style == "none":
		var selected_element: ElementLabel = get_selected_element()
		if selected_element != null:
			element_settings.none_preset = selected_element.individual_style
	element_settings.select_by_style_preset_id(canvases[cc].selected_preset_style)
	element_settings.toggle_none_preset_inputs(true)


func _on_canvas_has_deselected_element() -> void:
	element_settings.toggle_none_preset_inputs(false)


func _on_element_settings_is_editing_text() -> void:
	is_editing_preset_name = true


func _on_element_settings_stopped_editing_text() -> void:
	is_editing_preset_name = false


func _on_resized() -> void:
	var window_size: Vector2 = get_viewport_rect().size
	if pan_indicator_camera:
		pan_indicator_camera.set_window_size(window_size)
	if drawing_manager:
		drawing_manager.resize_to_window()


func _on_drawing_manager_finished_saving(save_canvas: int) -> void:
	finish_saving_images_unlock_UI()
	if !canvases.has(save_canvas):
		printerr("Canvas doesn't exist in main.gd:_on_drawing_manager_finished_saving()")
		return
	if cc != save_canvas:
		switch_main_canvas(save_canvas)
	var save_action = -1	# save_file() resets the save state of the canvas
	if canvases[save_canvas].has_requested_save_action():
		save_action = canvases[save_canvas].get_requested_save_action()
	
	save_file(canvases[save_canvas].opened_file_path)
	if save_action != -1:
		execute_file_action(save_action)


func _on_drawing_manager_status_message(message: String) -> void:
	status_bar.update_status_immediate(message, Color(0.6, 0.6, 0.3, 0.55))


func _on_drawing_manager_forced_save_started() -> void:
	status_bar.update_status("Need to capture images to reduce VRAM usage", Color(0.55, 0.3, 0.3, 0.5))
	prepare_to_save_images_lock_UI()


func _on_drawing_manager_forced_save_ended() -> void:
	status_bar.update_status("Done capturing images to reduce VRAM usage", Color(0.3, 0.55, 0.3, 0.5))
	finish_saving_images_unlock_UI()


func _on_drawing_tool_box_item_selected(index: Enums.DrawingTool) -> void:
	if !canvases.has(cc):
		return
	canvases[cc].drawing_settings.selected_tool = index as Enums.DrawingTool
	drawing_tool_bar.change_tool()
	change_drawing_tool_cursor()


# true: DRAWING, false: PLANNING
func _on_toggle_mode_toggled(toggled_on: bool) -> void:
	if !canvases.has(cc):
		return
	if toggled_on:
		canvases[cc].settings.app_mode = Enums.AppMode.DRAWING
		canvases[cc].toggle_element_label_mouse_inputs(false)
		canvases[cc].toggle_show_priority_tool(false, false)	# Hide priority tool popup while drawing
		tool_box.visible = false
		drawing_tool_box.visible = true
		drawing_tool_bar.visible = true
		drawing_tool_bar.inputs_enabled = true
		element_settings.toggle_style_presets(false)
		change_accent_color(accent_color_drawing)
		set_toggle_mode_button_tooltip("Change to Planning Mode")
	else:
		drawing_manager.end_stroke()
		canvases[cc].settings.app_mode = Enums.AppMode.PLANNING
		canvases[cc].toggle_element_label_mouse_inputs(true)
		# Restore priority tool popup enabled state
		canvases[cc].toggle_show_priority_tool(canvases[cc].settings.checkbox_data[Enums.Checkbox.SHOW_PRIORITY_TOOL], false)
		tool_box.visible = true
		drawing_tool_box.visible = false
		drawing_tool_bar.visible = false
		drawing_tool_bar.inputs_enabled = false
		element_settings.toggle_style_presets(true)
		tool_box.select(Enums.Tool.SELECT)
		_on_tool_box_item_selected(Enums.Tool.SELECT)
		change_accent_color(accent_color_planning)
		set_toggle_mode_button_tooltip("Change to Drawing Mode")
	change_drawing_tool_cursor()


func _on_drawing_tool_bar_color_picker_toggled(toggled_on) -> void:
	if canvases.has(cc):
		canvases[cc].is_color_picker_visible = toggled_on
