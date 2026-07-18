extends SceneTree

const MAX_TOTAL_MESHES := 6400
const MAX_NEIGHBORHOOD_DETAIL_MESHES := 10000
const OVERLAP_TOLERANCE := 0.75
const MESH_OVERLAP_AREA_TOLERANCE := 0.35
const FILLER_GROUPS := [&"palm_scenery", &"lamp_scenery", &"portrait_scenery"]
const REQUIRED_POSTER_TEXTURES := [
	"res://assets/generated/friends/1daf0fdc-2536-4e54-b476-fc61c770b23d.jpg",
	"res://assets/generated/friends/481d5ab6-7c3f-47be-a2bd-e02bdfb2c1d5.jpg",
	"res://assets/generated/friends/5213d1b1-6e99-448d-ad81-26f61e859010.jpg",
	"res://assets/generated/friends/882a2791-af8b-4378-b3b7-a05b4cf0dd08.jpg",
]
const DENSITY_RULES := {
	# Symmetric building blocks intentionally leave breathing room between
	# neighborhoods; these limits catch truly empty spans without demanding
	# the previous random roadside scatter.
	"start_coast": {"min_featured": 4, "max_gap": 150.0},
	"party_town": {"min_featured": 18, "max_gap": 150.0},
	"city_centre": {"min_featured": 10, "max_gap": 200.0},
	"shopping_alley": {"min_featured": 6, "max_gap": 220.0},
	"sport_complex": {"min_featured": 5, "max_gap": 250.0},
	"north_coast": {"min_featured": 20, "max_gap": 330.0},
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

	var all_meshes := race.find_children("*", "MeshInstance3D", true, false)
	var manual_root := race.get_node_or_null("ManualScenery")
	var manual_meshes := 0
	var detail_meshes := 0
	if manual_root != null:
		for mesh in all_meshes:
			if manual_root.is_ancestor_of(mesh):
				manual_meshes += 1
	for mesh in all_meshes:
		var counted_manual := false
		for manual_value in get_nodes_in_group("manual_scenery"):
			if manual_value is Node and (manual_value == mesh or (manual_value as Node).is_ancestor_of(mesh)):
				counted_manual = true
				break
		if counted_manual and (manual_root == null or not manual_root.is_ancestor_of(mesh)):
			manual_meshes += 1
		var details_root := race.get_node_or_null("EditableWorld/EditableBlocks")
		if details_root != null and details_root.is_ancestor_of(mesh):
			detail_meshes += 1
	var procedural_meshes := all_meshes.size() - manual_meshes - detail_meshes
	print("INFO: baseline meshes=%d (cap %d); neighborhood details=%d (cap %d); manual=%d" % [procedural_meshes, MAX_TOTAL_MESHES, detail_meshes, MAX_NEIGHBORHOOD_DETAIL_MESHES, manual_meshes])
	check(procedural_meshes <= MAX_TOTAL_MESHES, "generated world remains within the generous scenery mesh budget")
	check(detail_meshes <= MAX_NEIGHBORHOOD_DETAIL_MESHES, "editable neighborhood detail layer stays within its temporary authoring budget")

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
	check(_group_count_inside("loop_landmark", race) >= 5, "multiple unique landmarks animate the formerly empty loop sectors")
	check(_group_count_inside("building_mural_scenery", race) == 0, "generated friend murals are absent from landmark buildings")
	_check_personalized_posters(race)
	_check_tunnel_art(race)
	await _check_sky_traffic(race)
	_check_maritime_scenery(race, course)

	_finish()


func _group_count_inside(group_name: StringName, ancestor: Node) -> int:
	var count := 0
	for value in get_nodes_in_group(group_name):
		if value is Node and ancestor.is_ancestor_of(value):
			count += 1
	return count


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


func _check_personalized_posters(race: Node) -> void:
	var represented := {}
	for texture_path in REQUIRED_POSTER_TEXTURES:
		represented[texture_path] = false
		var texture_exists := ResourceLoader.exists(texture_path, "Texture2D")
		var texture_resource := load(texture_path) if texture_exists else null
		check(texture_exists and texture_resource is Texture2D, "required personalized poster texture loads: %s" % texture_path)

	var poster_count := 0
	for value in get_nodes_in_group("poster_scenery"):
		if not value is Node3D or not race.is_ancestor_of(value):
			continue
		poster_count += 1
		var poster := value as Node3D
		var poster_label := "poster root %s" % poster.name
		check(poster.is_in_group("grounded_scenery"), "%s is registered as grounded scenery" % poster_label)
		for metadata_name in [&"poster_texture", &"ground_y", &"course_offset", &"scenery_radius"]:
			check(poster.has_meta(metadata_name), "%s carries %s placement metadata" % [poster_label, metadata_name])

		if poster.has_meta("poster_texture"):
			var texture_path := str(poster.get_meta("poster_texture"))
			check(not texture_path.is_empty(), "%s has a non-empty poster texture path" % poster_label)
			var texture_exists := ResourceLoader.exists(texture_path, "Texture2D") if not texture_path.is_empty() else false
			var texture_resource := load(texture_path) if texture_exists else null
			check(texture_exists and texture_resource is Texture2D, "%s texture loads as Texture2D: %s" % [poster_label, texture_path])
			if represented.has(texture_path):
				represented[texture_path] = true

		if poster.has_meta("scenery_radius"):
			check(float(poster.get_meta("scenery_radius")) > 0.0, "%s has a positive scenery radius" % poster_label)
	# User-authored catalog billboards keep the texture on their Sprite3D even
	# when they are not one of the baked poster roots with placement metadata.
	for value in race.find_children("*", "Sprite3D", true, false):
		var sprite := value as Sprite3D
		if sprite.texture != null and represented.has(sprite.texture.resource_path):
			represented[sprite.texture.resource_path] = true

	print("INFO: personalized poster roots = %d; required textures = %d" % [poster_count, REQUIRED_POSTER_TEXTURES.size()])
	check(poster_count == 0, "no generated friend poster roots remain")
	for texture_path in REQUIRED_POSTER_TEXTURES:
		check(bool(represented[texture_path]), "required personalized poster is represented: %s" % texture_path)


func _check_tunnel_art(race: Node) -> void:
	var posters: Array[Node] = []
	for value in get_nodes_in_group("tunnel_wall_poster"):
		if value is Node3D and race.is_ancestor_of(value):
			posters.append(value)
	check(posters.is_empty(), "unplaced friend posters are absent from the tunnel")
	for value in posters:
		var poster := value as Node3D
		check(poster.has_meta("course_offset") and poster.has_meta("poster_texture"), "%s has tunnel placement metadata" % poster.name)
		check(not poster.find_children("*", "Sprite3D", true, false).is_empty(), "%s has a visible poster face" % poster.name)


func _check_sky_traffic(race: Node) -> void:
	var vehicles: Array[Node3D] = []
	for value in get_nodes_in_group("sky_traffic_vehicle"):
		if value is Node3D and race.is_ancestor_of(value):
			vehicles.append(value)
	check(vehicles.is_empty(), "unplaced friend-banner aircraft remain absent")
	check(get_nodes_in_group("zeppelin_scenery").is_empty(), "no generated zeppelin remains")
	check(get_nodes_in_group("plane_scenery").is_empty(), "no generated banner plane remains")
	check(get_nodes_in_group("air_banner_scenery").is_empty(), "no generated friend air banners remain")


func _check_maritime_scenery(race: Node, course: Object) -> void:
	var boats: Array[Node3D] = []
	for value in get_nodes_in_group("water_scenery"):
		if value is Node3D and race.is_ancestor_of(value):
			boats.append(value)
	check(boats.size() >= 6, "ships and boats populate several coasts")
	for boat in boats:
		var is_manual := boat.is_in_group("manual_scenery")
		if is_manual:
			check(int(boat.get_meta("manual_surface", -1)) == 1 and boat.has_meta("scenery_radius"), "%s carries catalog water-placement metadata" % boat.name)
		else:
			check(boat.has_meta("water_y") and boat.has_meta("scenery_radius") and boat.has_meta("course_offset"), "%s carries collision-safe water placement metadata" % boat.name)
		var minimum_road_distance := INF
		var offset := 0.0
		while offset < float(course.call("length")):
			var road_point: Vector3 = course.call("point_at", offset)
			minimum_road_distance = minf(minimum_road_distance, Vector2(boat.global_position.x, boat.global_position.z).distance_to(Vector2(road_point.x, road_point.z)))
			offset += 12.0
		check(minimum_road_distance > 45.0, "%s remains safely offshore" % boat.name)


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
			# Final-sprinkle objects are now authored editor content. Intentional
			# close planting around one of those buildings is not a generator fault.
			if bool(first.authored_sprinkle) and bool(second.authored_sprinkle):
				continue
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
		"authored_sprinkle": anchor.has_meta("final_sprinkle"),
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
