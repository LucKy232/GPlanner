class_name DrawingSettings
var selected_tool: Enums.DrawingTool = Enums.DrawingTool.PENCIL
var pencil_settings: PencilSettings = PencilSettings.new()
var brush_settings: BrushSettings = BrushSettings.new()
var eraser_pencil_settings: EraserPencilSettings = EraserPencilSettings.new()
var eraser_brush_settings: EraserBrushSettings = EraserBrushSettings.new()

var drawing_straight: bool = false
var initial_straight_point: Vector2 = Vector2.ZERO
var direction: Direction = Direction.NONE
var SQRT2: float = sqrt(2.0)

enum Direction
{
	NONE,
	UPDOWN,
	LEFTRIGHT,
	DIAGONALUP,
	DIAGONALDOWN,
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
	var size_limits: Vector2 = Vector2(1.4, 1000.0)
	var size: float = 10.0:
		get:
			return clampf(size, size_limits.x, size_limits.y)
		set(value):
			size = clampf(value, size_limits.x, size_limits.y)
			min_pressure = clampf(1.0 / size, 0.001, 1.0)
	var color: Color = Color.WHITE
	var pressure: float = 1.0:
		get:
			return clampf(pressure, 0.001, 1.0)
		set(value):
			pressure = clampf(value, 0.001, 1.0)
	var min_pressure: float = 0.1
	
	func to_json() -> Dictionary:
		var dict: Dictionary = {}
		dict["size"] = size
		dict["color.r"] = color.r
		dict["color.g"] = color.g
		dict["color.b"] = color.b
		dict["color.a"] = color.a
		dict["pressure"] = pressure
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
	var size_limits: Vector2 = Vector2(1.4, 400.0)
	var size: float = 10.0:
		get:
			return clampf(size, size_limits.x, size_limits.y)
		set(value):
			size = clampf(value, size_limits.x, size_limits.y)
			min_pressure = clampf(1.0 / size, 0.001, 1.0)
	var pressure: float = 0.1:
		get:
			return clampf(pressure, 0.001, 1.0)
		set(value):
			pressure = clampf(value, 0.001, 1.0)
	var min_pressure: float = 0.1
	
	func to_json() -> Dictionary:
		var dict: Dictionary = {}
		dict["size"] = size
		dict["pressure"] = pressure
		return dict


func to_json() -> Dictionary:
	var dict: Dictionary = {}
	dict["SelectedTool"] = selected_tool
	dict["PencilSettings"] = pencil_settings.to_json()
	dict["BrushSettings"] = brush_settings.to_json()
	dict["EraserPencilSettings"] = eraser_pencil_settings.to_json()
	dict["EraserBrushSettings"] = eraser_brush_settings.to_json()
	return dict


func rebuild_from_json(dict: Dictionary) -> void:
	selected_tool = dict["SelectedTool"]
	
	var pensett: Dictionary = dict["PencilSettings"]
	pencil_settings.size = int(pensett["size"])
	pencil_settings.color = Color(pensett["color.r"], pensett["color.g"], pensett["color.b"], pensett["color.a"])
	
	var eraserpensett: Dictionary = dict["EraserPencilSettings"]
	eraser_pencil_settings.size = int(eraserpensett["size"])
	
	var brushsett: Dictionary = dict["BrushSettings"]
	brush_settings.size = float(brushsett["size"])
	brush_settings.color = Color(brushsett["color.r"], brushsett["color.g"], brushsett["color.b"], brushsett["color.a"])
	if brushsett.has("pressure"):
		brush_settings.pressure = float(brushsett["pressure"])
	
	var eraserbrushsett: Dictionary = dict["EraserBrushSettings"]
	eraser_brush_settings.size = float(eraserbrushsett["size"])
	if eraserbrushsett.has("pressure"):
		eraser_brush_settings.pressure = float(eraserbrushsett["pressure"])


func toggle_draw_straight(toggled_on: bool) -> void:
	if toggled_on:
		drawing_straight = true
	else:
		drawing_straight = false
		initial_straight_point = Vector2.ZERO
		direction = Direction.NONE


func find_direction(p1: Vector2, p2: Vector2) -> void:
	initial_straight_point = p1
	var diff: Vector2 = p2 - p1
	var ang: float = atan2(diff.y, diff.x) * 180.0 / PI
	var margin: float = 22.5
	
	if (ang > -90.0 - margin and ang <= -90.0 + margin) or (ang > 90.0 - margin and ang <= 90.0 + margin):
		direction = Direction.UPDOWN
	elif (ang > -45.0 - margin and ang <= -45 + margin) or (ang > 135.0 - margin and ang <= 135.0 + margin):
		direction = Direction.DIAGONALUP
	elif (ang > 0.0 - margin and ang <= 0.0 + margin) or (ang > 180.0 - margin or ang < -180.0 + margin):
		direction = Direction.LEFTRIGHT
	elif (ang > 45.0 - margin and ang <= 45.0 + margin) or (ang > -135.0 - margin and ang <= -135.0 + margin):
		direction = Direction.DIAGONALDOWN


func get_next_straight_point(p: Vector2) -> Vector2:
	match direction:
		Direction.UPDOWN:
			return Vector2(initial_straight_point.x, p.y)
		Direction.LEFTRIGHT:
			return Vector2(p.x, initial_straight_point.y)
		Direction.DIAGONALUP:
			var dist: float = initial_straight_point.distance_to(p)
			var mult: float = 1.0 if p.x > initial_straight_point.x else -1.0
			return initial_straight_point + Vector2(1.0, -1.0) * dist * mult / SQRT2
		Direction.DIAGONALDOWN:
			var dist: float = initial_straight_point.distance_to(p)
			var mult: float = 1.0 if p.x > initial_straight_point.x else -1.0
			return initial_straight_point + Vector2(1.0, 1.0) * dist * mult / SQRT2
		Direction.NONE:
			return p
		_:
			return p
