class_name SettingsDrawer extends Control

@onready var show_completed: CheckBox = %ShowCompleted
@onready var show_priorities: CheckBox = %ShowPriorities
@onready var show_priority_tool: CheckBox = %ShowPriorityTool
@onready var priority_filter_label: Label = %PriorityFilterLabel
@onready var priority_filter: HScrollBar = %PriorityFilter
@onready var toggle_drawer: Button = %ToggleDrawer
@onready var background: Panel = %Background
@onready var tween_show_hide: TweenShowHide = %TweenShowHide

@export var priority_filter_text: Array[String]
@export var icon_hidden: CompressedTexture2D
@export var icon_shown: CompressedTexture2D

var checkboxes: Array[CheckBox] = []


func _ready() -> void:
	toggle_drawer.set_pressed_no_signal(true)
	_on_toggle_drawer_toggled(true)
	checkboxes = [show_priorities, show_priority_tool, show_completed]


func set_accent_color(c: Color) -> void:
	background.theme.get_stylebox("panel", "Panel").border_color = c
	priority_filter.theme.get_stylebox("scroll", "HScrollBar").border_color = c
	toggle_drawer.theme.get_stylebox("disabled", "Button").border_color = c
	toggle_drawer.theme.get_stylebox("hover", "Button").border_color = c
	toggle_drawer.theme.get_stylebox("normal", "Button").border_color = c
	toggle_drawer.theme.get_stylebox("pressed", "Button").border_color = c


# If the values are the same, the signal doesn't get sent
# Set the visual value and emit signal manually
func update_data(settings: SettingsStates) -> void:
	show_completed.set_pressed_no_signal(settings.checkbox_data[Enums.Checkbox.SHOW_COMPLETED])
	show_completed.toggled.emit.call_deferred(settings.checkbox_data[Enums.Checkbox.SHOW_COMPLETED])
	show_priorities.set_pressed_no_signal(settings.checkbox_data[Enums.Checkbox.SHOW_PRIORITIES])
	show_priorities.toggled.emit.call_deferred(settings.checkbox_data[Enums.Checkbox.SHOW_PRIORITIES])
	show_priority_tool.set_pressed_no_signal(settings.checkbox_data[Enums.Checkbox.SHOW_PRIORITY_TOOL])
	show_priority_tool.toggled.emit.call_deferred(settings.checkbox_data[Enums.Checkbox.SHOW_PRIORITY_TOOL])
	priority_filter.set_value_no_signal(settings.priority_filter_value)
	priority_filter.value_changed.emit.call_deferred(settings.priority_filter_value)


func _on_toggle_drawer_toggled(toggled_on: bool) -> void:
	tween_show_hide.toggle(toggled_on)
	if toggled_on:
		toggle_drawer.icon = icon_hidden
	else:
		toggle_drawer.icon = icon_shown


func _on_show_priorities_toggled(toggled_on: bool) -> void:
	show_priority_tool.visible = toggled_on
	priority_filter_label.visible = toggled_on
	priority_filter.visible = toggled_on


func _on_priority_filter_value_changed(value: float) -> void:
	priority_filter_label.text = ("Priority: %s" % priority_filter_text[int(value)])
