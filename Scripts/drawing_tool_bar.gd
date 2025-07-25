extends HBoxContainer
class_name DrawingToolBar
## Changes the DrawingSettings resource shared between this and the currenly selected PlannerCanvas

@onready var pencil_size_spin_box: SpinBox = $PencilSizeSpinBox
@onready var brush_size_spin_box: SpinBox = $BrushSizeSpinBox
@onready var color_picker_button: ColorPickerButton = $ColorPickerButton
@onready var pressure_check_button: CheckButton = $PressureCheckButton
@onready var min_pressure_spin_box: SpinBox = $MinPressureSpinBox

var settings: DrawingSettings = DrawingSettings.new()


func _ready() -> void:
	init_tooltips()


func init_tooltips() -> void:
	var dict: Dictionary[String, String] = {
		"PencilSize" : "Pencil Size Presets [0 - 4]",
		"BrushSize" : "Brush Size",
		"ColorPicker" : "Color Picker",
		"PressureCheck" : "Use pressure for brush size?",
		"MinPressure" : "Minimum pressure value for size variation",
	}
	pencil_size_spin_box.tooltip_text = dict["PencilSize"]
	brush_size_spin_box.tooltip_text = dict["BrushSize"]
	color_picker_button.tooltip_text = dict["ColorPicker"]
	pressure_check_button.tooltip_text = dict["PressureCheck"]
	min_pressure_spin_box.tooltip_text = dict["MinPressure"]


func change_tool() -> void:
	if settings.selected_tool == settings.DrawingTool.PENCIL:
		pencil_size_spin_box.visible = true
		brush_size_spin_box.visible = false
		color_picker_button.visible = true
		pressure_check_button.visible = false
		min_pressure_spin_box.visible = false
		
		pencil_size_spin_box.value = settings.pencil_settings.size
		color_picker_button.color = settings.pencil_settings.color
	elif settings.selected_tool == settings.DrawingTool.BRUSH:
		pencil_size_spin_box.visible = false
		brush_size_spin_box.visible = true
		color_picker_button.visible = true
		pressure_check_button.visible = true
		min_pressure_spin_box.visible = settings.brush_settings.use_pressure_for_size	# Visible if using pressure
		
		brush_size_spin_box.value = settings.brush_settings.size
		color_picker_button.color = settings.brush_settings.color
		pressure_check_button.set_pressed_no_signal(settings.brush_settings.use_pressure_for_size)
		min_pressure_spin_box.value = settings.brush_settings.min_pressure
	elif settings.selected_tool == settings.DrawingTool.ERASER_PENCIL:
		pencil_size_spin_box.visible = true
		brush_size_spin_box.visible = false
		color_picker_button.visible = false
		pressure_check_button.visible = false
		min_pressure_spin_box.visible = false
		
		pencil_size_spin_box.value = settings.eraser_pencil_settings.size
	elif settings.selected_tool == settings.DrawingTool.ERASER_BRUSH:
		pencil_size_spin_box.visible = false
		brush_size_spin_box.visible = true
		color_picker_button.visible = false
		pressure_check_button.visible = true
		min_pressure_spin_box.visible = settings.eraser_brush_settings.use_pressure_for_size	# Visible if using pressure
		
		brush_size_spin_box.value = settings.eraser_brush_settings.size
		pressure_check_button.set_pressed_no_signal(settings.eraser_brush_settings.use_pressure_for_size)
		min_pressure_spin_box.value = settings.eraser_brush_settings.min_pressure


func change_settings(sett: DrawingSettings) -> void:
	settings = sett
	pencil_size_spin_box.min_value = settings.pencil_settings.size_limits.x
	pencil_size_spin_box.max_value = settings.pencil_settings.size_limits.y
	brush_size_spin_box.min_value = settings.brush_settings.size_limits.x
	brush_size_spin_box.max_value = settings.brush_settings.size_limits.y


func _on_pencil_size_spin_box_value_changed(value: float) -> void:
	if settings.selected_tool == settings.DrawingTool.PENCIL:
		settings.pencil_settings.size = int(value)
	elif settings.selected_tool == settings.DrawingTool.ERASER_PENCIL:
		settings.eraser_pencil_settings.size = int(value)


func _on_brush_size_spin_box_value_changed(value: float) -> void:
	if settings.selected_tool == settings.DrawingTool.BRUSH:
		settings.brush_settings.size = value
	elif settings.selected_tool == settings.DrawingTool.ERASER_BRUSH:
		settings.eraser_brush_settings.size = value


func _on_color_picker_button_color_changed(color: Color) -> void:
	if settings.selected_tool == settings.DrawingTool.PENCIL:
		settings.pencil_settings.color = color
	elif settings.selected_tool == settings.DrawingTool.BRUSH:
		settings.brush_settings.color = color


func _on_pressure_check_button_toggled(toggled_on: bool) -> void:
	if settings.selected_tool == settings.DrawingTool.BRUSH:
		settings.brush_settings.use_pressure_for_size = toggled_on
	elif settings.selected_tool == settings.DrawingTool.ERASER_BRUSH:
		settings.eraser_brush_settings.use_pressure_for_size = toggled_on
	min_pressure_spin_box.visible = toggled_on


func _on_min_pressure_spin_box_value_changed(value: float) -> void:
	if settings.selected_tool == settings.DrawingTool.BRUSH:
		settings.brush_settings.min_pressure = value
	elif settings.selected_tool == settings.DrawingTool.ERASER_BRUSH:
		settings.eraser_brush_settings.min_pressure = value
