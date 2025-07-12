class_name SaveState

var action_type: int = -1
var needs_to_save_images: bool = false
var has_changes: bool = false
#var ignore_save: bool = false # TODO no?

enum RequestedActionType {
	NEW_BUTTON,
	LOAD_BUTTON,
	CLOSE_TAB_BUTTON,
	CONFIRMATION_TAB,
}


func _init() -> void:
	action_type = -1
	needs_to_save_images = false
	has_changes = false


func has_requested_action() -> bool:
	return action_type >= 0 and action_type < RequestedActionType.size()


func set_requested_action(act: RequestedActionType) -> void:
	if act >= 0 and act < RequestedActionType.size():
		action_type = act
	else:
		printerr("Wrong save action type index in planner_canvas.gd:set_requested_save_action()")


func reset_requested_action() -> void:
	action_type = -1


func is_ready_to_save() -> bool:
	return !needs_to_save_images# or ignore_save
