extends Panel
class_name ElementLabel

@export var completed_stylebox: StyleBoxFlat
@export var line_edit_theme: Theme
@export var line_edit_completed_theme: Theme
@onready var line_edit: LineEdit = $MarginContainer/LineEdit
var panel_stylebox
var id: int
var completed: bool = false

signal became_active


func _ready() -> void:
	panel_stylebox = get_theme_stylebox("panel").duplicate()
	add_theme_stylebox_override("panel", panel_stylebox)


func toggle_completed() -> void:
	completed = !completed
	if completed:
		add_theme_stylebox_override("panel", completed_stylebox)
		line_edit.theme = line_edit_completed_theme
	else:
		add_theme_stylebox_override("panel", panel_stylebox)
		line_edit.theme = line_edit_theme


func _on_line_edit_editing_toggled(toggled_on: bool) -> void:
	if toggled_on:
		became_active.emit()


func set_bg_color(color: Color) -> void:
	panel_stylebox.bg_color = color


func get_bg_color() -> Color:
	return panel_stylebox.bg_color
