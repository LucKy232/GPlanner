class_name SettingsStates
## Stores a file's (PlannerCanvas) settings states for settings that the user can change directly, not internal runtime data.

var checkbox_data: Array[bool]
var priority_filter_value: int = 0
var app_mode: Enums.AppMode = Enums.AppMode.PLANNING

func _init() -> void:
	checkbox_data.resize(Enums.Checkbox.size())
	for i in Enums.Checkbox.size():
		checkbox_data[i] = false
	priority_filter_value = Enums.Priority.NONE
