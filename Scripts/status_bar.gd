class_name StatusBar extends Control

@onready var status_label_file: StatusLabel = %StatusLabelFile
@export var status_labels: Dictionary[int, StatusLabel]
var active: Array[int]
var inactive: Array[int]


func _ready() -> void:
	add_inactive_label_ids()


func add_inactive_label_ids() -> void:
	for id in status_labels:
		inactive.append(id)
		status_labels[id].hidden.connect(_on_status_label_hidden.bind(id))



func update_status_file(new_text: String, bg_color := Color(0.6, 0.6, 0.6, 0.45)) -> void:
	status_label_file.show_message_then_hide(new_text, bg_color)
	status_label_file.move_to_front()


func add_status_message(new_text: String, bg_color := Color(0.6, 0.6, 0.6, 0.45)) -> void:
	if inactive.size() > 0:
		var first_inactive: int = inactive.pop_back()
		active.append(first_inactive)
		status_labels[first_inactive].move_to_front()
		status_labels[first_inactive].show_message_then_hide(new_text, bg_color)
	else:
		var first_in: int = active.pop_front()
		active.append(first_in)
		status_labels[first_in].move_to_front()
		status_labels[first_in].show_message_then_hide(new_text, bg_color)


func _on_status_label_hidden(id: int) -> void:
	print("Hidden")
	if active.has(id):
		active.erase(id)
	inactive.append(id)
