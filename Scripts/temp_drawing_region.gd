extends TextureRect
class_name TempDrawingRegion

var image: Image
var width: int
var height: int


func init_image(img_width: int, img_height: int) -> void:
	width = img_width
	height = img_height
	image = Image.create_empty(img_width, img_height, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(image)


func draw_pencil_1px(p1: Vector2, p2: Vector2) -> void:
	if width != size.x or height != size.y:
		init_image(int(size.x), int(size.y))
	#print("Draw p1 %f %f p2 %f %f" % [p1.x, p1.y, p2.x, p2.y])
	for pixel in Geometry2D.bresenham_line(p1, p2):
			if (pixel.x > 0 and pixel.x < width) and (pixel.y > 0 and pixel.y < height):
				image.set_pixel(pixel.x, pixel.y, Color.WHITE)
	texture = ImageTexture.create_from_image(image)


func get_drawing_region_chunks() -> Dictionary[Vector2i, Image]:
	var dict: Dictionary[Vector2i, Image] = {}
	#print(size * scale)
	var start_x: int = floori(position.x / 1024.0)
	var end_x: int = floori((position.x + width * scale.x) / 1024.0) + 1
	var start_y: int = floori(position.y / 1024.0)
	var end_y: int = floori((position.y + height * scale.y) / 1024.0) + 1
	var full_x_region: int = int(1024.0 / scale.x)
	var full_y_region: int = int(1024.0 / scale.y)
	var first_x_region: int = int(position.x) % full_x_region
	var first_y_region: int = int(position.y) % full_y_region
	#print("Region pixels: %d %d start: %d %d" % [full_x_region, full_y_region, first_x_region, first_y_region])
	for i in range(start_x, end_x):
		for j in range(start_y, end_y):
			var region: Vector2i = Vector2i(i, j)
			var reg_position: Vector2i = Vector2i(first_x_region + i * full_x_region, first_y_region + j * full_y_region)
			var reg_size: Vector2i = Vector2i(full_x_region, full_y_region)
			var img: Image = image.get_region(Rect2i(reg_position, reg_size))
			if !img.is_invisible():
				img.resize(1024, 1024, Image.INTERPOLATE_NEAREST)
				dict[region] = img
				#img.save_png("user://test_img x %d y %d.png" % [i,j])
			#print(reg_position, reg_size, img.is_invisible())
	#print("StartX: %f %d EndX: %f %d" % [position.x, floori(position.x / 1024.0), position.x + size.x * scale.x, floori((position.x + size.x * scale.x) / 1024.0) + 1])
	#print("StartY: %f %d EndY: %f %d" % [position.y, floori(position.y / 1024.0), position.y + size.y * scale.y, floori((position.y + size.y * scale.y) / 1024.0) + 1])
	return dict


#func resize_image(width: float, height: float) -> void:
	#image.resize()
