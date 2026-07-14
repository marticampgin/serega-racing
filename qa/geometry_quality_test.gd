extends SceneTree

const QAUtil := preload("res://qa/map_course_qa_util.gd")

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
	await physics_frame
	await physics_frame
	var terrain := race.find_child("IslandTerrain", true, false) as MeshInstance3D
	check(terrain != null and terrain.mesh != null, "single island terrain mesh exists")
	if terrain != null and terrain.mesh != null:
		var vertices := terrain.mesh.get_faces().size()
		print("INFO: terrain triangle vertices = ", vertices)
		check(vertices > 1000, "connected sand/seabed heightfield has substantial coverage")
		var terrain_arrays: Array = terrain.mesh.surface_get_arrays(0)
		check((terrain_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 1000, "ground is one indexed surface without deleted cells")
		var material := terrain.material_override as StandardMaterial3D
		if material != null:
			print("INFO: terrain color = ", material.albedo_color)
	var ocean_nodes := get_nodes_in_group("ocean_scenery")
	check(ocean_nodes.size() == 1, "world uses one ocean surface")
	if not ocean_nodes.is_empty() and ocean_nodes[0] is MeshInstance3D:
		var ocean_mesh := (ocean_nodes[0] as MeshInstance3D).mesh
		check(ocean_mesh != null and not ocean_mesh is BoxMesh, "ocean has no vertical box faces")
		check(ocean_mesh.get_faces().size() > 1000, "sea is a substantial continuous surface")
		var ocean_arrays: Array = ocean_mesh.surface_get_arrays(0)
		check((ocean_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() > 1000, "sea is indexed and has no deleted tunnel cells")
	var transparent_lane_volumes := 0
	for node in get_nodes_in_group("tunnel"):
		if node is MeshInstance3D and node.mesh is BoxMesh:
			var box := node.mesh as BoxMesh
			if box.size.x > 15.0 and box.size.y > 3.0 and box.size.z > 3.0:
				transparent_lane_volumes += 1
	check(transparent_lane_volumes == 0, "tunnel has no full-lane volume boxes")
	var bridge_boundaries := get_nodes_in_group("bridge_boundary")
	check(bridge_boundaries.size() >= 2, "bridge has course-length continuous visual boundaries")
	for node in bridge_boundaries:
		if node is MeshInstance3D:
			check((node as MeshInstance3D).mesh.get_faces().size() > 100, "bridge boundary is a substantial continuous mesh")
	var flyover_boundaries := get_nodes_in_group("flyover_boundary")
	check(flyover_boundaries.size() >= 2, "elevated crossings have course-length continuous visual boundaries")
	for node in flyover_boundaries:
		if node is MeshInstance3D:
			check((node as MeshInstance3D).mesh.get_faces().size() > 24, "flyover boundary is a substantial continuous mesh")
	check(get_nodes_in_group("shoreline_contour").size() == 1, "one continuous shoreline contour separates sand from water")
	_check_bridge_support_contact()
	_check_loop2_tunnel_separation(race)
	_check_tunnel_approach_surface(race)
	_check_render_distance(race, terrain, ocean_nodes[0] as MeshInstance3D)
	var curve := QAUtil.find_course_curve(race)
	check(curve != null, "course curve is available for dense geometry checks")
	if curve != null:
		await _check_road_edges(race, curve.get_baked_length())
		_check_ground_clearance(race, curve.get_baked_length())
		_check_tunnel_ocean_clearance(race)
		_check_crossing_clearance(race, curve.get_baked_length())
		_check_scenery_clearance(race, curve.get_baked_length())
	_check_opaque_surfaces()
	if failures.is_empty():
		print("GEOMETRY QUALITY QA: PASS")
		quit(0)
	else:
		print("GEOMETRY QUALITY QA: FAIL (%d issues)" % failures.size())
		quit(1)


func _check_road_edges(race: Node, length: float) -> void:
	var space: PhysicsDirectSpaceState3D = race.get_world_3d().direct_space_state
	var car := race.get_node_or_null("PlayerCar") as CollisionObject3D
	var misses := 0
	var samples := 0
	var offset := 0.0
	while offset < length:
		var frame := race.call("sample_course", offset) as Transform3D
		for lateral in [-8.2, 0.0, 8.2]:
			var point: Vector3 = frame.origin + frame.basis.x * lateral
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.0, point - Vector3.UP * 4.0, 1)
			if car != null:
				query.exclude = [car.get_rid()]
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty() or not (hit.collider as Node).is_in_group("track"):
				misses += 1
				print("INFO: road edge miss offset=%.1f lateral=%.1f hit=%s" % [offset, lateral, str(hit.get("collider", "none"))])
			samples += 1
		offset += 20.0
	print("INFO: dense road edge rays = %d, misses = %d" % [samples, misses])
	check(misses == 0, "road collider covers centre and both playable edges for the full lap")


func _check_crossing_clearance(race: Node, length: float) -> void:
	var samples: Array[Dictionary] = []
	var offset := 0.0
	while offset < length:
		var point: Vector3 = (race.call("sample_course", offset) as Transform3D).origin
		samples.append({"offset": offset, "point": point})
		offset += 12.0
	var unsafe := 0
	for i in range(samples.size()):
		var a: Dictionary = samples[i]
		for j in range(i + 1, samples.size()):
			var b: Dictionary = samples[j]
			var arc: float = absf(float(a.offset) - float(b.offset))
			arc = minf(arc, length - arc)
			if arc < 120.0:
				continue
			var pa: Vector3 = a.point
			var pb: Vector3 = b.point
			if Vector2(pa.x, pa.z).distance_to(Vector2(pb.x, pb.z)) < 3.0 and absf(pa.y - pb.y) < 7.0:
				unsafe += 1
	print("INFO: unsafe non-local road crossings = ", unsafe)
	check(unsafe == 0, "non-local road crossings have safe vertical separation")


func _check_ground_clearance(race: Node, length: float) -> void:
	var builder: Object = race.get("world_builder")
	var violations := 0
	var offset := 0.0
	while offset < length:
		var frame := race.call("sample_course", offset) as Transform3D
		for lateral in [-8.8, 0.0, 8.8]:
			var road_point: Vector3 = frame.origin + frame.basis.x * lateral
			var ground_height := float(builder.call("terrain_height_at", Vector2(road_point.x, road_point.z)))
			if ground_height > road_point.y - 0.35:
				violations += 1
		offset += 12.0
	print("INFO: road/ground clearance violations = ", violations)
	check(violations == 0, "sand and seabed remain below the road and both shoulders for the full lap")


func _check_tunnel_ocean_clearance(race: Node) -> void:
	var course: Object = race.get("course")
	var builder: Object = race.get("world_builder")
	var violations := 0
	for span: Dictionary in course.get("course_zones"):
		if str(span.get("name", "")) != "underwater_tunnel":
			continue
		var offset := float(span.start_distance) + 18.0
		while offset < float(span.end_distance) - 18.0:
			var frame := race.call("sample_course", offset) as Transform3D
			for lateral in [-8.8, 0.0, 8.8]:
				var road_point: Vector3 = frame.origin + frame.basis.x * lateral
				var rendered_ocean := float(builder.call("ocean_rendered_height_at", Vector2(road_point.x, road_point.z)))
				if rendered_ocean > road_point.y - 0.25:
					violations += 1
					print("INFO: tunnel/ocean violation offset=%.1f lateral=%.1f road=%.2f ocean=%.2f" % [offset, lateral, road_point.y, rendered_ocean])
			offset += 12.0
	print("INFO: rendered tunnel/ocean triangle violations = ", violations)
	check(violations == 0, "rendered ocean triangles stay below the tunnel road and shoulders")


func _check_bridge_support_contact() -> void:
	var violations := 0
	var supports := get_nodes_in_group("bridge_support")
	for node in supports:
		if not node is MeshInstance3D or not node.has_meta("contact_y"):
			violations += 1
			continue
		var cylinder := (node as MeshInstance3D).mesh as CylinderMesh
		var top := (node as MeshInstance3D).global_position.y + cylinder.height * 0.5
		if absf(top - float(node.get_meta("contact_y"))) > 0.18:
			violations += 1
		if not node.has_meta("cap_bottom_y") or top - float(node.get_meta("cap_bottom_y")) < 0.04:
			violations += 1
	var deck_intrusions := 0
	for group_name in ["bridge_girder", "bridge_pier_cap"]:
		for node in get_nodes_in_group(group_name):
			if not node.has_meta("top_local_y") or float(node.get_meta("top_local_y")) > -0.08:
				deck_intrusions += 1
	print("INFO: bridge pier/cap contact violations = ", violations)
	check(not supports.is_empty() and violations == 0, "bridge piers meet their pitched cap undersides")
	check(deck_intrusions == 0, "bridge girders and pier caps overlap the lower deck without bleeding through asphalt")


func _check_loop2_tunnel_separation(race: Node) -> void:
	var frame := race.call("sample_course", 3234.0) as Transform3D
	var builder: Object = race.get("world_builder")
	var ocean_variation := 0
	for lateral in [-8.8, 0.0, 8.8]:
		var point: Vector3 = frame.origin + frame.basis.x * float(lateral)
		var ocean_height := float(builder.call("ocean_rendered_height_at", Vector2(point.x, point.z)))
		if absf(ocean_height - -1.4) > 0.04:
			ocean_variation += 1
	var exposed_roofs := 0
	for node in get_nodes_in_group("tunnel_boundary"):
		if not node is MeshInstance3D or not node.mesh is BoxMesh:
			continue
		var size := (node.mesh as BoxMesh).size
		if size.x < 15.0 or size.z < 10.0:
			continue
		var distance := Vector2(node.global_position.x, node.global_position.z).distance_to(Vector2(frame.origin.x, frame.origin.z))
		if distance < 65.0 and node.global_position.y + size.y * 0.5 > -0.9:
			exposed_roofs += 1
	print("INFO: Loop 2 ocean variations=%d exposed tunnel roofs=%d" % [ocean_variation, exposed_roofs])
	check(ocean_variation == 0, "Loop 2 crossing keeps a level sea instead of exposed depression patches")
	check(exposed_roofs == 0, "no shallow tunnel roof protrudes beneath the Loop 2 crossing")


func _check_tunnel_approach_surface(race: Node) -> void:
	var builder: Object = race.get("world_builder")
	var course: Object = race.get("course")
	var exposed_samples := 0
	var sample_count := 0
	for span: Dictionary in course.get("course_zones"):
		if str(span.get("name", "")) != "underwater_tunnel":
			continue
		# Include both cameras' lead-in view and the complete tunnel corridor;
		# checking only one cross-section missed cutouts farther down the entrance.
		var offset := float(span.start_distance) - 72.0
		while offset <= float(span.end_distance) + 72.0:
			var frame := race.call("sample_course", offset) as Transform3D
			for lateral in [-36.0, -30.0, -24.0, -18.0, -12.0, 12.0, 18.0, 24.0, 30.0, 36.0]:
				var point: Vector3 = frame.origin + frame.basis.x * lateral
				var terrain_height := float(builder.call("terrain_rendered_height_at", Vector2(point.x, point.z)))
				var ocean_height := float(builder.call("ocean_rendered_height_at", Vector2(point.x, point.z)))
				sample_count += 1
				if terrain_height < ocean_height + 0.04:
					exposed_samples += 1
					print("INFO: exposed tunnel shoulder offset=%.0f lateral=%.0f terrain=%.2f ocean=%.2f" % [offset, lateral, terrain_height, ocean_height])
			offset += 18.0
	print("INFO: tunnel shoulder surface samples=%d exposed=%d" % [sample_count, exposed_samples])
	check(exposed_samples == 0, "sandy tunnel approaches cover the depressed ocean on both sides")


func _check_render_distance(race: Node, terrain: MeshInstance3D, ocean: MeshInstance3D) -> void:
	var camera := race.find_child("Camera3D", true, false) as Camera3D
	if camera == null:
		camera = race.get_viewport().get_camera_3d()
	check(camera != null and camera.far >= 6000.0, "camera far plane supports long district sightlines")
	check(terrain.visibility_range_end >= 5000.0 and ocean.visibility_range_end >= 5000.0, "terrain and ocean remain visible to the far horizon")
	var short_infill_meshes := 0
	for root in get_nodes_in_group("district_infill"):
		for child in root.find_children("*", "MeshInstance3D", true, false):
			if (child as MeshInstance3D).visibility_range_end < 1200.0:
				short_infill_meshes += 1
	check(short_infill_meshes == 0, "new district scenery remains visible from at least 1200 m")


func _check_scenery_clearance(race: Node, length: float) -> void:
	var palm_violations := 0
	for node in get_nodes_in_group("palm_scenery"):
		if not node.has_meta("course_offset"):
			continue
		if not _road_prism_clear(race, node.global_position, float(node.get_meta("course_offset")), length, 4.6, node.global_position.y, node.global_position.y + 11.0):
			palm_violations += 1
	var support_violations := 0
	for node in get_nodes_in_group("flyover_support"):
		if not node is MeshInstance3D or not node.has_meta("course_offset"):
			continue
		var cylinder := (node as MeshInstance3D).mesh as CylinderMesh
		var bottom: float = node.global_position.y - cylinder.height * 0.5
		var top: float = node.global_position.y + cylinder.height * 0.5
		if not _road_prism_clear(race, node.global_position, float(node.get_meta("course_offset")), length, cylinder.bottom_radius, bottom, top):
			support_violations += 1
	print("INFO: palm road-prism violations = %d; support violations = %d" % [palm_violations, support_violations])
	check(palm_violations == 0, "roadside palms and canopies clear every non-local road branch")
	check(support_violations == 0, "flyover supports clear every lower road branch")


func _road_prism_clear(race: Node, position: Vector3, own_offset: float, length: float, radius: float, bottom: float, top: float) -> bool:
	var offset := 0.0
	while offset < length:
		var arc := absf(offset - own_offset)
		arc = minf(arc, length - arc)
		if arc >= 110.0:
			var point: Vector3 = (race.call("sample_course", offset) as Transform3D).origin
			if point.y >= bottom - 1.0 and point.y <= top + 1.0:
				if Vector2(position.x, position.z).distance_to(Vector2(point.x, point.z)) < 8.5 + radius + 1.0:
					return false
		offset += 4.0
	return true


func _check_opaque_surfaces() -> void:
	var transparent := 0
	for group_name in ["ocean_scenery", "tunnel_boundary"]:
		for node in get_nodes_in_group(group_name):
			if node is MeshInstance3D:
				var instance := node as MeshInstance3D
				var material := instance.material_override as BaseMaterial3D
				if material == null and instance.mesh != null:
					material = instance.mesh.surface_get_material(0) as BaseMaterial3D
				if material != null and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					transparent += 1
	check(transparent == 0, "ocean and tunnel boundaries are opaque and cannot corrupt the panorama")
