class_name ObjectList extends Control

@export_file("*.tscn") var list_text_entry_scene
@export_file("*.tscn") var div_scene
@onready var add_button: Button = %AddButton
@onready var object_v_box: VBoxContainer = %ObjectVBox
var entries: Array[ListTextEntry]
var entry_divs: Dictionary[ListTextEntry, Panel]


func add_text() -> void:
	var new_list_text_entry: ListTextEntry = load(list_text_entry_scene).instantiate()
	var new_div: Panel = load(div_scene).instantiate()
	object_v_box.add_child(new_list_text_entry)
	object_v_box.add_child(new_div)
	entries.append(new_list_text_entry)
	entry_divs[new_list_text_entry] = new_div
	new_list_text_entry.erase_button.pressed.connect(_on_list_text_entry_erase.bind(new_list_text_entry))


func _on_add_button_pressed() -> void:
	add_text()


func _on_list_text_entry_erase(entry: ListTextEntry) -> void:
	if entry_divs.has(entry):
		entry_divs[entry].queue_free()
	entries.erase(entry)
	entry.queue_free()
