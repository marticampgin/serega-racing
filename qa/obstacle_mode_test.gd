extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.call("_on_mode_confirmed", "obstacle_course", false)
	game.call("_on_car_confirmed", "titan", Color("20c9e8"))
	await process_frame
	var obstacles := get_nodes_in_group("obstacle")
	var powerups := get_nodes_in_group("powerup")
	check(obstacles.size() > 100, "obstacle course densely populates the full lap")
	check(bool(game.get("powerups_enabled")), "obstacle mode forces power-ups on even when passed a disabled toggle")
	check(powerups.size() >= 7 and powerups.size() <= 11, "power-ups are valuable and genuinely rare around the lap")
	var kinds := {}
	for obstacle in obstacles:
		for kind in ["cone", "taxi", "car", "truck", "bulldozer", "wrecked_bolid"]:
			if kind in obstacle.name: kinds[kind] = true
	check(kinds.size() == 6, "course includes all six hazard families")
	var icon_signatures := {}
	for pickup in powerups:
		var pickup_offset := float(pickup.get_meta("course_offset", -1.0))
		var nearest_obstacle := INF
		for obstacle in obstacles:
			var obstacle_offset := float(obstacle.get_meta("course_offset", -1000.0))
			var separation := absf(pickup_offset - obstacle_offset)
			separation = minf(separation, float(game.get("TRACK_LENGTH")) - separation)
			nearest_obstacle = minf(nearest_obstacle, separation)
		check(nearest_obstacle >= 27.99, "%s is not inside or hidden directly behind an obstacle" % pickup.name)
		check(pickup.get_node_or_null("Visual") != null, "%s has a rotating 3D visual root" % pickup.name)
		var signature := ""
		for mesh_node in pickup.find_children("*", "MeshInstance3D", true, false):
			if (mesh_node as MeshInstance3D).mesh != null: signature += (mesh_node as MeshInstance3D).mesh.get_class() + ":"
		icon_signatures[signature] = true
	check(icon_signatures.size() == 4, "all four power-ups have distinct functional symbols")
	game.set("shield_hits", 0)
	game.set("ghost_time", 0.0)
	game.set("durability", 100.0)
	game.call("apply_vehicle_damage", 15.0, "TEST")
	check(float(game.get("durability")) < 100.0, "damage tolerance scales real vehicle health")
	var damaged := float(game.get("durability"))
	game.call("collect_powerup", "repair")
	check(float(game.get("durability")) > damaged, "repair power-up heals durability")
	game.call("collect_powerup", "boost")
	check(float(game.get("boost_time")) <= 6.5, "rare turbo duration stays within its balanced value")
	var car_cap := float(game.get("car_max_speed_mps"))
	game.set("road_edge_contacting", false)
	var boosted_cap := float(game.call("compute_drive_speed", 999.0, 1.0, false, false, 0.5, 0.1))
	check(boosted_cap <= car_cap * 1.051, "turbo adds only a modest maximum-speed bonus")
	game.set("road_edge_contacting", true)
	var wall_cap := float(game.call("compute_drive_speed", 999.0, 1.0, false, false, 0.5, 0.1))
	check(wall_cap <= car_cap, "turbo bonus disengages while sliding against a road edge")
	game.set("road_edge_contacting", false)
	game.call("update_hud")
	check("ТУРБО" in game.get("powerup_status_label").text and "С" in game.get("powerup_status_label").text, "HUD identifies timed power-ups and remaining duration")
	check(game.get("powerup_status_panel").visible and not game.get("powerup_icon_label").text.is_empty(), "active power-up uses the compact icon tab")
	check("ПОДОБРАНО" not in game.get("powerup_status_label").text, "power-up tab avoids redundant pickup wording")
	game.call("collect_powerup", "shield")
	game.call("collect_powerup", "shield")
	check(int(game.get("shield_hits")) == 1, "shield pickups cannot be stockpiled")
	var before_shield := float(game.get("durability"))
	game.call("apply_vehicle_damage", 30.0, "TEST")
	check(is_equal_approx(float(game.get("durability")), before_shield), "shield absorbs the next hit")
	game.call("collect_powerup", "ghost")
	check(float(game.get("ghost_time")) <= 6.0, "rare ghost duration stays within its balanced value")
	game.set("durability", 1.0)
	game.set("shield_hits", 0)
	game.set("ghost_time", 0.0)
	game.call("apply_vehicle_damage", 30.0, "TEST")
	check(not bool(game.get("race_active")) and game.get("results_overlay").visible, "zero durability opens results and ends the run")
	game.call("reset_car")
	check(is_equal_approx(float(game.get("durability")), 100.0) and bool(game.get("race_active")), "reset fully repairs the car")
	game.set("selected_game_mode", "free_run")
	game.set("powerups_enabled", false)
	game.call("build_gameplay_mode")
	check(get_nodes_in_group("obstacle").is_empty() and get_nodes_in_group("powerup").is_empty(), "free run with power-ups disabled stays completely clean")
	print("OBSTACLE MODE QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
