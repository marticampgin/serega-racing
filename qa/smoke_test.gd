extends SceneTree

const SCREENSHOT_PATH := "res://qa/artifacts/smoke.png"
const AUTHORED_FRIEND_TEXTURES := [
	"res://assets/generated/friends/1daf0fdc-2536-4e54-b476-fc61c770b23d.jpg",
	"res://assets/generated/friends/481d5ab6-7c3f-47be-a2bd-e02bdfb2c1d5.jpg",
	"res://assets/generated/friends/5213d1b1-6e99-448d-ad81-26f61e859010.jpg",
	"res://assets/generated/friends/882a2791-af8b-4378-b3b7-a05b4cf0dd08.jpg",
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


func mesh_bottom_y(node: MeshInstance3D) -> float:
	var bounds := node.mesh.get_aabb()
	return node.global_position.y + bounds.position.y * node.global_basis.get_scale().y


func count_floating_roots(nodes: Array[Node], race: Node) -> int:
	var floating := 0
	for node in nodes:
		if not node is MeshInstance3D:
			continue
		var mesh_node := node as MeshInstance3D
		var expected_ground := float(race.call("track_y", mesh_node.global_position.z))
		if absf(mesh_bottom_y(mesh_node) - expected_ground) > 1.1:
			floating += 1
	return floating


func count_oversized_cones(race: Node) -> int:
	var cones := 0
	for node in race.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh is CylinderMesh:
			var cylinder := mesh_node.mesh as CylinderMesh
			if cylinder.height > 5.0 and cylinder.bottom_radius > 3.0 and cylinder.top_radius < cylinder.bottom_radius * 0.5:
				cones += 1
	return cones


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "main scene loads")
	if packed == null:
		quit(1)
		return

	var race := packed.instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	var runtime_world := race.get_node_or_null("EditableWorld")
	var optimized_runtime := runtime_world != null and bool(runtime_world.get_meta("runtime_optimized", false))

	check(race is Node3D, "main scene instantiates as a 3D race")
	var car := race.get_node_or_null("PlayerCar") as CharacterBody3D
	check(car != null, "player car exists")
	var camera := root.get_camera_3d()
	check(camera != null and camera.is_current(), "active chase camera exists")
	check(get_nodes_in_group("obstacle").is_empty(), "obstacles remain disabled during track-layout testing")
	check(get_nodes_in_group("bridge").size() > 10, "elevated bridge road and supports exist")
	check(get_nodes_in_group("tunnel").size() > 10, "tunnel arch sequences exist")
	check(get_nodes_in_group("rock_scenery").is_empty(), "legacy giant rock-cone scenery is absent")
	check(count_oversized_cones(race) == 0, "no oversized cone meshes masquerade as scenery")
	check(get_nodes_in_group("ocean_scenery").size() == 1, "continuous island ocean exists")
	if optimized_runtime:
		# Runtime batching intentionally collapses per-prop group identities. Exact
		# source/catalog preservation is covered by runtime_world_optimization_test.
		check(get_nodes_in_group("runtime_static_batch").size() > 1000, "optimized batches retain the dense authored world")
	else:
		check(get_nodes_in_group("palm_scenery").size() > 40, "palms populate the island course")
		check(get_nodes_in_group("lamp_scenery").size() > 20, "neon lamp posts populate the course")
		check(get_nodes_in_group("house_scenery").size() > 20, "Miami-style beach houses populate the course")
		check(get_nodes_in_group("hotel_scenery").size() >= 2, "larger art-deco hotels punctuate the skyline")
		check(get_nodes_in_group("shop_scenery").size() >= 8, "multiple storefronts make commercial sectors lively")
		check(get_nodes_in_group("building_layout").size() >= 192, "planned building rows create recognizable neighborhoods")
	var grounded_buildings: Array[Node] = []
	grounded_buildings.append_array(get_nodes_in_group("house_scenery"))
	grounded_buildings.append_array(get_nodes_in_group("hotel_scenery"))
	grounded_buildings.append_array(get_nodes_in_group("shop_scenery"))
	check(count_floating_roots(grounded_buildings, race) == 0, "houses, hotels, and shops sit on their local ground")
	var authored_friend_textures := {}
	for value in race.find_children("*", "Sprite3D", true, false):
		var sprite := value as Sprite3D
		if sprite.texture != null:
			authored_friend_textures[sprite.texture.resource_path] = true
	for texture_path in AUTHORED_FRIEND_TEXTURES:
		check(authored_friend_textures.has(texture_path), "user-placed friend display remains: %s" % texture_path)
	check(race.get("fuel_bar") is ProgressBar, "fuel HUD exists")
	check(race.get("status_label") is Label, "race status HUD exists")

	var initial_fuel: float = race.get("fuel")
	race.call("apply_drink_result", "purple")
	check(float(race.get("fuel")) >= initial_fuel, "drink result refuels the car")
	check(float(race.get("ghost_time")) > 0.0, "purple drink enables ghost mode")
	var elevations: Array[float] = []
	var course: Object = race.get("course")
	for fraction in [0.0, 0.2, 0.4, 0.6, 0.8]:
		elevations.append(float((course.call("point_at", float(course.call("length")) * fraction) as Vector3).y))
	check(elevations.max() - elevations.min() > 8.0, "track has substantial hills and elevation changes")
	var braking_speed := float(race.call("compute_drive_speed", 20.0, 0.0, true, false, 0.3, 0.1))
	var reverse_speed := float(race.call("compute_drive_speed", 0.0, 0.0, true, false, 0.3, 0.1))
	check(braking_speed < 20.0 and braking_speed >= 0.0, "S brakes forward motion before reversing")
	check(reverse_speed < 0.0, "S engages reverse from a standstill")
	var accelerating_speed := 0.0
	for step in range(700):
		accelerating_speed = float(race.call("compute_drive_speed", accelerating_speed, 1.0, false, false, 0.5, 0.1))
	check(accelerating_speed > 65.0, "forward acceleration continues beyond the old speed cap")
	race.set("shield_hits", 0)
	race.set("ghost_time", 0.0)
	race.set("collision_cooldown", 0.0)
	race.set("durability", 100.0)
	race.set("speed", 100.0)
	car.velocity = Vector3(25.0, 0.0, -100.0)
	race.call("handle_obstacle_hit")
	check(float(race.get("speed")) < 100.0 and float(race.get("speed")) > 0.0, "obstacle collision slows according to tolerance")
	check(float(race.get("durability")) < 100.0, "obstacle collision causes real durability damage")
	check(float(race.get("collision_cooldown")) > 0.0, "collision cooldown prevents repeated damage and steering catapult")
	var head_on := race.call("project_motion_along_obstacle", Vector3(0, 0, -20), Vector3(0, 0, 1)) as Vector3
	var glancing := race.call("project_motion_along_obstacle", Vector3(10, 0, -20), Vector3(0, 0, 1)) as Vector3
	var outward := race.call("project_motion_along_obstacle", Vector3(0, 0, 20), Vector3(0, 0, 1)) as Vector3
	check(head_on.is_zero_approx(), "head-on motion remains blocked after impact")
	check(is_equal_approx(glancing.x, 10.0) and is_zero_approx(glancing.z), "glancing motion slides sideways along obstacles")
	check(outward.is_equal_approx(Vector3(0, 0, 20)), "motion away from an obstacle remains unrestricted")
	race.set("durability", 100.0)
	race.set("speed", 100.0)
	race.set("wall_impact_cooldown", 0.0)
	race.call("handle_road_edge_contact", 60.0, 0.0, 1.0 / 60.0, true, true)
	var after_wall_impact := float(race.get("durability"))
	var impact_damage := 100.0 - after_wall_impact
	check(impact_damage > 0.0 and float(race.get("speed")) > 0.0, "wall impact damage scales without stopping the car")
	race.call("handle_road_edge_contact", 0.0, 60.0, 1.0, false, false)
	var scrape_damage := after_wall_impact - float(race.get("durability"))
	check(scrape_damage > 0.0 and scrape_damage < impact_damage, "wall scraping causes lighter continuous damage")
	race.set("fuel", 12.0)
	race.call("debug_refill")
	check(is_equal_approx(float(race.get("fuel")), 100.0), "debug refill restores full fuel")
	race.call("reset_car")
	check(is_equal_approx(float(race.get("fuel")), 100.0), "race reset restores fuel")
	check(bool(race.get("race_active")), "race reset restores active state")

	await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path(SCREENSHOT_PATH)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var image := root.get_texture().get_image()
	check(not image.is_empty(), "rendered viewport can be read")
	if not image.is_empty():
		var save_error := image.save_png(output)
		check(save_error == OK, "viewport screenshot saved")
		if save_error == OK:
			print("SCREENSHOT: ", output)

	if failures.is_empty():
		print("QA RESULT: PASS")
		quit(0)
	else:
		print("QA RESULT: FAIL (%d checks)" % failures.size())
		quit(1)
