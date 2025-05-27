extends TextureRect
class_name TempDrawingRegion

var image: Image
var width: int
var height: int
## To keep this capped at 100% size under >100% zoom, modify the coordinates at which to draw to when canvas has a different zoom level
var capped_zoom: float = 1.0
var type: int = 0


func init_image(img_width: int, img_height: int) -> void:
	width = img_width
	height = img_height
	image = Image.create_empty(img_width, img_height, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)


func draw_pencil_1px(p1: Vector2, p2: Vector2) -> void:
	#print("Drawing (%f %f) (%f %f)" % [p1.x, p1.y, p2.x, p2.y])
	if width != size.x or height != size.y:
		init_image(int(size.x), int(size.y))
	#print("Draw p1 %f %f p2 %f %f" % [p1.x, p1.y, p2.x, p2.y])
	for pixel in Geometry2D.bresenham_line(p1 * capped_zoom, p2 * capped_zoom):
			if (pixel.x > 0 and pixel.x < width) and (pixel.y > 0 and pixel.y < height):
				image.set_pixel(pixel.x, pixel.y, Color.WHITE)
	texture = ImageTexture.create_from_image(image)


func make_mask() -> void:
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


# TODO gets saved 1px to the left / top-left / top
# TODO doesn't draw 1px at the edge of the DrawingRegion
# Splitting the image that is currently the size of the screen, into 1024x1024 chunks aligned with 
func get_drawing_region_chunks() -> Dictionary[Vector4i, Image]:
	var dict: Dictionary[Vector4i, Image] = {}
	var region_x_start: int = floori(position.x / 1024.0)
	var region_x_end: int = floori((position.x + width * scale.x) / 1024.0) + 1
	var region_y_start: int = floori(position.y / 1024.0)
	var region_y_end: int = floori((position.y + height * scale.y) / 1024.0) + 1
	var full_region: Vector2i = Vector2i(int(1024.0 / scale.x), int(1024.0 / scale.y))
	#print("FULL REGION X %d Y %d SCALE X %f Y %f" % [full_region.x, full_region.y, scale.x, scale.y])
	#print("Region pixels: %d %d start: %d %d" % [full_x_region, full_y_region, first_x_region, first_y_region])
	for i in range(region_x_start, region_x_end):
		for j in range(region_y_start, region_y_end):
			var start_x: int = clampi(full_region.x * i - int(position.x / scale.x), 0, width - 1)
			var end_x: int = clampi(full_region.x * (i + 1) - int(position.x / scale.x) - 1, 0, width - 1)
			var start_y: int = clampi(full_region.y * j - int(position.y / scale.y), 0, height - 1)
			var end_y: int = clampi(full_region.y * (j + 1) - int(position.y / scale.y) - 1, 0, height - 1)
			var size_x: int = end_x - start_x
			var size_y: int = end_y - start_y
			var occupied_percent: Vector2 = Vector2(float(size_x) / float(full_region.x), float(size_y) / float(full_region.y))
			#print("REGION (%02d %02d) IMG START X: %d END X: %d START Y: %d END Y: %d, SIZE X: %d SIZE Y: %d, OCCUPIED: %f %f, POSITION: %f %f" % [i, j, start_x, end_x, start_y, end_y, size_x, size_y, occupied_percent.x, occupied_percent.y, position.x, position.y])
			var reg_position: Vector2i = Vector2i(start_x, start_y)
			var reg_size: Vector2i = Vector2i(size_x, size_y)
			if size_x != 0 and size_y != 0:
				var img: Image = image.get_region(Rect2i(reg_position, reg_size))
				if !img.is_invisible():
					if scale != Vector2(1.0, 1.0):
						img.resize(int(1024.0 * occupied_percent.x), int(1024.0 * occupied_percent.y), Image.INTERPOLATE_NEAREST)
					var destination_x: int = int(position.x) % 1024 if i == region_x_start else 0
					var destination_y: int = int(position.y) % 1024 if j == region_y_start else 0
					var key: Vector4i = Vector4i(i, j, destination_x, destination_y)
					#print("REGION X START %d END %d REGION Y START %d END %d DESTINATION %d %d" % [region_x_start, region_x_end, region_y_start, region_y_end, destination_x, destination_y])
					dict[key] = img
				#else:
					#print("INVISIBLE")
	return dict


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
