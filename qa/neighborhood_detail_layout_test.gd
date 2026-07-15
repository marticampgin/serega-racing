extends SceneTree

const EXPECTED_BLOCKS := 13
const EXPECTED_CATALOG_ITEMS := {
	"art_deco_tower": 2,
	"art_bralis__billboard": 1,
	"art_milk_racer__wall_poster": 1,
	"stepping_stone_path": 5,
	"boardwalk_section": 10,
}
const MINIMUM_KIND_COUNTS := {
	"sidewalk": 20,
	"rear_walk": 20,
	"fence": 20,
	"bush": 20,
	"lamp": 90,
	"driveway": 90,
	"dock": 4,
	"boat": 4,
}

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
	var race := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	var details_root := race.get_node_or_null("EditableWorld/NeighborhoodDetails") as Node3D
	check(details_root != null, "one additive neighborhood detail layer loads with the edited world")
	if details_root == null:
		_finish()
		return
	check(get_nodes_in_group("neighborhood_details_root").size() == 1, "neighborhood detail layer is instantiated exactly once")
	check(details_root.find_children("*", "CollisionObject3D", true, false).is_empty(), "neighborhood details remain visual-only")
	var detail_meshes := details_root.find_children("*", "MeshInstance3D", true, false).size()
	check(detail_meshes <= 1200, "compacted neighborhood layer stays below 1200 mesh nodes")

	var detail_roots: Array[Node3D] = []
	var kind_counts: Dictionary = {}
	var kind_blocks: Dictionary = {}
	var district_counts: Dictionary = {}
	var metadata_complete := true
	var compact_networks_valid := true
	for value in get_nodes_in_group("neighborhood_detail_scenery"):
		if not value is Node3D or not details_root.is_ancestor_of(value):
			continue
		var detail := value as Node3D
		detail_roots.append(detail)
		for metadata_key in ["detail_kind", "detail_district", "detail_block_id", "detail_side"]:
			metadata_complete = metadata_complete and detail.has_meta(metadata_key)
		var kind := str(detail.get_meta("detail_kind", ""))
		var block_id := str(detail.get_meta("detail_block_id", ""))
		var district := str(detail.get_meta("detail_district", ""))
		kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
		district_counts[district] = int(district_counts.get(district, 0)) + 1
		if not kind_blocks.has(kind):
			kind_blocks[kind] = {}
		(kind_blocks[kind] as Dictionary)[block_id] = true
		if detail.has_meta("detail_count"):
			compact_networks_valid = compact_networks_valid and int(detail.get_meta("detail_count")) >= 2
			compact_networks_valid = compact_networks_valid and not detail.find_children("*", "MeshInstance3D", true, false).is_empty()
	check(metadata_complete, "every detail root carries kind, district, block and side metadata")
	check(compact_networks_valid, "compacted networks retain useful counts and visible geometry")
	check(detail_roots.size() <= 500, "detail roots remain editor-manageable after compaction")
	for kind: String in MINIMUM_KIND_COUNTS:
		check(int(kind_counts.get(kind, 0)) >= int(MINIMUM_KIND_COUNTS[kind]), "%s details meet the planned minimum" % kind)
	for kind in ["sidewalk", "rear_walk", "fence", "bush", "lamp"]:
		check((kind_blocks.get(kind, {}) as Dictionary).size() == EXPECTED_BLOCKS, "%s details represent every building block" % kind)
	for district in ["start_coast", "party_town", "city_centre", "shopping_alley", "sport_complex", "north_coast", "party_island_view"]:
		check(int(district_counts.get(district, 0)) > 0, "%s receives connective neighborhood details" % district)

	var course: Object = race.get("course")
	var terrain: Object = race.get("world_builder")
	_check_lamps(details_root, course, terrain)
	_check_land_and_water_details(details_root, terrain)
	_check_catalog_preservation(race)
	print("INFO: neighborhood detail roots=%d meshes=%d kinds=%s" % [detail_roots.size(), detail_meshes, kind_counts])
	_finish()


