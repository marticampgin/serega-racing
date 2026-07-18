extends SceneTree

const WORLD_PATH := "res://scenes/world/editable_world.tscn"
const CourseLayoutScript := preload("res://scripts/course_layout.gd")


func _init() -> void:
	var packed := load(WORLD_PATH) as PackedScene
	if packed == null:
		push_error("Could not load %s" % WORLD_PATH)
		quit(1)
		return
	var world := packed.instantiate()
	root.add_child(world)
	await process_frame

	print("AUTHORED SKY SCENERY")
	for node in get_nodes_in_group("manual_sky_scenery"):
		if world.is_ancestor_of(node) and node is Node3D:
			print("  %s | catalog=%s | position=%s | scale=%s" % [
				world.get_path_to(node),
				str(node.get_meta("catalog_id", "")),
				str(node.global_position),
				str(node.global_basis.get_scale()),
			])

	var motorcycle := world.find_child("MotorcycleRiderBillboard", true, false) as Node3D
	if motorcycle == null:
		push_error("MotorcycleRiderBillboard is missing")
		quit(1)
		return
	print("MOTORCYCLE BILLBOARD")
	print("  path=%s position=%s scale=%s visible=%s" % [
		world.get_path_to(motorcycle), motorcycle.global_position,
		motorcycle.global_basis.get_scale(), motorcycle.visible,
	])
	var course := CourseLayoutScript.load_default()
	var nearest_offset := 0.0
	var nearest_distance := INF
	var sample_offset := 0.0
	while sample_offset < course.length():
		var sample_distance := Vector2(course.point_at(sample_offset).x, course.point_at(sample_offset).z).distance_to(
			Vector2(motorcycle.global_position.x, motorcycle.global_position.z)
		)
		if sample_distance < nearest_distance:
			nearest_distance = sample_distance
			nearest_offset = sample_offset
		sample_offset += 5.0
	print("  nearest_track_offset=%.1f horizontal_distance=%.1f" % [nearest_offset, nearest_distance])
	var child_ranges: Array[float] = []
	for geometry_value in motorcycle.find_children("*", "GeometryInstance3D", true, false):
		child_ranges.append((geometry_value as GeometryInstance3D).visibility_range_end)
	child_ranges.sort()
	print("  child_visibility_ranges=%s" % str(child_ranges))
	print("NEARBY SCENERY WITHIN 100M")
	var nearby: Array[Dictionary] = []
	_collect_nearby(world, motorcycle.global_position, nearby)
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	for item in nearby:
		print("  %.2fm | %s | pos=%s | groups=%s" % [
			float(item.distance), str(item.path), str(item.position), str(item.groups),
		])
	quit(0)


func _collect_nearby(node: Node, origin: Vector3, result: Array[Dictionary]) -> void:
	for child in node.get_children():
		if child is Node3D:
			var spatial := child as Node3D
			var distance := Vector2(spatial.global_position.x, spatial.global_position.z).distance_to(Vector2(origin.x, origin.z))
			if distance <= 100.0 and spatial.name != "MotorcycleRiderBillboard":
				var relevant := spatial.is_in_group("manual_scenery") or spatial.is_in_group("building_scenery") or spatial.is_in_group("natural_landscape_scenery")
				if relevant:
					result.append({
						"distance": distance,
						"path": node.get_tree().current_scene.get_path_to(spatial) if node.get_tree().current_scene != null else spatial.get_path(),
						"position": spatial.global_position,
						"groups": spatial.get_groups(),
					})
		_collect_nearby(child, origin, result)
