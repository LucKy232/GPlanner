@abstract class_name CanvasElement extends Control

var id: int = -1

@abstract func select() -> void
@abstract func deselect() -> void
@abstract func change_size(new_size: Vector2) -> void
@abstract func get_bg_color() -> Color
@abstract func to_json() -> Dictionary
