@tool
extends Node3D

const CourseLayoutScript := preload("res://scripts/course_layout.gd")
const WorldBuilderScript := preload("res://scripts/world_builder.gd")
const EDITABLE_WORLD_PATH := "res://scenes/world/editable_world.tscn"

const ROAD_WIDTH := 17.0
const ROAD_SAMPLE_STEP := 2.0

@export var show_world_preview := true:
	set(value):
		show_world_preview = value
		_request_rebuild()
@export var show_saved_scenery := true:
	set(value):
		show_saved_scenery = value
		_request_rebuild()
@export var show_land_corridor := false:
	set(value):
		show_land_corridor = value
		_request_rebuild()
@export var show_water_plane := false:
	set(value):
		show_water_plane = value
		_request_rebuild()
@export_range(40.0, 220.0, 5.0) var land_corridor_width := 150.0:
	set(value):
		land_corridor_width = value
		_request_rebuild()
@export var refresh_preview := false:
	set(value):
		refresh_preview = false
		if value:
			_request_rebuild()

var _rebuild_queued := false


func _enter_tree() -> void:
	add_to_group("editor_placement_guide", true)
	_request_rebuild()


func _request_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	for child in get_children(true):
		remove_child(child)
		child.free()
	if not Engine.is_editor_hint():
		return

	var course: CourseLayout = CourseLayoutScript.load_default()
	if show_world_preview:
		_build_detailed_preview(course)
	else:
		_add_ribbon(course, course.road_half_width * 2.0, Color(0.16, 0.18, 0.24, 0.86), 0.03, "RoadPlacementGuide", 12.0, self)
		_add_ribbon(course, 0.7, Color(1.0, 0.25, 0.82, 1.0), 0.08, "CourseCentreGuide", 12.0, self)
	if show_water_plane:
		_add_water_plane()
	if show_land_corridor:
		_add_ribbon(course, land_corridor_width, Color(0.82, 0.48, 0.35, 0.22), -0.18, "LandPlacementGuide", 12.0, self)


func _build_detailed_preview(course: CourseLayout) -> void:
	var preview := Node3D.new()
	preview.name = "GeneratedWorldPreview"
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	preview.set_meta("editor_preview_only", true)
	preview.set_meta("_edit_lock_", true)
	add_child(preview, false, Node.INTERNAL_MODE_BACK)

	_add_exact_track_preview(course, preview)
	var builder: WorldBuilder = WorldBuilderScript.new()
	# The Race parent is the reservation scope, so procedural preview scenery
	# respects real ManualScenery siblings while remaining under this internal root.
	builder.build_infrastructure(preview, course, get_parent() as Node3D)
	var saved_meshes := 0
	if show_saved_scenery and ResourceLoader.exists(EDITABLE_WORLD_PATH):
		var packed := load(EDITABLE_WORLD_PATH) as PackedScene
		if packed != null:
			var saved_world := packed.instantiate() as Node3D
			var nested_guide := saved_world.get_node_or_null("EditorPlacementGuide")
			if nested_guide != null:
				saved_world.remove_child(nested_guide)
				nested_guide.free()
			saved_world.name = "SavedEditableSceneryPreview"
			saved_world.set_meta("_edit_lock_", true)
			preview.add_child(saved_world)
			saved_meshes = saved_world.find_children("*", "MeshInstance3D", true, false).size()
	print("Editor world preview: complete road, %d infrastructure meshes and %d saved scenery meshes" % [builder.mesh_instance_count, saved_meshes])


func _add_exact_track_preview(course: CourseLayout, parent: Node3D) -> void:
	_add_ribbon(course, ROAD_WIDTH + 1.4, Color("171b27"), -0.18, "RoadDeckPreview", ROAD_SAMPLE_STEP, parent)
	_add_ribbon(course, ROAD_WIDTH, Color("242832"), 0.0, "RoadSurfacePreview", ROAD_SAMPLE_STEP, parent)
	_add_shifted_ribbon(course, 0.6, ROAD_WIDTH * 0.5, 0.045, Color("ff3f81"), "PinkCurbPreview", parent)
	_add_shifted_ribbon(course, 0.6, -ROAD_WIDTH * 0.5, 0.045, Color("f4f4ee"), "WhiteCurbPreview", parent)

	var marker_material := _material(Color("f6f0ce"))
	var marker_offset := 18.0
	while marker_offset < course.length():
		var frame := course.sample_course(marker_offset)
		var marker := MeshInstance3D.new()
		marker.name = "CentreMarkerPreview"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.16, 0.04, 5.0)
		mesh.material = marker_material
		marker.mesh = mesh
		marker.transform = Transform3D(frame.basis, frame.origin + frame.basis.y * 0.055)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(marker)
		marker_offset += 24.0


func _add_ribbon(course: CourseLayout, width: float, color: Color, lift: float, label: String, step: float, parent: Node3D) -> void:
	_add_shifted_ribbon(course, width, 0.0, lift, color, label, parent, step)


func _add_shifted_ribbon(course: CourseLayout, width: float, lateral_shift: float, lift: float, color: Color, label: String, parent: Node3D, step := ROAD_SAMPLE_STEP) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offset := 0.0
	while offset < course.length():
		var next := minf(offset + step, course.length())
		var frame_a := course.sample_course(offset)
		var frame_b := course.sample_course(next)
		var a := frame_a.origin + frame_a.basis.x * lateral_shift + frame_a.basis.y * lift
		var b := frame_b.origin + frame_b.basis.x * lateral_shift + frame_b.basis.y * lift
		var ar := frame_a.basis.x * width * 0.5
		var br := frame_b.basis.x * width * 0.5
		for vertex in [a - ar, b - br, b + br, a - ar, b + br, a + ar]:
			surface.add_vertex(vertex)
		offset = next
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.commit()
	instance.material_override = _material(color)
	instance.visibility_range_end = 100000.0
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if label.contains("Guide") else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	instance.add_to_group("editor_only_placement_guide")
	parent.add_child(instance)


func _add_water_plane() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(4200.0, 4200.0)
	var material := _material(Color(0.05, 0.75, 0.9, 0.14))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = "WaterPlacementGuide"
	instance.mesh = mesh
	instance.position.y = -1.4
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_to_group("editor_only_placement_guide")
	add_child(instance, false, Node.INTERNAL_MODE_BACK)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	if color.a < 1.0:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
