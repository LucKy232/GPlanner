extends MarginContainer

@export_file("*.tscn") var button_scene
@onready var style_button_grid: GridContainer = $StyleButtonGrid

var current_pressed: int = -1
var MAX_BUTTON_COUNT = 36
var buttons: Dictionary[int, Button]
var keybinds: Dictionary[int, String]
var tooltips: Dictionary[int, String]

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
	if buttons.size() < MAX_BUTTON_COUNT:
		var id = buttons.size()
		tooltips[id] = tooltip
		buttons[id] = load(button_scene).instantiate()
		buttons[id].theme = buttons[id].theme.duplicate(true)
		buttons[id].pressed.connect(_on_button_pressed.bind(id))
		if id <= 10:
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
		if butt_id > 0:		# Keep none_preset
			buttons[butt_id].queue_free()
			to_erase.append(butt_id)
	for tip in tooltips:
		if tip > 0:
			tooltips.erase(tip)
	for butt_id in to_erase:
		buttons.erase(butt_id)


func rewind_button_dictionary(idx: int) -> void:
	#print("Removing %d" % [idx-1])
	var last_key: int = buttons.size() - 1
	var i: int = idx
	while i < buttons.size():
		#print("Placing %d into %d" % [i, i - 1])
		tooltips[i - 1] = tooltips[i]
		buttons[i - 1] = buttons[i]
		buttons[i - 1].text = str(i - 1)
		buttons[i - 1].pressed.disconnect(_on_button_pressed)
		buttons[i - 1].pressed.connect(_on_button_pressed.bind(i - 1))
		if i - 1 <= 10:
			var events: Array[InputEvent] = InputMap.action_get_events(keybinds[i - 1])
			buttons[i - 1].shortcut = Shortcut.new()
			buttons[i - 1].shortcut.events = InputMap.action_get_events(keybinds[i - 1])
			buttons[i - 1].tooltip_text = ("%s (%s)" % [tooltips[i - 1], events[0].as_text().split(" ")[0]])
		i += 1
	if last_key > 0:
		#print("Erasing last %d" % last_key)
		buttons.erase(last_key)


func focus_button(idx: int) -> void:
	if !buttons.has(idx):
		return
	if buttons.has(current_pressed):
		buttons[current_pressed].set_pressed_no_signal(false)
	buttons[idx].set_pressed_no_signal(true)
	buttons[idx].grab_focus()
	current_pressed = idx


func set_button_theme(idx: int, preset: ElementPresetStyle) -> void:
	change_button_font_size(idx, preset.font_size)
	change_button_font_outline_size(idx, preset.outline_size)
	change_button_font_color(idx, preset.font_color)
	change_button_font_outline_color(idx, preset.outline_color)
	change_button_border_color(idx, preset.border_color)
	change_button_background_color(idx, preset.background_color)


func change_button_font_size(idx: int, s: int) -> void:
	var fsize: int = clampi(int(s * 0.7), 6, 18)
	buttons[idx].theme.set_font_size("font_size", "Button", fsize)


func change_button_font_outline_size(idx: int, s: int) -> void:
	buttons[idx].theme.set_constant("outline_size", "Button", s)


func change_button_font_color(idx: int, color: Color) -> void:
	buttons[idx].theme.set_color("font_color", "Button", color)


func change_button_font_outline_color(idx: int, color: Color) -> void:
	buttons[idx].theme.set_color("font_outline_color", "Button", color)


func change_button_border_color(idx: int, color: Color) -> void:
	buttons[idx].theme.get_stylebox("normal", "Button").border_color = Color(color.r, color.g, color.b, 1.0)


func change_button_background_color(idx: int, color: Color) -> void:
	buttons[idx].theme.get_stylebox("normal", "Button").bg_color = color
	buttons[idx].theme.get_stylebox("pressed", "Button").bg_color = color * 1.2
	buttons[idx].theme.get_stylebox("focus", "Button").bg_color = color * 1.2
	buttons[idx].theme.get_stylebox("hover", "Button").bg_color = color * 0.9


func _on_button_pressed(idx: int) -> void:
	#print("Pressed %d" % idx)
	preset_style_button_pressed.emit(idx)
