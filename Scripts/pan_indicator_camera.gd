extends Control
class_name PanIndicatorCamera

@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var camera: Camera2D = $SubViewportContainer/SubViewport/Camera
@onready var highlight_panel: Panel = $HighlightPanel
@onready var hide_timer: Timer = $HideTimer
@onready var tween_show_hide: TweenShowHide = $TweenShowHide

var canvas_size: Vector2 = Vector2(1.0, 1.0)
var window_size: Vector2 = Vector2(1.0, 1.0)
var canvas_scale: float = 1.0
var indicator_size_ratio: float = 1.0		## Panning Indicator size / Canvas size
var window_canvas_size_ratio: Vector2 = Vector2(1.0, 1.0) 	## Window size / Canvas size * scale


func set_world_2d(world: World2D) -> void:
	sub_viewport.world_2d = world


func set_canvas_size(s: Vector2) -> void:
	canvas_size = s
	indicator_size_ratio = size.x / canvas_size.x
	camera.zoom = Vector2(indicator_size_ratio, indicator_size_ratio)
	camera.position = canvas_size * 0.5


func set_window_size(s: Vector2) -> void:
	window_size = s
	window_canvas_size_ratio = window_size / (canvas_size * canvas_scale)
	highlight_panel.set_deferred("size", size * window_canvas_size_ratio)


func move_camera_and_highlight(c_position: Vector2) -> void:
	show_this()
	hide_timer.start()
	camera.position = c_position
	highlight_panel.position = -c_position * indicator_size_ratio / canvas_scale


func update_zoom(c_position: Vector2, c_scale: float) -> void:
	#print("Update zoom: pos %0.3f %0.3f scale %0.3f indicator size ratio: %0.4f" % [c_position.x, c_position.y, c_scale, indicator_size_ratio])
	canvas_scale = c_scale
	window_canvas_size_ratio = window_size / (canvas_size * canvas_scale)
	camera.zoom = Vector2(indicator_size_ratio / c_scale, indicator_size_ratio / c_scale)
	camera.position = c_position
	
	highlight_panel.position = -c_position * indicator_size_ratio / c_scale
	highlight_panel.set_deferred("size", size * window_canvas_size_ratio)
	#print("Highlight pos X: %f Y: %f   Highlight size X: %f Y: %f   
			#Control size X: %f Y: %f   Window Ratio X: %f Y: %f   
			#Indicator Ratio: %f   Canvas pos X: %f Y: %f   Canvas scale: %f" % 
			#[highlight_panel.position.x, highlight_panel.position.y, highlight_panel.size.x, 
			#highlight_panel.size.y, size.x, size.y, window_canvas_size_ratio.x, 
			#window_canvas_size_ratio.y, indicator_size_ratio, c_position.x, c_position.y, c_scale])


func force_update_subviewport() -> void:
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func hide_this() -> void:
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	tween_show_hide.toggle(false)


func show_this() -> void:
	if !tween_show_hide.on:
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	tween_show_hide.toggle(true)


func _on_hide_timer_timeout() -> void:
	hide_this()
