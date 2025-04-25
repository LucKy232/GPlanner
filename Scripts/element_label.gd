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

var background_stylebox: StyleBoxFlat
var priority_stylebox: StyleBoxFlat
var priority_id: int
var id: int
var completed: bool = false
var priority_enabled: bool = false
var priority_tool_shown: bool = false
var priority_tool_enabled: bool = true
var manual_resize: bool = false

signal became_selected
signal changed_priority


func _ready() -> void:
	background_stylebox = background.get_theme_stylebox("panel").duplicate()
	priority_stylebox = priority.get_theme_stylebox("panel").duplicate()
	background.add_theme_stylebox_override("panel", background_stylebox)
	priority.add_theme_stylebox_override("panel", priority_stylebox)
	tool_margin_container.modulate.a = 0.0
	line_edit.theme = line_edit_theme


func toggle_completed() -> void:
	completed = !completed
	if completed:
		background.add_theme_stylebox_override("panel", completed_stylebox)
		priority.visible = false
		line_edit.theme = line_edit_completed_theme
		z_index = completed_z_index
		#TODO set priority completed color
	else:
		background.add_theme_stylebox_override("panel", background_stylebox)
		priority.visible = true
		line_edit.theme = line_edit_theme
		z_index = active_z_index


func set_bg_color(color: Color) -> void:
	background_stylebox.bg_color = color


func get_bg_color() -> Color:
	return background_stylebox.bg_color


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


func change_style_preset(preset: ElementPreset) -> void:
	line_edit.theme = preset.line_edit_theme
	background.add_theme_stylebox_override("panel", preset.background_panel_style_box)


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


func _on_priority_tool_area_mouse_entered() -> void:
	if !animation_player.is_playing() and !completed and priority_enabled:
		toggle_priority_tool(true)


func _on_priority_tool_area_mouse_exited() -> void:
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
