class_name SteppedScrollContainer extends ScrollContainer

@export var h_step: float = 0.0
@export var v_step: float = 0.0
@export var h_scroll_size: float = 6.0
@export var v_scroll_size: float = 6.0


func _ready() -> void:
	scroll_horizontal_custom_step = h_step
	get_h_scroll_bar().step = h_step
	get_h_scroll_bar().set_deferred("size", Vector2(0.0, h_scroll_size))
	get_h_scroll_bar().set_deferred("custom_minimum_size", Vector2(0.0, h_scroll_size))
	scroll_vertical_custom_step = v_step
	get_v_scroll_bar().step = v_step
	get_v_scroll_bar().set_deferred("size", Vector2(v_scroll_size, 0.0))
	get_v_scroll_bar().set_deferred("custom_minimum_size", Vector2(v_scroll_size, 0.0))
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
			scroll_vertical += int(v_step)
		elif event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP:
			scroll_vertical -= int(v_step)
