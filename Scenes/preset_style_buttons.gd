extends MarginContainer

@export_file("*.tscn") var button_scene
var button_theme: Theme
var MAX_BUTTON_COUNT = 42
var buttons: Dictionary[int, Button]
var keybinds: Dictionary[int, String]
signal preset_style_button_pressed	# With ID


func _process(delta: float) -> void:
	for n in keybinds:
		if Input.is_action_just_pressed(keybinds[n]) and buttons.has(n):
			preset_style_button_pressed.emit(n)


func init_keybinds() -> void:
	keybinds[0] = ""
	keybinds[1] = ""
	keybinds[2] = ""
	keybinds[3] = ""
	keybinds[4] = ""
	keybinds[5] = ""
	keybinds[6] = ""
	keybinds[7] = ""
	keybinds[8] = ""
	keybinds[9] = ""


func add_button(tooltip: String) -> void:
	pass
	# Instantiate button scene & duplicate default theme
	# Connect signal & id


func remove_button(idx: int) -> void:
	pass
	# Reorder buttons dictionary


func set_button_theme(idx: int, preset: ElementPresetStyle) -> void:
	pass
