extends Control

@export var default_background_style_box: StyleBoxFlat
@export var default_line_edit_theme: Theme
@onready var preset_options: OptionButton = $MarginContainer/VBoxContainer/PresetHBox/PresetOptions
@onready var background_color_picker_button: ColorPickerButton = $MarginContainer/VBoxContainer/BackgroundColorHBox/BackgroundColorPickerButton
@onready var font_size_spin_box: SpinBox = $MarginContainer/VBoxContainer/FontSizeHBox/FontSizeSpinBox
@onready var font_color_picker_button: ColorPickerButton = $MarginContainer/VBoxContainer/FontColorHBox/FontColorPickerButton
@onready var font_outline_spin_box: SpinBox = $MarginContainer/VBoxContainer/FontOutlineHBox/FontOutlineSpinBox
@onready var font_outline_color_picker_button: ColorPickerButton = $MarginContainer/VBoxContainer/OutlineColorHBox/FontOutlineColorPickerButton
@onready var border_size_spin_box: SpinBox = $MarginContainer/VBoxContainer/BorderSizeHBox/BorderSizeSpinBox
@onready var border_color_picker_button: ColorPickerButton = $MarginContainer/VBoxContainer/BorderColorHBox/BorderColorPickerButton

var presets: Dictionary[int, ElementPreset]
var none_preset: ElementPreset = ElementPreset.new(0)
var max_preset_id: int = 1

signal preset_changed

func _ready() -> void:
	none_preset.background_panel_style_box = default_background_style_box.duplicate()
	none_preset.line_edit_theme = default_line_edit_theme.duplicate()
	if preset_options.selected == 0:
		background_color_picker_button.color = none_preset.background_color
		font_size_spin_box.value = none_preset.font_size
		font_color_picker_button.color = none_preset.font_color
		font_outline_spin_box.value = none_preset.outline_size
		font_outline_color_picker_button.color = none_preset.outline_color
		border_size_spin_box.value = none_preset.border_size
		border_color_picker_button.color = none_preset.border_color


func _on_add_preset_pressed() -> void:
	preset_options.add_item("%d" % max_preset_id, max_preset_id)
	var new_preset: ElementPreset = ElementPreset.new(max_preset_id)
	new_preset.background_panel_style_box = default_background_style_box.duplicate()
	new_preset.line_edit_theme = default_line_edit_theme.duplicate()
	presets[max_preset_id] = new_preset
	preset_changed.emit()
	max_preset_id += 1


func _on_remove_preset_pressed() -> void:
	var selected_id: int = preset_options.selected
	if selected_id > 0:
		check_key_equivalence()
		preset_options.remove_item(selected_id)
		rewind_option_button(selected_id)
		rewind_dict(selected_id+1)
		preset_options.select(0)
		#check_key_equivalence()


func rebuild_options_and_dictionary(dict: Dictionary) -> Dictionary[int, ElementPreset]:
	for key in dict:
		_on_add_preset_pressed()
		var id = int(key)
		
		var bgc: Color = Color(dict[key]["background_color.r"], dict[key]["background_color.g"], dict[key]["background_color.b"], dict[key]["background_color.a"])
		var fc: Color = Color(dict[key]["font_color.r"], dict[key]["font_color.g"], dict[key]["font_color.b"], dict[key]["font_color.a"])
		var oc: Color = Color(dict[key]["outline_color.r"], dict[key]["outline_color.g"], dict[key]["outline_color.b"], dict[key]["outline_color.a"])
		var bc: Color = Color(dict[key]["border_color.r"], dict[key]["border_color.g"], dict[key]["border_color.b"], dict[key]["border_color.a"])
		presets[id].set_background_color(bgc)
		presets[id].set_font_size(int(dict[key]["font_size"]))
		presets[id].set_font_color(fc)
		presets[id].set_outline_size(int(dict[key]["outline_size"]))
		presets[id].set_outline_color(oc)
		presets[id].set_border_size(int(dict[key]["border_size"]))
		presets[id].set_border_color(bc)
	return presets


