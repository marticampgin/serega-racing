extends SceneTree

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
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame

	var world := game.get_node_or_null("EditableWorld")
	check(world != null and bool(world.get_meta("runtime_optimized", false)), "main game selects optimized runtime world")
	check(not bool(game.get("game_started")), "main menu holds the race before Start")
	check(game.get("main_menu").visible, "Russian main menu is visible initially")
	check(not game.get("minimap").visible, "minimap waits for the race")
	check(game.get("minimap").call("track_point_count") >= 300, "minimap contains the complete sampled track")

	game.get("main_menu").call("_on_start_pressed")
	check(not bool(game.get("game_started")), "opening car selection does not start the race")
	check(game.get("mode_selector").visible, "Start opens game-mode selection")
	check(not game.get("main_menu").visible, "mode selection replaces the main menu")
	game.call("_on_mode_confirmed", "free_run", true)
	check(game.get("car_selector").visible, "confirming a mode opens the animated car selector")
	game.call("_on_car_confirmed", "molniya", Color("20c9e8"))
	check(bool(game.get("game_started")), "Start begins the race")
	check(not game.get("main_menu").visible, "Start hides the menu")
	check(not game.get("car_selector").visible, "confirming a car hides the selector")
	check(game.get("minimap").visible, "Start reveals the minimap")
	check(str(game.get("selected_car_id")) == "molniya", "selected car profile reaches gameplay")
	check(is_equal_approx(float(game.get("car_acceleration_mult")), 1.34), "acceleration stat changes acceleration")
	check(is_equal_approx(float(game.get("car_steering_mult")), 0.82), "control stat changes steering")
	check(is_equal_approx(float(game.get("car_fuel_mult")), 1.22), "efficiency stat changes fuel consumption")
	check(is_equal_approx(float(game.get("car_damage_mult")), 1.18), "tolerance stat changes collision penalties")
	check(is_equal_approx(float(game.get("car_max_speed_mps")) * 3.6, 650.0), "maximum-speed stat reaches gameplay")
	var capped := float(game.call("compute_drive_speed", 999.0, 1.0, false, false, 0.5, 0.1))
	check(capped <= float(game.get("car_max_speed_mps")), "drive speed respects the selected car cap")
	game.call("_pause_game")
	check(paused and game.get("pause_menu").visible, "Escape pause stops the race and shows its menu")
	game.call("_resume_game")
	check(not paused and not game.get("pause_menu").visible, "Continue returns to the race")

	var plane := world.get_node_or_null("FriendDarkHairBannerPlane") as Node3D
	var zeppelin := world.get_node_or_null("FriendBeardZeppelin") as Node3D
	check(plane != null and bool(plane.get("movement_enabled")), "authored banner plane has runtime motion")
	check(zeppelin != null and bool(zeppelin.get("movement_enabled")), "authored zeppelin has runtime motion")
	var plane_before := plane.position if plane != null else Vector3.ZERO
	var zeppelin_before := zeppelin.position if zeppelin != null else Vector3.ZERO
	await create_timer(0.3).timeout
	check(plane != null and plane.position.distance_to(plane_before) > 0.5, "banner plane moves through the sky")
	check(zeppelin != null and zeppelin.position.distance_to(zeppelin_before) > 0.1, "zeppelin moves through the sky")

	var motorcycle := world.get_node_or_null("MotorcycleRiderBillboard") as Node3D
	check(motorcycle != null and motorcycle.transform.basis.determinant() > 0.0, "motorcycle billboard support has renderable winding")
	var carrier_ranges_ok := motorcycle != null
	if motorcycle != null:
		for value in motorcycle.find_children("*", "GeometryInstance3D", true, false):
			carrier_ranges_ok = carrier_ranges_ok and (value as GeometryInstance3D).visibility_range_end >= 3200.0
	check(carrier_ranges_ok, "motorcycle billboard structure and poster share a long render range")

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	game.call("_unhandled_input", press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(80.0, -120.0)
	game.call("_unhandled_input", motion)
	check(absf(float(game.get("camera_orbit_yaw"))) > 0.1, "right-drag orbits the chase camera")
	check(float(game.get("camera_extra_height")) > 0.0, "right-drag can raise the chase camera")
	motion.relative = Vector2(0.0, 10000.0)
	game.call("_unhandled_input", motion)
	check(is_equal_approx(float(game.get("camera_extra_height")), -1.4), "camera can move slightly lower but respects its safety limit")

	print("GAMEPLAY FEATURES QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
