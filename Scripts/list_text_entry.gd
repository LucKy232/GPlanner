class_name ListTextEntry extends Control

@onready var priority_idicator: PriorityIndicatorDot = %PriorityIdicator
@onready var grabber: TextureRect = %Grabber
@onready var grabber_margin: MarginContainer = %GrabberMargin
@onready var grabber_control: Control = %GrabberControl
@onready var text_edit: TextEdit = %TextEdit
@onready var mouse_hover: Area2D = %MouseHover
@onready var mouse_hover_shape: CollisionShape2D = %MouseHoverShape
@onready var bottom_div: Panel = %BottomDiv

var grabber_clicked: bool = false
var initial_grabber_event: Vector2 = Vector2.ZERO
var can_hover: bool = true
var priority_id: Enums.Priority = Enums.Priority.NONE
var priority_color: Color = Color.WHITE
var list_id: int = -1
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
	reset_item_sizes.call_deferred()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if grabber_clicked:
		return self
	return null


func _input(event: InputEvent) -> void:
	if !grabber_clicked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		end_grab()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		end_grab()
	elif event is InputEventMouseMotion:
		grabber_moved.emit(event, id)


func end_grab() -> void:
	grabber_clicked = false
	grabber_ended_move.emit(id)
	_on_hover(false)


func change_priority_color(c: Color) -> void:
	priority_idicator.inner_circle_color = c
	priority_idicator.queue_redraw()


func change_text_edit_theme(_theme: Theme) -> void:
	text_edit.theme = _theme
	reset_item_sizes.call_deferred()


func change_div_theme(_theme: Theme) -> void:
	bottom_div.theme = _theme


func get_font_size() -> int:
	return text_edit.get_theme_font_size("font_size")


func set_priority(p: Enums.Priority) -> void:
	priority_id = p


func set_priority_color(color: Color) -> void:
	priority_color = color
	priority_idicator.inner_circle_color = color
	priority_idicator.outer_circle_color = color if priority_id != Enums.Priority.NONE else Color.WHITE
	priority_idicator.queue_redraw()


func disable_priority_color() -> void:
	priority_idicator.inner_circle_color = Color.TRANSPARENT
	priority_idicator.outer_circle_color = Color.WHITE
	priority_idicator.queue_redraw()


func enable_priority_color() -> void:
	priority_idicator.inner_circle_color = priority_color
	priority_idicator.outer_circle_color = priority_color if priority_id != Enums.Priority.NONE else Color.WHITE
	priority_idicator.queue_redraw()


func toggle_div(toggle_on: bool) -> void:
	bottom_div.visible = toggle_on


func rebuild_from_dict(dict: Dictionary) -> void:
	text_edit.text = dict["text"]


func reset_item_sizes() -> void:
	var text_size: float = float(get_font_size() + 3)
	change_priority_indicator_size(text_size)
	change_grabber_size(text_size)


func change_priority_indicator_size(text_size: float) -> void:
	priority_idicator.circle_radius = text_size / 6.0
	priority_idicator.circle_thickness = text_size / 12.0
	priority_idicator.custom_minimum_size = Vector2(text_size, text_size)
	priority_idicator.queue_redraw()


func change_grabber_size(text_size: float) -> void:
	var new_scale: float = text_size / (grabber.size.y)
	grabber_margin.scale = Vector2.ONE * new_scale
	grabber_control.custom_minimum_size = Vector2(text_size, text_size)
	grabber_margin.offset_top = 0


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
		"priority_id": priority_id,
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
		initial_grabber_event = ( event.position * grabber_margin.scale
					+ Vector2(grabber_margin.get_theme_constant("margin_left"), grabber_margin.get_theme_constant("margin_top")) )
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
