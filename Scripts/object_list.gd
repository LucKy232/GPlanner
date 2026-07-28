class_name ObjectList extends Control

@export_file("*.tscn") var list_text_entry_scene
@export_file("*.tscn") var div_scene
@onready var add_button: Button = %AddButton
@onready var object_v_box: VBoxContainer = %ObjectVBox
@onready var mouse_input: Area2D = $MouseInput
@onready var mouse_input_shape: CollisionShape2D = $MouseInput/MouseInputShape
var id: int = -1
var entries: Array[ListTextEntry]
#var entry_divs: Dictionary[ListTextEntry, Panel]
var dragger: ListDragHelper = ListDragHelper.new()
var canvas_scale: float = 1.0
var drag_inside_lowest_id: int = -1
var drag_inside_highest_id: int = -1
var drag_inside_position_id: int = -1

signal list_changed


func _ready() -> void:
	_on_hover(false)


func add_text_entry(is_user_input: bool) -> void:
	var new_list_text_entry: ListTextEntry = load(list_text_entry_scene).instantiate()
	#var new_div: Panel = load(div_scene).instantiate()
	object_v_box.add_child(new_list_text_entry)
	#object_v_box.add_child(new_div)
	new_list_text_entry.id = entries.size()
	new_list_text_entry.name = "ListTextEntry"
	entries.append(new_list_text_entry)
	#entry_divs[new_list_text_entry] = new_div
	new_list_text_entry.erase_button.pressed.connect(_on_list_text_entry_erase.bind(new_list_text_entry))
	new_list_text_entry.grabber_moved.connect(_on_list_text_entry_grabber_moved.bind(new_list_text_entry.id))
	new_list_text_entry.grabber_started_move.connect(_on_list_text_entry_grabber_started_move.bind(new_list_text_entry.id))
	new_list_text_entry.grabber_ended_move.connect(_on_list_text_entry_grabber_ended_move.bind(new_list_text_entry.id))
	new_list_text_entry.text_changed.connect(_on_list_text_entry_text_changed)
	if is_user_input:
		list_changed.emit()


func change_size(delta_size: Vector2) -> void:
	size += delta_size


func rebuild_from_dict(dict: Dictionary) -> void:
	id = dict["id"]
	size = Vector2(dict["size.x"], dict["size.y"])
	position = Vector2(dict["pos.x"], dict["pos.y"])
	for entry_id in dict["entries"]:
		add_text_entry(false)
		entries[-1].rebuild_from_dict(dict["entries"][entry_id])
		#print("Added ", entry_id)
	# TODO sort in entry_id order if they don't get saved in order in the .json???


# Map order to entry
func to_json() -> Dictionary:
	var dict: Dictionary
	dict["entries"] = {}
	for entry in entries:
		var entry_id: int = entry.id
		dict["entries"][entry_id] = entry.to_json()
	dict["id"] = id
	dict["pos.x"] = position.x
	dict["pos.y"] = position.y
	dict["size.x"] = size.x
	dict["size.y"] = size.y
	return dict


func _on_hover(on: bool) -> void:
	add_button.visible = on


func _on_add_button_pressed() -> void:
	add_text_entry(true)


func _on_list_text_entry_erase(entry: ListTextEntry) -> void:
	#if entry_divs.has(entry):
	#	entry_divs[entry].queue_free()
	entries.erase(entry)
	entry.queue_free()
	list_changed.emit()


func _on_mouse_input_mouse_entered() -> void:
	_on_hover(true)


func _on_mouse_input_mouse_exited() -> void:
	_on_hover(false)


func _on_resized() -> void:
	mouse_input_shape.shape.size = size
	mouse_input.position = size * 0.5


func _on_list_text_entry_text_changed() -> void:
	list_changed.emit()


func _on_list_text_entry_grabber_started_move(entry_id: int) -> void:
	if entries.size() <= entry_id:
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	dragger.start_drag(entry_id, entries)


func _on_list_text_entry_grabber_moved(event: InputEventMouseMotion, entry_id: int) -> void:
	if entries.size() <= entry_id:
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	entries[entry_id].offset_transform_position += event.relative / canvas_scale
	dragger.drag()


func _on_list_text_entry_grabber_ended_move(entry_id: int) -> void:
	if entries.size() <= entry_id:
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	if dragger.object_id != entry_id:
		push_error("Wrong drag ID")
		return
	var move_to: int = dragger.current
	dragger.end_drag()
	if entry_id != move_to:
		object_v_box.move_child(entries[entry_id], move_to)
		sort_entries(entry_id, move_to)
		list_changed.emit()


func sort_entries(move_entry_id: int, to_id: int) -> void:
	var reference: ListTextEntry = entries[move_entry_id]
	if move_entry_id > to_id:	# Moving entry down
		var idx: int = move_entry_id
		while idx > to_id:
			entries[idx] = entries[idx - 1]
			idx -= 1
	if move_entry_id < to_id:	# Moving entry up
		for idx in range(move_entry_id, to_id):
			entries[idx] = entries[idx + 1]
	entries[to_id] = reference
	# Set new IDs
	for i in range(0, entries.size()):
		entries[i].id = i