# We need preset_options.selected to == preset_options.get_selected_id() == the same presets key as before
func rewind_option_button(index: int) -> void:
	while index < preset_options.item_count:
		preset_options.set_item_id(index, index)
		preset_options.select(index)
		index += 1


func rewind_dict(index: int) -> void:
	var last_key: int = 0
	for key in presets:
		if key >= index:
			presets[key - 1] = presets[key]
			last_key = key
	presets.erase(last_key)


func check_key_equivalence() -> void:
	print("\nCheck equivalence: ")
	var i = 1
	while i < preset_options.item_count:
		preset_options.select(i)
		print("Selected: %d Selected ID: %d Dictionary has ID as key: %s Preset ID: %d" % [preset_options.selected, preset_options.get_selected_id(), presets.has(i), presets[i].id if presets.has(i) else -1])
		i += 1


func get_selected_preset() -> ElementPreset:
	if preset_options.selected > 0:
		return presets[preset_options.selected]
	elif preset_options.selected == 0:
		return none_preset
	else:
		return ElementPreset.new(-1)


# TODO Integrate into canvas.gd and main.gd
func _on_preset_options_item_selected(index: int) -> void:
	if index == 0:
		# TODO if element is selected, copy its style attributes, otherwise go back to none_preset
		# TODO main.gd tells this if element is selected
		background_color_picker_button.color = none_preset.background_color
		font_size_spin_box.value = none_preset.font_size
		font_color_picker_button.color = none_preset.font_color
		font_outline_spin_box.value = none_preset.outline_size
		font_outline_color_picker_button.color = none_preset.outline_color
		border_size_spin_box.value = none_preset.border_size
		border_color_picker_button.color = none_preset.border_color
	elif index > 0:
		# TODO signal to main.gd that preset style changed
		# TODO set selected element style to equal selected preset in main.gd
		# Set individual settings to selected preset settings
		background_color_picker_button.color = presets[index].background_color
		font_size_spin_box.value = presets[index].font_size
		font_color_picker_button.color = presets[index].font_color
		font_outline_spin_box.value = presets[index].outline_size
		font_outline_color_picker_button.color = presets[index].outline_color
		border_size_spin_box.value = presets[index].border_size
		border_color_picker_button.color = presets[index].border_color
		preset_changed.emit()


func _on_background_color_picker_button_color_changed(color: Color) -> void:
	if preset_options.selected == 0:
		none_preset.set_background_color(color)
	else:
		presets[preset_options.selected].set_background_color(color)
	preset_changed.emit()


func _on_font_size_spin_box_value_changed(value: float) -> void:
	if preset_options.selected == 0:
		none_preset.set_font_size(int(value))
	else:
		presets[preset_options.selected].set_font_size(int(value))
	preset_changed.emit()


func _on_font_color_picker_button_color_changed(color: Color) -> void:
	if preset_options.selected == 0:
		none_preset.set_font_color(color)
	else:
		presets[preset_options.selected].set_font_color(color)
	preset_changed.emit()


func _on_font_outline_spin_box_value_changed(value: float) -> void:
	if preset_options.selected == 0:
		none_preset.set_outline_size(int(value))
	else:
		presets[preset_options.selected].set_outline_size(int(value))
	preset_changed.emit()


func _on_font_outline_color_picker_button_color_changed(color: Color) -> void:
	if preset_options.selected == 0:
		none_preset.set_outline_color(color)
	else:
		presets[preset_options.selected].set_outline_color(color)
	preset_changed.emit()


func _on_border_size_spin_box_value_changed(value: float) -> void:
	if preset_options.selected == 0:
		none_preset.set_border_size(int(value))
	else:
		presets[preset_options.selected].set_border_size(int(value))
	preset_changed.emit()


func _on_border_color_picker_button_color_changed(color: Color) -> void:
	if preset_options.selected == 0:
		none_preset.set_border_color(color)
	else:
		presets[preset_options.selected].set_border_color(color)
	preset_changed.emit()
