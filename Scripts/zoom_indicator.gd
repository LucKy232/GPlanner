extends VBoxContainer
class_name ZoomIndicator

@export var alpha_when_hidden: float = 0.5
@onready var zoom_progress_bar: ProgressBar = %ZoomProgressBar
@onready var zoom_icon: TextureRect = %ZoomIcon
@onready var zoom_label: Label = $ZoomLabel
@onready var hide_timer: Timer = $HideTimer
@onready var tween_show_hide: TweenShowHide = $TweenShowHide
var tween_modulate: Tween		## Takes the settings from tween_show_hide, modulates alpha of "zoom_label" when hiding


func _ready() -> void:
	show_zoom()


func update_zoom(zoom_val: float) -> void:
	show_zoom()
	zoom_progress_bar.value = zoom_val
	zoom_label.text = "%d%%" % int(zoom_val * 100.0)


func show_zoom() -> void:
	tween_show_hide.toggle(true)
	tween_modulate_toggle(true)
	hide_timer.start()


func hide_zoom() -> void:
	tween_show_hide.toggle(false)
	tween_modulate_toggle(false)


func tween_modulate_toggle(toggled_on: bool) -> void:
	if tween_modulate and tween_modulate.is_running():
		tween_modulate.stop()
	tween_modulate = create_tween().set_ease(tween_show_hide.ease_type).set_trans(tween_show_hide.transition_type)
	if toggled_on:
		tween_modulate.tween_property(zoom_label, "modulate:a", 1.0, tween_show_hide.animation_time)
	else:
		tween_modulate.tween_property(zoom_label, "modulate:a", alpha_when_hidden, tween_show_hide.animation_time)


func set_accent_color(c: Color) -> void:
	zoom_progress_bar.theme.get_stylebox("background", "ProgressBar").border_color = c


func _on_hide_timer_timeout() -> void:
	hide_zoom()
