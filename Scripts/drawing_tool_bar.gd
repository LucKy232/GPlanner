extends HBoxContainer
class_name DrawingToolBar
## Changes the DrawingSettings resource shared between this and the currenly selected PlannerCanvas

@export var color_picker_theme: Theme
@export var color_picker_panel_theme: Theme
@onready var pencil_size_spin_box: SpinBox = $PencilSizeSpinBox
@onready var brush_size_spin_box: SpinBox = $BrushSizeSpinBox
@onready var color_picker_button: ColorPickerButton = $ColorPickerButton
@onready var pressure_spin_box: SpinBox = $PressureSpinBox
@onready var input_repeat_timer: Timer = $InputRepeatTimer

var settings: DrawingSettings = DrawingSettings.new()
var inputs_enabled: bool = false
var keybinds: Dictionary[SettingKeybind, String] = {}
var input_repeat_time: float = 0.1
var input_multiplier: float = 1.0
var input_repeats: int = 0

signal color_picker_toggled
signal brush_size_changed
signal brush_color_changed

enum SettingKeybind {
	PENCIL_SIZE_INCREASE,
	PENCIL_SIZE_DECREASE,
	BRUSH_SIZE_INCREASE,
	BRUSH_SIZE_DECREASE,
	COLOR_PICKER_SHOW,
	PRESSURE_INCREASE,
	PRESSURE_DECREASE,
}

func _ready() -> void:
	init_tooltips()
	create_keybinds()
	customize_color_picker(color_picker_button)


func _process(_delta: float) -> void:
	if inputs_enabled:
		if Input.is_action_pressed("increase_tool_size", true) and input_repeat_timer.is_stopped():
			input_repeat_timer.start(input_repeat_time * input_multiplier)
			if pencil_size_spin_box.visible == true:
				pencil_size_spin_box.value += pencil_size_spin_box.step
			if brush_size_spin_box.visible == true:
				brush_size_spin_box.value += brush_size_spin_box.step
		if Input.is_action_pressed("decrease_tool_size", true) and input_repeat_timer.is_stopped():
			input_repeat_timer.start(input_repeat_time * input_multiplier)
			if pencil_size_spin_box.visible == true:
				pencil_size_spin_box.value -= pencil_size_spin_box.step
			if brush_size_spin_box.visible == true:
				brush_size_spin_box.value -= brush_size_spin_box.step
		if Input.is_action_just_pressed("show_color_picker"):
			color_picker_button.get_popup().show()
		if Input.is_action_pressed("increase_pressure", true) and input_repeat_timer.is_stopped():
			input_repeat_timer.start(input_repeat_time * 2.0 * input_multiplier)
			if pressure_spin_box.visible == true:
				pressure_spin_box.value += pressure_spin_box.step
		if Input.is_action_pressed("decrease_pressure", true) and input_repeat_timer.is_stopped():
			input_repeat_timer.start(input_repeat_time * 2.0 * input_multiplier)
			if pressure_spin_box.visible == true:
				pressure_spin_box.value -= pressure_spin_box.step
		
		for bind in keybinds:
			if Input.is_action_just_released(keybinds[bind], true):
				input_multiplier = 1.0
				input_repeats = 0


func init_tooltips() -> void:
	var dict: Dictionary[String, String] = {
		"PencilSize" : "Pencil Size Presets [0 - 4]",
		"BrushSize" : "Brush Size",
		"ColorPicker" : "Color Picker",
		"Pressure" : "How much pressure affects the brush size\n0.0 - brush size at 0 pressure is 100%\n1.0 - brush size at 0 pressure is minimum%",
	}
	pencil_size_spin_box.tooltip_text = dict["PencilSize"]
	brush_size_spin_box.tooltip_text = dict["BrushSize"]
	color_picker_button.tooltip_text = dict["ColorPicker"]
	pressure_spin_box.tooltip_text = dict["Pressure"]


