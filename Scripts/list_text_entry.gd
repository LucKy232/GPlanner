class_name ListTextEntry extends Control

@onready var priority_idicator: PriorityIndicatorDot = %PriorityIdicator
@onready var grabber: TextureRect = %Grabber
@onready var grabber_margin: MarginContainer = %GrabberMargin
@onready var grabber_control: Control = %GrabberControl
@onready var text_edit: TextEdit = %TextEdit
@onready var mouse_hover: Area2D = %MouseHover
@onready var mouse_hover_shape: CollisionShape2D = %MouseHoverShape

var grabber_clicked: bool = false
var can_hover: bool = true
var id: int = -1

@warning_ignore("unused_signal")
signal remove_from_list
signal text_edit_toggled
signal text_changed
signal grabber_moved
signal grabber_started_move
signal grabber_ended_move
signal text_resized


func _ready() -> void:
	_on_hover(false)
	reset_item_sizes()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if grabber_clicked:
		return self
	return null


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		if grabber_clicked:
			grabber_clicked = false
			grabber_ended_move.emit(id)
			_on_hover(false)
	if grabber_clicked and event is InputEventMouseMotion:
		grabber_moved.emit(event, id)


func change_priority_color(c: Color) -> void:
	priority_idicator.inner_circle_color = c
	priority_idicator.queue_redraw()


func set_font_size(font_size: int) -> void:
	text_edit.add_theme_font_size_override("font_size", font_size)
	reset_item_sizes()


func get_font_size() -> float:
	return text_edit.get_theme_font_size("font_size")


func rebuild_from_dict(dict: Dictionary) -> void:
	text_edit.text = dict["text"]


func reset_item_sizes() -> void:
	var text_size: float = int(get_font_size()) + 3.0
	# Resize priority indicator dot
	priority_idicator.custom_minimum_size = Vector2(20.0, text_size)
	priority_idicator.queue_redraw()
	# Resize grabber by scaling its margin container down
	var margin: float = float(grabber_margin.get_theme_constant("margin_left"))
	var new_scale: float = text_size / (grabber.size.y + margin)
	var new_scale_clamped: float = clampf(new_scale, 0.1, 0.25)
	var min_size: Vector2 = grabber_margin.size * new_scale_clamped
	min_size.x = maxf(floorf(min_size.x), 20.0)
	min_size.y = floorf(min_size.y)
	grabber_margin.scale = Vector2.ONE * new_scale_clamped
	grabber_control.custom_minimum_size = min_size
	# Place grabber_margin in the middle of grabber_control
	var left_offset: float = (min_size.x - floorf(grabber_margin.scale.x * grabber_margin.size.x)) * 0.5
	var top_offset: float = (new_scale - new_scale_clamped) * grabber_margin.size.y * 0.5 if new_scale_clamped < new_scale else 0.0
	grabber_margin.position.x = left_offset
	grabber_margin.offset_top = top_offset


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
	grabber_control.visible = on


func _on_grabber_margin_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		grabber_started_move.emit(id, event.position)
		grabber_clicked = true


func _on_text_edit_lines_edited_from(_from_line: int, _to_line: int) -> void:
	text_changed.emit()


func _on_mouse_hover_mouse_entered() -> void:
	_on_hover(true)


func _on_mouse_hover_mouse_exited() -> void:
	_on_hover(false)


func _on_resized() -> void:
	if !is_node_ready():
		return
	if is_editing_text():
		text_resized.emit()
	mouse_hover_shape.shape.size = size
	mouse_hover.position = size * 0.5


func _on_text_edit_focus_entered() -> void:
	text_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	text_edit_toggled.emit(id, true)


func _on_text_edit_focus_exited() -> void:
	text_edit.mouse_filter = Control.MOUSE_FILTER_PASS
	text_edit_toggled.emit(id, false)


func _on_text_edit_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit_text_edit", false, true):
		exit_text_edit()
