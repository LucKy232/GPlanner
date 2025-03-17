extends Panel
class_name ElementLabel

@onready var line_edit: LineEdit = $MarginContainer/LineEdit
var panel_stylebox
var id: int

signal become_active


func _ready() -> void:
	panel_stylebox = get_theme_stylebox("panel").duplicate()
	add_theme_stylebox_override("panel",panel_stylebox)


func _on_line_edit_editing_toggled(toggled_on: bool) -> void:
	if toggled_on:
		become_active.emit()


func set_bg_color(color: Color) -> void:
	panel_stylebox.bg_color = color
