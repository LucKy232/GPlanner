@abstract class_name CanvasElement extends Control

var id: int = -1

@abstract func select() -> void
@abstract func deselect() -> void
@abstract func change_size(new_size: Vector2) -> void
@abstract func get_bg_color() -> Color
@abstract func to_json() -> Dictionary
@abstract func set_priority_visible(toggled_on: bool) -> void
@abstract func set_priority_tool_enabled(toggled_on: bool) -> void
@abstract func change_style_preset(preset: PresetStyle) -> void
@abstract func unassign_style_preset() -> void
