@tool
extends Node3D


func _enter_tree() -> void:
	add_to_group("manual_scenery_root", true)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for child in get_children():
		if child is Node3D and not child.is_in_group("manual_scenery"):
			warnings.append("%s is not a catalog preset and will not receive clearance validation." % child.name)
	return warnings
