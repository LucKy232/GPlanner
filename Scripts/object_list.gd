class_name ObjectList extends Control

@export_file("*.tscn") var list_text_entry_scene
@export var default_text_edit_theme: Theme
@export var default_div_theme: Theme
@onready var object_v_box: VBoxContainer = %ObjectVBox
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var mouse_hover: Area2D = $MouseHover
@onready var mouse_hover_shape: CollisionShape2D = $MouseHover/MouseHoverShape
@onready var margin_container: MarginContainer = %ListMarginContainer
@onready var drop_visual: Panel = %DropVisualIndicator
@onready var list_title: TextEdit = %ListTitle
@onready var list_title_div: Panel = %ListTitleDiv
@onready var drag_and_resize_input: DragAndResizeInput = $DragAndResizeInput
@onready var add_buttons_tween: TweenShowHide = %AddButtonsTween
@onready var toggle_title_tween: TweenShowHide = %ToggleTitleTween
@onready var toggle_title_button: CheckBox = %ToggleTitleButton
@onready var erase_entry_margin: MarginContainer = %EraseEntryMargin
@onready var erase_button: Button = %EraseButton
@onready var erase_entry_tween: TweenShowHide = %EraseEntryTween
@onready var priority_buttons_tween: TweenShowHide = %PriorityButtonsTween
@onready var priority_buttons_margin: MarginContainer = %PriorityButtonsMargin
@onready var background: Panel = %Background

var id: int = -1
var entries: Array[ListTextEntry]
var last_edited_entry_id: int = -1
var dragger: ListDragHelper = ListDragHelper.new()
var canvas_scale: float = 1.0
var mouse_inside: bool = false
var top_left_margin: Vector2 = Vector2.ZERO
var priority_enabled: bool = false
var priority_tool_enabled: bool = true
var show_title: bool = true
var selected: bool = false
var state: State
var individual_style: ElementPresetStyle
var style_preset: ElementPresetStyle
var has_style_preset: bool = false

enum State {
	DEFAULT,
	DRAGGING_CHILD_INSIDE,
	DRAGGING_CHILD_OUTSIDE,
	DRAGGING_FROM_OUTSIDE,
}

signal list_changed
signal filtered_gui_input
signal can_drop
signal remove_element_request
signal select_request
signal text_edit_active
signal dragging
signal entry_priority_changed
signal copied_to_clipboard


func _ready() -> void:
	init_individual_style()
	scroll_container.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_PASS
	scroll_container.get_v_scroll_bar().scrolling.connect(_on_scroll)
	top_left_margin = Vector2(margin_container.get_theme_constant("margin_left"), margin_container.get_theme_constant("margin_top"))
	_on_scroll_hover(false)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is ListTextEntry:
		# Is dragging child entry
		if dragger.is_dragging_child:
			can_drop.emit()
			return false
		# Start drag from outside
		elif !dragger.is_dragging_outside and !entries.has(data):
			dragger.start_drag_from_outside(entries, drop_visual, get_new_drag_position_data())
			change_state(State.DRAGGING_FROM_OUTSIDE)
			drop_visual.size = Vector2(object_v_box.size.x, float(get_font_size() + 4))
			return true
		# Continue drag from outside
		elif dragger.is_dragging_outside:
			var position_in_list: Vector2 = scroll_container.position
			dragger.drag_from_outside(at_position - position_in_list, scroll_container.scroll_vertical)
			dragger.position_outside_drop_visual()
			can_drop.emit()		# For visual on canvas
			return true
		else:
			return false
	elif data is TextElement:
		# Start drag from outside
		if !dragger.is_dragging_outside and mouse_inside:
			dragger.start_drag_from_outside(entries, drop_visual, get_new_drag_position_data())
			change_state(State.DRAGGING_FROM_OUTSIDE)
			drop_visual.size = Vector2(object_v_box.size.x, float(get_font_size() + 4))
			return true
		# Continue drag from outside
		elif dragger.is_dragging_outside:
			var position_in_list: Vector2 = scroll_container.position
			dragger.drag_from_outside(at_position - position_in_list, scroll_container.scroll_vertical)
			dragger.position_outside_drop_visual()
			return true
		else:
			return false
	else:
		return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is ListTextEntry:
		data.remove_from_list.emit()
		data.reparent(object_v_box, false)
		data.list_id = id
		data.change_text_edit_theme(style_preset.text_edit_theme if has_style_preset else individual_style.text_edit_theme)
		data.change_div_theme(style_preset.list_div_theme if has_style_preset else individual_style.list_div_theme)
		connect_list_text_entry(data)
		entries.append(data)
		data.id = dragger.current
		object_v_box.move_child(data, dragger.current)
		sort_entries(entries.size() - 1, dragger.current)	# Last entry added move to its id
		reset_entry_ids()
		change_state(State.DEFAULT)
		dragger.end_drag()
		select_request.emit(id)
	if data is TextElement:
		add_text_entry(false)
		entries[-1].set_text(data.get_text())
		entries[-1].list_id = id
		entries[-1].change_text_edit_theme(style_preset.text_edit_theme if has_style_preset else individual_style.text_edit_theme)
		entries[-1].change_div_theme(style_preset.list_div_theme if has_style_preset else individual_style.list_div_theme)
		entry_priority_changed.emit(entries[-1], data.priority_id)
		object_v_box.move_child(entries[-1], dragger.current)
		sort_entries(entries.size() - 1, dragger.current)
		reset_entry_ids()
		change_state(State.DEFAULT)
		dragger.end_drag()
		remove_element_request.emit(data.id)
		select_request.emit(id)


