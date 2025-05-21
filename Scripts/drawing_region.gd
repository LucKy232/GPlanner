extends TextureRect
class_name DrawingRegion

var IMG_HEIGHT: int = 1024
var IMG_WIDTH: int = 1024
var offset: Vector2i = Vector2i(-1, -1)
var image: Image
var has_changes: bool = false
#var file_path: String = ""


func _init() -> void:
	image = Image.create_empty(IMG_WIDTH, IMG_HEIGHT, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)


func blit_at(coords: Vector2i, img: Image) -> void:
	has_changes = true
	image.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), coords)
	texture = ImageTexture.create_from_image(image)


func update_texture(img: Image) -> void:
	image = img
	texture = ImageTexture.create_from_image(img)
