class_name PresetFont extends RefCounted

var id: String = ""
var order_id: int = -1
var system_font: SystemFont


func new_empty(_order_id: int, _string_id: String, default_font_name: String) -> PresetFont:
	id = _string_id
	order_id = _order_id
	system_font = SystemFont.new()
	system_font.font_names = [default_font_name]
	return self


func new_from_system_font(_order_id: int, _string_id: String, font: SystemFont) -> PresetFont:
	id = _string_id
	order_id = _order_id
	system_font = font
	return self


func get_first_font_name() -> String:
	if system_font.font_names.size() > 0:
		return system_font.font_names[0]
	return ""


func set_font_name(name: String) -> void:
	system_font.set_deferred("font_names", [name])


func get_font_weight() -> int:
	return system_font.font_weight


func set_font_weight(value: int) -> void:
	system_font.font_weight = value


func get_msdf_enabled() -> bool:
	return system_font.multichannel_signed_distance_field


func set_msdf_size(value: int) -> void:
	system_font.msdf_size = value


func get_msdf_size() -> int:
	return system_font.msdf_size


func get_italic() -> bool:
	return system_font.font_italic


func set_italic(italic: bool) -> void:
	system_font.font_italic = italic


func set_msdf_enabled(toggled_on: bool) -> void:
	system_font.multichannel_signed_distance_field = toggled_on


func set_values_from_dict(_order_id: int, dict: Dictionary) -> void:
	if !system_font:
		push_error("Needs an existing SystemFont - shared resource")
		return
	order_id = _order_id
	set_all_values_from_dict(dict)


func rebuild_from_json(_order_id: int, dict: Dictionary) -> PresetFont:
	system_font = SystemFont.new()
	order_id = _order_id
	set_all_values_from_dict(dict)
	return self


func set_all_values_from_dict(dict: Dictionary) -> void:
	id = str(get_value_from_dict(dict, "id", ""))
	system_font.font_names = [get_value_from_dict(dict, "font_name", "")]
	system_font.font_weight = int(get_value_from_dict(dict, "weight", system_font.font_weight))
	system_font.multichannel_signed_distance_field = bool(get_value_from_dict(dict, "msdf_enabled", false))
	system_font.msdf_size = int(get_value_from_dict(dict, "msdf_size", 48))
	system_font.font_italic = bool(get_value_from_dict(dict, "italic", false))


func get_value_from_dict(dict: Dictionary, value_string_name: String, default_value: Variant) -> Variant:
	if dict.has(value_string_name):
		return dict[value_string_name]
	else:
		push_error("Value not found in dictionary %s" % [value_string_name])
		return default_value


func to_json() -> Dictionary:
	var dict: Dictionary
	dict["id"] = id
	dict["font_name"] = system_font.font_names[0]
	dict["weight"] = system_font.font_weight
	dict["msdf_enabled"] = system_font.multichannel_signed_distance_field
	dict["msdf_size"] = system_font.msdf_size
	dict["italic"] = system_font.font_italic
	return dict
