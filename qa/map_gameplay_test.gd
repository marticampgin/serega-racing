extends SceneTree

var failures: Array[String] = []
const AUTHORED_FRIEND_TEXTURES := [
	"res://assets/generated/friends/1daf0fdc-2536-4e54-b476-fc61c770b23d.jpg",
	"res://assets/generated/friends/481d5ab6-7c3f-47be-a2bd-e02bdfb2c1d5.jpg",
	"res://assets/generated/friends/5213d1b1-6e99-448d-ad81-26f61e859010.jpg",
	"res://assets/generated/friends/882a2791-af8b-4378-b3b7-a05b4cf0dd08.jpg",
]


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
	var race := packed.instantiate()
	root.add_child(race)
	await physics_frame
	await physics_frame
	race.process_mode = Node.PROCESS_MODE_DISABLED

	var car := race.get_node("PlayerCar") as CharacterBody3D
	var length: float = race.get("TRACK_LENGTH")
	check(length > 11000.0, "map lap retains the intended four-to-six-minute scale")
	check(get_nodes_in_group("obstacle").is_empty(), "track-testing build remains obstacle-free")
	var authored_friend_textures := {}
	for value in race.find_children("*", "Sprite3D", true, false):
		var sprite := value as Sprite3D
		if sprite.texture != null:
			authored_friend_textures[sprite.texture.resource_path] = true
	for texture_path in AUTHORED_FRIEND_TEXTURES:
		check(authored_friend_textures.has(texture_path), "user-placed friend display remains: %s" % texture_path)
	check(get_nodes_in_group("poster_scenery").is_empty(), "no unplaced generated friend posters are restored")
	check(get_nodes_in_group("tunnel_wall_poster").is_empty(), "no unplaced tunnel friend art is restored")
	check(get_nodes_in_group("sky_traffic_vehicle").is_empty(), "no unplaced friend-banner aircraft are restored")

	# Follow the racing line in small deterministic jumps. This exercises the same
	# branch-local progress resolver used during play, including all three loops.
	var offset := 0.0
	while offset < length:
		offset = minf(length, offset + 40.0)
		var frame := race.call("sample_course", offset) as Transform3D
		car.global_position = frame.origin + frame.basis.y * 0.55
		car.global_transform.basis = frame.basis
		race.call("update_progress", 0.0)
	check(not bool(race.get("race_active")), "one complete map lap triggers the finish")
	check(float(race.get("distance")) >= length - 2.1, "finish records a complete lap distance")

	race.call("reset_car")
	check(bool(race.get("race_active")), "reset starts a fresh map lap")
	check(is_zero_approx(float(race.get("course_offset"))), "reset returns progress to the start gate")
	var sample_offset := length * 0.71
	var recovery_frame := race.call("sample_course", sample_offset) as Transform3D
	race.set("course_offset", sample_offset)
	car.global_position = recovery_frame.origin + recovery_frame.basis.x * 40.0 - recovery_frame.basis.y * 8.0
	race.call("enforce_track_safety", 1.0 / 60.0)
	var expected := recovery_frame.origin + recovery_frame.basis.y * 0.55
	var recovery_delta := car.global_position - expected
	check(absf(recovery_delta.dot(recovery_frame.basis.x)) <= 8.4 and absf(recovery_delta.dot(recovery_frame.basis.z)) < 0.3, "off-track recovery clamps to the correct local edge without a centerline respawn")

	var braking := float(race.call("compute_drive_speed", 20.0, 0.0, true, false, 0.5, 0.1))
	var reverse := float(race.call("compute_drive_speed", 0.0, 0.0, true, false, 0.5, 0.1))
	check(braking < 20.0 and braking >= 0.0, "S brakes before selecting reverse")
	check(reverse < 0.0, "S still provides reverse on the map-driven track")
	race.set("fuel", 5.0)
	race.call("debug_refill")
	check(is_equal_approx(float(race.get("fuel")), 100.0), "debug fuel refill remains available")

	if failures.is_empty():
		print("MAP GAMEPLAY QA: PASS")
		quit(0)
	else:
		print("MAP GAMEPLAY QA: FAIL (%d issues)" % failures.size())
		quit(1)
