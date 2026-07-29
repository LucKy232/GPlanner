class_name ObjectList extends Control

@export_file("*.tscn") var list_text_entry_scene
@export_file("*.tscn") var div_scene
@onready var add_button: Button = %AddButton
@onready var object_v_box: VBoxContainer = %ObjectVBox
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var mouse_hover: Area2D = $MouseHover
@onready var mouse_hover_shape: CollisionShape2D = $MouseHover/MouseHoverShape
var id: int = -1
var entries: Array[ListTextEntry]
#var entry_divs: Dictionary[ListTextEntry, Panel]
var dragger: ListDragHelper = ListDragHelper.new()
var canvas_scale: float = 1.0

signal list_changed
signal filtered_gui_input


func _ready() -> void:
	_on_hover(false)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is ListTextEntry:
		if dragger.is_dragging:
			print("Drag Same List ", _at_position)
			return false
		else:
			print("Drag Different List ", _at_position)
			return true
	else:
		return false
	# TODO visually show at_position + move others with dragger


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if data is ListTextEntry:
		data.remove_from_list.emit()
		data.reparent(object_v_box, false)
		entries.append(data)
		reset_entry_ids()
		connect_list_text_entry(data)
		# TODO position at_position
		# TODO reorder IDs based on dropped position


func add_text_entry(is_user_input: bool) -> void:
	var new_list_text_entry: ListTextEntry = load(list_text_entry_scene).instantiate()
	#var new_div: Panel = load(div_scene).instantiate()
	object_v_box.add_child(new_list_text_entry)
	#object_v_box.add_child(new_div)
	new_list_text_entry.id = entries.size()
	new_list_text_entry.name = "ListTextEntry"
	entries.append(new_list_text_entry)
	#entry_divs[new_list_text_entry] = new_div
	connect_list_text_entry(new_list_text_entry)
	if is_user_input:
		list_changed.emit()


func connect_list_text_entry(entry: ListTextEntry) -> void:
	entry.erase_button.pressed.connect(_on_list_text_entry_erase.bind(entry))
	entry.grabber_moved.connect(_on_list_text_entry_grabber_moved)
	entry.grabber_started_move.connect(_on_list_text_entry_grabber_started_move)
	entry.grabber_ended_move.connect(_on_list_text_entry_grabber_ended_move)
	entry.text_changed.connect(_on_list_text_entry_text_changed)
	entry.remove_from_list.connect(_on_list_text_entry_remove_from_list.bind(entry))


func disconnect_list_text_entry(entry: ListTextEntry) -> void:
	entry.erase_button.pressed.disconnect(_on_list_text_entry_erase)
	entry.grabber_moved.disconnect(_on_list_text_entry_grabber_moved)
	entry.grabber_started_move.disconnect(_on_list_text_entry_grabber_started_move)
	entry.grabber_ended_move.disconnect(_on_list_text_entry_grabber_ended_move)
	entry.text_changed.disconnect(_on_list_text_entry_text_changed)
	entry.remove_from_list.disconnect(_on_list_text_entry_remove_from_list)


func change_size(delta_size: Vector2) -> void:
	size += delta_size


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
	reset_entry_ids()


# Set new IDs in list index (ascending) order
func reset_entry_ids() -> void:
	for i in range(0, entries.size()):
		entries[i].id = i


func rebuild_from_dict(dict: Dictionary) -> void:
	id = dict["id"]
	size = Vector2(dict["size.x"], dict["size.y"])
	position = Vector2(dict["pos.x"], dict["pos.y"])
	for entry_id in dict["entries"]:
		add_text_entry(false)
		entries[-1].rebuild_from_dict(dict["entries"][entry_id])
		#print("Added ", entry_id)
	# TODO sort in entry.id order if they don't get saved in order in the .json???


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
	reset_entry_ids()
	entry.queue_free()
	list_changed.emit()


func _on_list_text_entry_remove_from_list(entry: ListTextEntry) -> void:
	disconnect_list_text_entry(entry)
	entries.erase(entry)
	reset_entry_ids()
	list_changed.emit()


func _on_mouse_hover_mouse_entered() -> void:
	_on_hover(true)


func _on_mouse_hover_mouse_exited() -> void:
	_on_hover(false)


func _on_resized() -> void:
	if !is_node_ready():
		return
	mouse_hover_shape.shape.size = size
	mouse_hover.position = size * 0.5


func _on_list_text_entry_text_changed() -> void:
	list_changed.emit()


func _on_list_text_entry_grabber_started_move(entry_id: int, event_pos: Vector2) -> void:
	if entries.size() <= entry_id:
		push_error("Entry ID %d Invalid!" % [entry_id])
		return
	dragger.start_drag(entry_id, entries, event_pos)
	scroll_container.clip_contents = false


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
	scroll_container.clip_contents = true
	print("ENDED")


func _on_gui_input(event: InputEvent) -> void:
	if dragger.is_dragging:
		return
	filtered_gui_input.emit(event)