func _input(event: InputEvent) -> void:
	if !selected:
		return
	if event.is_action_pressed("add_list_text_entry"):
		add_text_entry(true)
	if event.is_action_pressed("add_list_link_entry"):
		add_link_entry(true)
	
	if entries.size() == 0:
		return
	if event.is_action_pressed("edit_previous_in_list", true, true):
		last_edited_entry_id -= 1
		if last_edited_entry_id < 0:
			last_edited_entry_id = entries.size() - 1
		enter_text_edit()
	if event.is_action_pressed("edit_next_in_list", true, true):
		last_edited_entry_id += 1
		if last_edited_entry_id > entries.size() - 1:
			last_edited_entry_id = 0
		enter_text_edit()
	if list_title.visible and event.is_action_pressed("edit_list_title", false, true):
		list_title.grab_focus()
	
	if !is_editing_text() and event.is_action_pressed("ui_copy"):
		copy_list_text_to_clipboard()
	if !is_editing_text(false):	# Not editing an entry
		return
	if event.is_action_pressed("erase_selected_list_entry", false, true):
		_on_erase_button_pressed()
	if event.is_action_pressed("move_list_entry_up", true, true):
		if last_edited_entry_id == entries.size() - 1:
			return
		object_v_box.move_child(entries[last_edited_entry_id], last_edited_entry_id + 1)
		sort_entries(last_edited_entry_id, last_edited_entry_id + 1)
		last_edited_entry_id += 1
		ensure_entry_visible.call_deferred()
		line_up_side_buttons.call_deferred()
		list_changed.emit()
	if event.is_action_pressed("move_list_entry_down", true, true):
		if last_edited_entry_id == 0:
			return
		object_v_box.move_child(entries[last_edited_entry_id], last_edited_entry_id - 1)
		sort_entries(last_edited_entry_id, last_edited_entry_id - 1)
		last_edited_entry_id -= 1
		ensure_entry_visible.call_deferred()
		line_up_side_buttons.call_deferred()
		list_changed.emit()


func copy_list_text_to_clipboard() -> void:
	var clip_text: String = (list_title.text)
	for entry in entries:
		clip_text += ("\n - %s" % [entry.get_text()])
	DisplayServer.clipboard_set(clip_text)
	copied_to_clipboard.emit()


func change_state(new_state: State) -> void:
	state = new_state
	match state:
		State.DEFAULT:
			mouse_filter = Control.MOUSE_FILTER_PASS
			scroll_container.clip_contents = true
			drop_visual.visible = false
		State.DRAGGING_CHILD_INSIDE:	# Stop the input going to canvas
			mouse_filter = Control.MOUSE_FILTER_STOP
			scroll_container.clip_contents = false
			drop_visual.visible = true
		State.DRAGGING_CHILD_OUTSIDE:
			mouse_filter = Control.MOUSE_FILTER_PASS
			drop_visual.visible = false
		State.DRAGGING_FROM_OUTSIDE:
			scroll_container.clip_contents = false
			drop_visual.visible = true


