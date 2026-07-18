extends SceneTree

const WORLD_PATH := "res://scenes/world/editable_world.tscn"
const FORBIDDEN_INFRASTRUCTURE_GROUPS := [
	&"track", &"road_boundary", &"bridge_boundary", &"bridge_support",
	&"tunnel_boundary", &"flyover_boundary", &"ocean_scenery", &"island_terrain",
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _run() -> void:
	var packed := load(WORLD_PATH) as PackedScene
	check(packed != null, "editable world scene loads")
	if packed == null:
		quit(1)
		return
	var world := packed.instantiate() as Node3D
	root.add_child(world)
	var blocks_root := world.get_node_or_null("EditableBlocks") as Node3D
	check(blocks_root != null, "editable block root is saved in the world")
	if blocks_root == null:
		quit(1)
		return
	var blocks := get_nodes_in_group("editable_neighborhood_block")
	var detail_roots: Array[Node3D] = []
	for value in get_nodes_in_group("neighborhood_detail_scenery"):
		if value is Node3D and blocks_root.is_ancestor_of(value):
			detail_roots.append(value)
	check(blocks.size() >= 30, "all neighborhood and standalone sites have duplicable block roots")
	check(detail_roots.size() >= 2500, "connective decor is stored as individual editor objects")
	check(blocks_root.find_children("*", "CollisionObject3D", true, false).is_empty(), "editable blocks remain visual-only")
	var hierarchy_valid := true
	var details_editable := true
	var buildings_editable := true
	for value in blocks:
		var block := value as Node3D
		hierarchy_valid = hierarchy_valid and block.get_node_or_null("Buildings") != null and block.get_node_or_null("Decor") != null
		hierarchy_valid = hierarchy_valid and bool(block.get_meta("copy_as_unit", false))
		hierarchy_valid = hierarchy_valid and not block.has_meta("_edit_group_")
	for detail in detail_roots:
		details_editable = details_editable and bool(detail.get_meta("_edit_group_", false))
		details_editable = details_editable and detail.owner == world
		details_editable = details_editable and detail.get_parent() != null and detail.get_parent().name == &"Decor"
		details_editable = details_editable and not detail.has_meta("detail_count")
	for value in get_nodes_in_group("building_layout"):
		if not value is Node3D or not world.is_ancestor_of(value):
			continue
		var building := value as Node3D
		buildings_editable = buildings_editable and bool(building.get_meta("_edit_group_", false))
		buildings_editable = buildings_editable and building.get_parent() != null and building.get_parent().name == &"Buildings"
	check(hierarchy_valid, "every block exposes Buildings and Decor folders and can be copied as a unit")
	check(details_editable, "every generated decor element is locally selectable and uncombined")
	check(buildings_editable, "planned buildings remain individually selectable inside their blocks")
	var sample := blocks[0] as Node3D
	var duplicate := sample.duplicate() as Node3D
	check(duplicate != null and duplicate.find_children("*", "Node", true, false).size() == sample.find_children("*", "Node", true, false).size(), "duplicating a block retains its complete building-and-decor hierarchy")
	if duplicate != null:
		duplicate.free()
	for group_name: StringName in FORBIDDEN_INFRASTRUCTURE_GROUPS:
		var found := false
		for value in get_nodes_in_group(group_name):
			if value is Node and world.is_ancestor_of(value):
				found = true
				break
		check(not found, "locked infrastructure remains outside the editable scene: %s" % group_name)
	root.remove_child(world)
	world.free()

	var race := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	check(race.get_node_or_null("EditableWorld/EditableBlocks") != null, "runtime uses the saved editable blocks")
	check(race.get_node_or_null("EditableWorld/NeighborhoodDetails") == null, "runtime does not duplicate the legacy detail overlay")
	print("FULLY EDITABLE WORLD QA: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
