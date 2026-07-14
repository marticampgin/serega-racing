extends SceneTree

const CourseLayoutScript := preload("res://scripts/course_layout.gd")

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
	var manual_root := race.get_node("ManualScenery") as Node3D
	var hotel := (load("res://scenes/manual_scenery/presets/buildings/grand_hotel.tscn") as PackedScene).instantiate() as Node3D
	var course := CourseLayoutScript.load_default()
	var offset := 336.5
	var road := course.point_at(offset)
	var position := road + course.lateral_at(offset) * 72.0
	position.y = 1.32
	hotel.position = position
	manual_root.add_child(hotel)
	var initial_transform := hotel.transform
	root.add_child(race)
	await process_frame
	await process_frame

	check(hotel.transform.is_equal_approx(initial_transform), "manual placement remains exactly editor-authored at runtime")
	check(hotel.is_in_group("manual_grounded_scenery"), "manual building registers its land reservation")
	check(hotel.find_children("*", "MeshInstance3D", true, false).size() > 10, "dragged preset keeps its complete visible model")
	var manual_radius := float(hotel.get_meta("scenery_radius", 22.0))
	var overlaps := 0
	for value in get_nodes_in_group("grounded_scenery"):
		if not value is Node3D or value == hotel or not race.is_ancestor_of(value) or manual_root.is_ancestor_of(value):
			continue
		var generated := value as Node3D
		var generated_radius := float(generated.get_meta("scenery_radius", 4.0))
		if generated.is_in_group("palm_scenery"):
			generated_radius = maxf(generated_radius, 4.6)
		var distance := Vector2(hotel.global_position.x, hotel.global_position.z).distance_to(Vector2(generated.global_position.x, generated.global_position.z))
		if distance < manual_radius + generated_radius + 1.0:
			overlaps += 1
			print("INFO: manual overlap candidate %s distance=%.2f radii=%.2f" % [generated.name, distance, manual_radius + generated_radius])
	check(overlaps == 0, "procedural scenery reserves the manually decorated footprint")
	check(race.get_node_or_null("PlayerCar") != null, "manual scenery layer does not affect gameplay initialization")
	print("MANUAL SCENERY RESERVATION QA: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
