class_name ClipboardImage extends Control
## Movable, resizable TextureRect, doesn't interacting with drawings

@export var IMAGE_FRONT_TEXTURE: CompressedTexture2D
@export var DRAWING_FRONT_TEXTURE: CompressedTexture2D
@export var RESIZE_RECT: Vector2 = Vector2(32.0, 32.0)
@onready var texture_rect: TextureRect = $TextureRect
@onready var hide_button: Button = %HideButton
@onready var order_button: Button = %OrderButton
@onready var main_shape: CollisionShape2D = %MainShape
@onready var resize_shape: CollisionShape2D = %ResizeShape
@onready var margin_container: MarginContainer = $MarginContainer
var serialized_data: String = ""	## Set on file load from .json
var cached_position: Vector2 = Vector2.ZERO 	## To be read by a different thread
var cached_scale: float = 1.0					## To be read by a different thread
var image: Image
var save: bool = true		## Used to check which images to save to disk
var resize_area_active: bool = false
var is_resizing: bool = false
var is_loaded: bool = false

signal mouse_pressed


func update_from_image(img: Image) -> void:
	var img_size: Vector2i = img.get_size()
	cached_scale = 1.0
	texture_rect.texture = ImageTexture.create_from_image(img)
	texture_rect.size = img.get_size()
	main_shape.shape = main_shape.shape.duplicate()
	main_shape.shape.size = img_size
	main_shape.position = img_size * 0.5
	resize_shape.shape = resize_shape.shape.duplicate()
	resize_shape.shape.size = RESIZE_RECT
	resize_shape.position = Vector2(img_size) - RESIZE_RECT * 0.5
	is_loaded = true


func load_from_dict(dict: Dictionary) -> void:
	serialized_data = dict["serialized_data"]
	var pos: Vector2 = Vector2(dict["pos_x"], dict["pos_y"])
	var scl: float = dict["scale"]
	position = pos
	texture_rect.scale = Vector2(scl, scl)
	cached_position = pos
	cached_scale = scl
	load_image_from_data()
	set_texture_rect_scale(cached_scale)


func load_image_from_data() -> void:
	var raw: PackedByteArray = Marshalls.base64_to_raw(serialized_data)
	if raw.size() > 0:
		free_image()
		image.load_png_from_buffer(raw)
		call_thread_safe("redraw_texture_from_image")


func redraw_texture_from_image() -> void:
	texture_rect.texture = ImageTexture.create_from_image(image)
	texture_rect.size = image.get_size()
	main_shape.shape = main_shape.shape.duplicate()
	resize_shape.shape = resize_shape.shape.duplicate()
	resize_shape.shape.size = RESIZE_RECT
	is_loaded = true
	free_image()


#func redraw_texture_from_image() -> void:
	#


func save_image(path: String) -> void:
	if image and !image.is_empty():
		image.save_png(path)


# Remove the image from RAM
func free_image() -> void:
	image = Image.new()


# Remove the image from VRAM
func free_texture() -> void:
	texture_rect.texture = ImageTexture.new()
	is_loaded = false


# Only call if image is prepared
func get_serialized_data_from_texture() -> String:
	image = texture_rect.texture.get_image()
	var imgdata: PackedByteArray = image.save_png_to_buffer()
	serialized_data = Marshalls.raw_to_base64(imgdata)
	free_image()
	return serialized_data


#func update_serialized_image_data() -> void:
	#var imgdata: PackedByteArray = image.save_png_to_buffer()
	#serialized_data = Marshalls.raw_to_base64(imgdata)


func set_texture_rect_scale(scl: float) -> void:
	texture_rect.scale = Vector2(scl, scl)
	size = texture_rect.size * texture_rect.scale
	cached_scale = scl
	main_shape.shape.size = size
	main_shape.position = size * 0.5
	resize_shape.position = size - RESIZE_RECT * 0.5
	resized.emit()


func to_json() -> Dictionary:
	var dict: Dictionary
	if serialized_data == "":
		dict["serialized_data"] = get_serialized_data_from_texture()
	else:
		dict["serialized_data"] = serialized_data
	dict["pos_x"] = cached_position.x
	dict["pos_y"] = cached_position.y
	dict["scale"] = cached_scale
	return dict


func unload() -> void:
	texture_rect.texture = ImageTexture.new()
	image = Image.new()
	is_loaded = false


func _on_hide_button_pressed() -> void:
	visible = false


func _on_visibility_changed() -> void:
	save = visible


func _on_order_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		z_index = -2
		order_button.icon = IMAGE_FRONT_TEXTURE
		order_button.tooltip_text = "Image in front"
	else:
		z_index = -4
		order_button.icon = DRAWING_FRONT_TEXTURE
		order_button.tooltip_text = "Drawings in front"


func _on_area_2d_move_mouse_entered() -> void:
	margin_container.visible = true


func _on_area_2d_move_mouse_exited() -> void:
	margin_container.visible = false


func _on_area_2d_resize_mouse_exited() -> void:
	resize_area_active = false


func _on_area_2d_resize_mouse_entered() -> void:
	resize_area_active = true


func _on_area_2d_move_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if resize_area_active:
		return
	mouse_default_cursor_shape = Control.CURSOR_HELP
	if event is InputEventMouseButton and event.button_index == MouseButton.MOUSE_BUTTON_LEFT and event.is_pressed():
		mouse_pressed.emit()


func _on_area_2d_resize_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		is_resizing = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
		is_resizing = false
	elif event is InputEventMouseMotion and is_resizing:
		var new_scale: Vector2 = texture_rect.scale * (texture_rect.size / (texture_rect.size - event.relative))
		var min_axis: float = min(new_scale.x, new_scale.y)
		set_texture_rect_scale(min_axis)
