class_name StyleSettings extends Control

@export_range(150.0, 800.0, 5.0) var MAX_HEIGHT_SETTINGS: float = 335.0
@export_range(150.0, 1000.0, 5.0) var MAX_HEIGHT_ALL: float = 490.0
@export var default_background_style_box: StyleBoxFlat
@export var default_text_edit_theme: Theme
@export var color_picker_theme: Theme
@export var color_picker_panel_theme: Theme
@export var div_theme: Theme
@onready var order_previous_button: Button = %OrderPrevious
@onready var order_next_button: Button = %OrderNext
@onready var rename_preset_button: Button = %RenamePreset
# Preset Settings
@onready var preset_options: OptionButton = %PresetOptions
@onready var background_color_picker_button: ColorPickerButton = %BackgroundColorPickerButton
@onready var border_size_spin_box: SpinBox = %BorderSizeSpinBox
@onready var border_color_picker_button: ColorPickerButton = %BorderColorPickerButton
@onready var border_blend_check_box: CheckBox = %BorderBlendCheckBox
@onready var font_size_spin_box: SpinBox = %FontSizeSpinBox
@onready var font_color_picker_button: ColorPickerButton = %FontColorPickerButton
@onready var font_outline_spin_box: SpinBox = %FontOutlineSpinBox
@onready var font_outline_color_picker_button: ColorPickerButton = %FontOutlineColorPickerButton
@onready var line_spacing_spin_box: SpinBox = %LineSpacingSpinBox
@onready var title_font_size_spin_box: SpinBox = %TitleFontSizeSpinBox
@onready var title_font_color_picker_button: ColorPickerButton = %TitleFontColorPickerButton
@onready var title_font_outline_spin_box: SpinBox = %TitleFontOutlineSpinBox
@onready var title_outline_color_picker_button: ColorPickerButton = %TitleOutlineColorPickerButton
@onready var title_line_spacing_spin_box: SpinBox = %TitleLineSpacingSpinBox
@onready var entry_separation_spin_box: SpinBox = %EntrySeparationSpinBox
@onready var entry_div_line_check_box: CheckBox = %EntryDivLineCheckBox
@onready var entry_div_line_color_picker_button: ColorPickerButton = %EntryDivLineColorPickerButton

@onready var name_insert: LineEdit = %NameInsert
@onready var name_change: LineEdit = %NameChange
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var v_box_container: VBoxContainer = %VBoxContainer
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var style_buttons: PresetStyleButtons = %StyleButtons
@onready var current_preset_label: Label = %CurrentPresetLabel
# For visibility toggle
@onready var background_color_h_box: HBoxContainer = %BackgroundColorHBox
@onready var border_size_h_box: HBoxContainer = %BorderSizeHBox
@onready var border_color_h_box: HBoxContainer = %BorderColorHBox
@onready var border_blend_h_box: HBoxContainer = %BorderBlendHBox
@onready var font_h_box: HBoxContainer = %FontHBox
@onready var font_option_button: OptionButton = %FontOptionButton
@onready var font_size_h_box: HBoxContainer = %FontSizeHBox
@onready var font_color_h_box: HBoxContainer = %FontColorHBox
@onready var line_spacing_h_box: HBoxContainer = %LineSpacingHBox
@onready var font_outline_h_box: HBoxContainer = %FontOutlineHBox
@onready var outline_color_h_box: HBoxContainer = %OutlineColorHBox
@onready var title_font_size_h_box: HBoxContainer = %TitleFontSizeHBox
@onready var title_font_color_h_box: HBoxContainer = %TitleFontColorHBox
@onready var title_font_outline_h_box: HBoxContainer = %TitleFontOutlineHBox
@onready var title_outline_color_h_box: HBoxContainer = %TitleOutlineColorHBox
@onready var title_line_spacing_h_box: HBoxContainer = %TitleLineSpacingHBox
@onready var entry_separation_h_box: HBoxContainer = %EntrySeparationHBox
@onready var entry_div_line_h_box: HBoxContainer = %EntryDivLineHBox
@onready var list_title_category_button: Button = %ListTitleCategoryButton
@onready var list_title_category_div: Panel = %ListTitleCategoryDiv
@onready var list_entry_category_button: Button = %ListEntryCategoryButton
@onready var list_entry_category_div: Panel = %ListEntryCategoryDiv

## KEY: preset_options selector ID (not preset ID like in planner_canvas.gd)
## Doesn't contain '0', keys should always be sorted, without gaps, representing preset_options selected ID (except for 0)
var presets: Dictionary[int, PresetStyle]
var fonts: Dictionary[String, int]		## Takes font name as KEY and gives index in font_option_button as VALUE
## Is the current (or last selected) CanvasElement's individual preset (if that CanvasElement is using the individual preset)
var individual_preset: PresetStyle

