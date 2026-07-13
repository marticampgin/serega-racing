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
		check(vertices > 1000, "island terrain contains substantial non-overlapping surface coverage")
		var material := terrain.material_override as StandardMaterial3D
		if material != null:
			print("INFO: terrain color = ", material.albedo_color)
	var ocean_nodes := get_nodes_in_group("ocean_scenery")
	check(ocean_nodes.size() == 1, "world uses one ocean surface")
	if not ocean_nodes.is_empty() and ocean_nodes[0] is MeshInstance3D:
		var ocean_mesh := (ocean_nodes[0] as MeshInstance3D).mesh
		check(ocean_mesh != null and not ocean_mesh is BoxMesh, "ocean has no vertical box faces")
		check(ocean_mesh.get_faces().size() > 1000, "ocean is a substantial single surface with an authored tunnel opening")
	var transparent_lane_volumes := 0
	for node in get_nodes_in_group("tunnel"):
		if node is MeshInstance3D and node.mesh is BoxMesh:
			var box := node.mesh as BoxMesh
			if box.size.x > 15.0 and box.size.y > 3.0 and box.size.z > 3.0:
				transparent_lane_volumes += 1
	check(transparent_lane_volumes == 0, "tunnel has no full-lane volume boxes")
	check(get_nodes_in_group("bridge_boundary").size() > 50, "bridge has continuous visual boundaries")
	check(get_nodes_in_group("flyover_boundary").size() > 20, "elevated crossings have continuous visual boundaries")
	var submerged_floor := get_nodes_in_group("submerged_floor")
	check(submerged_floor.size() == 1, "submerged approach uses one non-overlapping bed below the ocean opening")
	if not submerged_floor.is_empty() and submerged_floor[0] is MeshInstance3D:
		check((submerged_floor[0] as MeshInstance3D).mesh.get_faces().size() > 100, "submerged bed covers the tunnel opening")
	var curve := QAUtil.find_course_curve(race)
	check(curve != null, "course curve is available for dense geometry checks")
	if curve != null:
		await _check_road_edges(race, curve.get_baked_length())
		_check_crossing_clearance(race, curve.get_baked_length())
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
			if Vector2(pa.x, pa.z).distance_to(Vector2(pb.x, pb.z)) < 3.0 and absf(pa.y - pb.y) < 5.0:
				unsafe += 1
	print("INFO: unsafe non-local road crossings = ", unsafe)
	check(unsafe == 0, "non-local road crossings have safe vertical separation")


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
