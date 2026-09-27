class_name StatusBar extends Label

@onready var hide_timer: Timer = $HideTimer
@onready var tween_show_hide: TweenShowHide = $TweenShowHide


func update_status(new_text: String, bg_color := Color(0.6, 0.6, 0.6, 0.45)) -> void:
	show_status_bar()
	text = new_text
	hide_timer.start()
	get_theme_stylebox("normal").bg_color = bg_color


func show_status_bar() -> void:
	tween_show_hide.toggle(true)


func hide_status_bar() -> void:
	tween_show_hide.toggle(false)


func _on_timer_timeout() -> void:
	hide_status_bar()