signal preset_added
signal preset_added_undo
signal preset_changed
signal preset_name_changed
signal individual_preset_changed
signal preset_color_changed
signal preset_removed
signal preset_removed_undo
signal request_single_preset_update
signal preset_selected
signal order_changed


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("test_mult"):
		if preset_options.selected == 0 and individual_preset:
			var new_font: SystemFont = SystemFont.new()
			new_font.font_names = [font_option_button.get_item_text(font_option_button.selected)]
			individual_preset.text_edit_theme.set_font("font", "TextEdit", new_font)
			individual_preset.title_text_edit_theme.set_font("font", "TextEdit", new_font)
		elif presets.has(preset_options.selected):
			var preset: PresetStyle = presets[preset_options.selected]
			var new_font: SystemFont = SystemFont.new()
			new_font.font_names = [font_option_button.get_item_text(font_option_button.selected)]
			preset.text_edit_theme.set_font("font", "TextEdit", new_font)
			preset.title_text_edit_theme.set_font("font", "TextEdit", new_font)


func _ready() -> void:
	customize_color_picker(background_color_picker_button)
	customize_color_picker(font_color_picker_button)
	customize_color_picker(font_outline_color_picker_button)
	customize_color_picker(border_color_picker_button)
	scroll_container.get_v_scroll_bar().custom_minimum_size = Vector2(8.0, 0.0)
	style_buttons.preset_style_button_pressed.connect(change_preset)
	style_buttons.add_button("0", "Individual")
	reset_individual_preset()
	populate_system_fonts()
	if preset_options.selected == 0:
		load_values_from_preset(individual_preset)


func populate_system_fonts() -> void:
	var font_names: PackedStringArray = OS.get_system_fonts()
	fonts["Default"] = 0
	font_option_button.add_item("Default")
	for font_name in font_names:
		fonts[font_name] = font_option_button.item_count
		font_option_button.add_item(font_name)


# Only use set_no_signal functions (user didn't change the values)
func load_values_from_preset(preset: PresetStyle) -> void:
	background_color_picker_button.color = preset.background_color
	border_size_spin_box.set_value_no_signal(preset.border_size)
	border_color_picker_button.color = preset.border_color
	border_blend_check_box.set_pressed_no_signal(preset.border_blend)
	if fonts.has(preset.font_name):
		font_option_button.select(fonts[preset.font_name])
	font_size_spin_box.set_value_no_signal(preset.font_size)
	font_color_picker_button.color = preset.font_color
	font_outline_spin_box.set_value_no_signal(preset.outline_size)
	font_outline_color_picker_button.color = preset.outline_color
	line_spacing_spin_box.set_value_no_signal(preset.line_spacing)
	title_font_size_spin_box.set_value_no_signal(preset.title_font_size)
	title_font_color_picker_button.color = preset.title_font_color
	title_font_outline_spin_box.set_value_no_signal(preset.title_outline_size)
	title_outline_color_picker_button.color = preset.title_outline_color
	title_line_spacing_spin_box.set_value_no_signal(preset.title_line_spacing)
	entry_separation_spin_box.set_value_no_signal(preset.entry_separation)
	entry_div_line_check_box.set_pressed_no_signal(preset.list_div_enabled)
	entry_div_line_color_picker_button.color = preset.list_div_color
	toggle_background_border_settings(false if preset.border_size == 0 else true)
	toggle_font_outline_settings(false if preset.outline_size == 0 else true)
	toggle_title_font_outline_settings(false if preset.title_outline_size == 0 else true)


func toggle_visible(toggled_on: bool):
	settings_panel.visible = toggled_on


func is_panel_visible() -> bool:
	return settings_panel.visible


func add_preset(p_name: String, is_user_input: bool = true) -> void:
	var selection_id: int = preset_options.item_count
	preset_options.add_item(p_name)
	style_buttons.add_button(str(selection_id), p_name)
	presets[selection_id] = get_new_preset()
	presets[selection_id].name = p_name
	presets[selection_id].order_id = selection_id
	change_preset(selection_id)
	style_buttons.set_button_theme(selection_id, presets[selection_id])
	preset_added.emit(presets[selection_id])
	if is_user_input:
		preset_added_undo.emit(presets[selection_id], selection_id)