func _check_lamps(details_root: Node3D, course: Object, terrain: Object) -> void:
	var balance: Dictionary = {}
	var exact_setbacks := true
	var all_grounded := true
	var safe_zones := true
	for value in get_nodes_in_group("neighborhood_lamp"):
		if not value is Node3D or not details_root.is_ancestor_of(value):
			continue
		var lamp := value as Node3D
		var offset := float(lamp.get_meta("course_offset", -1.0))
		var side := int(lamp.get_meta("detail_side", 0))
		var road := course.call("point_at", offset) as Vector3
		var lateral := course.call("lateral_at", offset) as Vector3
		var signed_setback := (lamp.global_position - road).dot(lateral) * float(side)
		exact_setbacks = exact_setbacks and absf(signed_setback - 13.0) <= 0.6
		var terrain_y := float(terrain.call("terrain_height_at", Vector2(lamp.global_position.x, lamp.global_position.z)))
		all_grounded = all_grounded and absf(lamp.global_position.y - terrain_y) <= 0.12
		safe_zones = safe_zones and str(course.call("zone_at", offset)) not in ["bridge", "underwater_tunnel"]
		var key := str(lamp.get_meta("detail_block_id"))
		if not balance.has(key):
			balance[key] = {-1: 0, 1: 0}
		(balance[key] as Dictionary)[side] = int((balance[key] as Dictionary).get(side, 0)) + 1
	check(exact_setbacks, "all neighborhood lamps keep the exact roadside setback")
	check(all_grounded, "all neighborhood lamps are grounded")
	check(safe_zones, "neighborhood lamps avoid bridges and tunnels")
	for block_id: String in balance:
		var sides: Dictionary = balance[block_id]
		check(absi(int(sides.get(-1, 0)) - int(sides.get(1, 0))) <= 2, "%s has balanced paired lamp rhythm" % block_id)


func _check_land_and_water_details(details_root: Node3D, terrain: Object) -> void:
	var land_details_safe := true
	var boats_safe := true
	for value in get_nodes_in_group("neighborhood_detail_scenery"):
		if not value is Node3D or not details_root.is_ancestor_of(value):
			continue
		var detail := value as Node3D
		if detail.has_meta("detail_count"):
			continue
		var kind := str(detail.get_meta("detail_kind", ""))
		var xz := Vector2(detail.global_position.x, detail.global_position.z)
		var terrain_y := float(terrain.call("terrain_height_at", xz))
		var ocean_y := float(terrain.call("ocean_rendered_height_at", xz))
		if kind == "boat":
			boats_safe = boats_safe and terrain_y - ocean_y < 0.12
		elif kind != "dock":
			land_details_safe = land_details_safe and terrain_y - ocean_y >= 0.12
	check(land_details_safe, "all standalone land details remain on land")
	check(boats_safe, "all neighborhood boats remain over water")


func _check_catalog_preservation(race: Node) -> void:
	var actual: Dictionary = {}
	for value in get_nodes_in_group("manual_scenery"):
		if not value is Node or not race.is_ancestor_of(value):
			continue
		var catalog_id := str(value.get_meta("catalog_id", ""))
		if not catalog_id.is_empty():
			actual[catalog_id] = int(actual.get(catalog_id, 0)) + 1
	for catalog_id: String in EXPECTED_CATALOG_ITEMS:
		check(int(actual.get(catalog_id, 0)) == int(EXPECTED_CATALOG_ITEMS[catalog_id]), "user-authored %s instances are preserved" % catalog_id)
	var total := 0
	for count in actual.values():
		total += int(count)
	check(total == 19, "all 19 saved user catalog instances survive the additive detail layer")


func _finish() -> void:
	print("NEIGHBORHOOD DETAIL QA: %s (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)
