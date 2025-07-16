extends TextureRect
class_name DrawingRegion

var image: Image
var has_changes: bool = false		## Used to check which images to save to disk
var is_invisible: bool = true		## Used to check which image paths to save
var is_loaded: bool = false
var file_path: String = ""			## Set on file load from .json or on save CanvasDrawingGroup:save_all_regions_to_disk()


func update_from_image(img: Image, changes: bool = true) -> void:
	set_has_changes(changes, "Update from image")
	texture = ImageTexture.create_from_image(img)
	is_loaded = true
	if !img.is_invisible():
		is_invisible = false


## unused
func update_from_texture(txtr: Texture2D, changes: bool = true) -> void:
	set_has_changes(changes, "Update from texture")
	texture = txtr
	is_loaded = true


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


func unload() -> void:
	texture = ImageTexture.new()
	image = Image.new()
	is_loaded = false


func load_from_path() -> void:
	image = Image.load_from_file(file_path)


func redraw_existing_image() -> void:
	if !image.is_empty():
		texture = ImageTexture.create_from_image(image)
		is_loaded = true
		if !image.is_invisible():
			is_invisible = false
		image = Image.new()
