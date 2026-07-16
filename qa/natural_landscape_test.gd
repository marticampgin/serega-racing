extends SceneTree

const EXPECTED_IDS := [
	"start_west_headland",
	"start_interior_dunes",
	"loop_one_oasis",
	"loop_two_highlands",
	"bridge_west_dunes",
	"bridge_east_dunes",
	"south_limestone_cliffs",
	"city_coastal_bluff",
	"south_natural_arch",
	"north_mangrove_lagoon",
	"east_coastal_rock_garden",
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
	var race := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	var landscapes := race.get_node_or_null("EditableWorld/NaturalLandscapes") as Node3D
	check(landscapes != null, "natural landscapes load from the editable world")
	if landscapes == null:
		_finish()
		return
	check(landscapes.transform.is_equal_approx(Transform3D.IDENTITY), "natural landscape folder retains a stable identity transform")
	check(get_nodes_in_group("natural_landscapes_root").size() == 1, "natural landscape folder is instantiated exactly once")
	check(landscapes.find_children("*", "CollisionObject3D", true, false).is_empty(), "natural landscapes remain visual-only")
	check(landscapes.find_children("*", "MeshInstance3D", true, false).size() <= 800, "natural landscape mesh budget remains bounded after authored copies")
	var island := race.find_child("IslandTerrain", true, false) as MeshInstance3D
	var island_material := island.material_override as StandardMaterial3D if island != null else null
	check(island_material != null and island_material.albedo_color.is_equal_approx(Color("c77d68")), "map terrain uses the canonical landscape sand color")

	var course: CourseLayout = race.get("course")
	var terrain: WorldBuilder = race.get("world_builder")
	var found: Dictionary = {}
	for value in get_nodes_in_group("natural_landscape_scenery"):
		if not value is Node3D or not landscapes.is_ancestor_of(value):
			continue
		var feature := value as Node3D
		var id := str(feature.get_meta("landscape_id", ""))
		found[id] = int(found.get(id, 0)) + 1
		check(feature.get_parent() == landscapes, "%s is a directly movable landscape instance" % feature.name)
		check(not feature.scene_file_path.is_empty(), "%s remains linked to an external reusable scene" % feature.name)
		check(bool(feature.get_meta("_edit_group_", false)), "%s is click-selectable as one compound editor object" % feature.name)
		if str(feature.get_meta("landscape_kind", "")) in ["dune_field", "rock_garden"]:
			check(_feature_uses_sand(feature, Color("c77d68")), "%s sandy surface matches the map terrain" % feature.name)
		if _uses_default_transform(feature):
			_check_feature(feature, course, terrain)
		else:
			check(feature.global_transform.is_finite(), "%s authored transform remains finite" % feature.name)
			print("INFO: %s uses an authored placement; visual QA owns its contextual clearance" % feature.name)
	for id in EXPECTED_IDS:
		check(int(found.get(id, 0)) >= 1, "%s has its canonical editable instance" % id)
	check(found.size() == EXPECTED_IDS.size(), "no unplanned natural landscape roots were introduced")
	_finish()


func _check_feature(feature: Node3D, course: CourseLayout, terrain: WorldBuilder) -> void:
	var scale := feature.global_transform.basis.get_scale()
	var radius := float(feature.get_meta("landscape_radius", 0.0)) * maxf(absf(scale.x), absf(scale.z))
	var centre := Vector2(feature.global_position.x, feature.global_position.z)
	var ground := terrain.terrain_rendered_height_at(centre)
	check(absf(feature.global_position.y - ground) <= 0.12, "%s is grounded to the rendered sand surface" % feature.name)
	var rim_is_land := true
	var stable_base := true
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		var probe := centre + Vector2(cos(angle), sin(angle)) * radius
		var probe_ground := terrain.terrain_rendered_height_at(probe)
		rim_is_land = rim_is_land and probe_ground - terrain.ocean_rendered_height_at(probe) >= 0.16
		stable_base = stable_base and absf(probe_ground - ground) <= 2.2
	check(rim_is_land, "%s has no water clipping around its footprint" % feature.name)
	check(stable_base, "%s sits on a stable, non-floating terrain base" % feature.name)
	var minimum_road_clearance := INF
	var offset := 0.0
	while offset < course.length():
		var point := course.point_at(offset)
		if absf(point.y - ground) < 18.0:
			minimum_road_clearance = minf(minimum_road_clearance, centre.distance_to(Vector2(point.x, point.z)))
		offset += 10.0
	check(minimum_road_clearance >= radius + course.road_half_width + 7.0, "%s remains safely clear of every driveable road branch" % feature.name)


func _feature_uses_sand(feature: Node3D, expected: Color) -> bool:
	var landform := feature.find_child("ContinuousLandform", true, false) as MeshInstance3D
	if landform == null or landform.mesh == null or landform.mesh.get_surface_count() == 0:
		return false
	var material := landform.mesh.surface_get_material(0) as StandardMaterial3D
	return material != null and material.albedo_color.is_equal_approx(expected)


func _uses_default_transform(feature: Node3D) -> bool:
	if feature.scene_file_path.is_empty():
		return false
	var packed := load(feature.scene_file_path) as PackedScene
	if packed == null:
		return false
	var source := packed.instantiate() as Node3D
	var matches := source != null and feature.transform.is_equal_approx(source.transform)
	if source != null:
		source.free()
	return matches


func _finish() -> void:
	print("NATURAL LANDSCAPE QA: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
