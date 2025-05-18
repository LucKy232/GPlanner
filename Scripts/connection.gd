extends Line2D
class_name Connection

var has_p1: bool = false
var has_p2: bool = false
var p1: Vector2
var p2: Vector2
var size_1: Vector2
var size_2: Vector2
var TEST_MARGIN: float = 25.0
var CONNECTION_MARGIN: float = 10.0


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


# Assigning points[0] to p1 corresponding side, points[3] to p2 corresponding side & points[0] & points[1] as intermediaries
func update_positions() -> void:
	if !(has_p1 and has_p2):
		return
	
	var p1_on_top: bool = true if p1.y < p2.y else false
	var p1_on_left: bool = true if p1.x < p2.x else false
	var p1_left: bool = p1_left_inside(p1.x, size_1.x, p2.x, size_2.x, TEST_MARGIN)
	var p1_right: bool = p1_right_inside(p1.x, size_1.x, p2.x, size_2.x, TEST_MARGIN)
	var p2_left: bool = p2_left_inside(p1.x, size_1.x, p2.x, size_2.x, TEST_MARGIN)
	var p2_right: bool = p2_right_inside(p1.x, size_1.x, p2.x, size_2.x, TEST_MARGIN)
	
	if p1_left and p1_right and p2_left and p2_right:			# Top-Bottom = Full overlap
		points[0] = middle_of_bottom(p1, size_1) if p1_on_top else middle_of_top(p1, size_1)
		points[3] = middle_of_top(p2, size_2) if p1_on_top else middle_of_bottom(p2, size_2)
		if abs(points[0].x - points[3].x) < 10.0:	# Average x coord if in range to prevent very small difference in points[1] & points[2] for aesthetic reasons
			var mid_x: float = snappedf((points[0].x + points[3].x) * 0.5, 10.0)
			points[0].x = mid_x
			points[3].x = mid_x
		var mid_y: float = snappedf((points[0].y + points[3].y) * 0.5, 10.0)
		points[1] = Vector2(points[0].x, mid_y)
		points[2] = Vector2(points[3].x, mid_y)
	elif !p1_left and !p1_right and !p2_left and !p2_right:		# Side-Side = No overlap
		points[0] = right_side(p1, size_1) if p1_on_left else left_side(p1, size_1)
		points[3] = left_side(p2, size_2) if p1_on_left else right_side(p2, size_2)
		if abs(points[0].y - points[3].y) < 10.0:	# Average y coord if in range to prevent very small difference in points[1] & points[2] for aesthetic reasons
			var mid_y: float = snappedf((points[0].y + points[3].y) * 0.5, 10.0)
			points[0].y = mid_y
			points[3].y = mid_y
		var mid_x: float = snappedf((points[0].x + points[3].x) * 0.5, 10.0)
		points[1] = Vector2(mid_x, points[0].y)
		points[2] = Vector2(mid_x, points[3].y)
	elif p1_left or p1_right or p2_left or p2_right:			# Partial overlap: Top-Bottom or Top-Side
		if p1_on_top:
			points[0] = middle_of_bottom(p1, size_1)
			var overlap_middle: bool = false
			if p2_left or p1_right:
				overlap_middle = p2.x < p1.x + size_1.x * 0.5 + TEST_MARGIN
				points[3] = middle_of_top(p2, size_2) if overlap_middle else left_side(p2, size_2)
			elif p2_right or p1_left:
				overlap_middle = p2.x + size_2.x > p1.x + size_1.x * 0.5 - TEST_MARGIN
				points[3] = middle_of_top(p2, size_2) if overlap_middle else right_side(p2, size_2)
			if overlap_middle:
				if abs(points[0].x - points[3].x) < 10.0:	# Average x coord if in range to prevent very small difference in points[1] & points[2] for aesthetic reasons
					var mid_x: float = snappedf((points[0].x + points[3].x) * 0.5, 10.0)
					points[0].x = mid_x
					points[3].x = mid_x
				var mid_y: float = snappedf((points[0].y + points[3].y) * 0.5, 10.0)
				points[1] = Vector2(points[0].x, mid_y)
				points[2] = Vector2(points[3].x, mid_y)
			else:
				points[1] = Vector2(points[0].x, points[3].y)
				points[2] = Vector2(points[0].x, points[3].y)
		else:
			points[3] = middle_of_bottom(p2, size_2)
			var overlap_middle: bool = false
			if p1_left or p2_right:
				overlap_middle = p1.x < p2.x + size_2.x * 0.5 + TEST_MARGIN
				points[0] = middle_of_top(p1, size_1) if overlap_middle else left_side(p1, size_1)
			elif p1_right or p2_left:
				overlap_middle = p1.x + size_1.x > p2.x + size_2.x * 0.5 - TEST_MARGIN
				points[0] = middle_of_top(p1, size_1) if overlap_middle else right_side(p1, size_1)
			if overlap_middle:
				if abs(points[0].x - points[3].x) < 10.0:	# Average x coord if in range to prevent very small difference in points[1] & points[2] for aesthetic reasons
					var mid_x: float = snappedf((points[0].x + points[3].x) * 0.5, 10.0)
					points[0].x = mid_x
					points[3].x = mid_x
				var mid_y: float = snappedf((points[0].y + points[3].y) * 0.5, 10.0)
				points[1] = Vector2(points[0].x, mid_y)
				points[2] = Vector2(points[3].x, mid_y)
			else:
				points[1] = Vector2(points[3].x, points[0].y)
				points[2] = Vector2(points[3].x, points[0].y)


