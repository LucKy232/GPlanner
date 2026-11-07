extends MarginContainer
class_name PresetStyleButtons

@onready var style_button_grid: GridContainer = %StyleButtonGrid
@export var limit_button_amount: bool = false
@export var MAX_BUTTON_COUNT = 14		## Visible buttons

var current_pressed: int = -1
var buttons: Dictionary[int, Button]
var tooltips: Dictionary[int, String]
var keybinds: Dictionary[int, String]

signal preset_style_button_pressed


func _ready() -> void:
	init_keybinds()


func _process(_delta: float) -> void:
	for n in keybinds:
		if Input.is_action_just_pressed(keybinds[n]) and buttons.has(n):
			preset_style_button_pressed.emit(n)
			focus_button(n)


func init_keybinds() -> void:
	keybinds[0] = "style_preset_0"
	keybinds[1] = "style_preset_1"
	keybinds[2] = "style_preset_2"
	keybinds[3] = "style_preset_3"
	keybinds[4] = "style_preset_4"
	keybinds[5] = "style_preset_5"
	keybinds[6] = "style_preset_6"
	keybinds[7] = "style_preset_7"
	keybinds[8] = "style_preset_8"
	keybinds[9] = "style_preset_9"
	keybinds[10] = "style_preset_10"


func add_button(text: String, tooltip: String) -> void:
	if limit_button_amount and buttons.size() >= MAX_BUTTON_COUNT:
		return
	var id = buttons.size()
	tooltips[id] = tooltip
	buttons[id] = load(GlobalScenes.style_select_button_scene).instantiate()
	buttons[id].theme = buttons[id].theme
	buttons[id].pressed.connect(_on_button_pressed.bind(id))
	if id <= 10:	# Add keybinds
		var events: Array[InputEvent] = InputMap.action_get_events(keybinds[id])
		buttons[id].shortcut = Shortcut.new()
		buttons[id].shortcut.events = InputMap.action_get_events(keybinds[id])
		tooltip += " (%s)" % [events[0].as_text().split(" ")[0]]
	buttons[id].tooltip_text = ("%s" % tooltip)
	buttons[id].text = text
	style_button_grid.add_child(buttons[id])


func remove_button(idx: int) -> void:
	if !buttons.has(idx):
		return
	buttons[idx].queue_free()
	rewind_button_dictionary(idx + 1)


func erase_everything() -> void:
	var to_erase: PackedInt32Array = PackedInt32Array()
	for butt_id in buttons:
		if butt_id > 0:		# Keep individual_preset
			buttons[butt_id].queue_free()
			to_erase.append(butt_id)
	for tip in tooltips:
		if tip > 0:
			tooltips.erase(tip)
	for butt_id in to_erase:
		buttons.erase(butt_id)


func rewind_button_dictionary(idx: int) -> void:
	var last_key: int = buttons.size() - 1
	for i in range(idx, buttons.size()):
		swap_buttons(i, i - 1)
	if last_key > 0:
		buttons.erase(last_key)


func focus_button(idx: int) -> void:
	if !buttons.has(idx):
		return
	if buttons.has(current_pressed):
		buttons[current_pressed].set_pressed_no_signal(false)
	buttons[idx].set_pressed_no_signal(true)
	current_pressed = idx


func set_button_theme(idx: int, preset: PresetStyle) -> void:
	if !buttons.has(idx):
		return
	change_button_font_size(idx, preset.font_size)
	change_button_font_outline_size(idx, preset.outline_size)
	change_button_font_color(idx, preset.font_color)
	change_button_font_outline_color(idx, preset.outline_color)
	change_button_border_color(idx, preset.border_color)
	change_button_border_size(idx, preset.border_size)
	change_button_background_color(idx, preset.background_color)


func move_button(from_idx: int, to_idx: int) -> void:
	if from_idx <= 0 or !buttons.has(from_idx) or !buttons.has(to_idx):
		push_error("Can't move button %d" % [from_idx])
		return
	if from_idx == to_idx:
		return
	# Keep data
	var button: Button = buttons[from_idx]
	var tooltip: String = tooltips[from_idx]
	# Free to_idx slot
	if from_idx < to_idx:
		for idx in range(from_idx, to_idx):
			swap_buttons(idx+1, idx)
	elif from_idx > to_idx:
		for idx in range(from_idx - 1, to_idx - 1, -1):
			swap_buttons(idx, idx+1)
	# Assign, remake
	buttons[to_idx] = button
	tooltips[to_idx] = tooltip
	if to_idx <= 10:
		var events: Array[InputEvent] = InputMap.action_get_events(keybinds[to_idx])
		buttons[to_idx].shortcut = Shortcut.new()
		buttons[to_idx].shortcut.events = InputMap.action_get_events(keybinds[to_idx])
		buttons[to_idx].tooltip_text = ("%s (%s)" % [tooltips[to_idx], events[0].as_text().split(" ")[0]])
	button.pressed.disconnect(_on_button_pressed)
	button.pressed.connect(_on_button_pressed.bind(to_idx))
	style_button_grid.move_child(button, to_idx)