func remove_preset(idx: int, is_user_input: bool = true) -> void:
	if !presets.has(idx):
		printerr("Remove preset doesn't have %d" % [idx])
		return
	style_buttons.remove_button(idx)
	var removed_id: String = presets[idx].id
	var preset_dict: Dictionary = presets[idx].to_json()
	preset_options.remove_item(idx)
	rewind_option_button(idx)
	rewind_dict(idx+1)
	change_preset(0)
	# Add new button in place of deleted one if there's a space
	if style_buttons.limit_button_amount and presets.size() >= style_buttons.MAX_BUTTON_COUNT - 1:
		style_buttons.add_button(str(style_buttons.MAX_BUTTON_COUNT - 1), presets[style_buttons.MAX_BUTTON_COUNT - 1].name)
		style_buttons.set_button_theme(style_buttons.MAX_BUTTON_COUNT - 1, presets[style_buttons.MAX_BUTTON_COUNT - 1])
	if is_user_input:
		preset_removed_undo.emit(preset_dict, idx)
	preset_removed.emit(removed_id)


func change_preset(idx: int) -> void:
	if !presets.has(idx) and idx != 0:
		push_error("Style preset index not found: %d" % idx)
		return
	preset_options.select(idx)
	_on_preset_options_item_selected(idx)


func get_new_preset() -> PresetStyle:
	var new_preset: PresetStyle = PresetStyle.new("%s %d" % [Time.get_datetime_string_from_system(), Time.get_ticks_usec()])
	new_preset.set_background_panel_style_box(default_background_style_box.duplicate(), false)
	new_preset.set_text_edit_theme(default_text_edit_theme.duplicate(), false)
	new_preset.set_title_text_edit_theme(default_text_edit_theme.duplicate(), false)
	return new_preset


func erase_everything() -> void:
	style_buttons.erase_everything()
	presets.clear()
	reset_individual_preset()
	while preset_options.item_count > 1:
		preset_options.remove_item(1)
	change_preset(0)


func reset_individual_preset() -> void:
	individual_preset = PresetStyle.new("individual")
	individual_preset.background_panel_style_box = default_background_style_box.duplicate()
	individual_preset.text_edit_theme = default_text_edit_theme.duplicate()


# Returns dictionary that will be assigned to PlannerCanvas
func get_presets_dictionary_from_json(dict: Dictionary) -> Dictionary:
	var preset_dict: Dictionary[String, PresetStyle] = {}
	for key in dict:
		var new_preset: PresetStyle = get_new_preset()
		new_preset.rebuild_from_json_dict(dict[key])
		preset_dict[new_preset.id] = new_preset
	return preset_dict


# Takes PlannerCanvas style preset dictionary (built at load) and builds options & buttons
func rebuild_options_and_dictionary_from_canvas(dict: Dictionary[String, PresetStyle]) -> void:
	for key in dict:
		rebuild_single_preset(dict[key], preset_options.item_count)


func register_single_preset_from_dict(dict: Dictionary, order: int, elements_assigned: PackedInt32Array) -> void:
	var new_preset: PresetStyle = get_new_preset()
	new_preset.rebuild_from_json_dict(dict)
	rebuild_single_preset(new_preset, order)
	request_single_preset_update.emit(new_preset, elements_assigned)


func rebuild_single_preset(preset: PresetStyle, order: int) -> void:
	style_buttons.add_button(str(order), preset.name)
	if order == preset_options.item_count:
		presets[preset_options.item_count] = preset
		preset.order_id = preset_options.item_count
		preset_options.add_item("%s" % preset.name)
	else:
		insert_preset_into_dict(preset, order)
		style_buttons.move_button(preset_options.item_count, order)
		while preset_options.item_count > 1:
			preset_options.remove_item(1)
		for idx in range(1, presets.size() + 1):
			preset_options.add_item("%s" % presets[idx].name, idx)
	style_buttons.set_button_theme(order, preset)


# Needs preset_options.selected to == preset_options.get_selected_id() == the same presets key as before
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


func insert_preset_into_dict(added_preset: PresetStyle, at_idx: int) -> void:
	if !presets.has(at_idx):
		push_error("Can't insert preset at index %d" % [at_idx])
		return
	var new_dict: Dictionary[int, PresetStyle]
	for key in presets.keys():
		if key == at_idx:
			new_dict[key] = added_preset
		elif key > at_idx:
			new_dict[key] = presets[key - 1]
		else:
			new_dict[key] = presets[key]
	var last: PresetStyle = presets[presets.keys().size()]	# Remember it starts at 1
	new_dict[presets.keys().size() + 1] = last
	presets = new_dict


func get_preset_order_dict() -> Dictionary[int, String]:
	var dict: Dictionary[int, String]
	for i in presets:
		dict[i] = presets[i].id
	return dict


func get_preset_id_dict() -> Dictionary[String, PresetStyle]:
	var dict: Dictionary[String, PresetStyle]
	for i in presets:
		dict[presets[i].id] = presets[i]
	return dict


