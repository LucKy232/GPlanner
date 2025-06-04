extends TextureRect
class_name TempDrawingRegion

var image: Image
var width: int
var height: int
## To keep this capped at 100% size under >100% zoom, modify the coordinates at which to draw to when canvas has a different zoom level
var capped_zoom: float = 1.0
var type: int = 0
var is_mask: bool = false


func init_image(img_width: int, img_height: int) -> void:
	width = img_width
	height = img_height
	image = Image.create_empty(img_width, img_height, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)


func draw_pencil_1px(p1: Vector2, p2: Vector2, c: Color) -> void:
	#print("Drawing (%f %f) (%f %f)" % [p1.x, p1.y, p2.x, p2.y])
	if width != size.x or height != size.y:
		init_image(int(size.x), int(size.y))
	#print("Draw p1 %f %f p2 %f %f" % [p1.x, p1.y, p2.x, p2.y])
	for pixel in Geometry2D.bresenham_line(p1 * capped_zoom, p2 * capped_zoom):
			if (pixel.x > 0 and pixel.x < width) and (pixel.y > 0 and pixel.y < height):
				image.set_pixel(pixel.x, pixel.y, c)
	texture = ImageTexture.create_from_image(image)


func make_mask() -> void:
	is_mask = true
	image.fill(Color.WHITE)


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


func mask_eraser_pencil_1px(p1: Vector2, p2: Vector2) -> void:
	if width != size.x or height != size.y:
		init_image(int(size.x), int(size.y))
	for pixel in Geometry2D.bresenham_line(p1 * capped_zoom, p2 * capped_zoom):
			if (pixel.x > 0 and pixel.x < width) and (pixel.y > 0 and pixel.y < height):
				image.set_pixel(pixel.x, pixel.y, Color.TRANSPARENT)
	texture = ImageTexture.create_from_image(image)


func get_drawing_reions_array() -> Array[Vector2i]:
	var arr: Array[Vector2i] = []
	var img_used_space: Rect2i = image.get_used_rect()
	var img_start: Vector2 = position + Vector2(float(img_used_space.position.x), float(img_used_space.position.y)) * scale
	var img_end: Vector2 = position + Vector2(img_used_space.end.x, img_used_space.end.y) * scale
	#print("Occupied img: ", img_used_space.position, img_used_space.end, img_used_space.size)
	#print("Occupied img * scale: ", Vector2(float(img_used_space.position.x), float(img_used_space.position.y)) * scale, Vector2(img_used_space.end.x, img_used_space.end.y) * scale, Vector2(img_used_space.size.x, img_used_space.size.y) * scale)
	var region_x_start: int = floori(img_start.x / 1024.0)
	var region_x_end: int = floori(img_end.x / 1024.0) + 1
	var region_y_start: int = floori(img_start.y / 1024.0)
	var region_y_end: int = floori(img_end.y / 1024.0) + 1
	for i in range(region_x_start, region_x_end):
		for j in range(region_y_start, region_y_end):
			arr.append(Vector2i(i, j))
	#print("Temp regions: ", position, scale, size, arr)
	return arr
