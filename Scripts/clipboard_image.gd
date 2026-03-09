class_name ClipboardImage extends TextureRect
## Movable, resizable TextureRect, doesn't interacting with drawings

@export var IMAGE_FRONT_TEXTURE: CompressedTexture2D
@export var DRAWING_FRONT_TEXTURE: CompressedTexture2D
@onready var hide_button: Button = %HideButton
@onready var order_button: Button = %OrderButton
@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D
@onready var margin_container: MarginContainer = $MarginContainer
var save: bool = false		## Used to check which images to save to disk
var serialized_data: String = ""	## Set on file load from .json
var cached_position: Vector2 = Vector2.ZERO 	## To be read by a different thread
var cached_scale: float = 1.0					## To be read by a different thread
var image: Image

signal mouse_pressed


func update_from_image(img: Image) -> void:
	image = img
	texture = ImageTexture.create_from_image(img)
	collision_shape_2d.shape = collision_shape_2d.shape.duplicate()
	collision_shape_2d.shape.size = img.get_size()
	collision_shape_2d.position = img.get_size() * 0.5


func load_from_dict(dict: Dictionary) -> void:
	serialized_data = dict["serialized_data"]
	var pos: Vector2 = Vector2(dict["pos_x"], dict["pos_y"])
	var scl: float = dict["scale"]
	position = pos
	scale = Vector2(scl, scl)
	cached_position = pos
	cached_scale = scl
	load_from_data()


func load_from_data() -> void:
	var raw: PackedByteArray = Marshalls.base64_to_raw(serialized_data)
	if raw.size() > 0:
		image = Image.new()
		image.load_png_from_buffer(raw)
		texture = ImageTexture.create_from_image(image)
		size = image.get_size()
		collision_shape_2d.shape = collision_shape_2d.shape.duplicate()
		collision_shape_2d.shape.size = image.get_size()
		collision_shape_2d.position = image.get_size() * 0.5


func save_image(path: String) -> void:
	image.save_png(path)


# Remove the image from RAM
func free_image() -> void:
	image = Image.new()


# Remove the image from VRAM
func free_texture() -> void:
	texture = ImageTexture.new()


# Only call if image is prepared
func get_serialized_image_data() -> String:
	var imgdata: PackedByteArray = image.save_png_to_buffer()
	serialized_data = Marshalls.raw_to_base64(imgdata)
	return serialized_data


func update_serialized_image_data() -> void:
	var imgdata: PackedByteArray = image.save_png_to_buffer()
	serialized_data = Marshalls.raw_to_base64(imgdata)


func to_json() -> Dictionary:
	var dict: Dictionary
	if serialized_data == "":
		dict["serialized_data"] = get_serialized_image_data()
	else:
		dict["serialized_data"] = serialized_data
	dict["pos_x"] = cached_position.x
	dict["pos_y"] = cached_position.y
	dict["scale"] = cached_scale
	return dict


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MouseButton.MOUSE_BUTTON_LEFT and event.is_pressed():
		mouse_pressed.emit()


func _on_hide_button_pressed() -> void:
	visible = false


func _on_visibility_changed() -> void:
	save = visible


func _on_area_2d_mouse_exited() -> void:
	margin_container.visible = false


func _on_area_2d_mouse_entered() -> void:
	margin_container.visible = true


func _on_order_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		z_index = -2
		order_button.icon = IMAGE_FRONT_TEXTURE
		order_button.tooltip_text = "Image in front"
	else:
		z_index = -4
		order_button.icon = DRAWING_FRONT_TEXTURE
		order_button.tooltip_text = "Drawings in front"
