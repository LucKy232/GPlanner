extends Control

@onready var sub_viewport: SubViewport = $SubViewportContainer/SubViewport
@onready var camera: Camera2D = $SubViewportContainer/SubViewport/Camera
@onready var highlight_panel: Panel = $HighlightPanel
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var timer: Timer = $Timer

var canvas_size: Vector2 = Vector2(1.0, 1.0)
var window_size: Vector2 = Vector2(1.0, 1.0)
var canvas_scale: float = 1.0
var indicator_size_ratio: float = 1.0		## Panning Indicator size / Canvas size
var window_canvas_size_ratio: Vector2 = Vector2(1.0, 1.0) 	## Window size / Canvas size * scale

#func _ready() -> void:
	#max_hignlight_size = size


func set_world_2d(world: World2D) -> void:
	sub_viewport.world_2d = world


func set_canvas_size(s: Vector2) -> void:
	canvas_size = s
	indicator_size_ratio = size.x / s.x
	camera.zoom = Vector2(indicator_size_ratio, indicator_size_ratio)
	camera.position = s * 0.5


func set_window_size(s: Vector2) -> void:
	window_size = s
	window_canvas_size_ratio = window_size / (canvas_size * canvas_scale)
	highlight_panel.size = size * window_canvas_size_ratio


func move_camera_and_highlight(c_position: Vector2) -> void:
	if !animation_player.is_playing() and modulate.a == 0.0:
		animation_player.play("show")
		
	timer.start()
	camera.position = c_position
	highlight_panel.position = -c_position * indicator_size_ratio / canvas_scale


func update_zoom(c_position: Vector2, c_scale: float) -> void:
	canvas_scale = c_scale
	window_canvas_size_ratio = window_size / (canvas_size * canvas_scale)
	camera.zoom = Vector2(indicator_size_ratio / c_scale, indicator_size_ratio / c_scale)
	camera.position = c_position
	
	highlight_panel.position = -c_position * indicator_size_ratio / c_scale
	highlight_panel.size = size * window_canvas_size_ratio
	#print("Highlight pos X: %f Y: %f   Highlight size X: %f Y: %f   
			#Control size X: %f Y: %f   Window Ratio X: %f Y: %f   
			#Indicator Ratio: %f   Canvas pos X: %f Y: %f   Canvas scale: %f" % 
			#[highlight_panel.position.x, highlight_panel.position.y, highlight_panel.size.x, 
			#highlight_panel.size.y, size.x, size.y, window_canvas_size_ratio.x, 
			#window_canvas_size_ratio.y, indicator_size_ratio, c_position.x, c_position.y, c_scale])


func _on_timer_timeout() -> void:
	if !animation_player.is_playing():
		animation_player.play("hide")
