extends SceneTree

const CourseLayoutScript := preload("res://scripts/course_layout.gd")
const WorldBuilderScript := preload("res://scripts/world_builder.gd")
const LandscapeBuilderScript := preload("res://scripts/natural_landscape_builder.gd")

const EDITABLE_WORLD_PATH := "res://scenes/world/editable_world.tscn"
const OUTPUT_DIRECTORY := "res://scenes/world/natural_landscapes"


func _initialize() -> void:
	call_deferred("_generate")


func _generate() -> void:
	var packed_world := load(EDITABLE_WORLD_PATH) as PackedScene
	if packed_world == null:
		push_error("Cannot load edited world: %s" % EDITABLE_WORLD_PATH)
		quit(1)
		return
	var editable := packed_world.instantiate() as Node3D
	root.add_child(editable)
	for legacy_name in ["NeighborhoodDetails", "NaturalLandscapes"]:
		var legacy := editable.get_node_or_null(legacy_name)
		if legacy != null:
			editable.remove_child(legacy)
			legacy.free()

	var course: CourseLayout = CourseLayoutScript.load_default()
	var infrastructure := Node3D.new()
	root.add_child(infrastructure)
	var terrain: WorldBuilder = WorldBuilderScript.new()
	terrain.build_infrastructure(infrastructure, course, editable)

	var landscapes := Node3D.new()
	landscapes.name = "NaturalLandscapes"
	landscapes.add_to_group("natural_landscapes_root", true)
	root.add_child(landscapes)
	var builder = LandscapeBuilderScript.new()
	builder.build(landscapes, course, terrain, editable)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var mesh_count := landscapes.find_children("*", "MeshInstance3D", true, false).size()
	var saved_count := 0
	for value in landscapes.get_children():
		var feature := value as Node3D
		landscapes.remove_child(feature)
		_persist_groups(feature)
		_set_owned(feature, feature)
		var id := str(feature.get_meta("landscape_id", feature.name.to_snake_case()))
		var packed := PackedScene.new()
		var pack_error := packed.pack(feature)
		if pack_error != OK:
			push_error("Could not pack natural landscape %s: %s" % [id, error_string(pack_error)])
			quit(1)
			return
		var output_path := "%s/%s.tscn" % [OUTPUT_DIRECTORY, id]
		var save_error := ResourceSaver.save(packed, output_path)
		if save_error != OK:
			push_error("Could not save natural landscape %s: %s" % [id, error_string(save_error)])
			quit(1)
			return
		saved_count += 1
		feature.free()
	print("NATURAL LANDSCAPE: saved %d editable sites / %d meshes to %s" % [saved_count, mesh_count, OUTPUT_DIRECTORY])
	quit(0)


func _set_owned(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		_set_owned(child, scene_owner)


func _persist_groups(node: Node) -> void:
	for group: StringName in node.get_groups():
		node.remove_from_group(group)
		node.add_to_group(group, true)
	for child in node.get_children():
		_persist_groups(child)
