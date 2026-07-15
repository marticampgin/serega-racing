extends SceneTree

const GuideScript := preload("res://scripts/editor/editor_placement_guide.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not Engine.is_editor_hint():
		push_error("Run this test with --editor so the editor-only guide is enabled")
		quit(2)
		return
	var guide := Node3D.new()
	guide.name = "EditorPlacementGuide"
	guide.set_script(GuideScript)
	guide.set("show_world_preview", false)
	guide.set("show_land_corridor", true)
	guide.set("show_water_plane", true)
	root.add_child(guide)
	await process_frame
	await process_frame
	var meshes := guide.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 4:
		push_error("Expected water, land, road and centre-line guide meshes; got %d" % meshes.size())
		quit(1)
		return
	for value in meshes:
		var mesh := value as MeshInstance3D
		if mesh.mesh == null or mesh.get_aabb().size.length() < 100.0:
			push_error("Placement guide mesh is missing or too small: %s" % mesh.name)
			quit(1)
			return
	if not guide.find_children("*", "CollisionObject3D", true, false).is_empty():
		push_error("Editor placement guide must never create collision")
		quit(1)
		return
	root.remove_child(guide)
	guide.free()
	await process_frame
	print("EDITOR PLACEMENT GUIDE QA: PASS (water, land, road and centre line)")
	quit(0)
