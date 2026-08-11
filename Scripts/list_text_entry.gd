class_name ListTextEntry extends HBoxContainer

@onready var priority_idicator: PriorityIndicatorDot = $PriorityIdicator
@onready var text_edit: TextEdit = $TextEdit
@onready var grabber_margin: MarginContainer = $GrabberMargin
@onready var complete_button: Button = $CompleteButton
@onready var erase_button: Button = $EraseButton
@onready var mouse_hover: Area2D = $MouseHover
@onready var mouse_hover_shape: CollisionShape2D = $MouseHover/MouseHoverShape
var grabber_clicked: bool = false
var can_hover: bool = true
var id: int = -1

signal text_edit_active
signal text_changed
signal grabber_moved
signal grabber_started_move
signal grabber_ended_move
@warning_ignore("unused_signal")
signal remove_from_list


func _ready() -> void:
	_on_hover(false)


func _get_drag_data(_at_position: Vector2) -> Variant:
	return self


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		if grabber_clicked:
			grabber_clicked = false
			complete_button.visible = true
			erase_button.visible = true
			grabber_ended_move.emit(id)
			_on_hover(false)
	if grabber_clicked and event is InputEventMouseMotion:
		grabber_moved.emit(event, id)


func change_priority_color(c: Color) -> void:
	priority_idicator.inner_circle_color = c
	priority_idicator.queue_redraw()


func set_font_size(font_size: int) -> void:
	text_edit.add_theme_font_size_override("font_size", font_size)


func rebuild_from_dict(dict: Dictionary) -> void:
	text_edit.text = dict["text"]


func set_text(text: String) -> void:
	text_edit.text = text


func get_text() -> String:
	return text_edit.text


func enter_text_edit() -> void:
	text_edit.grab_focus()


func exit_text_edit() -> void:
	text_edit.release_focus()


func is_editing_text() -> bool:
	return text_edit.has_focus()


func to_json() -> Dictionary:
	var dict: Dictionary = {
		"text": text_edit.text,
	}
	return dict


func _on_hover(on: bool) -> void:
	if grabber_clicked or !can_hover:
		return
	priority_idicator.visible = !on
	grabber_margin.visible = on
	complete_button.visible = on
	erase_button.visible = on


func _on_grabber_margin_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		grabber_started_move.emit(id, event.position)
		grabber_clicked = true
		complete_button.visible = false
		erase_button.visible = false


func _on_text_edit_lines_edited_from(_from_line: int, _to_line: int) -> void:
	text_changed.emit()


func _on_mouse_hover_mouse_entered() -> void:
	_on_hover(true)


func _on_mouse_hover_mouse_exited() -> void:
	_on_hover(false)


func _on_resized() -> void:
	if !is_node_ready():
		return
	mouse_hover_shape.shape.size = size
	mouse_hover.position = size * 0.5


func _on_text_edit_focus_entered() -> void:
	text_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	text_edit_active.emit(id)


func _on_text_edit_focus_exited() -> void:
	text_edit.mouse_filter = Control.MOUSE_FILTER_PASS
