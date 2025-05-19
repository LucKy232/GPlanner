extends TextureRect
class_name DrawingRegion

var IMG_HEIGHT: int = 1024
var IMG_WIDTH: int = 1024
var offset: Vector2i = Vector2i(-1, -1)
var image: Image
var path: String

func _init() -> void:
	image = Image.create_empty(IMG_WIDTH, IMG_HEIGHT, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)


func blit_at(coords: Vector2i, img: Image) -> void:
	image.blend_rect(img, Rect2i(0, 0, 1024, 1024), Vector2i(0, 0))
	texture = ImageTexture.create_from_image(image)
