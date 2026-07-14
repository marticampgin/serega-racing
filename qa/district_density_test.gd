extends SceneTree

const MAX_TOTAL_MESHES := 4600
const OVERLAP_TOLERANCE := 0.75
const MESH_OVERLAP_AREA_TOLERANCE := 0.35
const FILLER_GROUPS := [&"palm_scenery", &"lamp_scenery", &"portrait_scenery"]
const DENSITY_RULES := {
	"start_coast": {"min_featured": 4, "max_gap": 100.0},
	"party_town": {"min_featured": 18, "max_gap": 80.0},
	"city_centre": {"min_featured": 10, "max_gap": 100.0},
	"shopping_alley": {"min_featured": 6, "max_gap": 150.0},
	"sport_complex": {"min_featured": 5, "max_gap": 250.0},
	"north_coast": {"min_featured": 20, "max_gap": 130.0},
	"party_island_view": {"min_featured": 3, "max_gap": 130.0},
}

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
	var race := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(race)
	await process_frame
	await process_frame

	var course: Object = race.get("course")
	check(course != null, "course metadata is available for district density QA")
	if course == null:
		_finish()
		return

	var total_meshes := race.find_children("*", "MeshInstance3D", true, false).size()
	print("INFO: total MeshInstance3D nodes = %d (cap %d)" % [total_meshes, MAX_TOTAL_MESHES])
	check(total_meshes <= MAX_TOTAL_MESHES, "world remains within the generous scenery mesh budget")

	var zones: Array = course.get("course_zones")
	var spans: Array[Dictionary] = []
	for index in range(zones.size()):
		var zone: Dictionary = zones[index]
		spans.append({
			"index": index,
			"name": str(zone.get("name", "")),
			"start": float(zone.get("start_distance", 0.0)),
			"finish": float(zone.get("end_distance", 0.0)),
			"all_offsets": [],
			"featured_offsets": [],
			"mesh_count": 0,
		})

	var metadata_anchors := 0
	var offtrack_roots := 0
	var featured_anchors: Array[Node3D] = []
	for value in get_nodes_in_group("grounded_scenery"):
		if not value is Node3D or not race.is_ancestor_of(value):
			continue
		var anchor := value as Node3D
		if not anchor.has_meta("course_offset"):
			offtrack_roots += 1
			continue
		metadata_anchors += 1
		var offset := fposmod(float(anchor.get_meta("course_offset")), float(course.call("length")))
		var span_index := _span_index_for_offset(spans, offset)
		if span_index < 0:
			continue
		var span: Dictionary = spans[span_index]
		(span.all_offsets as Array).append(offset)
		span.mesh_count = int(span.mesh_count) + _mesh_count(anchor)
		if not _is_filler(anchor):
			(span.featured_offsets as Array).append(offset)
			featured_anchors.append(anchor)
		spans[span_index] = span

	print("INFO: grounded metadata anchors = %d; off-track grounded roots = %d" % [metadata_anchors, offtrack_roots])
	for span in spans:
		var zone_name := str(span.name)
		if not DENSITY_RULES.has(zone_name):
			continue
		var all_offsets := span.all_offsets as Array
		var featured_offsets := span.featured_offsets as Array
		all_offsets.sort()
		featured_offsets.sort()
		var max_gap := _maximum_gap(float(span.start), float(span.finish), featured_offsets)
		var rule: Dictionary = DENSITY_RULES[zone_name]
		print(
			"INFO: district=%s span=%d range=%.1f-%.1f all_anchors=%d featured=%d meshes=%d max_featured_gap=%.1fm"
			% [zone_name, int(span.index), float(span.start), float(span.finish), all_offsets.size(), featured_offsets.size(), int(span.mesh_count), max_gap]
		)
		check(
			featured_offsets.size() >= int(rule.min_featured),
			"%s span %d has enough recognizable district anchors" % [zone_name, int(span.index)]
		)
		check(
			max_gap <= float(rule.max_gap),
			"%s span %d has no obvious long empty stretch" % [zone_name, int(span.index)]
		)
	_check_feature_anchor_overlaps(featured_anchors)

	_finish()


