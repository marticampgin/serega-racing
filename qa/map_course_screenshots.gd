extends SceneTree

const QAUtil := preload("res://qa/map_course_qa_util.gd")
const CAPTURES := [
	{"file": "start_coast.png", "zone": "start"},
	{"file": "underwater_tunnel.png", "zone": "underwater tunnel"},
	{"file": "bridge.png", "zone": "bridge"},
	{"file": "party_town.png", "zone": "party town"},
	{"file": "city_centre.png", "zone": "city centre"},
	{"file": "loop_3.png", "zone": "loop 3"},
	{"file": "shopping_alley.png", "zone": "shopping alley"},
	{"file": "sport_complex.png", "zone": "sport complex"},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("main scene does not load")
		quit(1)
		return
	var race := packed.instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	var curve := QAUtil.find_course_curve(race)
	var camera := root.get_camera_3d()
	var zones := QAUtil.course_zones(race)
	if curve == null or camera == null or zones.is_empty():
		push_error("map course, camera, or zone metadata is unavailable")
		quit(1)
		return
	var output_dir := ProjectSettings.globalize_path("res://qa/artifacts/map_course")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var failures := 0
	for capture in CAPTURES:
		var zone := QAUtil.find_zone(zones, capture.zone)
		if zone.is_empty():
			push_error("missing screenshot zone: " + capture.zone)
			failures += 1
			continue
		var length := curve.get_baked_length()
		var offset := (QAUtil.zone_start(zone, length) + QAUtil.zone_end(zone, length)) * 0.5
		var point := QAUtil.course_position(race, curve, offset)
		var tangent := QAUtil.course_tangent(race, curve, offset)
		var up := QAUtil.course_up(race, curve, offset)
		camera.global_position = point - tangent * 15.0 + up * 6.0
		camera.look_at(point + tangent * 24.0 + up * 1.0, up)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var output := output_dir.path_join(capture.file)
		var error := image.save_png(output)
		if error == OK:
			print("SCREENSHOT: ", output)
		else:
			push_error("could not save %s: %s" % [capture.file, error_string(error)])
			failures += 1
	quit(0 if failures == 0 else 1)
