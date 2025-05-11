class_name ElementPresetStyle

var id: String = "unassigned_id"
var name: String = ""
var font_size: int = 20
var outline_size: int = 8
var border_size: int = 1
var background_color: Color = Color.DEEP_SKY_BLUE
var font_color: Color = Color.WHITE
var outline_color: Color = Color.BLACK
var border_color: Color = Color.BLACK
var background_panel_style_box: StyleBoxFlat
var line_edit_theme: Theme


func _init(idx: String) -> void:
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


func set_background_panel_style_box(style_box_flat: StyleBoxFlat) -> void:
	background_panel_style_box = style_box_flat
	border_size = background_panel_style_box.border_width_top
	background_color = background_panel_style_box.bg_color
	border_color = background_panel_style_box.border_color


func set_line_edit_theme(theme: Theme) -> void:
	line_edit_theme = theme
	font_size = line_edit_theme.get_font_size("font_size", "LineEdit")
	outline_size = line_edit_theme.get_constant("outline_size", "LineEdit")
	font_color = line_edit_theme.get_color("font_color", "LineEdit")
	outline_color = line_edit_theme.get_color("font_outline_color", "LineEdit")


func rebuild_from_json_dict(dict: Dictionary) -> void:
	var p_id: String
	var p_name = "none"
	if dict.has("ID"):
		p_id = str(dict["ID"])
	elif dict.has("id"):
		p_id = str(dict["id"])
	if dict.has("name"):
		p_name = str(dict["name"])
	id = p_id
	name = p_name
	
	var bgc: Color = Color(dict["background_color.r"], dict["background_color.g"], dict["background_color.b"], dict["background_color.a"])
	var fc: Color = Color(dict["font_color.r"], dict["font_color.g"], dict["font_color.b"], dict["font_color.a"])
	var oc: Color = Color(dict["outline_color.r"], dict["outline_color.g"], dict["outline_color.b"], dict["outline_color.a"])
	var bc: Color = Color(dict["border_color.r"], dict["border_color.g"], dict["border_color.b"], dict["border_color.a"])
	set_background_color(bgc)
	set_font_size(int(dict["font_size"]))
	set_font_color(fc)
	set_outline_size(int(dict["outline_size"]))
	set_outline_color(oc)
	set_border_size(int(dict["border_size"]))
	set_border_color(bc)


func to_json() -> Dictionary:
	return {
		"id": id,
		"name": name,
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
