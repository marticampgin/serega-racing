extends SceneTree

const CourseLayoutScript := preload("res://scripts/course_layout.gd")
const WorldBuilderScript := preload("res://scripts/world_builder.gd")
const GuideScript := preload("res://scripts/editor/editor_placement_guide.gd")
const ManualRootScript := preload("res://scripts/editor/manual_scenery_root.gd")

const OUTPUT_PATH := "res://scenes/world/editable_world.tscn"
const DISTRICTS := [
	"StartCoast", "LoopOne", "UnderwaterTunnel", "LoopTwo", "BridgeApproach",
	"PartyTown", "CityCentre", "LoopThree", "ShoppingAlley", "SportComplex",
	"NorthCoast", "PartyIsland", "Waterfront", "Sky", "Other",
]


func _initialize() -> void:
	call_deferred("_generate")


func _generate() -> void:
	var course: CourseLayout = CourseLayoutScript.load_default()
	var staging := Node3D.new()
	staging.name = "DecorationStaging"
	root.add_child(staging)
	var builder: WorldBuilder = WorldBuilderScript.new()
	builder.build_decorations(staging, course, staging)

	var editable := Node3D.new()
	editable.name = "EditableWorld"
	editable.add_to_group("editable_world", true)
	var folders: Dictionary = {}
	for district_name: String in DISTRICTS:
		var folder := Node3D.new()
		folder.name = district_name
		folder.add_to_group("editable_district", true)
		folder.set_meta("_edit_group_", true)
		editable.add_child(folder)
		folders[district_name] = folder

	var counters: Dictionary = {}
	var object_count := 0
	for child in staging.get_children():
		var object := child as Node3D
		var district := _district_for(object, course)
		var folder := folders[district] as Node3D
		var world_transform := object.global_transform
		staging.remove_child(object)
		if object.name.begins_with("@"):
			object.name = _friendly_name(object, district)
		folder.add_child(object, true)
		object.global_transform = world_transform
		var key := "%s/%s" % [district, object.name]
		var sequence := int(counters.get(key, 0))
		counters[key] = sequence + 1
		object.set_meta("bake_id", "%s/%s/%03d" % [district, object.name, sequence])
		object.set_meta("_edit_group_", true)
		object.add_to_group("editable_scenery", true)
		_persist_groups(object)
		object_count += 1

	var manual := Node3D.new()
	manual.name = "ManualScenery"
	manual.set_script(ManualRootScript)
	manual.add_to_group("manual_scenery_root", true)
	editable.add_child(manual)
	var guide := Node3D.new()
	guide.name = "EditorPlacementGuide"
	guide.set_script(GuideScript)
	guide.set("show_saved_scenery", false)
	editable.add_child(guide)

	_set_owned(editable, editable)
	var packed := PackedScene.new()
	var pack_error := packed.pack(editable)
	if pack_error != OK:
		push_error("Could not pack editable world: %s" % error_string(pack_error))
		quit(1)
		return
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	if directory_error != OK:
		push_error("Could not create world directory: %s" % error_string(directory_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		push_error("Could not save editable world: %s" % error_string(save_error))
		quit(1)
		return
	print("EDITABLE WORLD: saved %d objects / %d meshes to %s" % [object_count, builder.mesh_instance_count, OUTPUT_PATH])
	root.remove_child(staging)
	staging.free()
	editable.free()
	quit(0)


func _district_for(object: Node3D, course: CourseLayout) -> String:
	if object is SkyTraffic or object.name.contains("Zeppelin") or object.name.contains("Plane"):
		return "Sky"
	if object.is_in_group("party_island_scenery") or object.name.begins_with("PartyIsland"):
		return "PartyIsland"
	if object.is_in_group("water_scenery") or object.is_in_group("boat_scenery"):
		return "Waterfront"
	var offset := float(object.get_meta("course_offset", -1.0))
	if offset < 0.0:
		offset = _nearest_course_offset(object.global_position, course)
	match course.zone_at(offset):
		"start_coast": return "StartCoast"
		"loop_1": return "LoopOne"
		"underwater_tunnel": return "UnderwaterTunnel"
		"loop_2": return "LoopTwo"
		"bridge": return "BridgeApproach"
		"party_town": return "PartyTown"
		"city_centre": return "CityCentre"
		"loop_3", "loop_3_lower", "loop_3_upper": return "LoopThree"
		"shopping_alley": return "ShoppingAlley"
		"sport_complex": return "SportComplex"
		"north_coast", "party_island_view": return "NorthCoast"
		_: return "StartCoast"


func _nearest_course_offset(position: Vector3, course: CourseLayout) -> float:
	var best_offset := 0.0
	var best_distance := INF
	var offset := 0.0
	while offset < course.length():
		var point := course.point_at(offset)
		var distance := Vector2(position.x, position.z).distance_squared_to(Vector2(point.x, point.z))
		if distance < best_distance:
			best_distance = distance
			best_offset = offset
		offset += 12.0
	return best_offset


func _friendly_name(object: Node3D, district: String) -> String:
	for mapping in [
		["house_scenery", "Villa"], ["hotel_scenery", "Hotel"],
		["palm_scenery", "Palm"], ["lamp_scenery", "RoadsideLamp"],
		["shop_scenery", "Storefront"], ["marina_scenery", "Marina"],
		["boat_scenery", "Boat"], ["poster_scenery", "Poster"],
		["coastal_promenade_scenery", "CoastalPromenade"],
		["neighborhood_scenery", "NeighborhoodBuilding"],
		["grounded_scenery", "Scenery"],
	]:
		if object.is_in_group(str(mapping[0])):
			return str(mapping[1])
	return "%sScenery" % district


func _set_owned(node: Node, scene_owner: Node) -> void:
	for child in node.get_children():
		child.owner = scene_owner
		_set_owned(child, scene_owner)


func _persist_groups(node: Node) -> void:
	# Runtime groups are not serialized unless marked persistent. Promote every
	# semantic group before packing so editor/runtime queries keep working.
	for group: StringName in node.get_groups():
		node.remove_from_group(group)
		node.add_to_group(group, true)
	for child in node.get_children():
		_persist_groups(child)
