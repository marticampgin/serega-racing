@tool
class_name EditableWorldBlock
extends Node3D

@export var block_id := ""
@export var district := ""
@export_multiline var editing_tip := "Select this block root in the Scene tree to duplicate or move the complete block. Expand Buildings or Decor to edit individual objects."


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if block_id.is_empty():
		warnings.append("This editable block is missing its stable block id.")
	if get_node_or_null("Buildings") == null and get_node_or_null("Decor") == null:
		warnings.append("This editable block has no Buildings or Decor folder.")
	return warnings