func reorder_by_preset_order_dict(preset_order: Dictionary[int, String]) -> void:
	# 1. new presets dict
	var current_presets: Dictionary[String, PresetStyle] = get_preset_id_dict()
	var new_presets: Dictionary[int, PresetStyle]
	for order_id in preset_order:
		if current_presets.has(preset_order[order_id]):
			new_presets[order_id] = current_presets[preset_order[order_id]]
			new_presets[order_id].order_id = order_id
		else:
			push_error("PresetStyle ID %s not found in current presets" % [order_id])
	presets = new_presets
	# 2. remake preset_order OptionButton items
	while preset_options.item_count > 1:
		preset_options.remove_item(1)
	for idx in range(1, presets.size() + 1):
		preset_options.add_item("%s" % presets[idx].name, idx)
	# 3. reorder / remake StyleButtons
	style_buttons.erase_everything()
	for idx in range(1, presets.size() + 1):
		style_buttons.add_button(str(idx), presets[idx].name)
		style_buttons.set_button_theme(idx, presets[idx])


func rename_preset(idx: int, new_name: String, is_user_input: bool = true) -> void:
	if idx < 1 or !presets.has(idx):
		return
	var old_name: String = presets[idx].name
	presets[idx].name = new_name
	preset_options.set_item_text(idx, new_name)
	style_buttons.set_button_tooltip_text(idx, new_name)
	if preset_options.selected == idx:
		current_preset_label.text = ("Current Style: %s" % new_name)
	if is_user_input:
		preset_name_changed.emit(idx, old_name, new_name)


func get_selected_preset() -> PresetStyle:
	if preset_options.selected > 0:
		return presets[preset_options.selected]
	elif preset_options.selected == 0:
		return individual_preset
	else:
		return get_new_preset()


func select_by_style_preset_id(idx: String) -> void:
	if idx == "individual":
		change_preset(0)
		return
	
	var found_style: bool = false
	for key in presets:
		if presets[key].id == idx:
			change_preset(key)
			found_style = true
	if !found_style:
		change_preset(0)


func toggle_individual_preset_inputs(toggled_on: bool) -> void:
	if preset_options.selected == 0:
		toggle_preset_inputs(toggled_on)


func toggle_preset_inputs(toggled_on: bool) -> void:
	background_color_picker_button.disabled = !toggled_on
	border_size_spin_box.editable = toggled_on
	border_color_picker_button.disabled = !toggled_on
	border_blend_check_box.disabled = !toggled_on
	
	font_size_spin_box.editable = toggled_on
	font_color_picker_button.disabled = !toggled_on
	font_outline_spin_box.editable = toggled_on
	font_outline_color_picker_button.disabled = !toggled_on
	line_spacing_spin_box.editable = toggled_on
	
	title_font_size_spin_box.editable = toggled_on
	title_font_color_picker_button.disabled = !toggled_on
	title_font_outline_spin_box.editable = toggled_on
	title_outline_color_picker_button.disabled = !toggled_on
	title_line_spacing_spin_box.editable = toggled_on
	
	entry_separation_spin_box.editable = toggled_on
	entry_div_line_color_picker_button.disabled = !toggled_on


func toggle_style_presets(toggled_on: bool) -> void:
	style_buttons.visible = toggled_on
	current_preset_label.visible = toggled_on
	if !toggled_on:	# Don't always show
		settings_panel.visible = false


func set_accent_color(c: Color) -> void:
	settings_panel.theme.get_stylebox("panel", "PanelContainer").border_color = c
	div_theme.get_stylebox("panel", "Panel").color = Color(c.r, c.g, c.b, 0.7)
	scroll_container.theme.get_stylebox("grabber", "VScrollBar").bg_color = c
	scroll_container.theme.get_stylebox("grabber_highlight", "VScrollBar").bg_color = c.lightened(0.15)
	scroll_container.theme.get_stylebox("grabber_pressed", "VScrollBar").bg_color = c.lightened(0.30)


func get_color_picker_background_panel(button: ColorPickerButton) -> Panel:
	if button.get_popup().get_child(0, true) is Panel:
		return button.get_popup().get_child(0, true)
	elif button.get_popup().get_child(1, true) is Panel:
		return button.get_popup().get_child(1, true)
	return Panel.new()


func customize_color_picker(button: ColorPickerButton) -> void:
	var picker: ColorPicker = button.get_picker()
	var popup: PopupPanel = button.get_popup()
	var panel: Panel = get_color_picker_background_panel(button)
	
	picker.theme = color_picker_theme
	panel.theme = color_picker_panel_theme
	picker.scale = Vector2(0.835, 0.835)
	panel.scale = Vector2(0.835, 0.835)
	panel.visibility_changed.connect(remove_theme_override.bind(panel))
	popup.about_to_popup.connect(move_color_picker_popup.bind(popup))


