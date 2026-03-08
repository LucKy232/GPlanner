class_name ClipboardImage extends TextureRect
## Movable, resizable TextureRect, doesn't interacting with drawings

@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D
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
	position = Vector2(dict["pos_x"], dict["pos_y"])
	scale = Vector2(dict["scale"], dict["scale"])
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


func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MouseButton.MOUSE_BUTTON_LEFT and event.is_pressed():
		mouse_pressed.emit()


func _on_visibility_changed() -> void:
	save = visible