func toggle_title(toggled_on: bool) -> void:
	list_title.visible = toggled_on
	list_title_div.visible = toggled_on


func select() -> void:
	add_buttons_tween.toggle(true)
	toggle_title_tween.toggle(true)
	selected = true


func deselect() -> void:
	if list_title.has_focus():
		list_title.release_focus()
	exit_text_edit()
	add_buttons_tween.toggle(false)
	toggle_title_tween.toggle(false)
	selected = false


func get_font_size() -> int:
	if has_style_preset:
		return style_preset.font_size
	else:
		return individual_style.font_size


func get_new_drag_position_data() -> ListDragHelper.DragPositionData:
	return ListDragHelper.DragPositionData.new(
				top_left_margin,
				object_v_box.get_theme_constant("separation"),
				scroll_container.scroll_vertical,
				scroll_container.position
			)


func set_priority_visible(toggled_on: bool) -> void:
	if !priority_enabled and toggled_on:
		for entry in entries:
			entry.enable_priority_color()
	elif priority_enabled and !toggled_on:
		for entry in entries:
			entry.disable_priority_color()
	priority_enabled = toggled_on


func set_priority_tool_enabled(toggled_on: bool) -> void:
	priority_tool_enabled = toggled_on


func is_editing_text(include_title: bool = true) -> bool:
	if include_title and list_title.has_focus():
		return true
	if entries.size() > last_edited_entry_id and last_edited_entry_id >= 0:
		return entries[last_edited_entry_id].is_editing_text()
	return false


func enter_text_edit() -> void:
	if entries.size() > last_edited_entry_id and last_edited_entry_id >= 0:
		entries[last_edited_entry_id].enter_text_edit()
		ensure_entry_visible()


func exit_text_edit() -> void:
	if entries.size() > last_edited_entry_id and last_edited_entry_id >= 0:
		entries[last_edited_entry_id].exit_text_edit()


# Moving the entire list
func start_dragging() -> void:
	drag_and_resize_input.is_being_dragged = true
	drag_and_resize_input.is_being_resized = false
	set_default_cursor_shape(Control.CURSOR_DRAG)


# Resizing the entire list
func start_resizing() -> void:
	drag_and_resize_input.is_being_resized = true
	drag_and_resize_input.is_being_dragged = false
	set_default_cursor_shape(Control.CURSOR_FDIAGSIZE)


# When moving/resizing the entire list
func end_input() -> void:
	drag_and_resize_input.end()
	set_default_cursor_shape(Control.CURSOR_POINTING_HAND)


func add_text_entry(is_user_input: bool) -> void:
	var new_list_text_entry: ListTextEntry = load(list_text_entry_scene).instantiate()
	object_v_box.add_child(new_list_text_entry)
	new_list_text_entry.id = entries.size()
	new_list_text_entry.list_id = id
	new_list_text_entry.name = "ListTextEntry"
	new_list_text_entry.change_text_edit_theme(style_preset.text_edit_theme if has_style_preset else individual_style.text_edit_theme)
	new_list_text_entry.change_div_theme(style_preset.list_div_theme if has_style_preset else individual_style.list_div_theme)
	entries.append(new_list_text_entry)
	connect_list_text_entry(new_list_text_entry)
	toggle_entry_divs(style_preset.list_div_enabled if has_style_preset else individual_style.list_div_enabled)
	if is_user_input:
		list_changed.emit()


func add_link_entry(_is_user_input: bool) -> void:
	pass
	#var new_list_text_entry: ListTextEntry = load(list_text_entry_scene).instantiate()
	#object_v_box.add_child(new_list_text_entry)
	#new_list_text_entry.id = entries.size()
	#new_list_text_entry.name = "ListTextEntry"
	#entries.append(new_list_text_entry)
	#connect_list_text_entry(new_list_text_entry)
	#if is_user_input:
		#list_changed.emit()


