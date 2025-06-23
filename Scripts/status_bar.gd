extends Label
class_name StatusBar

@onready var hide_timer: Timer = $HideTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func update_status(new_text: String, bg_color := Color(0.6, 0.6, 0.6, 0.45)) -> void:
	animation_player.play("fade_in_status_bar")
	visible = true
	hide_timer.start()
	text = new_text
	get_theme_stylebox("normal").bg_color = bg_color


func update_status_immediate(new_text: String, bg_color := Color(0.6, 0.6, 0.6, 0.45)) -> void:
	if visible == false:
		animation_player.play("fade_in_status_bar")
	visible = true
	text = new_text
	hide_timer.start()
	get_theme_stylebox("normal").bg_color = bg_color


func _on_timer_timeout() -> void:
	hide_status_bar()


func hide_status_bar() -> void:
	animation_player.play("fade_out_status_bar")
