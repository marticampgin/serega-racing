extends SceneTree

## Deterministic visual-regression captures for the geometry and world-density
## checkpoints that have historically needed manual inspection.
##
## Run with:
##   Godot_v4.7-stable_win64_console.exe --path . --script res://qa/exact_visual_checkpoint_audit.gd
##
## Unlike the broad full-lap harness, this script does not await
## RenderingServer.frame_post_draw. That signal can stall in headless or
## minimized Compatibility-renderer sessions. Explicit draws and process frames
## keep the checkpoint run finite while still presenting completed frames.

const QAUtil := preload("res://qa/map_course_qa_util.gd")
const OUTPUT_DIRECTORY := "res://qa/artifacts/exact_visual_checkpoints"

const FIXED_CHECKPOINTS := [
	{"file": "tunnel_approach_1552.png", "offset": 1552.0, "mode": "chase"},
	{"file": "tunnel_shoreline_overview_1552.png", "offset": 1552.0, "mode": "shoreline_overview"},
	{"file": "tunnel_waterline_1906.png", "offset": 1906.0, "mode": "chase"},
	{"file": "loop_2_structure_3234.png", "offset": 3234.0, "mode": "chase"},
	{"file": "loop_2_structure_side_3234.png", "offset": 3234.0, "mode": "side_overview"},
	{"file": "bridge_entry_3600.png", "offset": 3600.0, "mode": "chase"},
	{"file": "bridge_entry_shoreline_3600.png", "offset": 3600.0, "mode": "shoreline_overview"},
	{"file": "bridge_middle_4200.png", "offset": 4200.0, "mode": "chase"},
	{"file": "bridge_support_overview_4200.png", "offset": 4200.0, "mode": "overview"},
	{"file": "bridge_exit_4800.png", "offset": 4800.0, "mode": "chase"},
	{"file": "bridge_exit_shoreline_4800.png", "offset": 4800.0, "mode": "shoreline_overview"},
	{"file": "city_crossing_5823.png", "offset": 5823.0, "mode": "chase"},
]

# These checkpoint offsets are derived from zone boundaries so they continue to
# target the same physical construction detail if the course bake changes.
const ZONE_RELATIVE_CHECKPOINTS := [
	{"file": "tunnel_water_patch_before.png", "zone": "underwater tunnel", "from": "start", "delta": -28.0, "mode": "chase"},
	{"file": "tunnel_water_patch_after.png", "zone": "underwater tunnel", "from": "end", "delta": 28.0, "mode": "chase"},
	# Bridge supports are emitted at zone start + 24 + 48*n. These three views
	# therefore aim at exact cap/pier locations, not arbitrary points between piers.
	{"file": "bridge_contact_near.png", "zone": "bridge", "from": "start", "delta": 216.0, "mode": "bridge_low_side_left"},
	{"file": "bridge_contact_middle.png", "zone": "bridge", "from": "start", "delta": 600.0, "mode": "bridge_low_side_right"},
	{"file": "bridge_contact_far.png", "zone": "bridge", "from": "start", "delta": 984.0, "mode": "bridge_low_side_left"},
]

