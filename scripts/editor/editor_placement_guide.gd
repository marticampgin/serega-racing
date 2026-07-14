@tool
extends Node3D

const CourseLayoutScript := preload("res://scripts/course_layout.gd")

@export var show_land_corridor := true:
	set(value):
		show_land_corridor = value
		_rebuild.call_deferred()
@export var show_water_plane := true:
	set(value):
		show_water_plane = value
		_rebuild.call_deferred()
@export_range(40.0, 220.0, 5.0) var land_corridor_width := 150.0:
	set(value):
		land_corridor_width = value
		_rebuild.call_deferred()


func _enter_tree() -> void:
	add_to_group("editor_placement_guide", true)
	_rebuild.call_deferred()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)
		child.free()
	if not Engine.is_editor_hint():
		return
	var course := CourseLayoutScript.load_default()
	if show_water_plane:
		_add_water_plane()
	if show_land_corridor:
		_add_ribbon(course, land_corridor_width, Color(0.82, 0.48, 0.35, 0.22), -0.18, "LandPlacementGuide")
	_add_ribbon(course, course.road_half_width * 2.0, Color(0.16, 0.18, 0.24, 0.86), 0.03, "RoadPlacementGuide")
	_add_ribbon(course, 0.7, Color(1.0, 0.25, 0.82, 1.0), 0.08, "CourseCentreGuide")


func _add_ribbon(course: CourseLayout, width: float, color: Color, lift: float, label: String) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 12.0
	var offset := 0.0
	while offset < course.length():
		var next := minf(offset + step, course.length())
		var a := course.point_at(offset) + Vector3.UP * lift
		var b := course.point_at(next) + Vector3.UP * lift
		var ar := course.lateral_at(offset) * width * 0.5
		var br := course.lateral_at(next) * width * 0.5
		for vertex in [a - ar, b - br, b + br, a - ar, b + br, a + ar]:
			surface.add_vertex(vertex)
		offset = next
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if color.a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_to_group("editor_only_placement_guide")
	add_child(instance, false, Node.INTERNAL_MODE_BACK)


func _add_water_plane() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(4200.0, 4200.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.75, 0.9, 0.14)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = "WaterPlacementGuide"
	instance.mesh = mesh
	instance.position.y = -1.4
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_to_group("editor_only_placement_guide")
	add_child(instance, false, Node.INTERNAL_MODE_BACK)
