extends Control
class_name ElementSettings

@export var default_background_style_box: StyleBoxFlat
@export var default_line_edit_theme: Theme
@onready var preset_options: OptionButton = $VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/PresetHBox/PresetOptions
@onready var background_color_picker_button: ColorPickerButton = $VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/BackgroundColorHBox/BackgroundColorPickerButton
@onready var font_size_spin_box: SpinBox = $VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/FontSizeHBox/FontSizeSpinBox
@onready var font_color_picker_button: ColorPickerButton = $VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/FontColorHBox/FontColorPickerButton
@onready var font_outline_spin_box: SpinBox = $VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/FontOutlineHBox/FontOutlineSpinBox
@onready var font_outline_color_picker_button: ColorPickerButton = $VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/OutlineColorHBox/FontOutlineColorPickerButton
@onready var border_size_spin_box: SpinBox = $VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/BorderSizeHBox/BorderSizeSpinBox
@onready var border_color_picker_button: ColorPickerButton = $VBoxContainer/SettingsPanel/MarginContainer/VBoxContainer/BorderColorHBox/BorderColorPickerButton
@onready var settings_panel: Panel = $VBoxContainer/SettingsPanel
@onready var name_insert: LineEdit = $NameInsert
@onready var style_buttons: MarginContainer = $VBoxContainer/StyleButtons
@onready var current_preset_label: Label = $VBoxContainer/CurrentPresetLabel


var presets: Dictionary[int, ElementPresetStyle]	## KEY: preset_options selector ID (not preset ID like in canvas.gd)
var none_preset: ElementPresetStyle
var max_option_id: int = 1
var is_user_input: bool = true

signal preset_added
signal preset_changed
signal preset_color_changed
signal preset_removed
signal preset_selected
signal is_editing_text
signal stopped_editing_text


func _ready() -> void:
	style_buttons.preset_style_button_pressed.connect(change_preset)
	style_buttons.add_button("0", "No Preset")
	reset_none_preset()
	if preset_options.selected == 0:
		background_color_picker_button.color = none_preset.background_color
		font_size_spin_box.value = none_preset.font_size
		font_color_picker_button.color = none_preset.font_color
		font_outline_spin_box.value = none_preset.outline_size
		font_outline_color_picker_button.color = none_preset.outline_color
		border_size_spin_box.value = none_preset.border_size
		border_color_picker_button.color = none_preset.border_color


func toggle_visible(toggled_on: bool):
	settings_panel.visible = toggled_on
	#if toggled_on:
		#settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	#else:
		#settings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_panel_visible() -> bool:
	return settings_panel.visible


func add_preset(p_name: String) -> void:
	var selection_id: int = preset_options.item_count
	preset_options.add_item(p_name)
	style_buttons.add_button(str(selection_id), p_name)
	presets[selection_id] = get_new_preset()
	presets[selection_id].name = p_name
	change_preset(selection_id)
	max_option_id += 1
	style_buttons.set_button_theme(selection_id, presets[selection_id])
	preset_added.emit()


func remove_preset(idx: int) -> void:
	if idx > 0:
		style_buttons.remove_button(idx)
		var removed_id: String = presets[idx].id
		preset_options.remove_item(idx)
		rewind_option_button(idx)
		rewind_dict(idx+1)
		change_preset(0)
		preset_removed.emit(removed_id)
		#check_key_equivalence()


func change_preset(idx: int) -> void:
	preset_options.select(idx)
	_on_preset_options_item_selected(idx)
	style_buttons.focus_button(idx)


func get_new_preset() -> ElementPresetStyle:
	var new_preset: ElementPresetStyle = ElementPresetStyle.new("%s %d" % [Time.get_datetime_string_from_system(), Time.get_ticks_msec()])
	new_preset.background_panel_style_box = default_background_style_box.duplicate()
	new_preset.line_edit_theme = default_line_edit_theme.duplicate()
	return new_preset


func erase_everything() -> void:
	style_buttons.erase_everything()
	presets.clear()
	max_option_id = 1
	reset_none_preset()
	while preset_options.item_count > 1:
		preset_options.remove_item(1)
	change_preset(0)


func reset_none_preset() -> void:
	none_preset = ElementPresetStyle.new("individual")
	none_preset.background_panel_style_box = default_background_style_box.duplicate()
	none_preset.line_edit_theme = default_line_edit_theme.duplicate()


func rebuild_options_and_dictionary_from_json(dict: Dictionary) -> void:
	for key in dict:
		var id: int = max_option_id
		presets[id] = get_new_preset()
		presets[id].rebuild_from_json_dict(dict[key])
		preset_options.add_item("%s" % presets[id].name)
		style_buttons.add_button(str(id), presets[id].name)
		style_buttons.set_button_theme(max_option_id, presets[id])
		max_option_id += 1


func rebuild_options_and_dictionary_from_canvas(dict: Dictionary[String, ElementPresetStyle]) -> void:
	for key in dict:
		preset_options.add_item("%s" % dict[key].name)
		style_buttons.add_button(str(max_option_id), dict[key].name)
		style_buttons.set_button_theme(max_option_id, dict[key])
		presets[max_option_id] = dict[key]
		max_option_id += 1


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
		print("Selected: %d Selected ID: %d Dictionary has ID as key: %s Preset ID: %d" % [preset_options.selected, preset_options.get_selected_id(), presets.has(i), presets[i].id if presets.has(i) else "No ID"])
		i += 1


func get_selected_preset() -> ElementPresetStyle:
	if preset_options.selected > 0:
		return presets[preset_options.selected]
	elif preset_options.selected == 0:
		return none_preset
	else:
		return get_new_preset()