func remove_text_entry(entry: ListTextEntry, delete_from_memory: bool) -> void:
	disconnect_list_text_entry(entry)
	entries.erase(entry)
	if delete_from_memory:
		entry.queue_free()
	if last_edited_entry_id > entries.size() - 1:
		last_edited_entry_id = entries.size() - 1
	reset_entry_ids()
	toggle_entry_divs(style_preset.list_div_enabled if has_style_preset else individual_style.list_div_enabled)
	list_changed.emit()


func connect_list_text_entry(entry: ListTextEntry) -> void:
	entry.grabber_moved.connect(_on_list_text_entry_grabber_moved)
	entry.grabber_started_move.connect(_on_list_text_entry_grabber_started_move)
	entry.grabber_ended_move.connect(_on_list_text_entry_grabber_ended_move)
	entry.text_changed.connect(_on_list_text_entry_text_changed)
	entry.text_edit_toggled.connect(_on_list_text_entry_text_entry_toggled)
	entry.remove_from_list.connect(_on_list_text_entry_remove_from_list.bind(entry))
	entry.text_resized.connect(_on_list_text_entry_text_resized)


func disconnect_list_text_entry(entry: ListTextEntry) -> void:
	entry.grabber_moved.disconnect(_on_list_text_entry_grabber_moved)
	entry.grabber_started_move.disconnect(_on_list_text_entry_grabber_started_move)
	entry.grabber_ended_move.disconnect(_on_list_text_entry_grabber_ended_move)
	entry.text_changed.disconnect(_on_list_text_entry_text_changed)
	entry.text_edit_toggled.disconnect(_on_list_text_entry_text_entry_toggled)
	entry.remove_from_list.disconnect(_on_list_text_entry_remove_from_list)
	entry.text_resized.disconnect(_on_list_text_entry_text_resized)


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


func filter_entries(value: int) -> void:
	for entry in entries:
		if entry.priority_id > value:
			if last_edited_entry_id == entry.id:
				last_edited_entry_id = -1
			entry.visible = false
		else:
			entry.visible = true
	line_up_side_buttons.call_deferred()


func rebuild_from_dict(dict: Dictionary, priority_colors: Dictionary[Enums.Priority, Color]) -> void:
	id = dict["id"]
	size = Vector2(dict["size.x"], dict["size.y"])
	position = Vector2(dict["pos.x"], dict["pos.y"])
	if dict.has("title"):
		list_title.text = dict["title"]
	if dict.has("show_title"):
		_on_toggle_title_button_toggled(bool(dict["show_title"]))
		toggle_title_button.set_pressed_no_signal(show_title)
	for entry_id in dict["entries"]:
		add_text_entry(false)
		entries[-1].rebuild_from_dict(dict["entries"][entry_id])
		if dict["entries"][entry_id].has("priority_id"):
			var priority: Enums.Priority = dict["entries"][entry_id]["priority_id"] as Enums.Priority
			entries[-1].set_priority(priority)
			entries[-1].set_priority_color(priority_colors[priority])
	# NOTE doesn't need to be sorted in entry.id order because they get saved / read in alphabetical / numerical order to the .json


# Map order to entry
func to_json() -> Dictionary:
	var style_preset_id: String = "none" if !has_style_preset else style_preset.id
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
	dict["title"] = list_title.text
	dict["show_title"] = show_title
	dict["has_style_preset"] = has_style_preset
	dict["style_preset_id"] = style_preset_id
	if !has_style_preset:
		dict["individual_style"] = individual_style.to_json()
	return dict


func ensure_entry_visible() -> void:
	if entries.size() == 0 or last_edited_entry_id < 0 or last_edited_entry_id >= entries.size():
		return
	scroll_container.ensure_control_visible(entries[last_edited_entry_id])