func move_color_picker_popup(popup: PopupPanel) -> void:
	popup.position = Vector2i(int(global_position.x - popup.size.x * 0.835 - 10.0), 62) + Vector2i(0, 0)


# Theme doesn't show because override is present. Doesn't work earlier (ColorPickerButton adds the override?)
# Also gets reset when changing AppMode (?), so can't disconnect
func remove_theme_override(panel: Panel) -> void:
	if panel.is_visible_in_tree() and panel.has_theme_stylebox_override("panel"):
		panel.remove_theme_stylebox_override("panel")
		#panel.visibility_changed.disconnect(remove_theme_override)


func toggle_background_border_settings(toggled_on: bool) -> void:
	border_color_h_box.visible = toggled_on
	border_blend_h_box.visible = toggled_on


func toggle_font_outline_settings(toggled_on: bool) -> void:
	outline_color_h_box.visible = toggled_on


func toggle_title_font_outline_settings(toggled_on: bool) -> void:
	title_outline_color_h_box.visible = toggled_on


func toggle_list_settings(toggled_on) -> void:
	list_title_category_button.set_pressed_no_signal(toggled_on)
	list_title_category_button.visible = toggled_on
	list_title_category_div.visible = toggled_on
	title_font_size_h_box.visible = toggled_on
	title_font_color_h_box.visible = toggled_on
	title_font_outline_h_box.visible = toggled_on
	title_outline_color_h_box.visible = toggled_on
	title_line_spacing_h_box.visible = toggled_on
	list_entry_category_button.set_pressed_no_signal(toggled_on)
	list_entry_category_button.visible = toggled_on
	list_entry_category_div.visible = toggled_on
	entry_separation_h_box.visible = toggled_on
	entry_div_line_h_box.visible = toggled_on


func is_preset_selected(preset: PresetStyle) -> bool:
	if preset_options.selected == 0:
		if individual_preset == preset:
			return true
		return false
	else:
		if presets[preset_options.selected] == preset:
			return true
		return false


# Used with UndoRedo
func set_individual_preset_single_setting(setting: Enums.StyleSetting, value: Variant, preset: PresetStyle) -> void:
	_set_preset_single_setting(setting, value, preset)


# Used with UndoRedo
func set_existing_preset_single_setting(setting: Enums.StyleSetting, value: Variant, preset_selection_id: int) -> void:
	if !presets.has(preset_selection_id):
		push_error("Preset ID not found in presets dictionary")
		return
	var preset: PresetStyle = presets[preset_selection_id]
	_set_preset_single_setting(setting, value, preset, preset_selection_id)


func toggle_modify_preset_buttons() -> void:
	if preset_options.selected < 1:
		order_next_button.disabled = true
		order_previous_button.disabled = true
		rename_preset_button.disabled = true
	elif preset_options.selected < 2:
		if presets.has(preset_options.selected + 1):
			order_next_button.disabled = false
		else:
			order_next_button.disabled = true
		order_previous_button.disabled = true
		rename_preset_button.disabled = false
	else:
		if presets.has(preset_options.selected + 1):
			order_next_button.disabled = false
		else:
			order_next_button.disabled = true
		order_previous_button.disabled = false
		rename_preset_button.disabled = false


## index decreases
func _on_order_previous_pressed() -> void:
	var selected_idx: int = preset_options.selected
	if selected_idx < 2:
		return
	var old_order: Dictionary[int, String] = get_preset_order_dict()
	var new_order: Dictionary[int, String] = old_order.duplicate()
	var current_id: String = new_order[selected_idx]
	var previous_id: String = new_order[selected_idx - 1]
	new_order[selected_idx] = previous_id
	new_order[selected_idx - 1] = current_id
	reorder_by_preset_order_dict(new_order)
	preset_options.select(selected_idx - 1)
	_on_preset_options_item_selected(selected_idx - 1)
	order_changed.emit(old_order, new_order)


## index increases
func _on_order_next_pressed() -> void:
	var selected_idx: int = preset_options.selected
	if selected_idx < 1 or !presets.has(selected_idx + 1):
		return
	var old_order: Dictionary[int, String] = get_preset_order_dict()
	var new_order: Dictionary[int, String] = old_order.duplicate()
	var current_id: String = new_order[selected_idx]
	var next_id: String = new_order[selected_idx + 1]
	new_order[selected_idx] = next_id
	new_order[selected_idx + 1] = current_id
	reorder_by_preset_order_dict(new_order)
	preset_options.select(selected_idx + 1)
	_on_preset_options_item_selected(selected_idx + 1)
	order_changed.emit(old_order, new_order)


func _on_add_preset_pressed() -> void:
	name_insert.visible = true
	name_insert.edit()


func _on_rename_preset_pressed() -> void:
	name_change.visible = true
	name_change.edit()


