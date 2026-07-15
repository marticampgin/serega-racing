extends SceneTree

const EDITABLE_WORLD_PATH := "res://scenes/world/editable_world.tscn"
const EXPECTED_EDITABLE_OBJECTS := 405
const EXPECTED_DECORATIVE_MESHES := 3951
const EXPECTED_RUNTIME_MESHES := 5086
const EXPECTED_DISTRICTS := ["StartCoast", "LoopOne", "UnderwaterTunnel", "LoopTwo", "BridgeApproach", "PartyTown", "CityCentre", "LoopThree", "ShoppingAlley", "SportComplex", "NorthCoast", "PartyIsland", "Waterfront", "Sky", "Other"]
const FORBIDDEN_GROUPS := ["ocean_scenery", "island_terrain", "shoreline_contour", "bridge_boundary", "bridge_support", "flyover_boundary", "tunnel_boundary", "party_island_foundation"]
const REQUIRED_GROUPS := ["district_infill", "grounded_scenery", "poster_scenery", "boat_scenery", "sky_traffic_vehicle"]

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
	for district_name: String in EXPECTED_DISTRICTS:
		var district := editable.get_node_or_null(district_name) as Node3D
		check(district != null, "district is serialized: %s" % district_name)
		if district == null:
			continue
		check(not bool(district.get_meta("_edit_group_", false)), "%s allows viewport selection of individual objects" % district_name)
		if district_name not in ["BridgeApproach", "Other"]:
			check(district.get_child_count() > 0, "district contains editable scenery: %s" % district_name)
		for child in district.get_children():
			baked_roots.append(child)
			var bake_id := str(child.get_meta("bake_id", ""))
			check(not bake_id.is_empty(), "%s has a stable bake id" % child.name)
			check(not bake_ids.has(bake_id), "bake id is unique: %s" % bake_id)
			bake_ids[bake_id] = true
			check(bool(child.get_meta("_edit_group_", false)), "%s moves as one compound object" % child.name)
			check(child.owner == editable, "%s is persisted and locally editable" % child.name)
			var descendants_owned := true
			for descendant in child.find_children("*", "Node", true, false):
				if descendant.owner != editable:
					descendants_owned = false
					break
			check(descendants_owned, "%s descendants survive scene serialization" % child.name)
	check(baked_roots.size() == EXPECTED_EDITABLE_OBJECTS, "all %d existing decorative objects are editable" % EXPECTED_EDITABLE_OBJECTS)
	check(editable.find_children("*", "MeshInstance3D", true, false).size() == EXPECTED_DECORATIVE_MESHES, "baked scene preserves the %d decorative meshes" % EXPECTED_DECORATIVE_MESHES)
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
	check(get_nodes_in_group("editable_scenery").size() == EXPECTED_EDITABLE_OBJECTS, "runtime contains each baked object exactly once")
	check(get_nodes_in_group("ocean_scenery").size() == 1, "ocean remains procedural infrastructure")
	check(not get_nodes_in_group("bridge_boundary").is_empty(), "bridge remains procedural infrastructure")
	check(not get_nodes_in_group("tunnel_boundary").is_empty(), "tunnel remains procedural infrastructure")
	check(not get_nodes_in_group("flyover_boundary").is_empty(), "flyovers remain procedural infrastructure")
	for group_name: String in REQUIRED_GROUPS:
		check(not get_nodes_in_group(group_name).is_empty(), "runtime restores semantic group: %s" % group_name)
	check(race.find_children("*", "MeshInstance3D", true, false).size() == EXPECTED_RUNTIME_MESHES, "runtime mesh count is unchanged after baking")
	var vehicles := get_nodes_in_group("sky_traffic_vehicle")
	var vehicle_positions: Array[Vector3] = []
	for vehicle in vehicles:
		vehicle_positions.append((vehicle as Node3D).global_position)
	for frame in range(12):
		await process_frame
	var moving_vehicles := 0
	for index in range(vehicles.size()):
		if (vehicles[index] as Node3D).global_position.distance_to(vehicle_positions[index]) > 0.01:
			moving_vehicles += 1
	check(vehicles.size() == 2, "both baked sky vehicles retain their movement tags")
	check(moving_vehicles == vehicles.size(), "baked plane and zeppelin continue moving")
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
