extends Label

@onready var hide_timer: Timer = $HideTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func update_status(new_text: String) -> void:
	show_status_bar()
	text = new_text


func show_status_bar() -> void:
	visible = true
	animation_player.play("fade_in_status_bar")
	hide_timer.start()


func _on_timer_timeout() -> void:
	hide_status_bar()


func hide_status_bar() -> void:
	animation_player.play("fade_out_status_bar")
