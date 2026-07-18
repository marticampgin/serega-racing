extends SceneTree

const CourseLayoutScript := preload("res://scripts/course_layout.gd")
const WorldBuilderScript := preload("res://scripts/world_builder.gd")
const DetailBuilderScript := preload("res://scripts/neighborhood_detail_builder.gd")
const BlockScript := preload("res://scripts/editor/editable_world_block.gd")

const WORLD_PATH := "res://scenes/world/editable_world.tscn"


func _initialize() -> void:
	call_deferred("_migrate")


func _migrate() -> void:
	var packed := load(WORLD_PATH) as PackedScene
	if packed == null:
		push_error("FULLY EDITABLE WORLD: cannot load %s" % WORLD_PATH)
		quit(1)
		return
	var world := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	root.add_child(world)
	if world.get_node_or_null("EditableBlocks") != null:
		push_error("FULLY EDITABLE WORLD: EditableBlocks already exists; refusing to overwrite authored block edits")
		quit(2)
		return

	# Build the connective scenery against the user's latest saved placements.
	# This deliberately skips the old compaction pass: every lamp, fence panel,
	# path panel, bush and dock segment remains a selectable editor object.
	var course: CourseLayout = CourseLayoutScript.load_default()
	var infrastructure := Node3D.new()
	infrastructure.name = "TerrainSampler"
	root.add_child(infrastructure)
	var terrain: WorldBuilder = WorldBuilderScript.new()
	terrain.build_infrastructure(infrastructure, course, world)
	var staging := Node3D.new()
	staging.name = "EditableDetailStaging"
	root.add_child(staging)
	var builder := DetailBuilderScript.new()
	builder.build(staging, course, terrain, world)

	var members_by_block: Dictionary = {}
	var district_by_block: Dictionary = {}
	for value in staging.find_children("*", "Node3D", true, false):
		var detail := value as Node3D
		if not detail.has_meta("neighborhood_detail"):
			continue
		var block_id := str(detail.get_meta("detail_block_id", ""))
		if block_id.is_empty():
			continue
		if not members_by_block.has(block_id):
			members_by_block[block_id] = {"buildings": [] as Array[Node3D], "decor": [] as Array[Node3D]}
		(members_by_block[block_id].decor as Array[Node3D]).append(detail)
		district_by_block[block_id] = str(detail.get_meta("detail_district", "other"))

	# Planned buildings already carry the same stable block id as their details.
	for value in world.find_children("*", "Node3D", true, false):
		var building := value as Node3D
		if not building.is_in_group("building_layout") or not building.has_meta("layout_block_id"):
			continue
		var block_id := str(building.get_meta("layout_block_id"))
		if not members_by_block.has(block_id):
			members_by_block[block_id] = {"buildings": [] as Array[Node3D], "decor": [] as Array[Node3D]}
		(members_by_block[block_id].buildings as Array[Node3D]).append(building)
		if not district_by_block.has(block_id):
			district_by_block[block_id] = str(building.get_meta("layout_district", "other"))

	# Connect each standalone detail group with the closest standalone building.
	var standalone_buildings: Array[Node3D] = []
	for value in world.find_children("*", "Node3D", true, false):
		var building := value as Node3D
		if building.is_in_group("building_scenery") and not building.is_in_group("building_layout") and building.has_meta("course_offset"):
			standalone_buildings.append(building)
	var claimed_standalone: Dictionary = {}
	for block_id: String in members_by_block:
		if not block_id.begins_with("standalone_"):
			continue
		var decor := members_by_block[block_id].decor as Array[Node3D]
		var centre := _centre_of(decor)
		var closest: Node3D
		var closest_distance := INF
		for building in standalone_buildings:
			if claimed_standalone.has(building.get_instance_id()):
				continue
			var distance := Vector2(building.global_position.x, building.global_position.z).distance_to(Vector2(centre.x, centre.z))
			if distance < closest_distance:
				closest = building
				closest_distance = distance
		if closest != null:
			(members_by_block[block_id].buildings as Array[Node3D]).append(closest)
			claimed_standalone[closest.get_instance_id()] = true

	var blocks_root := Node3D.new()
	blocks_root.name = "EditableBlocks"
	blocks_root.add_to_group("editable_blocks_root", true)
	blocks_root.add_to_group("neighborhood_details_root", true)
	world.add_child(blocks_root)
	blocks_root.owner = world

	var block_ids: Array = members_by_block.keys()
	block_ids.sort()
	var moved_buildings := 0
	var moved_details := 0
	for block_id_value in block_ids:
		var block_id := str(block_id_value)
		var members: Dictionary = members_by_block[block_id]
		var buildings := members.buildings as Array[Node3D]
		var decor := members.decor as Array[Node3D]
		if buildings.is_empty() and decor.is_empty():
			continue
		var combined: Array[Node3D] = []
		combined.append_array(buildings)
		combined.append_array(decor)
		var block := Node3D.new()
		block.name = _safe_block_name(block_id)
		block.set_script(BlockScript)
		block.set("block_id", block_id)
		block.set("district", str(district_by_block.get(block_id, "other")))
		block.position = _centre_of(combined)
		block.add_to_group("editable_neighborhood_block", true)
		block.set_meta("copy_as_unit", true)
		block.set_meta("_edit_group_", false)
		blocks_root.add_child(block)
		block.owner = world
		var buildings_folder := Node3D.new()
		buildings_folder.name = "Buildings"
		block.add_child(buildings_folder)
		buildings_folder.owner = world
		var decor_folder := Node3D.new()
		decor_folder.name = "Decor"
		block.add_child(decor_folder)
		decor_folder.owner = world
		for building in buildings:
			building.reparent(buildings_folder, true)
			building.set_meta("_edit_group_", true)
			moved_buildings += 1
		for detail in decor:
			detail.reparent(decor_folder, true)
			detail.set_meta("_edit_group_", true)
			detail.owner = world
			_set_owned(detail, world)
			moved_details += 1

	_persist_groups(blocks_root)
	var output := PackedScene.new()
	var pack_error := output.pack(world)
	if pack_error != OK:
		push_error("FULLY EDITABLE WORLD: pack failed: %s" % error_string(pack_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(output, WORLD_PATH)
	if save_error != OK:
		push_error("FULLY EDITABLE WORLD: save failed: %s" % error_string(save_error))
		quit(1)
		return
	print("FULLY EDITABLE WORLD: saved %d blocks, %d buildings and %d individual decor objects" % [
		blocks_root.get_child_count(), moved_buildings, moved_details,
	])
	root.remove_child(world)
	world.free()
	root.remove_child(staging)
	staging.free()
	root.remove_child(infrastructure)
	infrastructure.free()
	quit(0)


func _centre_of(nodes: Array[Node3D]) -> Vector3:
	if nodes.is_empty():
		return Vector3.ZERO
	var centre := Vector3.ZERO
	for node in nodes:
		centre += node.global_position
	centre /= float(nodes.size())
	return centre


func _safe_block_name(block_id: String) -> String:
	var result := block_id.to_pascal_case()
	return result if not result.is_empty() else "EditableBlock"


func _set_owned(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		_set_owned(child, scene_owner)


func _persist_groups(node: Node) -> void:
	for group: StringName in node.get_groups():
		node.remove_from_group(group)
		node.add_to_group(group, true)
	for child in node.get_children():
		_persist_groups(child)
