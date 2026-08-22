class_name ElementLabel extends Panel

@export var line_wrap_limit: float = 4.0
@export var completed_stylebox: StyleBoxFlat
@export var text_edit_theme: Theme
@export var text_edit_completed_theme: Theme
@export var completed_z_index = 0
@export var active_z_index = 1
@onready var background: Panel = %Background
@onready var priority_panel: Panel = %PriorityPanel
@onready var text_edit: TextEdit = %TextEdit
@onready var text_margin_container: MarginContainer = %TextMarginContainer
@onready var priority_buttons: VBoxContainer = %PriorityButtons
@onready var grab_indicator: Panel = %GrabIndicator
@onready var resize_timer: Timer = $ResizeTimer
@onready var drag_and_resize_input: DragAndResizeInput = $DragAndResizeInput
@onready var priority_buttons_tween: TweenShowHide = %PriorityButtonsTween

var individual_style: ElementPresetStyle
var priority_stylebox: StyleBoxFlat
var preset_text_edit_theme: Theme
var preset_background_stylebox: StyleBoxFlat
var id: int
var priority_id: Enums.Priority
var style_preset_id: String = "none"
var completed: bool = false
var has_style_preset: bool = false
var priority_enabled: bool = false
var priority_tool_enabled: bool = true
var manual_resize: bool = false
var total_horizontal_margin: float
var total_vertical_margin: float

signal became_selected
signal changed_priority
signal text_changed


func _ready() -> void:
	init_individual_style()
	background.add_theme_stylebox_override("panel", individual_style.background_panel_style_box)
	text_edit.theme = individual_style.text_edit_theme
	priority_stylebox = priority_panel.get_theme_stylebox("panel").duplicate()
	priority_panel.add_theme_stylebox_override("panel", priority_stylebox)
	total_horizontal_margin = text_margin_container.get_theme_constant("margin_left") + text_margin_container.get_theme_constant("margin_right")
	total_vertical_margin = text_margin_container.get_theme_constant("margin_top") + text_margin_container.get_theme_constant("margin_bottom")


func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_and_resize_input.is_being_dragged:
		return self
	else:
		return null


func start_dragging() -> void:
	drag_and_resize_input.is_being_dragged = true
	drag_and_resize_input.is_being_resized = false
	set_default_cursor_shape(Control.CURSOR_DRAG)


func start_resizing() -> void:
	drag_and_resize_input.is_being_resized = true
	drag_and_resize_input.is_being_dragged = false
	set_default_cursor_shape(Control.CURSOR_FDIAGSIZE)


func end_input() -> void:
	drag_and_resize_input.end()
	set_default_cursor_shape(Control.CURSOR_POINTING_HAND)


func init_individual_style() -> void:
	individual_style = ElementPresetStyle.new("individual")
	individual_style.set_background_panel_style_box(background.get_theme_stylebox("panel").duplicate())
	individual_style.set_text_edit_theme(text_edit_theme.duplicate())


func toggle_completed() -> void:
	completed = !completed
	if completed:
		background.add_theme_stylebox_override("panel", completed_stylebox)
		priority_panel.visible = false
		text_edit.theme = text_edit_completed_theme
		z_index = completed_z_index
	else:
		if has_style_preset:
			background.add_theme_stylebox_override("panel", preset_background_stylebox)
			text_edit.theme = preset_text_edit_theme
		else:
			background.add_theme_stylebox_override("panel", individual_style.background_panel_style_box)
			text_edit.theme = individual_style.text_edit_theme
		priority_panel.visible = true
		z_index = active_z_index


func set_bg_color(color: Color) -> void:
	individual_style.set_background_color(color)


func get_bg_color() -> Color:
	if has_style_preset:
		return preset_background_stylebox.bg_color
	else:
		return individual_style.background_panel_style_box.bg_color


