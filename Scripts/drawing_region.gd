extends TextureRect
class_name DrawingRegion

var IMG_HEIGHT: int = 1024
var IMG_WIDTH: int = 1024
var image: Image
var has_changes: bool = false		# Used to check which images to save to disk
#var offset: Vector2i = Vector2i(-1, -1)	# unused
#var file_path: String = ""					# unused


func _init() -> void:
	image = Image.create_empty(IMG_WIDTH, IMG_HEIGHT, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)


func update_from_image(img: Image, changes: bool = true) -> void:
	set_has_changes(changes, "Update from image")
	image = img
	texture = ImageTexture.create_from_image(img)


func update_from_texture(txtr: Texture2D, changes: bool = true) -> void:
	set_has_changes(changes, "Update from texture")
	texture = txtr
	image = txtr.get_image()


func set_has_changes(changes: bool, _reason: String = "") -> void:
	has_changes = changes
	#print("Drawing region has changes: %s   Reason: %s" % [str(has_changes), _reason])