func _span_index_for_offset(spans: Array[Dictionary], offset: float) -> int:
	for index in range(spans.size()):
		var span: Dictionary = spans[index]
		if offset >= float(span.start) and offset < float(span.finish):
			return index
	return -1


func _mesh_count(anchor: Node) -> int:
	var count := 1 if anchor is MeshInstance3D else 0
	count += anchor.find_children("*", "MeshInstance3D", true, false).size()
	return count


func _is_filler(anchor: Node) -> bool:
	for group_name in FILLER_GROUPS:
		if anchor.is_in_group(group_name):
			return true
	return false


func _maximum_gap(start: float, finish: float, sorted_offsets: Array) -> float:
	if sorted_offsets.is_empty():
		return finish - start
	var maximum := maxf(0.0, float(sorted_offsets[0]) - start)
	for index in range(1, sorted_offsets.size()):
		maximum = maxf(maximum, float(sorted_offsets[index]) - float(sorted_offsets[index - 1]))
	return maxf(maximum, finish - float(sorted_offsets[-1]))


func _check_feature_anchor_overlaps(anchors: Array[Node3D]) -> void:
	var footprints: Array[Dictionary] = []
	for anchor in anchors:
		var footprint := _anchor_footprint(anchor)
		if not footprint.is_empty():
			footprints.append(footprint)
	var overlaps := 0
	var nearby_pairs := 0
	var smallest_center_gap := INF
	for first_index in range(footprints.size()):
		var first: Dictionary = footprints[first_index]
		for second_index in range(first_index + 1, footprints.size()):
			var second: Dictionary = footprints[second_index]
			if float(first.max_y) <= float(second.min_y) + 0.25 or float(second.max_y) <= float(first.min_y) + 0.25:
				continue
			var center_distance := (first.center as Vector2).distance_to(second.center as Vector2)
			var radius_gap := center_distance - float(first.radius) - float(second.radius)
			smallest_center_gap = minf(smallest_center_gap, radius_gap)
			if radius_gap < 3.0:
				nearby_pairs += 1
			var penetration := _rectangle_penetration(first, second)
			if penetration > OVERLAP_TOLERANCE:
				var overlap_area := _mesh_overlap_area(first, second)
				if overlap_area > MESH_OVERLAP_AREA_TOLERANCE:
					overlaps += 1
					print(
						"INFO: feature overlap depth=%.2fm mesh_area=%.2fm2 first=%s@%.1f groups=%s second=%s@%.1f groups=%s"
						% [penetration, overlap_area, str(first.name), float(first.offset), str(first.groups), str(second.name), float(second.offset), str(second.groups)]
					)
	print(
		"INFO: featured footprint rectangles=%d; nearby broad-phase pairs=%d; overlap violations=%d; smallest radius gap=%.2fm"
		% [footprints.size(), nearby_pairs, overlaps, smallest_center_gap]
	)
	check(overlaps == 0, "grounded feature footprints do not overlap each other")


