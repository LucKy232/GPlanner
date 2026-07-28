class_name ListTextEntry extends HBoxContainer

@onready var priority_idicator: PriorityIndicatorDot = $PriorityIdicator
@onready var text_edit: TextEdit = $TextEdit
@onready var grabber_margin: MarginContainer = $GrabberMargin
@onready var complete_button: Button = $CompleteButton
@onready var erase_button: Button = $EraseButton
var grabber_clicked: bool = false
var id: int = -1

signal text_changed
signal grabber_moved
signal grabber_started_move
signal grabber_ended_move


func _ready() -> void:
	_on_hover(false)


func change_priority_color(c: Color) -> void:
	priority_idicator.inner_circle_color = c
	priority_idicator.queue_redraw()


func set_font_size(font_size: int) -> void:
	text_edit.add_theme_font_size_override("font_size", font_size)


func rebuild_from_dict(dict: Dictionary) -> void:
	text_edit.text = dict["text"]


func to_json() -> Dictionary:
	var dict: Dictionary = {
		"text": text_edit.text,
	}
	return dict


func _on_hover(on: bool) -> void:
	if grabber_clicked:
		return
	priority_idicator.visible = !on
	grabber_margin.visible = on
	complete_button.visible = on
	erase_button.visible = on


func _on_mouse_entered() -> void:
	_on_hover(true)


func _on_mouse_exited() -> void:
	_on_hover(false)


func _on_grabber_margin_mouse_entered() -> void:
	_on_hover(true)


func _on_grabber_margin_mouse_exited() -> void:
	_on_hover(false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		if grabber_clicked:
			grabber_clicked = false
			complete_button.visible = true
			erase_button.visible = true
			grabber_ended_move.emit()
			_on_hover(false)
	if grabber_clicked and event is InputEventMouseMotion:
		grabber_moved.emit(event)


func _on_grabber_margin_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		grabber_started_move.emit()
		grabber_clicked = true
		complete_button.visible = false
		erase_button.visible = false


func _on_text_edit_lines_edited_from(_from_line: int, _to_line: int) -> void:
	text_changed.emit()
