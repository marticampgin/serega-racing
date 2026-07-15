extends SceneTree

const GuideScript := preload("res://scripts/editor/editor_placement_guide.gd")
const CourseLayoutScript := preload("res://scripts/course_layout.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Engine.is_editor_hint():
		push_error("Run this test with --editor")
		quit(2)
		return
	var capture_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
	var host: Node = root
	var capture_viewport: SubViewport
	if not capture_path.is_empty():
		capture_viewport = SubViewport.new()
		capture_viewport.size = Vector2i(1280, 720)
		capture_viewport.own_world_3d = true
		capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(capture_viewport)
		host = capture_viewport
	var race := Node3D.new()
	race.name = "Race"
	var manual := Node3D.new()
	manual.name = "ManualScenery"
	manual.add_to_group("manual_scenery_root")
	race.add_child(manual)
	var guide := Node3D.new()
	guide.name = "EditorPlacementGuide"
	guide.set_script(GuideScript)
	race.add_child(guide)
	host.add_child(race)

	for frame in range(12):
		await process_frame
	var preview := guide.get_node_or_null("GeneratedWorldPreview") as Node3D
	if preview == null:
		_fail("Detailed preview root was not created")
		return
	var meshes := preview.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() < 5000:
		_fail("Detailed preview is incomplete: only %d meshes" % meshes.size())
		return
	for required_name in ["RoadSurfacePreview", "OceanSurface", "IslandTerrain"]:
		if preview.find_child(required_name, true, false) == null:
			_fail("Detailed preview is missing %s" % required_name)
			return
	for required_group in ["bridge_boundary", "tunnel_boundary", "flyover_boundary", "district_infill"]:
		if not _preview_has_group(preview, required_group):
			_fail("Detailed preview is missing group %s" % required_group)
			return
	if not preview.find_children("*", "CollisionObject3D", true, false).is_empty():
		_fail("Editor preview must not contain collision objects")
		return
	if not preview.find_children("*", "CollisionShape3D", true, false).is_empty():
		_fail("Editor preview must not contain collision shapes")
		return
	if preview.process_mode != Node.PROCESS_MODE_DISABLED:
		_fail("Editor preview processing must be disabled")
		return
	if preview.owner != null or not bool(preview.get_meta("editor_preview_only", false)):
		_fail("Editor preview must be ownerless and marked editor-only")
		return
	var overlay_root := preview.get_node_or_null("GeneratedSceneryOverlays") as Node3D
	if overlay_root == null or not bool(overlay_root.get_meta("_edit_lock_", false)):
		_fail("Generated scenery overlays must be present in a locked preview root")
		return
	for overlay_name in ["NeighborhoodDetails", "NaturalLandscapes"]:
		var overlay := overlay_root.get_node_or_null(overlay_name) as Node3D
		if overlay == null or not overlay.transform.is_equal_approx(Transform3D.IDENTITY):
			_fail("Preview overlay %s must load once at identity" % overlay_name)
			return
		for value in overlay.find_children("*", "GeometryInstance3D", true, false):
			var geometry := value as GeometryInstance3D
			if geometry.visibility_range_end < 99999.0:
				_fail("Preview overlay %s still has runtime distance culling" % overlay_name)
				return
	if not capture_path.is_empty():
		await _capture_preview(race, capture_path)

	host.remove_child(race)
	race.free()
	if capture_viewport != null:
		root.remove_child(capture_viewport)
		capture_viewport.free()
	await process_frame
	print("EDITOR WORLD PREVIEW QA: PASS (%d visible meshes)" % meshes.size())
	quit(0)


func _preview_has_group(preview: Node3D, group_name: StringName) -> bool:
	for value in get_nodes_in_group(group_name):
		if value is Node and preview.is_ancestor_of(value):
			return true
	return false


func _capture_preview(race: Node3D, path: String) -> void:
	var course: CourseLayout = CourseLayoutScript.load_default()
	var frame := course.sample_course(5850.0)
	var camera := Camera3D.new()
	camera.far = 5200.0
	race.add_child(camera)
	camera.global_position = frame.origin + frame.basis.z * 42.0 + frame.basis.y * 25.0
	camera.look_at(frame.origin - frame.basis.z * 42.0 + frame.basis.y * 3.5, frame.basis.y)
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	light.light_energy = 1.25
	race.add_child(light)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("8a2e9e")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d6c2ff")
	environment.ambient_light_energy = 0.75
	world_environment.environment = environment
	race.add_child(world_environment)
	for frame_index in range(4):
		await process_frame
	var image := race.get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		_fail("Could not save editor preview capture: %s" % error_string(error))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
