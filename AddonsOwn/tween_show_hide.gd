class_name TweenShowHide extends Control

@export var target: Control
@export var animation_time: float = 1.0
@export var immediate_show: bool = false
@export var immediate_hide: bool = false
@export var transition_type: Tween.TransitionType
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT
@export var move_target: bool = true:
	set(value):
		move_target = value
		if is_node_ready():
			init_move_properties()
@export var hide_target: bool = true					## Modulates alpha
@export var change_visibility_value: bool = true		## If false, don't change visibility to false, only modulate alpha
@export var simultaneous_move_and_hide: bool = true
@export_category("Move")
@export var move_by_target_size: bool = true:
	set(value):
		move_by_target_size = value
		if is_node_ready():
			init_move_properties()
@export var default_hidden_behind: bool = false:
	set(value):
		default_hidden_behind = value
		if is_node_ready():
			init_move_properties()
@export var side: Enums.Side = Enums.Side.LEFT:
	set(value):
		side = value
		if is_node_ready():
			init_move_properties()
@export var offset_show: float = 0.0:
	set(value):
		offset_show = value
		if is_node_ready():
			init_move_properties()
@export var offset_hide: float = 0.0:
	set(value):
		offset_hide = value
		if is_node_ready():
			init_move_properties()
var transform_property: String = ""
var transform_amount_show: float = 0.0
var transform_amount_hide: float = 0.0
var on: bool = false
var tween: Tween


func _ready() -> void:
	if !target:
		push_error("No target selected for TweenShowHide")
		return
	elif (move_target and !target.offset_transform_enabled):
		push_error("Enable offset transform for target: %s to move with TweenShowHide" % [target.name])
		return
	if (!move_target and !hide_target):
		push_warning("TweenShowHide won't do anything if not moving or hiding its target!")
	init_move_properties()


func init_move_properties() -> void:
	if !move_target:
		transform_amount_show = 0.0
		transform_amount_hide = 0.0
		return
	var target_size: Vector2 = target.size if move_by_target_size else Vector2.ZERO
	match side:
		Enums.Side.LEFT:
			transform_property = "offset_transform_position:x"
			transform_amount_show = -target_size.x if default_hidden_behind else 0.0
			transform_amount_hide = 0.0 if default_hidden_behind else target_size.x
			target.offset_transform_position.x = transform_amount_hide
		Enums.Side.RIGHT:
			transform_property = "offset_transform_position:x"
			transform_amount_show = target_size.x if default_hidden_behind else 0.0
			transform_amount_hide = 0.0 if default_hidden_behind else -target_size.x
			target.offset_transform_position.x = transform_amount_hide
		Enums.Side.TOP:
			transform_property = "offset_transform_position:y"
			transform_amount_show = -target_size.y if default_hidden_behind else 0.0
			transform_amount_hide = 0.0 if default_hidden_behind else target_size.y
			target.offset_transform_position.y = transform_amount_hide
		Enums.Side.BOTTOM:
			transform_property = "offset_transform_position:y"
			transform_amount_show = target_size.y if default_hidden_behind else 0.0
			transform_amount_hide = 0.0 if default_hidden_behind else -target_size.y
			target.offset_transform_position.y = transform_amount_hide
	transform_amount_show += offset_show
	transform_amount_hide += offset_hide


func toggle(toggle_on: bool) -> void:
	if toggle_on and !on:
		show_control()
	elif !toggle_on and on:
		hide_control()
	on = toggle_on


func show_control() -> void:
	if (!move_target and !hide_target):
		return
	if tween and tween.is_running():
		tween.stop()
	target.visible = true
	tween = create_tween().set_ease(ease_type).set_trans(transition_type)
	if simultaneous_move_and_hide:
		tween.set_parallel()
	if hide_target:
		tween.tween_property(target, "modulate:a", 1.0, 0.0 if immediate_show else animation_time)
	if move_target:
		tween.tween_property(target, transform_property, transform_amount_show, 0.0 if immediate_show else animation_time)


func hide_control() -> void:
	if (!move_target and !hide_target):
		return
	if tween and tween.is_running():
		tween.stop()
	tween = create_tween().set_ease(ease_type).set_trans(transition_type)
	if simultaneous_move_and_hide:
		tween.set_parallel()
	if move_target:
		tween.tween_property(target, transform_property, transform_amount_hide, 0.0 if immediate_hide else animation_time)
	if hide_target:
		tween.tween_property(target, "modulate:a", 0.0, 0.0 if immediate_hide else animation_time)
		if change_visibility_value:
			tween.set_parallel(false)
			tween.tween_property(target, "visible", false, 0.0)
