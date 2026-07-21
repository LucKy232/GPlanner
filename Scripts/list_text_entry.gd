class_name ListTextEntry extends HBoxContainer

@onready var priority_idicator: PriorityIndicatorDot = $PriorityIdicator
@onready var text_edit: TextEdit = $TextEdit
@onready var grabber_margin: MarginContainer = $GrabberMargin
@onready var complete_button: Button = $CompleteButton
@onready var erase_button: Button = $EraseButton
var grabber_clicked: bool = false


func change_priority_color(c: Color) -> void:
	priority_idicator.inner_circle_color = c
	priority_idicator.queue_redraw()


func set_font_size(font_size: int) -> void:
	text_edit.add_theme_font_size_override("font_size", font_size)


func hover_on(on: bool) -> void:
	if grabber_clicked:
		return
	priority_idicator.visible = !on
	grabber_margin.visible = on
	complete_button.visible = on
	erase_button.visible = on


func _on_mouse_entered() -> void:
	hover_on(true)


func _on_mouse_exited() -> void:
	hover_on(false)


func _on_grabber_margin_mouse_entered() -> void:
	hover_on(true)


func _on_grabber_margin_mouse_exited() -> void:
	hover_on(false)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		grabber_clicked = false
		hover_on(false)
	if grabber_clicked:
		print("GRAB ", event.position + global_position)


func _on_grabber_margin_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		grabber_clicked = true