func middle_of_bottom(pos: Vector2, size: Vector2) -> Vector2:
	return Vector2(pos.x + size.x * 0.5, pos.y + size.y + CONNECTION_MARGIN)


func middle_of_top(pos: Vector2, size: Vector2) -> Vector2:
	return Vector2(pos.x + size.x * 0.5, pos.y - CONNECTION_MARGIN)


func left_side(pos: Vector2, size: Vector2) -> Vector2:
	return Vector2(pos.x - CONNECTION_MARGIN, pos.y + size.y * 0.5)


func right_side(pos: Vector2, size: Vector2) -> Vector2:
	return Vector2(pos.x + size.x + CONNECTION_MARGIN, pos.y + size.y * 0.5)


func p1_left_inside(p1x: float, _s1: float, p2x: float, s2: float, margin: float) -> bool:
	return p1x < (p2x + s2 + margin) and p1x > (p2x - margin)


func p1_right_inside(p1x: float, s1: float, p2x: float, s2: float, margin: float) -> bool:
	return (p1x + s1) < (p2x + s2 + margin) and (p1x + s1) > (p2x - margin)


func p2_left_inside(p1x: float, s1: float, p2x: float, _s2: float, margin: float) -> bool:
	return p2x < (p1x + s1 + margin) and p2x > (p1x - margin)


func p2_right_inside(p1x: float, s1: float, p2x: float, s2: float, margin: float) -> bool:
	return (p2x + s2) < (p1x + s1 + margin) and (p2x + s2) > (p1x - margin)


func segment_overlap(p1x: float, s1: float, p2x: float, s2: float, margin: float) -> bool:
	var p1_left: bool = p1_left_inside(p1x, s1, p2x, s2, margin)
	var p1_right: bool = p1_right_inside(p1x, s1, p2x, s2, margin)
	var p2_left: bool = p2_left_inside(p1x, s1, p2x, s2, margin)
	var p2_right: bool = p2_right_inside(p1x, s1, p2x, s2, margin)
	#print("P1 left: %s    P1 right: %s    P2 left: %s    P2 right: %s    P1R == P2L: %s    P1L == P2R: %s" % [str(p1_left), str(p1_right), str(p2_left), str(p2_right), str(p1_right==p2_left), str(p1_left==p2_right)])
	return p1_left or p1_right or p2_left or p2_right
