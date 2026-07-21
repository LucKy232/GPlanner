class_name ObjectList extends Control

@export_file("*.tscn") var list_text_entry_scene
@export_file("*.tscn") var div_scene
@onready var add_button: Button = %AddButton
@onready var object_v_box: VBoxContainer = %ObjectVBox
@onready var mouse_input: Area2D = $MouseInput
@onready var mouse_input_shape: CollisionShape2D = $MouseInput/MouseInputShape
var id: int = -1
var entries: Array[ListTextEntry]
var entry_divs: Dictionary[ListTextEntry, Panel]


func _ready() -> void:
	size = Vector2(500.0, 500.0)


func add_text() -> void:
	var new_list_text_entry: ListTextEntry = load(list_text_entry_scene).instantiate()
	var new_div: Panel = load(div_scene).instantiate()
	object_v_box.add_child(new_list_text_entry)
	object_v_box.add_child(new_div)
	entries.append(new_list_text_entry)
	entry_divs[new_list_text_entry] = new_div
	new_list_text_entry.erase_button.pressed.connect(_on_list_text_entry_erase.bind(new_list_text_entry))


func change_size(delta_size: Vector2) -> void:
	size += delta_size


func _on_add_button_pressed() -> void:
	add_text()


func _on_list_text_entry_erase(entry: ListTextEntry) -> void:
	if entry_divs.has(entry):
		entry_divs[entry].queue_free()
	entries.erase(entry)
	entry.queue_free()


func _on_mouse_input_mouse_entered() -> void:
	add_button.visible = true


func _on_mouse_input_mouse_exited() -> void:
	add_button.visible = false


func _on_resized() -> void:
	mouse_input_shape.shape.size = size
	mouse_input.position = size * 0.5
