class_name ElementLabel extends Panel

@export var priority_tool_animation_time: float = 1.0
@export var priority_tool_hide_delay: float = 3.0
@export var line_wrap_limit: float = 4.0
@export var completed_stylebox: StyleBoxFlat
@export var text_edit_theme: Theme
@export var text_edit_completed_theme: Theme
@export var completed_z_index = 0
@export var active_z_index = 1
@onready var background: Panel = $PanelContainer/Background
@onready var priority: Panel = $PanelContainer/Background/Priority
@onready var text_edit: TextEdit = %TextEdit
@onready var text_margin_container: MarginContainer = $PanelContainer/Background/TextMarginContainer
@onready var priority_buttons_margin: Control = %PriorityButtonsMargin
@onready var priority_buttons: VBoxContainer = %PriorityButtons
@onready var grab_indicator: Panel = %GrabIndicator
@onready var resize_timer: Timer = $ResizeTimer
@onready var hide_animation_timer: Timer = $HideAnimationTimer

var individual_style: ElementPresetStyle
var priority_stylebox: StyleBoxFlat
var preset_text_edit_theme: Theme
var preset_background_stylebox: StyleBoxFlat
var id: int
var priority_id: int
var style_preset_id: String = "none"
var completed: bool = false
var has_style_preset: bool = false
var priority_enabled: bool = false
var priority_tool_shown: bool = false
var priority_tool_enabled: bool = true
var manual_resize: bool = false
var total_horizontal_margin: float
var total_vertical_margin: float
var tween_priority_buttons: Tween

signal became_selected
signal changed_priority
signal text_changed


func _ready() -> void:
	init_individual_style()
	background.add_theme_stylebox_override("panel", individual_style.background_panel_style_box)
	text_edit.theme = individual_style.text_edit_theme
	priority_stylebox = priority.get_theme_stylebox("panel").duplicate()
	priority.add_theme_stylebox_override("panel", priority_stylebox)
	total_horizontal_margin = text_margin_container.get_theme_constant("margin_left") + text_margin_container.get_theme_constant("margin_right")
	total_vertical_margin = text_margin_container.get_theme_constant("margin_top") + text_margin_container.get_theme_constant("margin_bottom")


func init_individual_style() -> void:
	individual_style = ElementPresetStyle.new("individual")
	individual_style.set_background_panel_style_box(background.get_theme_stylebox("panel").duplicate())
	individual_style.set_text_edit_theme(text_edit_theme.duplicate())


func toggle_completed() -> void:
	completed = !completed
	if completed:
		background.add_theme_stylebox_override("panel", completed_stylebox)
		priority.visible = false
		text_edit.theme = text_edit_completed_theme
		z_index = completed_z_index
	else:
		if has_style_preset:
			background.add_theme_stylebox_override("panel", preset_background_stylebox)
			text_edit.theme = preset_text_edit_theme
		else:
			background.add_theme_stylebox_override("panel", individual_style.background_panel_style_box)
			text_edit.theme = individual_style.text_edit_theme
		priority.visible = true
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
	priority.visible = toggled_on


func toggle_priority_tool(toggle_on: bool) -> void:
	if toggle_on and !hide_animation_timer.is_stopped():
		hide_animation_timer.stop()
	if toggle_on and !priority_tool_shown and priority_tool_enabled:
		priority_buttons_margin.visible = true
		if tween_priority_buttons and tween_priority_buttons.is_running():
			tween_priority_buttons.stop()
		tween_priority_buttons = create_tween()
		tween_priority_buttons.set_parallel().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		var distance_mult: float = (priority_buttons.size.x - priority_buttons_margin.offset_transform_position.x) / priority_buttons.size.x
		tween_priority_buttons.tween_property(priority_buttons_margin, "offset_transform_position:x", priority_buttons.size.x, priority_tool_animation_time * distance_mult)
		tween_priority_buttons.tween_property(priority_buttons_margin, "modulate:a", 1.0, 0.2)
		priority_tool_shown = true
	elif !toggle_on and priority_tool_shown:
		if tween_priority_buttons and tween_priority_buttons.is_running():
			tween_priority_buttons.stop()
		tween_priority_buttons = create_tween()
		tween_priority_buttons.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
		tween_priority_buttons.tween_interval(priority_tool_hide_delay)
		tween_priority_buttons.tween_property(priority_buttons_margin, "offset_transform_position:x", 0.0, priority_tool_animation_time)
		tween_priority_buttons.tween_property(priority_buttons_margin, "modulate:a", 0.0, 0.2)
		tween_priority_buttons.tween_property(priority_buttons_margin, "visible", true, 0.0)
		priority_tool_shown = false


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


func deselect() -> void:
	text_edit.apply_ime()
	z_index = completed_z_index if completed else active_z_index
	exit_text_edit()
	grab_indicator.visible = false


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
	priority_id = 0
	changed_priority.emit()


func _on_priority_high_pressed() -> void:
	priority_id = 1
	changed_priority.emit()


func _on_priority_medium_pressed() -> void:
	priority_id = 2
	changed_priority.emit()


func _on_priority_low_pressed() -> void:
	priority_id = 3
	changed_priority.emit()


func _on_priority_none_pressed() -> void:
	priority_id = 4
	changed_priority.emit()


func _on_priority_buttons_gui_input(_event: InputEvent) -> void:
	if !completed and priority_enabled:
		toggle_priority_tool(true)


func _on_priority_buttons_mouse_exited() -> void:
	if hide_animation_timer and hide_animation_timer.is_inside_tree():
		hide_animation_timer.start()


func _on_resize_timer_timeout() -> void:
	manual_resize = false


func _on_visibility_changed() -> void:
	if is_node_ready():
		set_size_fixed()


func _on_text_edit_resized() -> void:
	if text_edit :
		custom_minimum_size.y = text_edit.size.y + total_vertical_margin


func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.position.x > (size.x - 25.0):
		if !manual_resize and !completed and priority_enabled:
			toggle_priority_tool(true)


func _on_text_edit_lines_edited_from(_from_line: int, _to_line: int) -> void:
	text_changed.emit()


func _on_text_edit_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit_text_edit", false, true):
		exit_text_edit()


func _on_text_edit_focus_entered() -> void:
	became_selected.emit()


func _on_hide_animation_timer_timeout() -> void:
	toggle_priority_tool(false)
