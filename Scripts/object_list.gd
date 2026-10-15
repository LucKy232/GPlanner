class_name ObjectList extends CanvasElement

@export var selected_z_index: int = 2
@export var default_z_index: int = 0
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

var entries: Dictionary[int, ListTextEntry]		## Keeps consistent ID references
var entries_order: Array[int]					## Keeps entry order info, contains entries IDs in array order
var entry_id_counter = 0
var last_edited_order_id: int = -1				## entries_order ID
var last_edited_entry_id: int = -1				## entries ID
var dragger: ListDragHelper = ListDragHelper.new()
var canvas_scale: float = 1.0
var mouse_inside: bool = false
var top_left_margin: Vector2 = Vector2.ZERO
var total_horizontal_margin: float = 0.0
var priority_enabled: bool = false
var priority_tool_enabled: bool = true
var show_title: bool = true
var selected: bool = false
var state: State
var individual_style: PresetStyle
var style_preset: PresetStyle
var has_style_preset: bool = false

enum State {
	DEFAULT,
	DRAGGING_CHILD_INSIDE,
	DRAGGING_CHILD_OUTSIDE,
	DRAGGING_FROM_OUTSIDE,
}

signal entry_added
signal entry_removed
signal entries_sorted
signal entry_priority_changed
signal list_changed
signal filtered_gui_input
signal can_drop
signal select_request
signal text_edit_active
signal dragging
signal copied_to_clipboard
signal remove_element_request


func _ready() -> void:
	init_individual_style()
	scroll_container.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_PASS
	scroll_container.get_v_scroll_bar().scrolling.connect(_on_scroll)
	top_left_margin = Vector2(margin_container.get_theme_constant("margin_left"), margin_container.get_theme_constant("margin_top"))
	total_horizontal_margin = margin_container.get_theme_constant("margin_left") + margin_container.get_theme_constant("margin_right")
	_on_scroll_hover(false)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if data is ListTextEntry:
		# Is dragging child entry
		if dragger.is_dragging_child:
			can_drop.emit()
			return false
		# Start drag from outside
		elif !dragger.is_dragging_outside and !entries.values().has(data):
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
		data.order_id = dragger.current
		data.id = entry_id_counter
		entry_id_counter += 1
		entries[data.id] = data
		object_v_box.move_child(data, dragger.current)
		sort_entries(entries.size() - 1, dragger.current)	# Last entry added move to its id
		reset_entry_order_ids()
		change_state(State.DEFAULT)
		refresh_entry_divs_visibility()
		dragger.end_drag()
		select_request.emit(id)
	if data is TextElement:
		var new_entry_id: int = add_text_entry(false)
		entries[new_entry_id].set_text(data.get_text())
		entries[new_entry_id].change_text_edit_theme(style_preset.text_edit_theme if has_style_preset else individual_style.text_edit_theme)
		entries[new_entry_id].change_div_theme(style_preset.list_div_theme if has_style_preset else individual_style.list_div_theme)
		entry_priority_changed.emit(entries[new_entry_id], data.priority_id)
		object_v_box.move_child(entries[new_entry_id], dragger.current)
		sort_entries(entries.size() - 1, dragger.current)
		reset_entry_order_ids()
		change_state(State.DEFAULT)
		refresh_entry_divs_visibility()
		dragger.end_drag()
		remove_element_request.emit(data.id)
		select_request.emit(id)


func _input(event: InputEvent) -> void:
	if !selected:
		return
	if !is_editing_text():
		if event.is_action_pressed("add_list_text_entry"):
			add_text_entry(true)
		if event.is_action_pressed("add_list_link_entry"):
			add_link_entry(true)
		if list_title.visible and event.is_action_pressed("edit_list_title", false, true):
			list_title.grab_focus()
		if event.is_action_pressed("ui_copy"):
			copy_list_text_to_clipboard()
	
	if entries.size() == 0:
		return
	if event.is_action_pressed("edit_previous_in_list", true, true):
		last_edited_order_id -= 1
		if last_edited_order_id < 0:
			last_edited_order_id = entries_order.size() - 1
		last_edited_entry_id = entries_order[last_edited_order_id]
		enter_text_edit()
	if event.is_action_pressed("edit_next_in_list", true, true):
		last_edited_order_id += 1
		if last_edited_order_id > entries_order.size() - 1:
			last_edited_order_id = 0
		last_edited_entry_id = entries_order[last_edited_order_id]
		enter_text_edit()
	
	if !is_editing_text(false):	# Not editing an entry
		return
	if event.is_action_pressed("erase_selected_list_entry", false, true):
		_on_erase_button_pressed()
	if event.is_action_pressed("move_list_entry_up", true, true):
		if last_edited_order_id >= entries_order.size() - 1:
			return
		move_entry_up_or_down(true)
	if event.is_action_pressed("move_list_entry_down", true, true):
		if last_edited_order_id == 0:
			return
		move_entry_up_or_down(false)