func create_keybinds() -> void:
	keybinds[SettingKeybind.PENCIL_SIZE_INCREASE] = "increase_tool_size"
	keybinds[SettingKeybind.PENCIL_SIZE_DECREASE] = "decrease_tool_size"
	keybinds[SettingKeybind.BRUSH_SIZE_INCREASE] = "increase_tool_size"
	keybinds[SettingKeybind.BRUSH_SIZE_DECREASE] = "decrease_tool_size"
	keybinds[SettingKeybind.COLOR_PICKER_SHOW] = "show_color_picker"
	keybinds[SettingKeybind.PRESSURE_INCREASE] = "increase_pressure"
	keybinds[SettingKeybind.PRESSURE_DECREASE] = "decrease_pressure"
	
	pressure_spin_box.tooltip_text += "\n"
	for bind in keybinds:
		for event in InputMap.action_get_events(keybinds[bind]):
			var event_text: String = event.as_text()
			event_text = event_text.replace("Kp", "Num")
			event_text = event_text.replace(" (Physical)", "")
			event_text = event_text.replace(" Subtract", "Minus")
			event_text = event_text.replace(" Add", "Plus")
			
			match bind:
				SettingKeybind.PENCIL_SIZE_INCREASE, SettingKeybind.PENCIL_SIZE_DECREASE:
					pencil_size_spin_box.tooltip_text = ("%s (%s)" % [pencil_size_spin_box.tooltip_text, event_text])
				SettingKeybind.BRUSH_SIZE_INCREASE, SettingKeybind.BRUSH_SIZE_DECREASE:
					brush_size_spin_box.tooltip_text = ("%s (%s)" % [brush_size_spin_box.tooltip_text, event_text])
				SettingKeybind.COLOR_PICKER_SHOW:
					color_picker_button.tooltip_text = ("%s (%s)" % [color_picker_button.tooltip_text, event_text])
				SettingKeybind.PRESSURE_INCREASE, SettingKeybind.PRESSURE_DECREASE:
					pressure_spin_box.tooltip_text = ("%s (%s)" % [pressure_spin_box.tooltip_text, event_text])


func change_tool() -> void:
	if settings.selected_tool == Enums.DrawingTool.PENCIL:
		pencil_size_spin_box.visible = true
		brush_size_spin_box.visible = false
		color_picker_button.visible = true
		pressure_spin_box.visible = false
		
		pencil_size_spin_box.min_value = settings.pencil_settings.size_limits.x
		pencil_size_spin_box.max_value = settings.pencil_settings.size_limits.y
		pencil_size_spin_box.value = settings.pencil_settings.size
		color_picker_button.color = settings.pencil_settings.color
	elif settings.selected_tool == Enums.DrawingTool.BRUSH:
		pencil_size_spin_box.visible = false
		brush_size_spin_box.visible = true
		color_picker_button.visible = true
		pressure_spin_box.visible = true
		
		brush_size_spin_box.min_value = settings.brush_settings.size_limits.x
		brush_size_spin_box.max_value = settings.brush_settings.size_limits.y
		brush_size_spin_box.value = settings.brush_settings.size
		color_picker_button.color = settings.brush_settings.color
		pressure_spin_box.value = settings.brush_settings.pressure * 100.0
	elif settings.selected_tool == Enums.DrawingTool.ERASER_PENCIL:
		pencil_size_spin_box.visible = true
		brush_size_spin_box.visible = false
		color_picker_button.visible = false
		pressure_spin_box.visible = false
		
		pencil_size_spin_box.min_value = settings.eraser_pencil_settings.size_limits.x
		pencil_size_spin_box.max_value = settings.eraser_pencil_settings.size_limits.y
		pencil_size_spin_box.value = settings.eraser_pencil_settings.size
	elif settings.selected_tool == Enums.DrawingTool.ERASER_BRUSH:
		pencil_size_spin_box.visible = false
		brush_size_spin_box.visible = true
		color_picker_button.visible = false
		pressure_spin_box.visible = true
		
		brush_size_spin_box.min_value = settings.eraser_brush_settings.size_limits.x
		brush_size_spin_box.max_value = settings.eraser_brush_settings.size_limits.y
		brush_size_spin_box.value = settings.eraser_brush_settings.size
		pressure_spin_box.value = settings.eraser_brush_settings.pressure * 100.0