func _on_remove_preset_pressed() -> void:
	remove_preset(preset_options.selected)


# If the fields get updated by this function and not by user input, don't trigger their signals
func _on_preset_options_item_selected(index: int) -> void:
	if index == 0:
		load_values_from_preset(individual_preset)
		current_preset_label.text = ("Current Style: Individual")
	elif index > 0:
		load_values_from_preset(presets[index])
		current_preset_label.text = ("Current Style: %s" % presets[index].name)
		toggle_preset_inputs(true)
	toggle_modify_preset_buttons()
	preset_selected.emit()
	style_buttons.focus_button(index)


func _on_background_color_picker_button_color_changed(color: Color) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.BG_COLOR, color)


func _on_border_size_spin_box_value_changed(value: float) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.BORDER_SIZE, value)


func _on_border_color_picker_button_color_changed(color: Color) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.BORDER_COLOR, color)


func _on_border_blend_check_box_toggled(toggled_on: bool) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.BORDER_BLEND, toggled_on)


func _on_font_option_button_item_selected(index: int) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.FONT_NAME, font_option_button.get_item_text(index))


func _on_font_size_spin_box_value_changed(value: float) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.FONT_SIZE, value)


func _on_font_color_picker_button_color_changed(color: Color) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.FONT_COLOR, color)


func _on_font_outline_spin_box_value_changed(value: float) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.OUTLINE_SIZE, value)


func _on_font_outline_color_picker_button_color_changed(color: Color) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.OUTLINE_COLOR, color)


func _on_line_spacing_spin_box_value_changed(value: float) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.LINE_SPACING, value)


func _on_title_font_size_spin_box_value_changed(value: float) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.TITLE_FONT_SIZE, value)


func _on_title_font_color_picker_button_color_changed(color: Color) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.TITLE_FONT_COLOR, color)


func _on_title_font_outline_spin_box_value_changed(value: float) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.TITLE_OUTLINE_SIZE, value)


func _on_title_outline_color_picker_button_color_changed(color: Color) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.TITLE_OUTLINE_COLOR, color)


func _on_title_line_spacing_spin_box_value_changed(value: float) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.TITLE_LINE_SPACING, value)


func _on_entry_separation_spin_box_value_changed(value: float) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.ENTRY_SEPARATION, value)


func _on_entry_div_line_check_box_toggled(toggled_on: bool) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.ENTRY_DIV_ENABLED, toggled_on)


func _on_entry_div_line_color_picker_button_color_changed(color: Color) -> void:
	_on_current_preset_value_changed(Enums.StyleSetting.ENTRY_DIV_COLOR, color)


func _on_name_insert_editing_toggled(toggled_on: bool) -> void:
	if toggled_on:
		return
	if name_insert.text == "":
		add_preset("Preset %s" % preset_options.item_count)
	else:
		add_preset(name_insert.text)
	name_insert.text = ""
	name_insert.visible = false


func _on_name_change_editing_toggled(toggled_on: bool) -> void:
	if toggled_on:
		return
	rename_preset(preset_options.selected, name_change.text)
	name_change.text = ""
	name_change.visible = false


func _on_style_buttons_preset_style_button_pressed(idx: int) -> void:
	change_preset(idx)


func _on_background_category_button_toggled(toggled_on: bool) -> void:
	background_color_h_box.visible = toggled_on
	border_size_h_box.visible = toggled_on
	toggle_background_border_settings(false if int(border_size_spin_box.value) == 0 else toggled_on)


func _on_font_category_button_toggled(toggled_on: bool) -> void:
	font_h_box.visible = toggled_on
	font_size_h_box.visible = toggled_on
	font_color_h_box.visible = toggled_on
	line_spacing_h_box.visible = toggled_on
	font_outline_h_box.visible = toggled_on
	toggle_font_outline_settings(false if int(font_outline_spin_box.value) == 0 else toggled_on)


func _on_list_title_category_button_toggled(toggled_on: bool) -> void:
	title_font_size_h_box.visible = toggled_on
	title_font_color_h_box.visible = toggled_on
	title_line_spacing_h_box.visible = toggled_on
	title_font_outline_h_box.visible = toggled_on
	toggle_title_font_outline_settings(false if int(title_font_outline_spin_box.value) == 0 else toggled_on)


func _on_list_entry_category_button_toggled(toggled_on: bool) -> void:
	entry_separation_h_box.visible = toggled_on
	entry_div_line_h_box.visible = toggled_on


