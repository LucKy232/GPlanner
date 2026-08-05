class_name DragAndResizeInput extends Control

var is_being_dragged: bool = false
var is_being_resized: bool = false

signal drag_requested
signal resize_requested
signal input_ended


func end() -> void:
	is_being_dragged = false
	is_being_resized = false


func _process(_delta: float) -> void:
	if (is_being_dragged or is_being_resized) and !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		input_ended.emit()


func _input(event: InputEvent) -> void:
	if !(visible or is_being_dragged or is_being_resized):
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if is_being_dragged:
			drag_requested.emit(event.relative)
		if is_being_resized:
			resize_requested.emit(event.relative)
