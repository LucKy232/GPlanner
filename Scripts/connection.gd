extends Line2D
class_name Connection

var has_p1: bool = false
var has_p2: bool = false
var p1: Vector2
var p2: Vector2
var size_1: Vector2
var size_2: Vector2


func _ready() -> void:
	gradient = gradient.duplicate()


func update_p1(pos: Vector2, size: Vector2) -> void:
	p1 = pos
	size_1 = size
	has_p1 = true


func update_p2(pos: Vector2, size: Vector2) -> void:
	p2 = pos
	size_2 = size
	has_p2 = true


func update_p1_color(color: Color) -> void:
	gradient.colors[0] = color
	gradient.colors[0].a = 1.0


func update_p2_color(color: Color) -> void:
	gradient.colors[1] = color
	gradient.colors[1].a = 1.0


func update_positions() -> void:
	if has_p1 and has_p2:
		var half_s1: Vector2 = size_1 * 0.5
		var half_s2: Vector2 = size_2 * 0.5
		var top_bottom: bool = segment_overlap(p1.x, size_1.x, p2.x, size_2.x, 25.0)
		
		if top_bottom:
			var side: int = signi(int(p1.y - p2.y))
			var offset1: Vector2 = -Vector2(0.0, (half_s1.y + 10.0) * side)
			var offset2: Vector2 = Vector2(0.0, (half_s2.y + 10.0) * side)
			points[0] = p1 + half_s1 + offset1
			points[3] = p2 + half_s2 + offset2
			
			var mid_x: float = snappedf((points[0].x + points[3].x) * 0.5, 10.0)
			var mid_y: float = snappedf((points[0].y + points[3].y) * 0.5, 10.0)
			if abs(points[0].x - points[3].x) < 10.0:
				points[0].x = mid_x
				points[3].x = mid_x
			else:
				points[0].x = snappedf(points[0].x, 10.0)
				points[3].x = snappedf(points[3].x, 10.0)
			
			points[1] = Vector2(points[0].x, mid_y)
			points[2] = Vector2(points[3].x, mid_y)
		else:
			var side: int = signi(int(p1.x - p2.x))
			var offset1: Vector2 = -Vector2((half_s1.x + 10.0) * side, 0.0)
			var offset2: Vector2 = Vector2((half_s2.x + 10.0) * side, 0.0)
			points[0] = p1 + half_s1 + offset1
			points[3] = p2 + half_s2 + offset2
		
			if abs(points[0].y - points[3].y) < 10.0:
				var mid_y: float = snappedf((points[0].y + points[3].y) * 0.5, 10.0)
				points[0].y = mid_y
				points[3].y = mid_y
			else:
				points[0].y = snappedf(points[0].y, 10.0)
				points[3].y = snappedf(points[3].y, 10.0)
			
			var mid_x: float = snappedf((points[0].x + points[3].x) * 0.5, 10.0)
			points[1] = Vector2(mid_x, points[0].y)
			points[2] = Vector2(mid_x, points[3].y)


func segment_overlap(p1x: float, s1: float, p2x: float, s2: float, margin: float) -> bool:
	var p1_left_inside: bool = p1x < (p2x + s2 + margin) and p1x > (p2x - margin)
	var p1_right_inside: bool = (p1x + s1) < (p2x + s2 + margin) and (p1x + s1) > (p2x - margin)
	var p2_left_inside: bool = p2x < (p1x + s1 + margin) and p2x > (p1x - margin)
	var p2_right_inside: bool = (p2x + s2) < (p1x + s1 + margin) and (p2x + s2) > (p1x - margin)
	return p1_left_inside or p1_right_inside or p2_left_inside or p2_right_inside
