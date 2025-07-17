extends TextureRect
class_name TempDrawingAction

var image: Image
var width: int
var height: int
## To keep this capped at 100% size under >100% zoom, modify the coordinates at which to draw to when canvas has a different zoom level
var capped_zoom: float = 1.0
var type: int = -1
var is_mask: bool = false
var is_finished: bool = false
var used_rect: Rect2i
var data_usage_kb: float = 0.0
var occupied_regions: Array[Vector2i] = []


func init_image(img_width: int, img_height: int) -> void:
	width = img_width
	height = img_height
	image = Image.create_empty(img_width, img_height, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)


func draw_brush_line(p1: Vector2, p2: Vector2, pressure: float) -> void:
	material.set_shader_parameter("scale", scale.x)
	material.set_shader_parameter("screen_size", size / 1024.0)
	material.set_shader_parameter("pressure", pressure)
	var p1_gpu: Vector2 = Vector2(p1.x / size.x, p1.y / size.y) * capped_zoom	# Converted to UV
	var p2_gpu: Vector2 = Vector2(p2.x / size.x, p2.y / size.y) * capped_zoom	# Converted to UV
	material.set_shader_parameter("p1", p1_gpu)
	material.set_shader_parameter("p2", p2_gpu)
	material.set_shader_parameter("can_draw", true)


func draw_pencil_1px(p1: Vector2, p2: Vector2, c: Color) -> void:
	#print("Drawing (%f %f) (%f %f)" % [p1.x, p1.y, p2.x, p2.y])
	if width != size.x or height != size.y:
		init_image(int(size.x), int(size.y))
	#print("Draw p1 %f %f p2 %f %f" % [p1.x, p1.y, p2.x, p2.y])
	for pixel in Geometry2D.bresenham_line(p1 * capped_zoom, p2 * capped_zoom):
		if (pixel.x > 0 and pixel.x < width) and (pixel.y > 0 and pixel.y < height):
			image.set_pixel(pixel.x, pixel.y, c)
	texture = ImageTexture.create_from_image(image)


func eraser_pencil_1px(p1: Vector2, p2: Vector2) -> void:
	#print("Drawing (%f %f) (%f %f)" % [p1.x, p1.y, p2.x, p2.y])
	if width != size.x or height != size.y:
		#print("reinit")
		init_image(int(size.x), int(size.y))
	#print("Draw p1 %f %f p2 %f %f" % [p1.x, p1.y, p2.x, p2.y])
	for pixel in Geometry2D.bresenham_line(p1 * capped_zoom, p2 * capped_zoom):
		if (pixel.x > 0 and pixel.x < width) and (pixel.y > 0 and pixel.y < height):
			image.set_pixel(pixel.x, pixel.y, Color.WHITE)
			#image.set_pixel(pixel.x, pixel.y, Color.TRANSPARENT)
	texture = ImageTexture.create_from_image(image)


func make_mask() -> void:
	is_mask = true
	image.fill(Color.WHITE)


func get_drawing_regions_array() -> Array[Vector2i]:
	var arr: Array[Vector2i] = []
	# used_rect.position might always == Vector2i.ZERO
	var img_start: Vector2 = position + Vector2(float(used_rect.position.x), float(used_rect.position.y)) * scale
	var img_end: Vector2 = position + Vector2(used_rect.end.x, used_rect.end.y) * scale
	
	var region_x_start: int = floori(img_start.x / 1024.0)
	var region_x_end: int = floori(img_end.x / 1024.0) + 1
	var region_y_start: int = floori(img_start.y / 1024.0)
	var region_y_end: int = floori(img_end.y / 1024.0) + 1
	var grid_length: int = int(1024.0 / scale.x)
	var grid_offset := Vector2i(int(position.x / scale.x) % grid_length, int(position.y / scale.y) % grid_length)
	# Divide the image by the scaled 1024x1024 image grid and check if the image region corresponding to the grid cell isn't invisible before adding it to the array
	# Might have precision errors
	for i in range(region_x_start, region_x_end):
		for j in range(region_y_start, region_y_end):
			var reg := Vector2i(i - region_x_start, j - region_y_start)
			var img_reg_start := Vector2i(clampi(grid_length * reg.x - grid_offset.x, 0, int(size.x)), clampi(grid_length * reg.y - grid_offset.y, 0, int(size.y)))
			var img_reg_end := Vector2i(clampi(grid_length * (reg.x + 1) - grid_offset.x, 0, int(size.x)), clampi(grid_length * (reg.y + 1) - grid_offset.y, 0, int(size.y)))
			var img_region := Rect2i(img_reg_start, img_reg_end - img_reg_start)
			if img_region.has_area() and !image.get_region(img_region).is_invisible():
				arr.append(Vector2i(i, j))
	return arr


func set_final_texture(img: Image) -> void:
	image = img
	texture = ImageTexture.create_from_image(img)


# Returns true if image is 0 pixels and needs to be deleted, and false if >0 pixels
func trim_down() -> bool:
	var img_used_space: Rect2i = image.get_used_rect()
	if img_used_space.size.x == 0 and img_used_space.size.y == 0:
		return true
	var trimmed_img: Image = Image.create_empty(img_used_space.size.x, img_used_space.size.y, false, Image.FORMAT_RGBA8)
	trimmed_img.blit_rect(image, img_used_space, Vector2i.ZERO)
	image = trimmed_img
	texture = ImageTexture.create_from_image(image)
	position += Vector2(img_used_space.position.x * scale.x, img_used_space.position.y * scale.y)
	size = img_used_space.size
	used_rect = image.get_used_rect()
	occupied_regions = get_drawing_regions_array()
	data_usage_kb = float(image.get_data_size()) / 1024.0	# Approximate VRAM usage
	image = Image.new()			# Save RAM usage, shouldn't be accessed afterwards
	return false
