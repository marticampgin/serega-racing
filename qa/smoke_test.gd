extends SceneTree

const SCREENSHOT_PATH := "res://qa/artifacts/smoke.png"

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
	check(packed != null, "main scene loads")
	if packed == null:
		quit(1)
		return

	var race := packed.instantiate()
	root.add_child(race)
	await process_frame
	await process_frame

	check(race is Node3D, "main scene instantiates as a 3D race")
	var car := race.get_node_or_null("PlayerCar") as CharacterBody3D
	check(car != null, "player car exists")
	var camera := root.get_camera_3d()
	check(camera != null and camera.is_current(), "active chase camera exists")
	check(get_nodes_in_group("obstacle").size() > 10, "randomized obstacle course is populated")
	check(get_nodes_in_group("bridge").size() > 10, "elevated bridge road and supports exist")
	check(get_nodes_in_group("tunnel").size() > 10, "tunnel arch sequences exist")
	check(get_nodes_in_group("rock_scenery").size() > 5, "non-box rock scenery exists")
	check(race.find_children("*", "Sprite3D", true, false).size() >= 6, "personalized portrait billboards remain placed")
	check(race.get("fuel_bar") is ProgressBar, "fuel HUD exists")
	check(race.get("status_label") is Label, "race status HUD exists")

	var initial_fuel: float = race.get("fuel")
	race.call("apply_drink_result", "purple")
	check(float(race.get("fuel")) >= initial_fuel, "drink result refuels the car")
	check(float(race.get("ghost_time")) > 0.0, "purple drink enables ghost mode")
	var elevations: Array[float] = []
	for z in [-500.0, -2500.0, -6000.0, -7200.0, -9000.0]:
		elevations.append(float(race.call("track_y", z)))
	check(elevations.max() - elevations.min() > 8.0, "track has substantial hills and elevation changes")
	var braking_speed := float(race.call("compute_drive_speed", 20.0, 0.0, true, false, 0.3, 0.1))
	var reverse_speed := float(race.call("compute_drive_speed", 0.0, 0.0, true, false, 0.3, 0.1))
	check(braking_speed < 20.0 and braking_speed >= 0.0, "S brakes forward motion before reversing")
	check(reverse_speed < 0.0, "S engages reverse from a standstill")
	var accelerating_speed := 0.0
	for step in range(700):
		accelerating_speed = float(race.call("compute_drive_speed", accelerating_speed, 1.0, false, false, 0.5, 0.1))
	check(accelerating_speed > 65.0, "forward acceleration continues beyond the old speed cap")
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
