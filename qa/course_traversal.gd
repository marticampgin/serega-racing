extends SceneTree

const SAMPLE_SPACING := 60

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func fail(message: String) -> void:
	failures.append(message)
	push_error("FAIL: " + message)


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		fail("main scene does not load")
		quit(1)
		return
	var race := packed.instantiate()
	root.add_child(race)
	await physics_frame
	await physics_frame

	# Obstacles can overlap the sampling line; disable them so rays validate road only.
	for obstacle in get_nodes_in_group("obstacle"):
		if obstacle is CollisionObject3D:
			obstacle.collision_layer = 0
	var car := race.get_node("PlayerCar") as CharacterBody3D
	car.collision_layer = 0
	await physics_frame

	var space := root.world_3d.direct_space_state
	var checked := 0
	for distance in range(0, int(race.TRACK_LENGTH) + 1, SAMPLE_SPACING):
		var z := -float(distance)
		var x := float(race.call("center_x", z))
		var y := float(race.call("track_y", z))
		if y < 0.29:
			fail("road is buried beneath terrain at distance %dm" % distance)
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(x, y + 4.0, z),
			Vector3(x, y - 4.0, z),
			1
		)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			fail("no road collider at distance %dm" % distance)
			continue
		var collider := hit.get("collider") as Node
		if collider == null or not (collider.is_in_group("track") or collider.is_in_group("bridge")):
			fail("unexpected collider at distance %dm" % distance)
			continue
		checked += 1

	# Reproduce the reported failure area with an extreme off-track/fall-through state.
	var recovery_z := -1682.0
	car.global_position = Vector3(
		float(race.call("center_x", recovery_z)) + 30.0,
		float(race.call("track_y", recovery_z)) - 8.0,
		recovery_z
	)
	race.call("enforce_track_safety", 1.0 / 60.0)
	var expected := Vector3(
		float(race.call("center_x", recovery_z)),
		float(race.call("track_y", recovery_z)) + 0.55,
		recovery_z
	)
	if car.global_position.distance_to(expected) > 0.2:
		fail("off-track recovery did not return car to the road")

	var previous_heading := float(race.call("track_heading", 0.0))
	var max_heading_step := 0.0
	var min_center := INF
	var max_center := -INF
	for distance in range(12, int(race.TRACK_LENGTH) + 1, 12):
		var sample_z := -float(distance)
		var heading := float(race.call("track_heading", sample_z))
		max_heading_step = maxf(max_heading_step, absf(angle_difference(previous_heading, heading)))
		previous_heading = heading
		var center := float(race.call("center_x", sample_z))
		min_center = minf(min_center, center)
		max_center = maxf(max_center, center)
	if max_heading_step > 0.35:
		fail("track direction changes too abruptly between adjacent segments")
	if max_center - min_center < 55.0:
		fail("loop-like curve sectors lack meaningful lateral variety")

	if failures.is_empty():
		print("COURSE QA: PASS (%d road samples + recovery)" % checked)
		quit(0)
	else:
		print("COURSE QA: FAIL (%d issues)" % failures.size())
		quit(1)