func set_priority_color(color: Color) -> void:
	priority_stylebox.bg_color = color
	if completed:
		priority_stylebox.bg_color.a = 0.4


func set_priority_visible(toggled_on: bool) -> void:
	priority_enabled = toggled_on
	priority_panel.visible = toggled_on


func get_text() -> String:
	return text_edit.text


func set_text(text: String) -> void:
	text_edit.text = text


func change_size(new_size: Vector2) -> void:
	manual_resize = true
	var smaller: bool = true if new_size.x < size.x else false
	var wraps: float = float(text_edit.get_visible_line_count()) / float(text_edit.get_line_count())
	if (smaller and wraps < line_wrap_limit) or !smaller:
		size = new_size
		text_edit.custom_maximum_size.x = clampf(new_size.x - total_horizontal_margin, text_edit.custom_minimum_size.x, 1000.0)
	resize_timer.start()


func set_size_fixed() -> void:
	manual_resize = true
	resize_timer.start()


func change_style_preset(preset: ElementPresetStyle) -> void:
	has_style_preset = true
	style_preset_id = preset.id
	preset_text_edit_theme = preset.text_edit_theme
	preset_background_stylebox = preset.background_panel_style_box
	if !completed:
		text_edit.theme = preset.text_edit_theme
		background.add_theme_stylebox_override("panel", preset.background_panel_style_box)


func unassign_preset_style() -> void:
	has_style_preset = false
	style_preset_id = "none"
	if completed:
		background.add_theme_stylebox_override("panel", completed_stylebox)
		text_edit.theme = text_edit_completed_theme
	else:
		background.add_theme_stylebox_override("panel", individual_style.background_panel_style_box)
		text_edit.theme = individual_style.text_edit_theme


func enter_text_edit() -> void:
	text_edit.grab_focus()


func exit_text_edit() -> void:
	text_edit.release_focus()


func is_editing_text() -> bool:
	return text_edit.has_focus()


func select() -> void:
	z_index = 2
	grab_indicator.visible = true
	if priority_tool_enabled:
		priority_buttons_tween.toggle(true)


func deselect() -> void:
	text_edit.apply_ime()
	z_index = completed_z_index if completed else active_z_index
	exit_text_edit()
	grab_indicator.visible = false
	priority_buttons_tween.toggle(false)


func to_json() -> Dictionary:
	var dict: Dictionary = {
		"id": id,
		"priority_id": priority_id,
		"completed": completed,
		"has_style_preset": has_style_preset,
		"style_preset_id": style_preset_id,
		"pos.x": position.x,
		"pos.y": position.y,
		"size.x": size.x,
		"size.y": size.y,
		"text": text_edit.text,
	}
	if !has_style_preset:
		dict["individual_style"] = individual_style.to_json()
	return dict


func _on_priority_active_pressed() -> void:
	priority_id = Enums.Priority.ACTIVE
	changed_priority.emit()


func _on_priority_high_pressed() -> void:
	priority_id = Enums.Priority.HIGH
	changed_priority.emit()


func _on_priority_medium_pressed() -> void:
	priority_id = Enums.Priority.MEDIUM
	changed_priority.emit()


func _on_priority_low_pressed() -> void:
	priority_id = Enums.Priority.LOW
	changed_priority.emit()


func _on_priority_none_pressed() -> void:
	priority_id = Enums.Priority.NONE
	changed_priority.emit()


func _on_resize_timer_timeout() -> void:
	manual_resize = false


func _on_visibility_changed() -> void:
	if is_node_ready():
		set_size_fixed()


func _on_text_edit_resized() -> void:
	if text_edit :
		custom_minimum_size.y = text_edit.size.y + total_vertical_margin


func _on_text_edit_lines_edited_from(_from_line: int, _to_line: int) -> void:
	text_changed.emit()


func _on_text_edit_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit_text_edit", false, true):
		exit_text_edit()


func _on_text_edit_focus_entered() -> void:
	became_selected.emit()