func move_entry_up_or_down(up: bool) -> void:
	var last_edited: ListTextEntry = get_last_edited_entry()
	if !last_edited:
		return
	var move: int = 1 if up else -1
	object_v_box.move_child(last_edited, last_edited_order_id + move)
	sort_entries(last_edited_order_id, last_edited_order_id + move)
	last_edited_order_id += move
	last_edited_entry_id = entries_order[last_edited_order_id]
	ensure_entry_visible.call_deferred()
	line_up_side_buttons.call_deferred()
	refresh_entry_divs_visibility()
	list_changed.emit()


func copy_list_text_to_clipboard() -> void:
	var clip_text: String = (list_title.text)
	for entry_id in entries:
		clip_text += ("\n- %s" % [entries[entry_id].get_text()])
	DisplayServer.clipboard_set(clip_text)
	copied_to_clipboard.emit()


func change_state(new_state: State) -> void:
	state = new_state
	match state:
		State.DEFAULT:
			mouse_filter = Control.MOUSE_FILTER_PASS
			scroll_container.clip_contents = true
			drop_visual.visible = false
			toggle_all_entries_hover(true)
		State.DRAGGING_CHILD_INSIDE:	# Stop the input going to canvas
			mouse_filter = Control.MOUSE_FILTER_STOP
			scroll_container.clip_contents = false
			drop_visual.visible = true
			toggle_all_entries_hover(false)
		State.DRAGGING_CHILD_OUTSIDE:
			mouse_filter = Control.MOUSE_FILTER_PASS
			drop_visual.visible = false
			toggle_all_entries_hover(false)
		State.DRAGGING_FROM_OUTSIDE:
			scroll_container.clip_contents = false
			drop_visual.visible = true
			toggle_all_entries_hover(false)


func toggle_title(toggled_on: bool) -> void:
	list_title.visible = toggled_on
	list_title_div.visible = toggled_on


func select() -> void:
	add_buttons_tween.toggle(true)
	toggle_title_tween.toggle(true)
	z_index = selected_z_index
	selected = true


func deselect() -> void:
	if list_title.has_focus():
		list_title.release_focus()
	exit_text_edit()
	add_buttons_tween.toggle(false)
	toggle_title_tween.toggle(false)
	z_index = default_z_index
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
		for entry_id in entries:
			entries[entry_id].enable_priority_color()
	elif priority_enabled and !toggled_on:
		for entry_id in entries:
			entries[entry_id].disable_priority_color()
	priority_enabled = toggled_on


func set_priority_tool_enabled(toggled_on: bool) -> void:
	priority_tool_enabled = toggled_on


func is_editing_text(include_title: bool = true) -> bool:
	if include_title and list_title.has_focus():
		return true
	var last_edited: ListTextEntry = get_last_edited_entry()
	if last_edited:
		return last_edited.is_editing_text()
	return false


func enter_text_edit() -> void:
	var last_edited: ListTextEntry = get_last_edited_entry()
	if last_edited:
		last_edited.enter_text_edit()


func exit_text_edit() -> void:
	var last_edited: ListTextEntry = get_last_edited_entry()
	if last_edited and last_edited.is_editing_text():
		last_edited.exit_text_edit()


func get_last_edited_entry() -> ListTextEntry:
	if !entries.has(last_edited_entry_id):
		if last_edited_entry_id != -1:
			push_error("entry ID %d from entries_order array not in entries dictionary" % [last_edited_entry_id])
		return null
	return entries[last_edited_entry_id]


# Moving the entire list Control
func start_dragging() -> void:
	drag_and_resize_input.is_being_dragged = true
	drag_and_resize_input.is_being_resized = false
	set_default_cursor_shape(Control.CURSOR_DRAG)


# Resizing the entire list Control
func start_resizing() -> void:
	drag_and_resize_input.is_being_resized = true
	drag_and_resize_input.is_being_dragged = false
	set_default_cursor_shape(Control.CURSOR_FDIAGSIZE)


