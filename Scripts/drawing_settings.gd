class_name DrawingSettings
var selected_tool: DrawingTool = DrawingTool.PENCIL
var pencil_settings: PencilSettings = PencilSettings.new()
var brush_settings: BrushSettings = BrushSettings.new()
var eraser_pencil_settings: EraserPencilSettings = EraserPencilSettings.new()
var eraser_brush_settings: EraserBrushSettings = EraserBrushSettings.new()

enum DrawingTool {
	PENCIL,
	BRUSH,
	ERASER_PENCIL,
	ERASER_BRUSH,
}

class PencilSettings:
	var size_limits: Vector2i = Vector2i(0, 4)		## Inclusive
	var size: int = 0:
		get:
			return clampi(size, size_limits.x, size_limits.y)
		set(value):
			size = clampi(value, size_limits.x, size_limits.y)
	var color: Color = Color.WHITE
	
	func to_json() -> Dictionary:
		var dict: Dictionary = {}
		dict["size"] = size
		dict["color.r"] = color.r
		dict["color.g"] = color.g
		dict["color.b"] = color.b
		dict["color.a"] = color.a
		return dict


class BrushSettings:
	var size_limits: Vector2 = Vector2(1.0, 50.0)
	var size: float = 10.0:
		get:
			return clampf(size, size_limits.x, size_limits.y)
		set(value):
			size = clampf(value, size_limits.x, size_limits.y)
	var color: Color = Color.WHITE
	var use_pressure_for_size: bool = true
	var min_pressure: float = 0.1:
		get:
			return clampf(min_pressure, 0.1, 1.0)
		set(value):
			min_pressure = clampf(value, 0.1, 1.0)
	
	func to_json() -> Dictionary:
		var dict: Dictionary = {}
		dict["size"] = size
		dict["color.r"] = color.r
		dict["color.g"] = color.g
		dict["color.b"] = color.b
		dict["color.a"] = color.a
		dict["use_pressure"] = use_pressure_for_size
		dict["min_pressure"] = min_pressure
		return dict


class EraserPencilSettings:
	var size_limits: Vector2i = Vector2i(0, 4)		## Inclusive
	var size: int = 0:
		get:
			return clampi(size, size_limits.x, size_limits.y)
		set(value):
			size = clampi(value, size_limits.x, size_limits.y)
	
	func to_json() -> Dictionary:
		var dict: Dictionary = {}
		dict["size"] = size
		return dict


class EraserBrushSettings:
	var size_limits: Vector2 = Vector2(1.0, 50.0)
	var size: float = 10.0:
		get:
			return clampf(size, size_limits.x, size_limits.y)
		set(value):
			size = clampf(value, size_limits.x, size_limits.y)
	var use_pressure_for_size: bool = true
	var min_pressure: float = 0.1:
		get:
			return clampf(min_pressure, 0.1, 1.0)
		set(value):
			min_pressure = clampf(value, 0.1, 1.0)
	
	func to_json() -> Dictionary:
		var dict: Dictionary = {}
		dict["size"] = size
		dict["use_pressure"] = use_pressure_for_size
		dict["min_pressure"] = min_pressure
		return dict


func to_json() -> Dictionary:
	var dict: Dictionary = {}
	dict["SelectedTool"] = selected_tool
	dict["PencilSettings"] = pencil_settings.to_json()
	dict["BrushSettings"] = brush_settings.to_json()
	dict["EraserPencilSettings"] = eraser_pencil_settings.to_json()
	dict["EraserBrushSettings"] = eraser_brush_settings.to_json()
	return dict


func reload_from_json(dict: Dictionary) -> void:
	selected_tool = dict["SelectedTool"]
	
	var pensett: Dictionary = dict["PencilSettings"]
	pencil_settings.size = int(pensett["size"])
	pencil_settings.color = Color(pensett["color.r"], pensett["color.g"], pensett["color.b"], pensett["color.a"])
	
	var eraserpensett: Dictionary = dict["EraserPencilSettings"]
	eraser_pencil_settings.size = int(eraserpensett["size"])
	
	var brushsett: Dictionary = dict["BrushSettings"]
	brush_settings.size = float(brushsett["size"])
	brush_settings.color = Color(brushsett["color.r"], brushsett["color.g"], brushsett["color.b"], brushsett["color.a"])
	brush_settings.use_pressure_for_size = bool(brushsett["use_pressure"])
	brush_settings.min_pressure = float(brushsett["min_pressure"])
	
	var eraserbrushsett: Dictionary = dict["EraserBrushSettings"]
	eraser_brush_settings.size = float(eraserbrushsett["size"])
	eraser_brush_settings.use_pressure_for_size = bool(eraserbrushsett["use_pressure"])
	eraser_brush_settings.min_pressure = float(eraserbrushsett["min_pressure"])
