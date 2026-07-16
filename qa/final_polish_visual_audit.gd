extends SceneTree

const CourseLayoutScript := preload("res://scripts/course_layout.gd")
const OUTPUT_DIR := "res://qa/artifacts/final_polish"
const CLUSTERS := [
	["city_monument", 6040.0, -1.0], ["city_bungalow", 6210.0, -1.0],
	["loop_cabana", 6550.0, 1.0], ["shopping_marina_office", 7570.0, 1.0],
	["sport_bus_stop", 7740.0, -1.0], ["sport_bungalow", 8420.0, 1.0],
	["sport_walking_trail", 8760.0, 1.0], ["north_sunset_pavilion", 9100.0, -1.0],
	["north_cabana", 10120.0, 1.0], ["north_marina_office", 10460.0, -1.0],
	["party_view_cabana", 11310.0, -1.0], ["loop_two_cabana", 2980.0, -1.0],
	["party_phone_booth", 5530.0, -1.0],
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var race := packed.instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	var camera := root.get_camera_3d()
	var course: CourseLayout = CourseLayoutScript.load_default()
	if camera == null:
		push_error("FINAL POLISH VISUAL: no active camera")
		quit(1)
		return
	race.process_mode = Node.PROCESS_MODE_DISABLED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var failures := 0
	for spec: Array in CLUSTERS:
		var offset := float(spec[1])
		var side := float(spec[2])
		var road := course.point_at(offset)
		var lateral := course.lateral_at(offset).normalized()
		var tangent := course.tangent_at(offset).normalized()
		var target := road + lateral * side * 51.0
		target.y = 3.0
		camera.global_position = road + lateral * side * 16.0 - tangent * 10.0 + Vector3.UP * 6.0
		camera.look_at(target, Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		failures += _save_capture("cluster_%s.png" % str(spec[0]))
	# The repaired promenade and four cardinal sky directions get their own views.
	var boardwalk_target := Vector3(-1172.0, 1.4, -842.0)
	camera.global_position = boardwalk_target + Vector3(24.0, 10.0, 22.0)
	camera.look_at(boardwalk_target, Vector3.UP)
	await process_frame
	await RenderingServer.frame_post_draw
	failures += _save_capture("repaired_boardwalk.png")
	for direction_index in range(8):
		var angle := float(direction_index) * TAU / 8.0
		camera.global_position = Vector3(0.0, 80.0, 0.0)
		camera.look_at(camera.global_position + Vector3(cos(angle), 0.08, sin(angle)) * 100.0, Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		failures += _save_capture("sky_%d.png" % direction_index)
	print("FINAL POLISH VISUAL QA: %d captures, %d failures" % [CLUSTERS.size() + 9, failures])
	quit(0 if failures == 0 else 1)


func _save_capture(file_name: String) -> int:
	var output := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(file_name))
	var error := root.get_texture().get_image().save_png(output)
	if error != OK:
		push_error("FINAL POLISH VISUAL: could not save %s: %s" % [file_name, error_string(error)])
		return 1
	print("FINAL POLISH VISUAL: %s" % file_name)
	return 0
