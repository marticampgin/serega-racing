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
	game.call("_on_mode_confirmed", "obstacle_course", true, 2, true)
	game.call("_on_car_confirmed", "iskra", Color("e9234f"))
	game.set("fuel", 20.0)
	game.call("_begin_refuel_request")
	await game.get("refuel_request").request_completed
	await process_frame
	check(not bool(game.get("refuel_in_progress")), "Godot receives the companion-service response")
	check(is_equal_approx(float(game.get("fuel")), 60.0), "dry HTTP drinking confirmation adds fuel end to end")
	check(not game.get("refuel_panel").visible, "recording overlay closes after the response")
	print("REFUEL HTTP INTEGRATION QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