func line_up_side_buttons() -> void:
	if !is_editing_text():
		return
	var new_y_position: float = (entries[last_edited_entry_id].position.y
								+ scroll_container.position.y
								- scroll_container.scroll_vertical)
	erase_entry_margin.position.y = new_y_position
	priority_buttons_margin.position.y = new_y_position
	if new_y_position < scroll_container.position.y - 40.0:
		erase_entry_margin.visible = false
		priority_buttons_margin.visible = false
	elif new_y_position > scroll_container.size.y + entries[last_edited_entry_id].size.y:
		erase_entry_margin.visible = false
		priority_buttons_margin.visible = false
	else:
		erase_entry_margin.visible = true
		if priority_enabled and priority_tool_enabled:
			priority_buttons_margin.visible = true


func set_active_entry_priority(p: Enums.Priority) -> void:
	if entries.size() > last_edited_entry_id and last_edited_entry_id >= 0:
		entry_priority_changed.emit(entries[last_edited_entry_id], p)


#region PresetStyles
func init_individual_style() -> void:
	individual_style = ElementPresetStyle.new("individual")
	individual_style.set_background_panel_style_box(background.get_theme_stylebox("panel", "Panel").duplicate(), true)
	individual_style.set_text_edit_theme(default_text_edit_theme.duplicate(), true)
	individual_style.set_title_text_edit_theme(default_text_edit_theme.duplicate(), true)
	individual_style.set_list_div_theme(default_div_theme.duplicate(true), true)
	individual_style.list_setting_changed.connect(_on_style_settings_changed)
	individual_style.entry_font_size_changed.connect(_on_style_font_size_changed)
	individual_style.entry_separation = object_v_box.get_theme_constant("separation")
	_apply_style_preset(individual_style)


func _apply_style_preset(preset: ElementPresetStyle) -> void:
	background.add_theme_stylebox_override("panel", preset.background_panel_style_box)
	list_title.theme = preset.title_text_edit_theme
	for e in entries:
		e.change_text_edit_theme(preset.text_edit_theme)
	for e in entries:
		e.change_div_theme(preset.list_div_theme)
	toggle_entry_divs(preset.list_div_enabled)


func change_style_preset(preset: ElementPresetStyle) -> void:
	if has_style_preset and style_preset:
		if style_preset == preset:		# Stop if changing to the same preset
			return
		style_preset.list_setting_changed.disconnect(_on_style_settings_changed)
		style_preset.entry_font_size_changed.disconnect(_on_style_font_size_changed)
	has_style_preset = true
	style_preset = preset
	style_preset.list_setting_changed.connect(_on_style_settings_changed)
	style_preset.entry_font_size_changed.connect(_on_style_font_size_changed)
	_apply_style_preset(style_preset)


func unassign_preset_style() -> void:
	has_style_preset = false
	style_preset = null
	_apply_style_preset(individual_style)


func toggle_entry_divs(toggled_on: bool) -> void:
	if entries.size() == 0:
		return
	for idx in range(0, entries.size() - 1):
		entries[idx].toggle_div(toggled_on)
	entries[-1].toggle_div(false)


func get_bg_color() -> Color:
	if has_style_preset:
		return style_preset.background_color
	else:
		return individual_style.background_panel_style_box.bg_color


func _on_style_settings_changed(setting: ElementPresetStyle.ListSettings, value) -> void:
	match setting:
		ElementPresetStyle.ListSettings.ENTRY_SEPARATION:
			object_v_box.add_theme_constant_override("separation", int(value))
		ElementPresetStyle.ListSettings.DIV_ENABLED:
			toggle_entry_divs(bool(value))


func _on_style_font_size_changed() -> void:
	for e in entries:
		e.reset_item_sizes.call_deferred()
#endregion


func _on_scroll_hover(inside: bool) -> void:
	mouse_inside = inside
	if dragger.is_dragging_outside and !inside:
		change_state(State.DEFAULT)
		dragger.end_drag()
	elif dragger.is_dragging_child and inside:
		change_state(State.DRAGGING_CHILD_INSIDE)
	elif dragger.is_dragging_child and !inside:
		change_state(State.DRAGGING_CHILD_OUTSIDE)


func _on_scroll() -> void:
	if dragger.is_dragging_child:
		dragger.position_child_drop_visual()
	if dragger.is_dragging_outside:
		dragger.position_outside_drop_visual()
	line_up_side_buttons.call_deferred()


