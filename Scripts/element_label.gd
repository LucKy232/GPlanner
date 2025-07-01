extends Panel
class_name ElementLabel

@export var completed_stylebox: StyleBoxFlat
@export var line_edit_theme: Theme
@export var line_edit_completed_theme: Theme
@export var completed_z_index = 0
@export var active_z_index = 1
@onready var background: Panel = $PanelContainer/Background
@onready var priority: Panel = $PanelContainer/Background/Priority
@onready var line_edit: LineEdit = $PanelContainer/Background/TextMarginContainer/LineEdit
@onready var text_margin_container: MarginContainer = $PanelContainer/Background/TextMarginContainer
@onready var tool_margin_container: MarginContainer = $PanelContainer/ToolMarginContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hide_options_timer: Timer = $HideOptionsTimer
@onready var resize_timer: Timer = $ResizeTimer

var individual_style: ElementPresetStyle
var priority_stylebox: StyleBoxFlat
var preset_line_edit_theme: Theme
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

signal became_selected
signal changed_priority

func _ready() -> void:
	init_individual_style()
	background.add_theme_stylebox_override("panel", individual_style.background_panel_style_box)
	line_edit.theme = individual_style.line_edit_theme
	
	priority_stylebox = priority.get_theme_stylebox("panel").duplicate()
	priority.add_theme_stylebox_override("panel", priority_stylebox)
	tool_margin_container.modulate.a = 0.0


func init_individual_style() -> void:
	individual_style = ElementPresetStyle.new("individual")
	individual_style.set_background_panel_style_box(background.get_theme_stylebox("panel").duplicate())
	individual_style.set_line_edit_theme(line_edit_theme.duplicate())


func toggle_completed() -> void:
	completed = !completed
	if completed:
		background.add_theme_stylebox_override("panel", completed_stylebox)
		priority.visible = false
		line_edit.theme = line_edit_completed_theme
		z_index = completed_z_index
	else:
		if has_style_preset:
			background.add_theme_stylebox_override("panel", preset_background_stylebox)
			line_edit.theme = preset_line_edit_theme
		else:
			background.add_theme_stylebox_override("panel", individual_style.background_panel_style_box)
			line_edit.theme = individual_style.line_edit_theme
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
	if toggle_on and !priority_tool_shown and priority_tool_enabled:
		animation_player.play("show_priority_buttons")
		priority_tool_shown = true
	elif !toggle_on and priority_tool_shown:
		animation_player.play("hide_priority_buttons")
		priority_tool_shown = false


func change_size(new_size: Vector2) -> void:
	manual_resize = true
	size = new_size
	resize_timer.start()


func set_size_fixed() -> void:
	manual_resize = true
	resize_timer.start()


func change_style_preset(preset: ElementPresetStyle) -> void:
	has_style_preset = true
	style_preset_id = preset.id
	preset_line_edit_theme = preset.line_edit_theme
	preset_background_stylebox = preset.background_panel_style_box
	if !completed:
		line_edit.theme = preset.line_edit_theme
		background.add_theme_stylebox_override("panel", preset.background_panel_style_box)


func unassign_preset_style() -> void:
	has_style_preset = false
	style_preset_id = "none"
	if completed:
		background.add_theme_stylebox_override("panel", completed_stylebox)
		line_edit.theme = line_edit_completed_theme
	else:
		background.add_theme_stylebox_override("panel", individual_style.background_panel_style_box)
		line_edit.theme = individual_style.line_edit_theme


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
		"text": line_edit.text,
	}
	if !has_style_preset:
		dict["individual_style"] = individual_style.to_json()
	return dict


func _on_line_edit_editing_toggled(toggled_on: bool) -> void:
	if toggled_on:
		became_selected.emit()


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


func _on_hide_options_timer_timeout() -> void:
	if !animation_player.is_playing():
		toggle_priority_tool(false)


func _on_priority_buttons_mouse_entered() -> void:
	if !animation_player.is_playing() and !completed and priority_enabled:
		toggle_priority_tool(true)
	if !hide_options_timer.is_stopped():
		hide_options_timer.stop()


func _on_priority_buttons_mouse_exited() -> void:
	if hide_options_timer.is_inside_tree():
		hide_options_timer.start()


func _on_text_margin_container_resized() -> void:
	if is_node_ready() and !manual_resize:
		size.x = text_margin_container.size.x
		#print("Resizing element %d to the text box" % [id])


func _on_resize_timer_timeout() -> void:
	manual_resize = false


func _on_visibility_changed() -> void:
	if is_node_ready():
		set_size_fixed()


func _on_background_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.position.x > (size.x - 25.0):
		if !completed and priority_enabled:
			toggle_priority_tool(true)
		if hide_options_timer.is_inside_tree():
			hide_options_timer.start()