# Called when any Control related to a StyleSetting changes value
func _on_current_preset_value_changed(setting: Enums.StyleSetting, value: Variant) -> void:
	var is_individual_preset: bool = true if preset_options.selected == 0 else false
	var preset: PresetStyle = individual_preset if is_individual_preset else presets[preset_options.selected]
	var old_value: Variant
	match setting:
		Enums.StyleSetting.BG_COLOR:
			old_value = preset.background_color
			preset.set_background_color(value as Color)
			preset_color_changed.emit(preset)		# For changing the line connection colors
			if !is_individual_preset:
				style_buttons.change_button_background_color(preset_options.selected, value as Color)
		Enums.StyleSetting.BORDER_SIZE:
			old_value = preset.border_size
			preset.set_border_size(int(value))
			if !is_individual_preset:
				style_buttons.change_button_border_size(preset_options.selected, int(value))
			toggle_background_border_settings(false if int(value) == 0 else true)
		Enums.StyleSetting.BORDER_COLOR:
			old_value = preset.border_color
			preset.set_border_color(value as Color)
			if !is_individual_preset:
				style_buttons.change_button_border_color(preset_options.selected, value as Color)
		Enums.StyleSetting.BORDER_BLEND:
			old_value = preset.border_blend
			preset.set_border_blend(bool(value))
			if !is_individual_preset:
				style_buttons.change_border_blend(preset_options.selected, bool(value))
		Enums.StyleSetting.FONT_NAME:
			old_value = preset.font_name
			preset.set_font_name(str(value))
			preset.set_title_font_name(str(value))
		Enums.StyleSetting.FONT_SIZE:
			old_value = preset.font_size
			preset.set_font_size(int(value))
			if !is_individual_preset:
				style_buttons.change_button_font_size(preset_options.selected, int(value))
		Enums.StyleSetting.FONT_COLOR:
			old_value = preset.font_color
			preset.set_font_color(value as Color)
			if !is_individual_preset:
				style_buttons.change_button_font_color(preset_options.selected, value as Color)
		Enums.StyleSetting.OUTLINE_SIZE:
			old_value = preset.outline_size
			preset.set_outline_size(int(value))
			if !is_individual_preset:
				style_buttons.change_button_font_outline_size(preset_options.selected, int(value))
			toggle_font_outline_settings(false if int(value) == 0 else true)
		Enums.StyleSetting.OUTLINE_COLOR:
			old_value = preset.outline_color
			preset.set_outline_color(value as Color)
			if !is_individual_preset:
				style_buttons.change_button_font_outline_color(preset_options.selected, value as Color)
		Enums.StyleSetting.LINE_SPACING:
			old_value = preset.line_spacing
			preset.set_line_spacing(int(value))
		Enums.StyleSetting.TITLE_FONT_SIZE:
			old_value = preset.title_font_size
			preset.set_title_font_size(int(value))
		Enums.StyleSetting.TITLE_FONT_COLOR:
			old_value = preset.title_font_color
			preset.set_title_font_color(value as Color)
		Enums.StyleSetting.TITLE_OUTLINE_SIZE:
			old_value = preset.title_outline_size
			preset.set_title_outline_size(int(value))
			toggle_title_font_outline_settings(false if int(value) == 0 else true)
		Enums.StyleSetting.TITLE_OUTLINE_COLOR:
			old_value = preset.title_outline_color
			preset.set_title_outline_color(value as Color)
		Enums.StyleSetting.TITLE_LINE_SPACING:
			old_value = preset.title_line_spacing
			preset.set_title_line_spacing(int(value))
		Enums.StyleSetting.ENTRY_SEPARATION:
			old_value = preset.entry_separation
			preset.set_list_entry_separation(int(value))
		Enums.StyleSetting.ENTRY_DIV_ENABLED:
			old_value = preset.list_div_enabled
			preset.set_list_div_toggled(bool(value))
		Enums.StyleSetting.ENTRY_DIV_COLOR:
			old_value = preset.list_div_color
			preset.set_list_div_color(value as Color)
	if is_individual_preset:
		individual_preset_changed.emit(setting, individual_preset, old_value, value)
	else:
		preset_changed.emit(setting, preset_options.selected, old_value, value)


