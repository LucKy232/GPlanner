extends VBoxContainer

#@onready var name_label: Label = $NameLabel
@onready var zoom_icon: Panel = $ZoomIcon
@onready var zoom_progress_bar: ProgressBar = $ZoomProgressBar
@onready var zoom_label: Label = $ZoomLabel
@onready var hide_timer: Timer = $HideTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.play("fade_out_zoom_indicator")


func update_zoom(zoom_val: float) -> void:
	show_zoom()
	zoom_progress_bar.value = zoom_val
	zoom_label.text = "%d%%" % int(zoom_val * 100.0)


func _on_hide_timer_timeout() -> void:
	hide_zoom()


func show_zoom() -> void:
	if !animation_player.is_playing() and hide_timer.is_stopped():
		animation_player.play("fade_in_zoom_indicator")
		hide_timer.start()


func hide_zoom() -> void:
	animation_player.play("fade_out_zoom_indicator")