# When moving/resizing the entire list Control
func end_input() -> void:
	drag_and_resize_input.end()
	set_default_cursor_shape(Control.CURSOR_POINTING_HAND)


func add_text_entry(is_user_input: bool, id_from_file: int = -1) -> int:
	var new_entry_id: int = 0
	if id_from_file < 0 or entries.has(id_from_file):	# Generate new ID
		new_entry_id = entry_id_counter
		entry_id_counter += 1
	else:
		new_entry_id = id_from_file
		if id_from_file >= entry_id_counter:
			entry_id_counter = id_from_file + 1
	var new_list_text_entry: ListTextEntry = load(GlobalScenes.list_text_entry_scene).instantiate()
	object_v_box.add_child(new_list_text_entry)
	new_list_text_entry.order_id = entries.size()
	new_list_text_entry.list_id = id
	new_list_text_entry.id = new_entry_id
	new_list_text_entry.name = "ListTextEntry"
	new_list_text_entry.change_text_edit_theme(style_preset.text_edit_theme if has_style_preset else individual_style.text_edit_theme)
	new_list_text_entry.change_div_theme(style_preset.list_div_theme if has_style_preset else individual_style.list_div_theme)
	last_edited_entry_id = new_entry_id
	entries[new_entry_id] = new_list_text_entry
	entries_order.append(new_entry_id)
	last_edited_order_id = new_list_text_entry.order_id
	connect_list_text_entry(new_list_text_entry)
	refresh_entry_divs_visibility()
	if is_user_input:
		list_changed.emit()
	return new_entry_id


func add_link_entry(_is_user_input: bool) -> void:
	pass


func remove_text_entry(entry: ListTextEntry, delete_from_memory: bool) -> void:
	disconnect_list_text_entry(entry)
	entries.erase(entry.id)
	if entries_order.has(entry.id):
		entries_order.erase(entry.id)
	if last_edited_entry_id == entry.id:
		last_edited_entry_id = -1
	if last_edited_order_id == entry.order_id:
		last_edited_order_id = -1
	elif last_edited_order_id > entries.size() - 1:
		last_edited_order_id = entries.size() - 1
	if delete_from_memory:
		entry.queue_free()
	reset_entry_order_ids()
	refresh_entry_divs_visibility()
	toggle_side_buttons(false)
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


# Sorts the entries_order array by moving Entry IDs around
func sort_entries(entry_order_id: int, to_id: int) -> void:
	var entry_id: int = entries_order[entry_order_id]
	if entry_order_id > to_id:	# Moving entry down
		var idx: int = entry_order_id
		while idx > to_id:
			entries_order[idx] = entries_order[idx - 1]
			idx -= 1
	if entry_order_id < to_id:	# Moving entry up
		for idx in range(entry_order_id, to_id):
			entries_order[idx] = entries_order[idx + 1]
	entries_order[to_id] = entry_id
	reset_entry_order_ids()


# Set new IDs in list index (ascending) order
func reset_entry_order_ids() -> void:
	for i in range(0, entries_order.size()):
		var entry_id: int = entries_order[i]
		if !entries.has(entry_id):
			push_error("entry ID %d from entries_order array not in entries dictionary" % [entry_id])
			return
		entries[entry_id].order_id = i


func filter_entries(value: int) -> void:
	for entry_id in entries:
		if entries[entry_id].priority_id > value:
			if last_edited_entry_id == entry_id:
				last_edited_entry_id = -1
				last_edited_order_id = -1
			entries[entry_id].visible = false
		else:
			entries[entry_id].visible = true
	line_up_side_buttons.call_deferred()


func rebuild_from_dict(dict: Dictionary, priority_colors: Dictionary[Enums.Priority, Color]) -> void:
	size = Vector2(dict["size.x"], dict["size.y"])
	position = Vector2(dict["pos.x"], dict["pos.y"])
	if dict.has("title"):
		list_title.text = dict["title"]
	if dict.has("show_title"):
		_on_toggle_title_button_toggled(bool(dict["show_title"]))
		toggle_title_button.set_pressed_no_signal(show_title)
	for order_id_str in dict["entries"]:
		var entry_dict: Dictionary = dict["entries"][order_id_str]
		var id_from_file: int = -1
		if entry_dict.has("id"):
			id_from_file = int(entry_dict["id"])
		var new_entry_id: int = add_text_entry(false, id_from_file)
		entries[new_entry_id].rebuild_from_dict(entry_dict)
		if entry_dict.has("priority_id"):
			var priority: Enums.Priority = entry_dict["priority_id"] as Enums.Priority
			entries[new_entry_id].set_priority(priority)
			entries[new_entry_id].set_priority_color(priority_colors[priority])


