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
	check(load("res://scripts/main.gd") is Script, "main gameplay script compiles")
	var results: Node = (load("res://scripts/ui/race_results_overlay.gd") as Script).new()
	root.add_child(results)
	var no_laps: Array[float] = []
	var no_speeds: Array[float] = []
	results.call("show_results", no_laps, no_speeds, 2, 100.0, 12.0, false, "МАШИНА РАЗБИТА")
	check(results.get("title_label").text == "МАШИНА РАЗБИТА", "wreck result names the broken car instead of showing generic game-over text")

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_source.contains("camera_smoothed_look_target = camera_smoothed_look_target.lerp"), "camera aim uses continuous smoothing")
	check(main_source.contains("camera_tunnel_blend = lerpf"), "tunnel and bridge-adjacent camera rig transitions are blended")
	check(main_source.contains('results_overlay.call("show_results", lap_times, lap_average_speeds, collision_count, damage_sustained, elapsed, completed, reason)'), "specific finish reason reaches the results overlay")

	print("CAMERA AND RESULTS QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