func change_settings(sett: DrawingSettings) -> void:
	settings = sett
	pencil_size_spin_box.min_value = settings.pencil_settings.size_limits.x
	pencil_size_spin_box.max_value = settings.pencil_settings.size_limits.y
	brush_size_spin_box.min_value = settings.brush_settings.size_limits.x
	brush_size_spin_box.max_value = settings.brush_settings.size_limits.y


func set_accent_color(color: Color) -> void:
	color_picker_panel_theme.get_stylebox("panel", "Panel").border_color = color
	var sb_theme: Theme = pencil_size_spin_box.theme
	sb_theme.get_stylebox("focus", "LineEdit").border_color = color.lightened(0.4)
	sb_theme.get_stylebox("normal", "LineEdit").border_color = color
	sb_theme.get_stylebox("down_background", "SpinBox").border_color = color
	sb_theme.get_stylebox("down_background_hovered", "SpinBox").border_color = color
	sb_theme.get_stylebox("down_background_pressed", "SpinBox").border_color = color
	sb_theme.get_stylebox("up_background", "SpinBox").border_color = color
	sb_theme.get_stylebox("up_background_hovered", "SpinBox").border_color = color
	sb_theme.get_stylebox("up_background_pressed", "SpinBox").border_color = color


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
	picker.scale = Vector2(0.835, 0.835)
	panel.theme = color_picker_panel_theme
	panel.scale = Vector2(0.835, 0.835)
	panel.visibility_changed.connect(remove_theme_override.bind(panel))
	popup.about_to_popup.connect(move_color_picker_popup.bind(popup))


func move_color_picker_popup(popup: PopupPanel) -> void:
	popup.position = Vector2i(int(global_position.x + size.x) + 40, 20)


# Theme doesn't show because override is present. Doesn't work earlier (ColorPickerButton adds the override?)
# Also gets reset when changing AppMode (?), so can't disconnect
func remove_theme_override(panel: Panel) -> void:
	if panel.is_visible_in_tree() and panel.has_theme_stylebox_override("panel"):
		panel.remove_theme_stylebox_override("panel")
		#panel.visibility_changed.disconnect(remove_theme_override)


func _on_pencil_size_spin_box_value_changed(value: float) -> void:
	if settings.selected_tool == Enums.DrawingTool.PENCIL:
		settings.pencil_settings.size = int(value)
	elif settings.selected_tool == Enums.DrawingTool.ERASER_PENCIL:
		settings.eraser_pencil_settings.size = int(value)


func _on_brush_size_spin_box_value_changed(value: float) -> void:
	if settings.selected_tool == Enums.DrawingTool.BRUSH:
		settings.brush_settings.size = value
	elif settings.selected_tool == Enums.DrawingTool.ERASER_BRUSH:
		settings.eraser_brush_settings.size = value
	brush_size_changed.emit()


func _on_color_picker_button_color_changed(color: Color) -> void:
	if settings.selected_tool == Enums.DrawingTool.PENCIL:
		settings.pencil_settings.color = color
	elif settings.selected_tool == Enums.DrawingTool.BRUSH:
		settings.brush_settings.color = color
		brush_color_changed.emit()


func _on_pressure_spin_box_value_changed(value: float) -> void:
	if settings.selected_tool == Enums.DrawingTool.BRUSH:
		settings.brush_settings.pressure = value / 100.0
	elif settings.selected_tool == Enums.DrawingTool.ERASER_BRUSH:
		settings.eraser_brush_settings.pressure = value / 100.0


func _on_input_repeat_timer_timeout() -> void:
	input_repeats += 1
	if input_repeats > 5:
		input_multiplier = 0.4


func _on_color_picker_button_toggled(toggled_on: bool) -> void:
	color_picker_toggled.emit(toggled_on)