# Map order to entry
func to_json() -> Dictionary:
	var style_preset_id: String = "individual" if !has_style_preset else style_preset.id
	var dict: Dictionary
	dict["entries"] = {}
	for entry_id in entries:
		var entry_order_id: int = entries[entry_id].order_id
		dict["entries"][entry_order_id] = entries[entry_id].to_json()
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
	if !entries.has(last_edited_entry_id):
		return
	scroll_container.ensure_control_visible(entries[last_edited_entry_id])


func line_up_side_buttons() -> void:
	if !is_editing_text() or !entries.has(last_edited_entry_id):
		return
	var new_y_position: float = (entries[last_edited_entry_id].position.y
								+ scroll_container.position.y
								- scroll_container.scroll_vertical)
	erase_entry_margin.position.y = new_y_position
	priority_buttons_margin.position.y = new_y_position
	priority_buttons_margin.visible = true if (priority_enabled and priority_tool_enabled) else false


func signal_active_entry_priority(p: Enums.Priority) -> void:
	if !entries.has(last_edited_entry_id):
		return
	entry_priority_changed.emit(entries[last_edited_entry_id], p)


func set_entry_priority(entry_id: int, priority: Enums.Priority, color: Color) -> void:
	if !entries.has(entry_id):
		return
	entries[entry_id].set_priority(priority)
	entries[entry_id].set_priority_color(color)


#region PresetStyles
func init_individual_style() -> void:
	individual_style = PresetStyle.new("individual")
	individual_style.set_background_panel_style_box(background.get_theme_stylebox("panel", "Panel").duplicate(), true)
	individual_style.set_text_edit_theme(default_text_edit_theme.duplicate(), false)
	individual_style.set_title_text_edit_theme(default_text_edit_theme.duplicate(), false)
	individual_style.set_list_div_theme(default_div_theme.duplicate(true), false)
	individual_style.list_setting_changed.connect(_on_style_settings_changed)
	individual_style.font_size_changed.connect(_on_style_font_size_changed)
	individual_style.entry_separation = object_v_box.get_theme_constant("separation")


func _apply_style_preset(preset: PresetStyle) -> void:
	background.add_theme_stylebox_override("panel", preset.background_panel_style_box)
	object_v_box.add_theme_constant_override("separation", preset.entry_separation)
	list_title.theme = preset.title_text_edit_theme
	for entry_id in entries:
		entries[entry_id].change_text_edit_theme(preset.text_edit_theme)
		entries[entry_id].change_div_theme(preset.list_div_theme)
	refresh_entry_divs_visibility()


func change_style_preset(preset: PresetStyle) -> void:
	if has_style_preset and style_preset:
		if style_preset == preset:		# Stop if changing to the same preset
			return
		style_preset.list_setting_changed.disconnect(_on_style_settings_changed)
		style_preset.font_size_changed.disconnect(_on_style_font_size_changed)
	has_style_preset = true
	style_preset = preset
	style_preset.list_setting_changed.connect(_on_style_settings_changed)
	style_preset.font_size_changed.connect(_on_style_font_size_changed)
	_apply_style_preset(style_preset)


func unassign_style_preset() -> void:
	if has_style_preset and style_preset:
		style_preset.list_setting_changed.disconnect(_on_style_settings_changed)
		style_preset.font_size_changed.disconnect(_on_style_font_size_changed)
	has_style_preset = false
	style_preset = null
	_apply_style_preset(individual_style)


# When entries change order - show all div lines except last entry's 
func refresh_entry_divs_visibility() -> void:
	if entries.size() < 1:
		return
	elif entries.size() == 1:
		entries[entries.keys()[0]].toggle_div(false)
		return
	var divs_enabled: bool = style_preset.list_div_enabled if has_style_preset else individual_style.list_div_enabled
	var last_entry_in_list: int = entries_order[-1]
	for entry_id in entries:
		entries[entry_id].toggle_div(divs_enabled)
	entries[last_entry_in_list].toggle_div(false)