func _on_scroll_mouse_entered() -> void:
	_on_scroll_hover(true)


func _on_scroll_mouse_exited() -> void:
	_on_scroll_hover(false)


func _on_mouse_hover_mouse_entered() -> void:
	mouse_inside = true


func _on_list_text_entry_erase(entry: ListTextEntry) -> void:
	remove_text_entry(entry, true)


func _on_list_text_entry_remove_from_list(entry: ListTextEntry) -> void:
	remove_text_entry(entry, false)


func _on_resized() -> void:
	if !is_node_ready():
		return
	mouse_hover_shape.shape.size = size
	mouse_hover.position = size * 0.5
	line_up_side_buttons.call_deferred()


func _on_list_text_entry_text_changed() -> void:
	ensure_entry_visible()
	list_changed.emit()


func _on_list_text_entry_grabber_started_move(entry_id: int, event_pos: Vector2) -> void:
	if entries.size() <= entry_id:
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	dragger.start_drag_child(entry_id, entries, event_pos, drop_visual, get_new_drag_position_data())
	dragging.emit(true)
	change_state(State.DRAGGING_CHILD_INSIDE)


func _on_list_text_entry_grabber_moved(event: InputEventMouseMotion, entry_id: int) -> void:
	if entries.size() <= entry_id:
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	dragger.accumulate_position(event.relative / canvas_scale, scroll_container.scroll_vertical)
	if mouse_inside:
		dragger.drag_child()
		dragger.position_child_drop_visual()


func _on_list_text_entry_grabber_ended_move(entry_id: int) -> void:
	if entries.size() <= entry_id:
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	if dragger.object_id != entry_id:
		push_error("Wrong drag ID")
		return
	var move_to: int = dragger.current
	change_state(State.DEFAULT)
	dragger.end_drag()
	dragging.emit(false)
	if entry_id != move_to:
		object_v_box.move_child(entries[entry_id], move_to)
		sort_entries(entry_id, move_to)
		last_edited_entry_id = move_to
		line_up_side_buttons.call_deferred()
		list_changed.emit()


func _on_list_text_entry_text_entry_toggled(entry_id: int, toggled: bool) -> void:
	last_edited_entry_id = entry_id		# on focus enterd and exited
	if toggled:
		text_edit_active.emit(id)
		erase_entry_tween.toggle(true)
		line_up_side_buttons.call_deferred()
		if priority_tool_enabled and priority_enabled:
			priority_buttons_tween.toggle(true)
	else:
		erase_entry_tween.toggle(false)
		priority_buttons_tween.toggle(false)


func _on_list_text_entry_text_resized() -> void:
	ensure_entry_visible()


func _on_gui_input(event: InputEvent) -> void:
	if dragger.is_dragging_child:
		return
	filtered_gui_input.emit(event, id)


func _on_list_name_focus_entered() -> void:
	text_edit_active.emit(id)


func _on_add_text_entry_button_pressed() -> void:
	add_text_entry(true)


func _on_add_link_entry_button_pressed() -> void:
	add_link_entry(true)


func _on_toggle_title_button_toggled(toggled_on: bool) -> void:
	show_title = toggled_on
	toggle_title(toggled_on)


func _on_erase_button_pressed() -> void:
	if entries.size() == 0 or last_edited_entry_id < 0 or last_edited_entry_id > entries.size() - 1:
		return
	var entry: ListTextEntry = entries[last_edited_entry_id]
	remove_text_entry(entry, true)


func _on_list_title_gui_input(event: InputEvent) -> void:
	if list_title.has_focus() and event.is_action_pressed("exit_text_edit", false, true):
		list_title.release_focus()


func _on_priority_active_pressed() -> void:
	set_active_entry_priority(Enums.Priority.ACTIVE)


func _on_priority_high_pressed() -> void:
	set_active_entry_priority(Enums.Priority.HIGH)


func _on_priority_medium_pressed() -> void:
	set_active_entry_priority(Enums.Priority.MEDIUM)


func _on_priority_low_pressed() -> void:
	set_active_entry_priority(Enums.Priority.LOW)


func _on_priority_none_pressed() -> void:
	set_active_entry_priority(Enums.Priority.NONE)