# Called when UndoRedo changes preset value
func _set_preset_single_setting(setting: Enums.StyleSetting, value: Variant, preset: PresetStyle, preset_selection_id: int = -1) -> void:
	match setting:
		Enums.StyleSetting.BG_COLOR:
			preset.set_background_color(value as Color)
			preset_color_changed.emit(preset)		# For changing the line connection colors
			if is_preset_selected(preset):
				background_color_picker_button.color = value as Color
			if preset_selection_id > 0:
				style_buttons.change_button_background_color(preset_selection_id, value as Color)
		Enums.StyleSetting.BORDER_SIZE:
			preset.set_border_size(int(value))
			if is_preset_selected(preset):
				border_size_spin_box.set_value_no_signal(int(value))
				toggle_background_border_settings(false if int(value) == 0 else true)
			if preset_selection_id > 0:
				style_buttons.change_button_border_size(preset_selection_id, int(value))
		Enums.StyleSetting.BORDER_COLOR:
			preset.set_border_color(value as Color)
			if is_preset_selected(preset):
				border_color_picker_button.color = value as Color
			if preset_selection_id > 0:
				style_buttons.change_button_border_color(preset_selection_id, value as Color)
		Enums.StyleSetting.BORDER_BLEND:
			preset.set_border_blend(bool(value))
			if is_preset_selected(preset):
				border_blend_check_box.set_pressed_no_signal(bool(value))
			if preset_selection_id > 0:
				style_buttons.change_border_blend(preset_selection_id, bool(value))
		Enums.StyleSetting.FONT_NAME:
			var str_value: String = str(value)
			preset.set_font_name(str_value)
			preset.set_title_font_name(str_value)
			if fonts.has(str_value):
				font_option_button.select(fonts[str_value])
		Enums.StyleSetting.FONT_SIZE:
			preset.set_font_size(int(value))
			if is_preset_selected(preset):
				font_size_spin_box.set_value_no_signal(int(value))
			if preset_selection_id > 0:
				style_buttons.change_button_font_size(preset_selection_id, int(value))
		Enums.StyleSetting.FONT_COLOR:
			preset.set_font_color(value as Color)
			if is_preset_selected(preset):
				font_color_picker_button.color = value as Color
			if preset_selection_id > 0:
				style_buttons.change_button_font_color(preset_selection_id, value as Color)
		Enums.StyleSetting.OUTLINE_SIZE:
			preset.set_outline_size(int(value))
			if is_preset_selected(preset):
				font_outline_spin_box.set_value_no_signal(int(value))
				toggle_font_outline_settings(false if int(value) == 0 else true)
			if preset_selection_id > 0:
				style_buttons.change_button_font_outline_size(preset_selection_id, int(value))
		Enums.StyleSetting.OUTLINE_COLOR:
			preset.set_outline_color(value as Color)
			if is_preset_selected(preset):
				font_outline_color_picker_button.color = value as Color
			if preset_selection_id > 0:
				style_buttons.change_button_font_outline_color(preset_selection_id, value as Color)
		Enums.StyleSetting.LINE_SPACING:
			preset.set_line_spacing(int(value))
			if is_preset_selected(preset):
				line_spacing_spin_box.set_value_no_signal(int(value))
		Enums.StyleSetting.TITLE_FONT_SIZE:
			preset.set_title_font_size(int(value))
			if is_preset_selected(preset):
				title_font_size_spin_box.set_value_no_signal(int(value))
		Enums.StyleSetting.TITLE_FONT_COLOR:
			preset.set_title_font_color(value as Color)
			if is_preset_selected(preset):
				title_font_color_picker_button.color = value as Color
		Enums.StyleSetting.TITLE_OUTLINE_SIZE:
			preset.set_title_outline_size(int(value))
			if is_preset_selected(preset):
				title_font_outline_spin_box.set_value_no_signal(int(value))
				toggle_title_font_outline_settings(false if int(value) == 0 else true)
		Enums.StyleSetting.TITLE_OUTLINE_COLOR:
			preset.set_title_outline_color(value as Color)
			if is_preset_selected(preset):
				title_outline_color_picker_button.color = value as Color
		Enums.StyleSetting.TITLE_LINE_SPACING:
			preset.set_title_line_spacing(value)
			if is_preset_selected(preset):
				title_line_spacing_spin_box.set_value_no_signal(int(value))
		Enums.StyleSetting.ENTRY_SEPARATION:
			preset.set_list_entry_separation(value)
			if is_preset_selected(preset):
				entry_separation_spin_box.set_value_no_signal(int(value))
		Enums.StyleSetting.ENTRY_DIV_ENABLED:
			preset.set_list_div_toggled(bool(value))
			if is_preset_selected(preset):
				entry_div_line_check_box.set_pressed_no_signal(bool(value))
		Enums.StyleSetting.ENTRY_DIV_COLOR:
			preset.set_list_div_color(value as Color)
			if is_preset_selected(preset):
				entry_div_line_color_picker_button.color = value as Color


# Test for dictionary keys, use after add_preset() or remove_preset()
#func check_key_equivalence() -> void:
	#print("\nCheck equivalence: ")
	#var i = 1
	#while i < preset_options.item_count:
		#preset_options.select(i)
		#print("Selected: %d Selected ID: %d Dictionary has ID as key: %s Preset ID: %d" % [preset_options.selected, preset_options.get_selected_id(), presets.has(i), presets[i].id if presets.has(i) else "No ID"])
		#i += 1