func swap_buttons(from_idx: int, to_idx: int) -> void:
	buttons[to_idx] = buttons[from_idx]
	buttons[to_idx].pressed.disconnect(_on_button_pressed)
	buttons[to_idx].pressed.connect(_on_button_pressed.bind(to_idx))
	buttons[to_idx].text = str(to_idx)
	tooltips[to_idx] = tooltips[from_idx]
	if to_idx <= 10:
		var events: Array[InputEvent] = InputMap.action_get_events(keybinds[to_idx])
		buttons[to_idx].shortcut = Shortcut.new()
		buttons[to_idx].shortcut.events = InputMap.action_get_events(keybinds[to_idx])
		buttons[to_idx].tooltip_text = ("%s (%s)" % [tooltips[to_idx], events[0].as_text().split(" ")[0]])
	else:
		buttons[to_idx].tooltip_text = tooltips[to_idx]


func change_button_font_size(idx: int, s: int) -> void:
	if !buttons.has(idx):
		return
	var fsize: int = clampi(int(s * 0.70), 6, 24)
	buttons[idx].theme.set_font_size("font_size", "Button", fsize)


func change_button_font_outline_size(idx: int, s: int) -> void:
	if !buttons.has(idx):
		return
	buttons[idx].theme.set_constant("outline_size", "Button", s)


func change_button_font_color(idx: int, color: Color) -> void:
	if !buttons.has(idx):
		return
	buttons[idx].theme.set_color("font_color", "Button", color)
	buttons[idx].theme.set_color("font_focus_color", "Button", color)
	buttons[idx].theme.set_color("font_hover_color", "Button", color)
	buttons[idx].theme.set_color("font_pressed_color", "Button", color)
	buttons[idx].theme.set_color("font_hover_pressed_color", "Button", color)


func change_button_font_outline_color(idx: int, color: Color) -> void:
	if !buttons.has(idx):
		return
	buttons[idx].theme.set_color("font_outline_color", "Button", color)


func change_button_border_color(idx: int, color: Color) -> void:
	if !buttons.has(idx):
		return
	buttons[idx].theme.get_stylebox("normal", "Button").border_color = Color(color.r, color.g, color.b, 1.0)


func change_button_background_color(idx: int, color: Color) -> void:
	if !buttons.has(idx):
		return
	buttons[idx].theme.get_stylebox("normal", "Button").bg_color = color
	buttons[idx].theme.get_stylebox("pressed", "Button").bg_color = color.lightened(0.2)
	buttons[idx].theme.get_stylebox("focus", "Button").bg_color = color.lightened(0.2)
	buttons[idx].theme.get_stylebox("hover", "Button").bg_color = color.darkened(0.1)


func change_button_border_size(idx: int, border_size: int) -> void:
	if !buttons.has(idx):
		return
	var new_size: int = 1 if border_size >= 1 else 0
	new_size += 1 if border_size >= 3 else 0
	new_size += 1 if border_size >= 5 else 0
	new_size += 1 if border_size >= 10 else 0
	new_size += 1 if border_size >= 15 else 0
	buttons[idx].theme.get_stylebox("normal", "Button").border_width_left = new_size
	buttons[idx].theme.get_stylebox("normal", "Button").border_width_top = new_size
	buttons[idx].theme.get_stylebox("normal", "Button").border_width_right = new_size
	buttons[idx].theme.get_stylebox("normal", "Button").border_width_bottom = new_size
	buttons[idx].theme.get_stylebox("pressed", "Button").border_width_left = new_size
	buttons[idx].theme.get_stylebox("pressed", "Button").border_width_top = new_size
	buttons[idx].theme.get_stylebox("pressed", "Button").border_width_right = new_size
	buttons[idx].theme.get_stylebox("pressed", "Button").border_width_bottom = new_size
	buttons[idx].theme.get_stylebox("focus", "Button").border_width_left = new_size
	buttons[idx].theme.get_stylebox("focus", "Button").border_width_top = new_size
	buttons[idx].theme.get_stylebox("focus", "Button").border_width_right = new_size
	buttons[idx].theme.get_stylebox("focus", "Button").border_width_bottom = new_size
	buttons[idx].theme.get_stylebox("hover", "Button").border_width_left = new_size
	buttons[idx].theme.get_stylebox("hover", "Button").border_width_top = new_size
	buttons[idx].theme.get_stylebox("hover", "Button").border_width_right = new_size
	buttons[idx].theme.get_stylebox("hover", "Button").border_width_bottom = new_size


func change_border_blend(idx: int, toggled_on: bool) -> void:
	if !buttons.has(idx):
		return
	buttons[idx].theme.get_stylebox("normal", "Button").border_blend = toggled_on
	buttons[idx].theme.get_stylebox("pressed", "Button").border_blend = toggled_on
	buttons[idx].theme.get_stylebox("focus", "Button").border_blend = toggled_on
	buttons[idx].theme.get_stylebox("hover", "Button").border_blend = toggled_on


func _on_button_pressed(idx: int) -> void:
	print("Pressed %d" % [idx])
	preset_style_button_pressed.emit(idx)
