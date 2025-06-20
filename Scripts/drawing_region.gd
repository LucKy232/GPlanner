extends TextureRect
class_name DrawingRegion

var image: Image
var has_changes: bool = false		# Used to check which images to save to disk
var is_invisible: bool = true		# Used to check which image paths to save
#var offset: Vector2i = Vector2i(-1, -1)	# unused
#var file_path: String = ""					# unused
#var IMG_HEIGHT: int = 1024					# unused
#var IMG_WIDTH: int = 1024					# unused


func _init() -> void:
	pass
	#image = Image.create_empty(IMG_WIDTH, IMG_HEIGHT, false, Image.FORMAT_RGBA8)
	#texture = ImageTexture.create_from_image(image)


func update_from_image(img: Image, changes: bool = true) -> void:
	set_has_changes(changes, "Update from image")
	texture = ImageTexture.create_from_image(img)
	#img = Image.new()
	#image = img
	#image = Image.new()


func update_from_texture(txtr: Texture2D, changes: bool = true) -> void:
	set_has_changes(changes, "Update from texture")
	texture = txtr
	#image = txtr.get_image()
	#image = Image.new()


func prepare_image_to_save() -> bool:
	image = texture.get_image()
	if !image.is_invisible():
		is_invisible = false
	if has_changes and !image.is_invisible():
		return true
	return false


# Remove the image from RAM
func free_image() -> void:
	image = Image.new()


func set_has_changes(changes: bool, _reason: String = "") -> void:
	has_changes = changes
	#print("Drawing region has changes: %s   Reason: %s" % [str(has_changes), _reason])


func save_image(path: String) -> void:
	image.save_png(path)
	set_has_changes(false, "Saved to disk")
