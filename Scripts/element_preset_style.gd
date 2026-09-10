class_name ElementPresetStyle

var id: String = "unassigned_id"
var name: String = ""
## BACKGROUND
var background_color: Color = Color.LIGHT_SEA_GREEN
var border_color: Color = Color.BLACK
var border_size: int = 1
var border_blend: bool = false
## TEXT EDIT
var font_size: int = 16
var font_color: Color = Color.WHITE
var outline_color: Color = Color.BLACK
var outline_size: int = 0
var line_spacing: int = 0
## TITLE TEXT EDIT
var title_font_size: int = 20
var title_font_color: Color = Color.WHITE 
var title_outline_color: Color = Color.BLACK
var title_outline_size: int = 0
var title_line_spacing: int = 0
## OBJECT LIST ENTRY - Connect by signal to list since they don't control a single Theme?
var entry_separation: int = 4
var list_div_enabled: bool = false
var list_div_color: Color = Color.DARK_GRAY
## THEMES (targets to get changed by the values)
var background_panel_style_box: StyleBoxFlat
var text_edit_theme: Theme
var title_text_edit_theme: Theme
var type: Type


enum Type {
	TEXT_ELEMENT,
	OBJECT_LIST,
}

enum Category {
	BACKGROUND,
	TEXT_EDIT,
	TITLE_TEXT_EDIT,
	OBJECT_LIST_ENTRY,
}


func _init(string_id: String) -> void:
	id = string_id


func set_default_values(category: Category) -> void:
	match category:
		Category.BACKGROUND:
			if !background_panel_style_box:
				return
			set_border_size(border_size)
			set_border_blend(border_blend)
			background_panel_style_box.bg_color = background_color
			background_panel_style_box.border_color = border_color
		Category.TEXT_EDIT:
			if !text_edit_theme:
				return
			text_edit_theme.set_font_size("font_size", "TextEdit", font_size)
			text_edit_theme.set_constant("outline_size", "TextEdit", outline_size)
			text_edit_theme.set_color("font_color", "TextEdit", font_color)
			text_edit_theme.set_color("font_outline_color", "TextEdit", outline_color)
			text_edit_theme.set_constant("line_spacing", "TextEdit", line_spacing)
		Category.TITLE_TEXT_EDIT:
			if !title_text_edit_theme:
				return
			title_text_edit_theme.set_font_size("font_size", "TextEdit", title_font_size)
			title_text_edit_theme.set_constant("outline_size", "TextEdit", title_outline_size)
			title_text_edit_theme.set_color("font_color", "TextEdit", title_font_color)
			title_text_edit_theme.set_color("font_outline_color", "TextEdit", title_outline_color)
			title_text_edit_theme.set_constant("line_spacing", "TextEdit", title_line_spacing)


func set_font_size(size: int) -> void:
	font_size = size
	text_edit_theme.set_font_size("font_size", "TextEdit", size)


func set_font_color(color: Color) -> void:
	font_color = color
	text_edit_theme.set_color("font_color", "TextEdit", color)


func set_outline_size(size: int) -> void:
	outline_size = size
	text_edit_theme.set_constant("outline_size", "TextEdit", size)


func set_outline_color(color: Color) -> void:
	outline_color = color
	text_edit_theme.set_color("font_outline_color", "TextEdit", color)


func set_line_spacing(value: int) -> void:
	line_spacing = value
	text_edit_theme.set_constant("line_spacing", "TextEdit", value)


func set_title_font_size(size: int) -> void:
	title_font_size = size
	title_text_edit_theme.set_font_size("font_size", "TextEdit", size)


func set_title_font_color(color: Color) -> void:
	title_font_color = color
	title_text_edit_theme.set_color("font_color", "TextEdit", color)


func set_title_outline_size(size: int) -> void:
	title_outline_size = size
	title_text_edit_theme.set_constant("outline_size", "TextEdit", size)


func set_title_outline_color(color: Color) -> void:
	title_outline_color = color
	title_text_edit_theme.set_color("font_outline_color", "TextEdit", color)


func set_title_line_spacing(value: int) -> void:
	title_line_spacing = value
	title_text_edit_theme.set_constant("line_spacing", "TextEdit", value)


func set_background_color(color: Color) -> void:
	background_color = color
	background_panel_style_box.bg_color = color


