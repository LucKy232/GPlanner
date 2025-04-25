class_name ElementPreset

var id: int = -1	# Not used
var font_size: int = 16
var outline_size: int = 2
var border_size: int = 2
var background_color: Color = Color.DEEP_SKY_BLUE
var font_color: Color = Color.WHITE
var outline_color: Color = Color.BLACK
var border_color: Color = Color.BLACK
var background_panel_style_box: StyleBoxFlat
var line_edit_theme: Theme


func _init(idx: int) -> void:
	id = idx


func set_font_size(size: int) -> void:
	font_size = size
	line_edit_theme.set_font_size("font_size", "LineEdit", size)


func set_outline_size(size: int) -> void:
	outline_size = size
	line_edit_theme.set_constant("outline_size", "LineEdit", size)


func set_background_color(color: Color) -> void:
	background_color = color
	background_panel_style_box.bg_color = color


func set_font_color(color: Color) -> void:
	font_color = color
	line_edit_theme.set_color("font_color", "LineEdit", color)


func set_outline_color(color: Color) -> void:
	outline_color = color
	line_edit_theme.set_color("font_outline_color", "LineEdit", color)


func set_border_color(color: Color) -> void:
	border_color = color
	background_panel_style_box.border_color = color


func set_border_size(size: int) -> void:
	border_size = size
	background_panel_style_box.border_width_top = size
	background_panel_style_box.border_width_bottom = size
	background_panel_style_box.border_width_left = size
	background_panel_style_box.border_width_right = size


func to_json() -> Dictionary:
	return {
		"font_size": font_size,
		"outline_size": outline_size,
		"border_size": border_size,
		"background_color.r": background_color.r,
		"background_color.g": background_color.g,
		"background_color.b": background_color.b,
		"background_color.a": background_color.a,
		"font_color.r": font_color.r,
		"font_color.g": font_color.g,
		"font_color.b": font_color.b,
		"font_color.a": font_color.a,
		"outline_color.r": outline_color.r,
		"outline_color.g": outline_color.g,
		"outline_color.b": outline_color.b,
		"outline_color.a": outline_color.a,
		"border_color.r": border_color.r,
		"border_color.g": border_color.g,
		"border_color.b": border_color.b,
		"border_color.a": border_color.a,
	}