func select_by_style_preset_id(idx: String) -> void:
	if idx == "none":
		change_preset(0)
		return
	
	var found_style: bool = false
	for key in presets:
		if presets[key].id == idx:
			change_preset(key)
			found_style = true
	if !found_style:
		change_preset(0)


func toggle_none_preset_inputs(toggled_on: bool) -> void:
	if preset_options.selected == 0:
		background_color_picker_button.disabled = !toggled_on
		font_color_picker_button.disabled = !toggled_on
		font_outline_color_picker_button.disabled = !toggled_on
		border_color_picker_button.disabled = !toggled_on
		
		font_size_spin_box.editable = toggled_on
		font_outline_spin_box.editable = toggled_on
		border_size_spin_box.editable = toggled_on


func toggle_preset_inputs(toggled_on: bool) -> void:
	background_color_picker_button.disabled = !toggled_on
	font_color_picker_button.disabled = !toggled_on
	font_outline_color_picker_button.disabled = !toggled_on
	border_color_picker_button.disabled = !toggled_on
	
	font_size_spin_box.editable = toggled_on
	font_outline_spin_box.editable = toggled_on
	border_size_spin_box.editable = toggled_on


func _on_add_preset_pressed() -> void:
	name_insert.visible = true
	name_insert.edit()
	is_editing_text.emit()


func _on_remove_preset_pressed() -> void:
	remove_preset(preset_options.selected)


# Loads settings into fields depending on active preset style
# If the fields get updated by this function and not by user input, don't trigger their signals
func _on_preset_options_item_selected(index: int) -> void:
	is_user_input = false
	if index == 0:
		background_color_picker_button.color = none_preset.background_color
		font_size_spin_box.value = none_preset.font_size
		font_color_picker_button.color = none_preset.font_color
		font_outline_spin_box.value = none_preset.outline_size
		font_outline_color_picker_button.color = none_preset.outline_color
		border_size_spin_box.value = none_preset.border_size
		border_color_picker_button.color = none_preset.border_color
		current_preset_label.text = "Current Style: None"
		preset_selected.emit()
	elif index > 0:
		background_color_picker_button.color = presets[index].background_color
		font_size_spin_box.value = presets[index].font_size
		font_color_picker_button.color = presets[index].font_color
		font_outline_spin_box.value = presets[index].outline_size
		font_outline_color_picker_button.color = presets[index].outline_color
		border_size_spin_box.value = presets[index].border_size
		border_color_picker_button.color = presets[index].border_color
		current_preset_label.text = ("Current Style: %s" % presets[index].name)
		toggle_preset_inputs(true)
		preset_selected.emit()
	style_buttons.focus_button(index)
	is_user_input = true


func _on_background_color_picker_button_color_changed(color: Color) -> void:
	if !is_user_input:
		return
	if preset_options.selected == 0:
		none_preset.set_background_color(color)
		#style_buttons.change_button_background_color(0, color)
	else:
		presets[preset_options.selected].set_background_color(color)
		style_buttons.change_button_background_color(preset_options.selected, color)
	preset_color_changed.emit()	# For changing the line connection colors
	preset_changed.emit()


func _on_font_size_spin_box_value_changed(value: float) -> void:
	if !is_user_input:
		return
	if preset_options.selected == 0:
		none_preset.set_font_size(int(value))
		#style_buttons.change_button_font_size(0, int(value))
	else:
		presets[preset_options.selected].set_font_size(int(value))
		style_buttons.change_button_font_size(preset_options.selected, int(value))
	preset_changed.emit()


func _on_font_color_picker_button_color_changed(color: Color) -> void:
	if !is_user_input:
		return
	if preset_options.selected == 0:
		none_preset.set_font_color(color)
		#style_buttons.change_button_font_color(0, color)
	else:
		presets[preset_options.selected].set_font_color(color)
		style_buttons.change_button_font_color(preset_options.selected, color)
	preset_changed.emit()


func _on_font_outline_spin_box_value_changed(value: float) -> void:
	if !is_user_input:
		return
	if preset_options.selected == 0:
		none_preset.set_outline_size(int(value))
		#style_buttons.change_button_font_outline_size(0, int(value))
	else:
		presets[preset_options.selected].set_outline_size(int(value))
		style_buttons.change_button_font_outline_size(preset_options.selected, int(value))
	preset_changed.emit()


func _on_font_outline_color_picker_button_color_changed(color: Color) -> void:
	if !is_user_input:
		return
	if preset_options.selected == 0:
		none_preset.set_outline_color(color)
		#style_buttons.change_button_font_outline_color(0, color)
	else:
		presets[preset_options.selected].set_outline_color(color)
		style_buttons.change_button_font_outline_color(preset_options.selected, color)
	preset_changed.emit()


func _on_border_size_spin_box_value_changed(value: float) -> void:
	if !is_user_input:
		return
	if preset_options.selected == 0:
		none_preset.set_border_size(int(value))
	else:
		presets[preset_options.selected].set_border_size(int(value))
	preset_changed.emit()


func _on_border_color_picker_button_color_changed(color: Color) -> void:
	if !is_user_input:
		return
	if preset_options.selected == 0:
		none_preset.set_border_color(color)
		#style_buttons.change_button_border_color(0, color)
	else:
		presets[preset_options.selected].set_border_color(color)
		style_buttons.change_button_border_color(preset_options.selected, color)
	preset_changed.emit()


func _on_name_insert_editing_toggled(toggled_on: bool) -> void:
	if !toggled_on:
		if name_insert.text == "":
			add_preset("Preset %s" % max_option_id)
		else:
			add_preset(name_insert.text)
		name_insert.text = ""
		name_insert.visible = false
		stopped_editing_text.emit()


func _on_style_buttons_preset_style_button_pressed(idx: int) -> void:
	change_preset(idx)