func set_border_color(color: Color) -> void:
	border_color = color
	background_panel_style_box.border_color = color


func set_border_size(size: int) -> void:
	border_size = size
	background_panel_style_box.border_width_top = size
	background_panel_style_box.border_width_bottom = size
	background_panel_style_box.border_width_left = size
	background_panel_style_box.border_width_right = size


func set_border_blend(toggled_on: bool) -> void:
	border_blend = toggled_on
	background_panel_style_box.border_blend = toggled_on


func set_list_entry_separation(value: int) -> void:
	entry_separation = value
	# TODO signal to list to change value, connect signal in list


func set_list_div_toggled(toggled_on: bool) -> void:
	list_div_enabled = toggled_on
	# TODO signal to list to change value, connect signal in list


func set_list_div_color(c: Color) -> void:
	list_div_color = c
	# TODO signal to list to change value, connect signal in list


func set_background_panel_style_box(style_box_flat: StyleBoxFlat, use_theme_values: bool) -> void:
	background_panel_style_box = style_box_flat
	if use_theme_values:
		border_size = background_panel_style_box.border_width_top
		background_color = background_panel_style_box.bg_color
		border_color = background_panel_style_box.border_color
		border_blend = background_panel_style_box.border_blend
	else:
		set_default_values(Category.BACKGROUND)


func set_text_edit_theme(theme: Theme, use_theme_values: bool) -> void:
	text_edit_theme = theme
	if use_theme_values:
		font_size = theme.get_font_size("font_size", "TextEdit")
		outline_size = theme.get_constant("outline_size", "TextEdit")
		font_color = theme.get_color("font_color", "TextEdit")
		outline_color = theme.get_color("font_outline_color", "TextEdit")
		line_spacing = theme.get_constant("line_spacing", "TextEdit")
	else:
		set_default_values(Category.TEXT_EDIT)


func set_title_text_edit_theme(theme: Theme, use_theme_values: bool) -> void:
	title_text_edit_theme = theme
	if use_theme_values:
		title_font_size = theme.get_font_size("font_size", "TextEdit")
		title_outline_size = theme.get_constant("outline_size", "TextEdit")
		title_font_color = theme.get_color("font_color", "TextEdit")
		title_outline_color = theme.get_color("font_outline_color", "TextEdit")
		title_line_spacing = theme.get_constant("line_spacing", "TextEdit")
	else:
		set_default_values(Category.TITLE_TEXT_EDIT)


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
	
	var bgc: Color = Color(dict["background_color.r"],
						dict["background_color.g"],
						dict["background_color.b"],
						dict["background_color.a"])
	var fc: Color = Color(dict["font_color.r"],
						dict["font_color.g"],
						dict["font_color.b"],
						dict["font_color.a"])
	var oc: Color = Color(dict["outline_color.r"],
						dict["outline_color.g"],
						dict["outline_color.b"],
						dict["outline_color.a"])
	var bc: Color = Color(dict["border_color.r"],
						dict["border_color.g"],
						dict["border_color.b"],
						dict["border_color.a"])
	set_background_color(bgc)
	set_border_size(int(dict["border_size"]))
	set_border_color(bc)
	if dict.has("border_blend"):
		set_border_blend(bool(dict["border_blend"]))
	set_font_size(int(dict["font_size"]))
	set_font_color(fc)
	set_outline_size(int(dict["outline_size"]))
	set_outline_color(oc)
	if dict.has("line_spacing"):
		set_line_spacing(dict["line_spacing"])


func to_json() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"background_color.r": background_color.r,
		"background_color.g": background_color.g,
		"background_color.b": background_color.b,
		"background_color.a": background_color.a,
		"border_size": border_size,
		"border_color.r": border_color.r,
		"border_color.g": border_color.g,
		"border_color.b": border_color.b,
		"border_color.a": border_color.a,
		"border_blend": border_blend,
		"font_size": font_size,
		"outline_size": outline_size,
		"font_color.r": font_color.r,
		"font_color.g": font_color.g,
		"font_color.b": font_color.b,
		"font_color.a": font_color.a,
		"outline_color.r": outline_color.r,
		"outline_color.g": outline_color.g,
		"outline_color.b": outline_color.b,
		"outline_color.a": outline_color.a,
		"line_spacing": line_spacing,
	}
