extends SceneTree

const CourseLayoutScript := preload("res://scripts/course_layout.gd")
const WorldBuilderScript := preload("res://scripts/world_builder.gd")
const DetailBuilderScript := preload("res://scripts/neighborhood_detail_builder.gd")

const EDITABLE_WORLD_PATH := "res://scenes/world/editable_world.tscn"
const OUTPUT_PATH := "res://scenes/world/neighborhood_details.tscn"


func _initialize() -> void:
	call_deferred("_generate")


func _generate() -> void:
	var packed_world := load(EDITABLE_WORLD_PATH) as PackedScene
	if packed_world == null:
		push_error("Cannot load edited world: %s" % EDITABLE_WORLD_PATH)
		quit(1)
		return
	var editable := packed_world.instantiate() as Node3D
	editable.name = "EditedWorldReservationSource"
	root.add_child(editable)
	var nested_details := editable.get_node_or_null("NeighborhoodDetails")
	if nested_details != null:
		editable.remove_child(nested_details)
		nested_details.free()

	var course: CourseLayout = CourseLayoutScript.load_default()
	var infrastructure := Node3D.new()
	infrastructure.name = "TerrainSampler"
	root.add_child(infrastructure)
	var terrain: WorldBuilder = WorldBuilderScript.new()
	terrain.build_infrastructure(infrastructure, course, editable)

	var details := Node3D.new()
	details.name = "NeighborhoodDetails"
	details.add_to_group("neighborhood_details_root", true)
	root.add_child(details)
	var builder = DetailBuilderScript.new()
	builder.build(details, course, terrain, editable)
	_compact_repeating_details(details)
	_persist_groups(details)
	_set_owned(details, details)

	var packed := PackedScene.new()
	var pack_error := packed.pack(details)
	if pack_error != OK:
		push_error("Could not pack neighborhood details: %s" % error_string(pack_error))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var save_error := ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		push_error("Could not save neighborhood details: %s" % error_string(save_error))
		quit(1)
		return
	print("NEIGHBORHOOD DETAILS: saved %d organized roots / %d meshes to %s" % [
		_count_detail_roots(details),
		details.find_children("*", "MeshInstance3D", true, false).size(),
		OUTPUT_PATH,
	])
	quit(0)


func _count_detail_roots(details: Node3D) -> int:
	var count := 0
	for value in details.find_children("*", "Node3D", true, false):
		if value.has_meta("neighborhood_detail"):
			count += 1
	return count


func _compact_repeating_details(details: Node3D) -> void:
	# Terrain-following panels are authored as short pieces, then baked into one
	# mesh per material/block/side. This keeps curves and grounding intact without
	# turning thousands of tiny pieces into thousands of runtime draw calls.
	var compact_kinds := ["sidewalk", "rear_walk", "fence", "bush", "dock"]
	var batches: Dictionary = {}
	for value in details.find_children("*", "Node3D", true, false):
		var detail := value as Node3D
		var kind := str(detail.get_meta("detail_kind", ""))
		if kind not in compact_kinds:
			continue
		var key := "%s|%s|%d" % [str(detail.get_meta("detail_block_id", "")), kind, int(detail.get_meta("detail_side", 0))]
		if not batches.has(key):
			batches[key] = [] as Array[Node3D]
		(batches[key] as Array[Node3D]).append(detail)

	for key: String in batches:
		var members := batches[key] as Array[Node3D]
		if members.size() < 2:
			continue
		var sample := members[0]
		var parent := sample.get_parent() as Node3D
		var merged := Node3D.new()
		merged.name = "%sNetwork" % key.replace("|", "_").to_pascal_case()
		merged.add_to_group("neighborhood_detail_scenery")
		merged.add_to_group("neighborhood_%s" % str(sample.get_meta("detail_kind")))
		merged.add_to_group("%s_scenery" % str(sample.get_meta("detail_district")))
		merged.set_meta("neighborhood_detail", true)
		merged.set_meta("detail_kind", str(sample.get_meta("detail_kind")))
		merged.set_meta("detail_district", str(sample.get_meta("detail_district")))
		merged.set_meta("detail_block_id", str(sample.get_meta("detail_block_id")))
		merged.set_meta("detail_side", int(sample.get_meta("detail_side")))
		merged.set_meta("detail_count", members.size())
		merged.set_meta("_edit_group_", true)
		parent.add_child(merged, true)

		var surfaces: Dictionary = {}
		for member in members:
			for mesh_value in member.find_children("*", "MeshInstance3D", true, false):
				var mesh_instance := mesh_value as MeshInstance3D
				if mesh_instance.mesh == null:
					continue
				for surface_index in range(mesh_instance.mesh.get_surface_count()):
					var material := mesh_instance.get_active_material(surface_index)
					var material_key := material.get_instance_id() if material != null else 0
					if not surfaces.has(material_key):
						var surface := SurfaceTool.new()
						surface.begin(Mesh.PRIMITIVE_TRIANGLES)
						if material != null:
							surface.set_material(material)
						surfaces[material_key] = surface
					(surfaces[material_key] as SurfaceTool).append_from(mesh_instance.mesh, surface_index, mesh_instance.global_transform)
		for material_key in surfaces:
			var combined := MeshInstance3D.new()
			combined.mesh = (surfaces[material_key] as SurfaceTool).commit()
			combined.visibility_range_end = 1400.0
			combined.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			merged.add_child(combined)
		for member in members:
			member.get_parent().remove_child(member)
			member.free()


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
