class_name TweenShowHide extends Control

@export var target: Control
@export var side: Enums.Side = Enums.Side.LEFT
@export var animation_time: float = 1.0
@export var transition_type: Tween.TransitionType
@export var default_hidden_behind: bool = false
var transform_property: String = ""
var transform_amount_show: float = 0.0
var transform_amount_hide: float = 0.0
var on: bool = false
var tween: Tween


func _ready() -> void:
	if !target:
		push_error("No target selected for TweenShowHide")
		return
	elif !target.offset_transform_enabled:
		push_error("Enable offset transform for target: %s to use in TweenShowHide" % [target.name])
		return
	init_properties()


func init_properties() -> void:
	match side:
		Enums.Side.LEFT:
			transform_property = "offset_transform_position:x"
			transform_amount_show = -target.size.x if default_hidden_behind else 0.0
			transform_amount_hide = 0.0 if default_hidden_behind else target.size.x
			target.offset_transform_position.x = transform_amount_hide
		Enums.Side.RIGHT:
			transform_property = "offset_transform_position:x"
			transform_amount_show = target.size.x if default_hidden_behind else 0.0
			transform_amount_hide = 0.0 if default_hidden_behind else -target.size.x
			target.offset_transform_position.x = transform_amount_hide
		Enums.Side.TOP:
			transform_property = "offset_transform_position:y"
			transform_amount_show = -target.size.y if default_hidden_behind else 0.0
			transform_amount_hide = 0.0 if default_hidden_behind else target.size.y
			target.offset_transform_position.y = transform_amount_hide
		Enums.Side.BOTTOM:
			transform_property = "offset_transform_position:y"
			transform_amount_show = target.size.y if default_hidden_behind else 0.0
			transform_amount_hide = 0.0 if default_hidden_behind else -target.size.y
			target.offset_transform_position.y = transform_amount_hide


func toggle(toggle_on: bool) -> void:
	if toggle_on and !on:
		show_control()
	elif !toggle_on and on:
		hide_control()
	on = toggle_on


func show_control() -> void:
	if tween and tween.is_running():
		tween.stop()
	tween = create_tween()
	tween.set_parallel().set_ease(Tween.EASE_IN_OUT).set_trans(transition_type)
	target.visible = true
	tween.tween_property(target, transform_property, transform_amount_show, animation_time)
	tween.tween_property(target, "modulate:a", 1.0, 0.2)


func hide_control() -> void:
	if tween and tween.is_running():
		tween.stop()
	tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(transition_type)
	tween.tween_property(target, transform_property, transform_amount_hide, animation_time)
	tween.tween_property(target, "modulate:a", 0.0, 0.2)
	tween.tween_property(target, "visible", false, 0.0)