const DISTRICT_CHECKPOINTS := [
	{"file": "party_town_far.png", "zone": "party town", "mode": "far_overview"},
	{"file": "city_centre_far.png", "zone": "city centre", "mode": "far_overview"},
	{"file": "shopping_alley_overview.png", "zone": "shopping alley"},
	{"file": "shopping_alley_far.png", "zone": "shopping alley", "mode": "far_overview"},
	{"file": "sport_complex_overview.png", "zone": "sport complex"},
	{"file": "sport_complex_far.png", "zone": "sport complex", "mode": "far_overview"},
	{"file": "north_coast_overview.png", "zone": "north coast"},
	{"file": "north_coast_far.png", "zone": "north coast", "mode": "far_overview"},
	{"file": "party_island_view_overview.png", "zone": "party island view", "mode": "party_island_overview"},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("exact visual audit requires a rendering display; run without --headless")
		quit(2)
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("exact visual audit could not load the main scene")
		quit(1)
		return
	var race := packed.instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	var camera := root.get_camera_3d()
	var car := race.get_node_or_null("PlayerCar") as Node3D
	var curve := QAUtil.find_course_curve(race)
	var zones := QAUtil.course_zones(race)
	if camera == null or car == null or curve == null or zones.is_empty():
		push_error("exact visual audit requires a camera, car, course, and zone metadata")
		quit(1)
		return
	var built_world: Variant = race.get("world_builder") if QAUtil.has_property(race, &"world_builder") else null
	if built_world == null or get_nodes_in_group("ocean_scenery").is_empty() or get_nodes_in_group("island_terrain").is_empty():
		push_error("exact visual audit refuses to capture an incomplete world")
		quit(1)
		return
	var countdown: Label = race.get("countdown_label")
	if countdown != null:
		countdown.visible = false
	# Freeze gameplay and its chase-camera updates after the complete world exists.
	race.process_mode = Node.PROCESS_MODE_DISABLED
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if directory_error != OK:
		push_error("could not create exact visual output directory: %s" % error_string(directory_error))
		quit(1)
		return

	var checkpoints: Array[Dictionary] = []
	for checkpoint: Dictionary in FIXED_CHECKPOINTS:
		checkpoints.append(checkpoint)
	for relative: Dictionary in ZONE_RELATIVE_CHECKPOINTS:
		var relative_zone := QAUtil.find_zone(zones, str(relative.zone))
		if relative_zone.is_empty():
			push_error("missing exact visual audit zone: %s" % relative.zone)
			continue
		var relative_length := curve.get_baked_length()
		var boundary := QAUtil.zone_start(relative_zone, relative_length)
		if str(relative.get("from", "start")) == "end":
			boundary = QAUtil.zone_end(relative_zone, relative_length)
		checkpoints.append({
			"file": relative.file,
			"offset": boundary + float(relative.get("delta", 0.0)),
			"mode": relative.mode,
		})
	for district: Dictionary in DISTRICT_CHECKPOINTS:
		var zone := QAUtil.find_zone(zones, str(district.zone))
		if zone.is_empty():
			push_error("missing exact visual audit zone: %s" % district.zone)
			continue
		var length := curve.get_baked_length()
		checkpoints.append({
			"file": district.file,
			"offset": (QAUtil.zone_start(zone, length) + QAUtil.zone_end(zone, length)) * 0.5,
			"mode": district.get("mode", "overview"),
		})

	var failures := DISTRICT_CHECKPOINTS.size() + FIXED_CHECKPOINTS.size() + ZONE_RELATIVE_CHECKPOINTS.size() - checkpoints.size()
	for checkpoint: Dictionary in checkpoints:
		var offset := float(checkpoint.offset)
		var frame := race.call("sample_course", offset) as Transform3D
		car.global_transform = Transform3D(frame.basis, frame.origin + frame.basis.y * 0.55)
		if str(checkpoint.mode) == "party_island_overview":
			var course: Object = race.get("course")
			var landmark: Vector3 = course.call("landmark_position", &"party_island")
			var roadward := (frame.origin - landmark).normalized()
			camera.global_position = landmark + roadward * 118.0 + Vector3.UP * 42.0
			camera.look_at(landmark + Vector3.UP * 8.0, Vector3.UP)
		elif str(checkpoint.mode) == "far_overview":
			camera.global_position = frame.origin + frame.basis.z * 145.0 + frame.basis.x * 115.0 + Vector3.UP * 68.0
			camera.look_at(frame.origin + Vector3.UP * 7.0, Vector3.UP)
		elif str(checkpoint.mode) == "shoreline_overview":
			camera.global_position = frame.origin + frame.basis.z * 30.0 + frame.basis.x * 68.0 + Vector3.UP * 24.0
			camera.look_at(frame.origin + frame.basis.x * 14.0 + Vector3.UP * 1.0, Vector3.UP)
		elif str(checkpoint.mode) == "side_overview":
			camera.global_position = frame.origin + frame.basis.z * 16.0 + frame.basis.x * 64.0 + Vector3.UP * 25.0
			camera.look_at(frame.origin + Vector3.UP * 3.0, Vector3.UP)
		elif str(checkpoint.mode).begins_with("bridge_low_side"):
			var camera_side := -1.0 if str(checkpoint.mode).ends_with("right") else 1.0
			camera.global_position = frame.origin + frame.basis.z * 10.0 + frame.basis.x * 34.0 * camera_side
			# Keep the lens just above the water/terrain rather than inheriting the
			# road deck height. This exposes column-to-cap and cap-to-deck contact.
			camera.global_position.y = 2.4
			camera.look_at(frame.origin - Vector3.UP * 0.7, Vector3.UP)
		elif str(checkpoint.mode) == "overview":
			camera.global_position = frame.origin + frame.basis.z * 52.0 + frame.basis.x * 58.0 + Vector3.UP * 34.0
			camera.look_at(frame.origin + Vector3.UP * 2.0, Vector3.UP)
		else:
			var course: Object = race.get("course")
			var in_tunnel := str(course.call("zone_at", offset)) == "underwater_tunnel"
			var camera_distance := 8.4 if in_tunnel else 10.5
			var camera_height := 4.15 if in_tunnel else 5.2
			camera.global_position = car.global_position + frame.basis.z * camera_distance + Vector3.UP * camera_height
			camera.look_at(car.global_position - frame.basis.z * 5.0 + Vector3.UP * 0.55, Vector3.UP)
		var output := output_dir.path_join(str(checkpoint.file))
		var capture_error := await _save_presented_frame(output)
		if capture_error == OK:
			print("EXACT VISUAL CHECKPOINT: %s offset=%.1f mode=%s" % [checkpoint.file, offset, checkpoint.mode])
		else:
			push_error("could not save %s: %s" % [checkpoint.file, error_string(capture_error)])
			failures += 1
	print("EXACT VISUAL CHECKPOINT QA: %d captures, %d failures" % [checkpoints.size(), failures])
	quit(0 if failures == 0 else 1)


func _save_presented_frame(path: String) -> Error:
	# Two explicit draws eliminate reliance on frame_post_draw and give imported
	# materials plus visibility-range changes a completed frame before readback.
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	var texture := root.get_texture()
	if texture == null:
		return ERR_UNAVAILABLE
	var image := texture.get_image()
	if image == null or image.is_empty():
		return ERR_UNAVAILABLE
	return image.save_png(path)
