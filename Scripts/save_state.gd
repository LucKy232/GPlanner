class_name SaveState

var action_type: int = -1
var needs_to_save_images: bool = false
var has_changes: bool = false
var is_loaded: bool = false


func _init() -> void:
	action_type = -1
	needs_to_save_images = false
	has_changes = false


func has_requested_action() -> bool:
	return action_type >= 0 and action_type < Enums.RequestedActionType.size()


func set_requested_action(act: Enums.RequestedActionType) -> void:
	if act >= 0 and act < Enums.RequestedActionType.size():
		action_type = act
	else:
		printerr("Wrong save action type index in planner_canvas.gd:set_requested_save_action()")


func reset_requested_action() -> void:
	action_type = -1


func is_ready_to_save() -> bool:
	return !needs_to_save_images
