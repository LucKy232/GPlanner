class_name StatusLabel extends Label

@onready var tween_show_hide: TweenShowHide = $TweenShowHide
@onready var hide_timer: Timer = $HideTimer


func show_message_then_hide(message: String, bg_color: Color) -> void:
	show_status_label()
	set_label_text(message)
	set_color(bg_color)
	start_hide_timer()


func set_label_text(new_text: String) -> void:
	text = new_text


func set_color(bg_color: Color) -> void:
	get_theme_stylebox("normal").bg_color = bg_color


func start_hide_timer() -> void:
	hide_timer.start()


func show_status_label() -> void:
	tween_show_hide.toggle(true)


func hide_status_label() -> void:
	tween_show_hide.toggle(false)


func _on_timer_timeout() -> void:
	hide_status_label()
