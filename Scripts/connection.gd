extends Line2D
class_name Connection

var has_p1: bool = false
var has_p2: bool = false
var p1: Vector2
var p2: Vector2
var size_1: Vector2
var size_2: Vector2


func update_p1(pos: Vector2, size: Vector2) -> void:
	p1 = pos
	size_1 = size
	has_p1 = true


func update_p2(pos: Vector2, size: Vector2) -> void:
	p2 = pos
	size_2 = size
	has_p2 = true


func update_positions() -> void:
	if has_p1 and has_p2:
		#var offset1: float = Vector2.ZERO.distance_to(size_1 / 2.0)	# Circle radius on which the connection sits
		#var offset2: float = Vector2.ZERO.distance_to(size_2 / 2.0)
		var distance: float = p1.distance_to(p2)
		points[0] = p1 + size_1 / 2.0 + (p2 - p1) * ((size_1 * 0.5 + Vector2(20.0, 20.0) * size_1.normalized()) / distance)
		points[1] = p2 + size_2 / 2.0 + (p1 - p2) * ((size_2 * 0.5 + Vector2(20.0, 20.0) * size_2.normalized()) / distance)