func _anchor_footprint(anchor: Node3D) -> Dictionary:
	var meshes: Array[Node] = anchor.find_children("*", "MeshInstance3D", true, false)
	if anchor is MeshInstance3D:
		meshes.append(anchor)
	if meshes.is_empty():
		return {}
	var inverse := anchor.global_transform.affine_inverse()
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var world_min_y := INF
	var world_max_y := -INF
	var mesh_shapes: Array[Dictionary] = []
	for value in meshes:
		var mesh_instance := value as MeshInstance3D
		var bounds := mesh_instance.get_aabb()
		var points := PackedVector2Array()
		var mesh_min_y := INF
		var mesh_max_y := -INF
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var world_point := mesh_instance.global_transform * Vector3(x, y, z)
					points.append(Vector2(world_point.x, world_point.z))
					var local_point := inverse * world_point
					minimum = minimum.min(local_point)
					maximum = maximum.max(local_point)
					world_min_y = minf(world_min_y, world_point.y)
					world_max_y = maxf(world_max_y, world_point.y)
					mesh_min_y = minf(mesh_min_y, world_point.y)
					mesh_max_y = maxf(mesh_max_y, world_point.y)
		mesh_shapes.append({
			"polygon": Geometry2D.convex_hull(points),
			"min_y": mesh_min_y,
			"max_y": mesh_max_y,
		})
	var local_center := (minimum + maximum) * 0.5
	var half := Vector2((maximum.x - minimum.x) * 0.5, (maximum.z - minimum.z) * 0.5)
	var world_center_3d := anchor.global_transform * Vector3(local_center.x, 0.0, local_center.z)
	var axis_x := Vector2(anchor.global_transform.basis.x.x, anchor.global_transform.basis.x.z).normalized()
	var axis_z := Vector2(anchor.global_transform.basis.z.x, anchor.global_transform.basis.z.z).normalized()
	return {
		"name": anchor.name,
		"groups": anchor.get_groups(),
		"offset": float(anchor.get_meta("course_offset", -1.0)),
		"center": Vector2(world_center_3d.x, world_center_3d.z),
		"axis_x": axis_x,
		"axis_z": axis_z,
		"half": half,
		"radius": half.length(),
		"min_y": world_min_y,
		"max_y": world_max_y,
		"mesh_shapes": mesh_shapes,
	}


func _rectangle_penetration(first: Dictionary, second: Dictionary) -> float:
	var delta: Vector2 = (second.center as Vector2) - (first.center as Vector2)
	var minimum_penetration := INF
	for axis_value in [first.axis_x, first.axis_z, second.axis_x, second.axis_z]:
		var axis := axis_value as Vector2
		var first_radius := (
			absf((first.axis_x as Vector2).dot(axis)) * (first.half as Vector2).x
			+ absf((first.axis_z as Vector2).dot(axis)) * (first.half as Vector2).y
		)
		var second_radius := (
			absf((second.axis_x as Vector2).dot(axis)) * (second.half as Vector2).x
			+ absf((second.axis_z as Vector2).dot(axis)) * (second.half as Vector2).y
		)
		var penetration := first_radius + second_radius - absf(delta.dot(axis))
		if penetration <= 0.0:
			return 0.0
		minimum_penetration = minf(minimum_penetration, penetration)
	return minimum_penetration


func _mesh_overlap_area(first: Dictionary, second: Dictionary) -> float:
	var area := 0.0
	for first_shape_value in first.mesh_shapes:
		var first_shape := first_shape_value as Dictionary
		for second_shape_value in second.mesh_shapes:
			var second_shape := second_shape_value as Dictionary
			if float(first_shape.max_y) <= float(second_shape.min_y) + 0.25:
				continue
			if float(second_shape.max_y) <= float(first_shape.min_y) + 0.25:
				continue
			var intersections := Geometry2D.intersect_polygons(
				first_shape.polygon as PackedVector2Array,
				second_shape.polygon as PackedVector2Array
			)
			for polygon in intersections:
				area += absf(_polygon_area(polygon as PackedVector2Array))
	return area


func _polygon_area(polygon: PackedVector2Array) -> float:
	if polygon.size() < 3:
		return 0.0
	var twice_area := 0.0
	for index in range(polygon.size()):
		var next := (index + 1) % polygon.size()
		twice_area += polygon[index].cross(polygon[next])
	return twice_area * 0.5


func _finish() -> void:
	if failures.is_empty():
		print("DISTRICT DENSITY QA: PASS")
		quit(0)
	else:
		print("DISTRICT DENSITY QA: FAIL (%d issues)" % failures.size())
		quit(1)
