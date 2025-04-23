extends Control

@onready var show_completed: CheckBox = $PanelContainer/HBoxContainer/Background/MarginContainer/Scroll/Settings/ShowCompleted
@onready var show_priorities: CheckBox = $PanelContainer/HBoxContainer/Background/MarginContainer/Scroll/Settings/ShowPriorities
@onready var show_priority_tool: CheckBox = $PanelContainer/HBoxContainer/Background/MarginContainer/Scroll/Settings/ShowPriorityTool
@onready var priority_filter_label: Label = $PanelContainer/HBoxContainer/Background/MarginContainer/Scroll/Settings/PriorityFilterLabel
@onready var priority_filter: HScrollBar = $PanelContainer/HBoxContainer/Background/MarginContainer/Scroll/Settings/PriorityFilter
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var checkboxes: Array[CheckBox] = []

enum Checkbox {
	SHOW_PRIORITIES,
	SHOW_PRIORITY_TOOL,
	SHOW_COMPLETED,
}

func _ready() -> void:
	checkboxes = [show_priorities, show_priority_tool, show_completed]


func get_checkbox_object(id: int) -> CheckBox:
	return checkboxes[id]


func get_priority_filter() -> HScrollBar:
	return priority_filter


func get_priority_filter_label() -> Label:
	return priority_filter_label


func _on_toggle_drawer_toggled(toggled_on: bool) -> void:
	if toggled_on and !animation_player.is_playing():
		animation_player.play("toggle_settings_drawer_on")
	elif !toggled_on and !animation_player.is_playing():
		animation_player.play("toggle_settings_drawer_off")
