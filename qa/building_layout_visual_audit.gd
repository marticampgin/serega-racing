extends SceneTree

const OUTPUT_DIRECTORY := "res://qa/artifacts/building_layout"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("building layout visual audit requires a rendering display")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var packed := load("res://scenes/main.tscn") as PackedScene
	var race := packed.instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	var camera := root.get_camera_3d()
	var course: CourseLayout = race.get("course")
	var blocks := {}
	for value in get_nodes_in_group("building_layout"):
		if not value is Node3D or not race.is_ancestor_of(value):
			continue
		var building := value as Node3D
		var block_id := str(building.get_meta("layout_block_id", ""))
		if not blocks.has(block_id):
			blocks[block_id] = []
		(blocks[block_id] as Array).append(building)
	var countdown: Label = race.get("countdown_label")
	if countdown != null:
		countdown.visible = false
	race.process_mode = Node.PROCESS_MODE_DISABLED
	var failures := 0
	var capture_count := 0
	var block_ids: Array = blocks.keys()
	block_ids.sort()
	for block_id: String in block_ids:
		var buildings: Array = blocks[block_id]
		var centre := Vector3.ZERO
		var offset_total := 0.0
		var minimum_offset := INF
		var maximum_offset := -INF
		for building: Node3D in buildings:
			centre += building.global_position
			var offset := float(building.get_meta("course_offset", 0.0))
			offset_total += offset
			minimum_offset = minf(minimum_offset, offset)
			maximum_offset = maxf(maximum_offset, offset)
		centre /= float(buildings.size())
		var middle_offset := offset_total / float(buildings.size())
		var forward := course.tangent_at(middle_offset)
		var lateral := course.lateral_at(middle_offset)
		camera.global_position = centre - forward * 105.0 + lateral * 120.0 + Vector3.UP * 125.0
		camera.look_at(centre + Vector3.UP * 10.0, Vector3.UP)
		if await _capture("%s_aerial.png" % block_id.to_snake_case()) != OK:
			failures += 1
		capture_count += 1
		var start := course.point_at(maxf(0.0, minimum_offset - 30.0))
		var target := course.point_at(minf(course.length(), maximum_offset + 20.0))
		camera.global_position = start + Vector3.UP * 7.0
		camera.look_at(target + Vector3.UP * 5.0, Vector3.UP)
		if await _capture("%s_street.png" % block_id.to_snake_case()) != OK:
			failures += 1
		capture_count += 1
	print("BUILDING LAYOUT VISUAL QA: %d captures, %d failures" % [capture_count, failures])
	quit(0 if failures == 0 else 1)


func _capture(file_name: String) -> Error:
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIRECTORY.path_join(file_name))
	var error := image.save_png(path)
	if error == OK:
		print("BUILDING LAYOUT VISUAL: ", file_name)
	else:
		push_error("Could not save %s: %s" % [file_name, error_string(error)])
	return error