func toggle_side_buttons(toggled_on: bool) -> void:
	if toggled_on:
		erase_entry_tween.toggle(true)
		if priority_tool_enabled and priority_enabled:
			priority_buttons_tween.toggle(true)
		line_up_side_buttons.call_deferred()
	else:
		erase_entry_tween.toggle(false)
		priority_buttons_tween.toggle(false)


func toggle_all_entries_hover(toggled_on: bool) -> void:
	for entry_id in entries:
		entries[entry_id].can_hover = toggled_on
		# FIXME this will stop dragging from list to canvas and from list to list
		#if !toggled_on:	#  and !entries[entry_id].grabber_clicked
			#entries[entry_id].reset_hover()


func toggle_mouse_input(toggled_on: bool) -> void:
	toggle_all_entries_hover(toggled_on)


func get_bg_color() -> Color:
	if has_style_preset:
		return style_preset.background_color
	else:
		return individual_style.background_panel_style_box.bg_color


func _on_style_settings_changed(setting: PresetStyle.ListSettings, value) -> void:
	match setting:
		PresetStyle.ListSettings.ENTRY_SEPARATION:
			object_v_box.add_theme_constant_override("separation", int(value))
		PresetStyle.ListSettings.DIV_ENABLED:
			refresh_entry_divs_visibility()


func _on_style_font_size_changed() -> void:
	for entry_id in entries:
		entries[entry_id].reset_item_sizes.call_deferred()
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
	list_title.custom_maximum_size.x = size.x - total_horizontal_margin
	mouse_hover_shape.shape.size = size
	mouse_hover.position = size * 0.5
	line_up_side_buttons.call_deferred()


func _on_list_text_entry_text_changed() -> void:
	ensure_entry_visible()
	list_changed.emit()


# TODO finish ListDragHelper
func _on_list_text_entry_grabber_started_move(entry_id: int, event_pos: Vector2) -> void:
	if !entries.has(entry_id):
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	dragger.start_drag_child(entry_id, entries, event_pos, drop_visual, get_new_drag_position_data())
	dragging.emit(true)
	change_state(State.DRAGGING_CHILD_INSIDE)


# TODO finish ListDragHelper
func _on_list_text_entry_grabber_moved(event: InputEventMouseMotion, entry_id: int) -> void:
	if !entries.has(entry_id):
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	dragger.accumulate_position(event.relative / canvas_scale, scroll_container.scroll_vertical)
	if mouse_inside:
		dragger.drag_child()
		dragger.position_child_drop_visual()


# TODO finish ListDragHelper
func _on_list_text_entry_grabber_ended_move(entry_id: int) -> void:
	if !entries.has(entry_id):
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	if dragger.object_id != entry_id:
		push_error("Wrong drag ID")
		return
	var move_to: int = dragger.current
	change_state(State.DEFAULT)
	dragger.end_drag()
	dragging.emit(false)
	toggle_all_entries_hover(true)
	if entry_id != move_to:
		object_v_box.move_child(entries[entry_id], move_to)
		sort_entries(entry_id, move_to)
		last_edited_entry_id = move_to
		last_edited_order_id = entries[entry_id].order_id
		line_up_side_buttons.call_deferred()
		refresh_entry_divs_visibility()
		list_changed.emit()


# On TextEdit focus entered and exited
func _on_list_text_entry_text_entry_toggled(entry_id: int, toggled_on: bool) -> void:
	if !entries.has(entry_id):
		return
	last_edited_entry_id = entry_id
	last_edited_order_id = entries[entry_id].order_id
	ensure_entry_visible()
	toggle_side_buttons(toggled_on)
	text_edit_active.emit(id)


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
	if !entries.has(last_edited_entry_id):
		return
	var entry: ListTextEntry = entries[last_edited_entry_id]
	remove_text_entry(entry, true)


func _on_list_title_gui_input(event: InputEvent) -> void:
	if list_title.has_focus() and event.is_action_pressed("exit_text_edit", false, true):
		list_title.release_focus()


func _on_priority_active_pressed() -> void:
	signal_active_entry_priority(Enums.Priority.ACTIVE)


func _on_priority_high_pressed() -> void:
	signal_active_entry_priority(Enums.Priority.HIGH)


func _on_priority_medium_pressed() -> void:
	signal_active_entry_priority(Enums.Priority.MEDIUM)


func _on_priority_low_pressed() -> void:
	signal_active_entry_priority(Enums.Priority.LOW)


func _on_priority_none_pressed() -> void:
	signal_active_entry_priority(Enums.Priority.NONE)
