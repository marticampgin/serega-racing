extends SceneTree

const OUTPUT_DIRECTORY := "res://qa/artifacts/natural_landscapes"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("natural landscape visual audit requires a rendering display")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var race := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	var camera := root.get_camera_3d()
	var course: CourseLayout = race.get("course")
	var countdown: Label = race.get("countdown_label")
	if countdown != null:
		countdown.visible = false
	race.process_mode = Node.PROCESS_MODE_DISABLED
	var features: Array[Node3D] = []
	for value in get_nodes_in_group("natural_landscape_scenery"):
		if value is Node3D and race.is_ancestor_of(value):
			features.append(value as Node3D)
	features.sort_custom(func(a: Node3D, b: Node3D) -> bool: return str(a.name) < str(b.name))
	var failures := 0
	var captures := 0
	var name_counts: Dictionary = {}
	for feature in features:
		var base_id := str(feature.name).to_snake_case()
		var copy_index := int(name_counts.get(base_id, 0))
		name_counts[base_id] = copy_index + 1
		var id := base_id if copy_index == 0 else "%s_copy_%02d" % [base_id, copy_index]
		var scale := feature.global_transform.basis.get_scale()
		var radius := float(feature.get_meta("landscape_radius", 25.0)) * maxf(absf(scale.x), absf(scale.z))
		var centre := feature.global_position
		var offset := _closest_course_offset(course, Vector2(centre.x, centre.z))
		var lateral := course.lateral_at(offset)
		var tangent := course.tangent_at(offset)
		camera.global_position = centre + lateral * radius * 1.8 - tangent * radius * 1.4 + Vector3.UP * maxf(42.0, radius * 1.6)
		camera.look_at(centre + Vector3.UP * 5.0, Vector3.UP)
		failures += 0 if await _capture("%s_aerial.png" % id) == OK else 1
		captures += 1
		var road := course.point_at(offset)
		camera.global_position = road - tangent * 55.0 + Vector3.UP * 7.0
		camera.look_at(centre + Vector3.UP * 7.0, Vector3.UP)
		failures += 0 if await _capture("%s_road.png" % id) == OK else 1
		captures += 1
	print("NATURAL LANDSCAPE VISUAL QA: %d captures, %d failures" % [captures, failures])
	quit(0 if failures == 0 else 1)


func _closest_course_offset(course: CourseLayout, position: Vector2) -> float:
	var best_offset := 0.0
	var best_distance := INF
	var offset := 0.0
	while offset < course.length():
		var point := course.point_at(offset)
		var distance := position.distance_squared_to(Vector2(point.x, point.z))
		if distance < best_distance:
			best_distance = distance
			best_offset = offset
		offset += 8.0
	return best_offset


func _capture(file_name: String) -> Error:
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIRECTORY.path_join(file_name))
	var error := image.save_png(path)
	if error == OK:
		print("NATURAL LANDSCAPE VISUAL: ", file_name)
	else:
		push_error("Could not save %s: %s" % [file_name, error_string(error)])
	return error
