extends SceneTree

const EDITABLE_WORLD_PATH := "res://scenes/world/editable_world.tscn"
const MINIMUM_EDITABLE_OBJECTS := 405
const MINIMUM_DECORATIVE_MESHES := 3951
const MINIMUM_AUTHORED_BAKED_COPIES := 12
const EXPECTED_DISTRICTS := ["StartCoast", "LoopOne", "UnderwaterTunnel", "LoopTwo", "BridgeApproach", "PartyTown", "CityCentre", "LoopThree", "ShoppingAlley", "SportComplex", "NorthCoast", "PartyIsland", "Waterfront", "Sky", "Other"]
const FORBIDDEN_GROUPS := ["ocean_scenery", "island_terrain", "shoreline_contour", "bridge_boundary", "bridge_support", "flyover_boundary", "tunnel_boundary", "party_island_foundation"]
const REQUIRED_GROUPS := ["district_infill", "grounded_scenery", "boat_scenery"]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _run() -> void:
	var packed := load(EDITABLE_WORLD_PATH) as PackedScene
	check(packed != null, "editable world PackedScene loads")
	if packed == null:
		quit(1)
		return
	var editable := packed.instantiate() as Node3D
	var baked_roots: Array[Node] = []
	var bake_ids := {}
	var repeated_bake_ids := 0
	for district_name: String in EXPECTED_DISTRICTS:
		var district := editable.get_node_or_null(district_name) as Node3D
		check(district != null, "district is serialized: %s" % district_name)
		if district == null:
			continue
		check(not bool(district.get_meta("_edit_group_", false)), "%s allows viewport selection of individual objects" % district_name)
		if district_name not in ["UnderwaterTunnel", "BridgeApproach", "Sky", "Other"]:
			check(district.get_child_count() > 0, "district contains editable scenery: %s" % district_name)
		for child in district.get_children():
			# Catalog presets are valid externally-instanced authored objects, not
			# generator-baked roots. They intentionally have no bake_id and retain
			# ownership inside their reusable preset scene.
			if child.is_in_group("manual_scenery"):
				continue
			baked_roots.append(child)
			var bake_id := str(child.get_meta("bake_id", ""))
			check(not bake_id.is_empty(), "%s has a stable bake id" % child.name)
			if bake_ids.has(bake_id):
				repeated_bake_ids += 1
			bake_ids[bake_id] = true
			check(bool(child.get_meta("_edit_group_", false)), "%s moves as one compound object" % child.name)
			check(child.owner == editable, "%s is persisted and locally editable" % child.name)
			var descendants_owned := true
			for descendant in child.find_children("*", "Node", true, false):
				if descendant.owner != editable:
					descendants_owned = false
					break
			check(descendants_owned, "%s descendants survive scene serialization" % child.name)
	var landscapes := editable.get_node_or_null("NaturalLandscapes") as Node3D
	var landscape_count := landscapes.get_child_count() if landscapes != null else 0
	check(landscape_count >= 11, "natural landscape roots are persisted as separate editable objects")
	var expected_editable_objects := baked_roots.size() + landscape_count
	var expected_saved_meshes := editable.find_children("*", "MeshInstance3D", true, false).size()
	check(expected_editable_objects >= MINIMUM_EDITABLE_OBJECTS, "the editable baseline plus authored copies remain saved")
	check(expected_saved_meshes >= MINIMUM_DECORATIVE_MESHES, "the saved world preserves the decorative mesh baseline")
	check(repeated_bake_ids >= MINIMUM_AUTHORED_BAKED_COPIES, "authored baked copies retain their source bake identity")
	var building_count := 0
	for value in editable.find_children("*", "Node3D", true, false):
		var building := value as Node3D
		if not building.is_in_group("building_scenery"):
			continue
		building_count += 1
		check(bool(building.get_meta("_edit_group_", false)), "%s is individually click-selectable" % building.name)
		check(building.owner == editable or not building.scene_file_path.is_empty(), "%s is an authored local or external scene object" % building.name)
	print("INFO: editable building roots=%d" % building_count)
	check(building_count >= 250, "the user-edited world retains its dense set of individually editable buildings")
	var baked_palms := 0
	var natural_crowns := true
	for value in editable.find_children("*", "Node3D", true, false):
		var palm := value as Node3D
		if not palm.is_in_group("palm_scenery"):
			continue
		baked_palms += 1
		var leaves := 0
		var crown_colors: Dictionary = {}
		for child in palm.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
				var leaf := child as MeshInstance3D
				leaves += 1
				natural_crowns = natural_crowns and Vector2(leaf.position.x, leaf.position.z).length() <= 0.01
				var material := (leaf.mesh as BoxMesh).material as StandardMaterial3D
				if material != null:
					crown_colors[material.albedo_color.to_html(false)] = true
		natural_crowns = natural_crowns and leaves == 6
		natural_crowns = natural_crowns and crown_colors.has(Color("20a779").to_html(false)) and crown_colors.has(Color("116553").to_html(false))
	check(baked_palms >= 100, "the authored standalone palm population remains in the editable world")
	check(natural_crowns, "every baked standalone palm matches the natural-landscape crown model")
	for group_name: String in REQUIRED_GROUPS:
		check(_contains_group(editable, group_name), "semantic group survives scene serialization: %s" % group_name)
	for group_name: String in FORBIDDEN_GROUPS:
		var forbidden := false
		for node in editable.find_children("*", "Node", true, false):
			if node.is_in_group(group_name):
				forbidden = true
				break
		check(not forbidden, "locked infrastructure is excluded from editable scenery: %s" % group_name)
	check(editable.find_children("*", "CollisionObject3D", true, false).is_empty(), "editable decorations remain visual-only")
	editable.free()

	var started := Time.get_ticks_msec()
	var main_packed := load("res://scenes/main.tscn") as PackedScene
	var race := main_packed.instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	var startup_ms := Time.get_ticks_msec() - started
	var runtime_worlds := get_nodes_in_group("editable_world")
	check(runtime_worlds.size() == 1, "runtime instantiates exactly one editable world")
	var runtime_editable_count := get_nodes_in_group("editable_scenery").size()
	check(runtime_editable_count <= expected_editable_objects and runtime_editable_count >= MINIMUM_EDITABLE_OBJECTS - 20, "runtime contains one copy of saved scenery except intentional manual-footprint replacements")
	check(get_nodes_in_group("ocean_scenery").size() == 1, "ocean remains procedural infrastructure")
	check(not get_nodes_in_group("bridge_boundary").is_empty(), "bridge remains procedural infrastructure")
	check(not get_nodes_in_group("tunnel_boundary").is_empty(), "tunnel remains procedural infrastructure")
	check(not get_nodes_in_group("flyover_boundary").is_empty(), "flyovers remain procedural infrastructure")
	for group_name: String in REQUIRED_GROUPS:
		check(not get_nodes_in_group(group_name).is_empty(), "runtime restores semantic group: %s" % group_name)
	var runtime_meshes := race.find_children("*", "MeshInstance3D", true, false).size()
	print("INFO: saved editable meshes=%d runtime meshes=%d" % [expected_saved_meshes, runtime_meshes])
	check(runtime_meshes >= int(expected_saved_meshes * 0.8), "runtime retains the saved scenery aside from intentional manual-footprint reservations")
	check(get_nodes_in_group("poster_scenery").is_empty(), "unplaced generated friend posters stay absent")
	check(get_nodes_in_group("tunnel_wall_poster").is_empty(), "unplaced tunnel friend art stays absent")
	check(get_nodes_in_group("sky_traffic_vehicle").is_empty(), "unplaced friend-banner aircraft stay absent")
	print("INFO: editable-world runtime startup = %d ms" % startup_ms)
	root.remove_child(race)
	race.free()
	await process_frame
	print("EDITABLE WORLD BAKE QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _contains_group(parent: Node, group_name: String) -> bool:
	if parent.is_in_group(group_name):
		return true
	for node in parent.find_children("*", "Node", true, false):
		if node.is_in_group(group_name):
			return true
	return false
