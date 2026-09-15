class_name GlobalScenes

const planner_canvas_scene: String = "uid://b1do6gcy6peum"
# Canvas objects
const text_element_scene: String = "uid://cdn8513i3j0ns"
const connection_scene: String = "uid://c4jirlcfvnhoj"
const object_list_scene: String = "uid://6odwhurrp3jx"
const list_text_entry_scene: String = "uid://q0me3hofnycc"
# Style settings
const style_select_button_scene: String = "uid://dvorb6p8oev77"
# Drawing
const canvas_drawing_group_scene: String = "uid://ciqbw443fikno"
const temp_drawing_action_scene: String = "uid://cpu02i5li1jfy"
const drawing_region_scene: String = "uid://cco3y5ld1vdkm"
const clipboard_image_scene: String = "uid://cph01rtbsrwne"


static func test_scene_paths() -> void:
	if ResourceUID.ensure_path(planner_canvas_scene) == "":
		push_error("Invalid UID for planner_canvas_scene!")
	if ResourceUID.ensure_path(text_element_scene) == "":
		push_error("Invalid UID for text_element_scene!")
	if ResourceUID.ensure_path(connection_scene) == "":
		push_error("Invalid UID for connection_scene!")
	if ResourceUID.ensure_path(object_list_scene) == "":
		push_error("Invalid UID for object_list_scene!")
	if ResourceUID.ensure_path(list_text_entry_scene) == "":
		push_error("Invalid UID for list_text_entry_scene!")
	if ResourceUID.ensure_path(style_select_button_scene) == "":
		push_error("Invalid UID for style_select_button_scene!")
	if ResourceUID.ensure_path(canvas_drawing_group_scene) == "":
		push_error("Invalid UID for canvas_drawing_group_scene!")
	if ResourceUID.ensure_path(temp_drawing_action_scene) == "":
		push_error("Invalid UID for temp_drawing_action_scene!")
	if ResourceUID.ensure_path(drawing_region_scene) == "":
		push_error("Invalid UID for drawing_region_scene!")
	if ResourceUID.ensure_path(clipboard_image_scene) == "":
		push_error("Invalid UID for clipboard_image_scene!")
