class_name CustomTextEdit extends TextEdit


## Default unicode handling
func _handle_unicode_input(unicode_char: int, p_caret: int) -> void:
	if (p_caret >= get_caret_count() || p_caret < -1):
		return
	if (!editable):
		return
	
	start_action(EditAction.ACTION_TYPING)
	begin_multicaret_edit()
	for i in get_caret_count():
		if (p_caret == -1 && multicaret_edit_ignore_caret(i)):
			continue
		
		if (p_caret != -1 && p_caret != i):
			continue
		
		# Remove the old character if in insert mode and no selection.
		if (is_overtype_mode_enabled() && !has_selection(i)):
			# Make sure we don't try and remove empty space.
			var cl = get_caret_line(i)
			var cc = get_caret_column(i)
			if (cc < get_line(cl).length()):
				remove_text(cl, cc, cl, cc + 1);

		insert_text_at_caret(String.chr(unicode_char), i)
	end_multicaret_edit();
	end_action();
