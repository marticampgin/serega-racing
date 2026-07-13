extends SceneTree

const QAUtil := preload("res://qa/map_course_qa_util.gd")
const RATIOS := [0.12, 0.5, 0.88]
const CRITICAL_OFFSETS := {
	"reported_ground_dip": 479.0,
	"reported_loop_1_crossing": 1417.0,
	"reported_bridge_approach": 3543.0,
	"tunnel_approach": 1500.0,
	"tunnel_portal_in": 1650.0,
	"tunnel_deep": 2150.0,
	"tunnel_portal_out": 2700.0,
	"loop_2_crossing": 3274.0,
	"bridge_approach": 3600.0,
	"bridge_exit": 4850.0,
	"loop_3_crossing": 7050.0,
	"sport_crossing": 8709.0,
	"former_loop_2_palm": 2732.0,
	"former_loop_3_palm": 6986.0,
}


func _initialize() -> void:
	call_deferred("_run")


func _safe_name(value: String) -> String:
	return value.to_lower().replace(" ", "_").replace("/", "_")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var race := packed.instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	var camera := root.get_camera_3d()
	var car := race.get_node_or_null("PlayerCar") as Node3D
	var curve := QAUtil.find_course_curve(race)
	var zones := QAUtil.course_zones(race)
	if camera == null or car == null or curve == null or zones.is_empty():
		push_error("visual audit requires a camera, car, curve, and zone metadata")
		quit(1)
		return
	var countdown: Label = race.get("countdown_label")
	if countdown != null:
		countdown.visible = false
	race.process_mode = Node.PROCESS_MODE_DISABLED
	var output_dir := ProjectSettings.globalize_path("res://qa/artifacts/full_lap_visual")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var capture_index := 0
	for zone_index in range(zones.size()):
		var zone: Dictionary = zones[zone_index]
		var zone_name := str(zone.get("name", "zone_%02d" % zone_index))
		var start := float(zone.get("start_distance", 0.0))
		var finish := float(zone.get("end_distance", start))
		for ratio_index in range(RATIOS.size()):
			var offset := lerpf(start, finish, RATIOS[ratio_index])
			var frame := race.call("sample_course", offset) as Transform3D
			car.global_transform = Transform3D(frame.basis, frame.origin + frame.basis.y * 0.55)
			camera.global_position = frame.origin + frame.basis.z * 13.5 + frame.basis.y * 5.8
			camera.look_at(frame.origin - frame.basis.z * 22.0 + frame.basis.y * 1.1, frame.basis.y)
			var chase_name := "%02d_%s_%d_chase.png" % [zone_index, _safe_name(zone_name), ratio_index]
			await _save_capture(camera, output_dir.path_join(chase_name))
			capture_index += 1
		# One elevated offset view per zone reveals terrain seams and roadside grounding.
		var middle := (start + finish) * 0.5
		var overview_frame := race.call("sample_course", middle) as Transform3D
		camera.global_position = overview_frame.origin + overview_frame.basis.z * 42.0 + overview_frame.basis.x * 48.0 + Vector3.UP * 30.0
		camera.look_at(overview_frame.origin + Vector3.UP * 2.0, Vector3.UP)
		var overview_name := "%02d_%s_overview.png" % [zone_index, _safe_name(zone_name)]
		await _save_capture(camera, output_dir.path_join(overview_name))
		capture_index += 1
	# Portal and crossing frames matter more than zone midpoints. These use the
	# same world-up chase geometry as gameplay, including the tunnel-safe rig.
	for label: String in CRITICAL_OFFSETS:
		var offset: float = CRITICAL_OFFSETS[label]
		var frame := race.call("sample_course", offset) as Transform3D
		car.global_transform = Transform3D(frame.basis, frame.origin + frame.basis.y * 0.55)
		var course: Object = race.get("course")
		var in_tunnel := str(course.call("zone_at", offset)) == "underwater_tunnel"
		var camera_distance := 8.4 if in_tunnel else 10.5
		var camera_height := 4.15 if in_tunnel else 5.2
		camera.global_position = car.global_position + frame.basis.z * camera_distance + Vector3.UP * camera_height
		camera.look_at(car.global_position - frame.basis.z * 5.0 + Vector3.UP * 0.55, Vector3.UP)
		await _save_capture(camera, output_dir.path_join("critical_%s.png" % label))
		capture_index += 1
	print("FULL LAP VISUAL AUDIT: %d captures" % capture_index)
	quit(0)


func _save_capture(_camera: Camera3D, path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("could not save %s: %s" % [path, error_string(error)])
