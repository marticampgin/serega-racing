extends SceneTree

const REQUIRED_DISTRICT_COUNTS := {
	"start_coast": 48,
	"party_town": 28,
	"city_centre": 12,
	"shopping_alley": 24,
	"sport_complex": 8,
	"north_coast": 60,
	"party_island_view": 8,
}
const UNIQUE_LANDMARK_IDS := [
	"start_coast_lighthouse",
	"start_coast_grand_hotel",
	"party_town_neon_theatre",
	"city_centre_twin_towers",
	"city_centre_monument",
	"shopping_alley_market_hall",
	"sport_complex_neon_arena",
	"north_coast_marina_hotel",
	"loop_one_neon_diner",
	"loop_one_beach_motel",
	"loop_two_marina_office",
	"loop_two_pastel_motor_inn",
	"loop_three_drive_in",
	"loop_three_sunset_pavilion",
	"sport_neon_skate_park",
	"sport_complex_stadium",
]

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
	var packed := load("res://scenes/main.tscn") as PackedScene
	var race := packed.instantiate()
	root.add_child(race)
	await process_frame
	await process_frame
	var course: CourseLayout = race.get("course")
	var builder: WorldBuilder = race.get("world_builder")
	var buildings: Array[Node3D] = []
	for value in get_nodes_in_group("building_layout"):
		if value is Node3D and race.is_ancestor_of(value):
			buildings.append(value as Node3D)
	check(buildings.size() >= 192, "at least 192 deliberately aligned row buildings are present")

	var district_counts := {}
	var rows := {}
	for building: Node3D in buildings:
		_validate_building(building, course, builder)
		var district := str(building.get_meta("layout_district", ""))
		district_counts[district] = int(district_counts.get(district, 0)) + 1
		var row_key := "%s|%s|%d|%d" % [
			str(building.get_meta("layout_block_id", "")),
			str(building.get_meta("layout_side", 0.0)),
			int(building.get_meta("layout_row", -1)),
			int(building.get_meta("layout_setback", -1.0)),
		]
		if not rows.has(row_key):
			rows[row_key] = []
		(rows[row_key] as Array).append(building)
	for district: String in REQUIRED_DISTRICT_COUNTS:
		check(int(district_counts.get(district, 0)) >= int(REQUIRED_DISTRICT_COUNTS[district]), "%s has a dense symmetric building population" % district)
	_validate_rows(rows)
	_validate_paired_rows(rows)
	_validate_building_overlaps(buildings)
	_validate_unique_landmarks(race)

	root.remove_child(race)
	race.free()
	await process_frame
	print("BUILDING LAYOUT QA: %d buildings, %d failures" % [buildings.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)


func _validate_building(building: Node3D, course: CourseLayout, builder: WorldBuilder) -> void:
	for key in ["layout_district", "layout_block_id", "layout_row", "layout_slot", "layout_side", "layout_setback", "building_archetype", "building_half_extents", "course_offset", "scenery_radius"]:
		check(building.has_meta(key), "%s carries %s metadata" % [building.name, key])
	var offset := float(building.get_meta("course_offset", 0.0))
	var road := course.point_at(offset)
	var lateral := course.lateral_at(offset)
	var displacement := building.global_position - road
	var side := float(building.get_meta("layout_side", 0.0))
	var setback := float(building.get_meta("layout_setback", 0.0))
	var signed_setback := displacement.dot(lateral)
	check(signf(signed_setback) == signf(side), "%s remains on its assigned road side" % building.name)
	check(absf(absf(signed_setback) - setback) <= 0.8, "%s stays on its exact setback row" % building.name)
	var to_road := Vector3(road.x, building.global_position.y, road.z) - building.global_position
	var facing := -building.global_basis.z.normalized()
	check(to_road.length_squared() > 0.01 and facing.dot(to_road.normalized()) >= 0.984, "%s facade faces the road" % building.name)
	var half_extents: Vector2 = building.get_meta("building_half_extents", Vector2.ZERO)
	var centre_y := builder.terrain_rendered_height_at(Vector2(building.global_position.x, building.global_position.z))
	check(absf(building.global_position.y - centre_y) <= 0.12, "%s is grounded at its centre" % building.name)
	for along in [-1.0, 0.0, 1.0]:
		for depth in [-1.0, 0.0, 1.0]:
			var sample: Vector3 = building.global_position + building.global_basis.x.normalized() * along * half_extents.x + building.global_basis.z.normalized() * depth * half_extents.y
			var xz := Vector2(sample.x, sample.z)
			var terrain_y := builder.terrain_rendered_height_at(xz)
			var ocean_y := builder.ocean_rendered_height_at(xz)
			check(terrain_y - ocean_y >= 0.11, "%s footprint remains fully on land" % building.name)
			check(absf(terrain_y - building.global_position.y) <= 1.4, "%s footprint follows stable terrain" % building.name)


func _validate_rows(rows: Dictionary) -> void:
	for row_key: String in rows:
		var row: Array = rows[row_key]
		row.sort_custom(func(a: Node3D, b: Node3D) -> bool: return float(a.get_meta("course_offset")) < float(b.get_meta("course_offset")))
		check(row.size() >= 3, "%s retains at least three aligned slots" % row_key)
		var base_spacing := INF
		for index in range(1, row.size()):
			var delta := float(row[index].get_meta("course_offset")) - float(row[index - 1].get_meta("course_offset"))
			base_spacing = minf(base_spacing, delta)
		if row.size() > 1:
			for index in range(1, row.size()):
				var delta := float(row[index].get_meta("course_offset")) - float(row[index - 1].get_meta("course_offset"))
				var multiple := maxf(1.0, roundf(delta / base_spacing))
				check(absf(delta - base_spacing * multiple) <= 1.0, "%s uses regular slot stations" % row_key)


func _validate_paired_rows(rows: Dictionary) -> void:
	var pairs := {}
	for row_key: String in rows:
		var parts := row_key.split("|")
		var pair_key := "%s|%s" % [parts[0], parts[1]]
		if not pairs.has(pair_key):
			pairs[pair_key] = []
		(pairs[pair_key] as Array).append(rows[row_key])
	for pair_key: String in pairs:
		var paired_rows: Array = pairs[pair_key]
		if paired_rows.size() < 2:
			continue
		var reference_slots := _slot_set(paired_rows[0])
		var reference_sequence := _archetype_sequence(paired_rows[0])
		for index in range(1, paired_rows.size()):
			check(_slot_set(paired_rows[index]) == reference_slots, "%s copied rows share the same slot stations" % pair_key)
			check(_archetype_sequence(paired_rows[index]) != reference_sequence, "%s rear rows reorder the building sequence" % pair_key)


func _slot_set(row: Array) -> Array[int]:
	var result: Array[int] = []
	for building: Node3D in row:
		result.append(int(building.get_meta("layout_slot")))
	result.sort()
	return result


func _archetype_sequence(row: Array) -> Array[String]:
	var ordered := row.duplicate()
	ordered.sort_custom(func(a: Node3D, b: Node3D) -> bool: return int(a.get_meta("layout_slot")) < int(b.get_meta("layout_slot")))
	var result: Array[String] = []
	for building: Node3D in ordered:
		result.append(str(building.get_meta("building_archetype")))
	return result


func _validate_building_overlaps(buildings: Array[Node3D]) -> void:
	var overlaps := 0
	for left_index in range(buildings.size()):
		var left := buildings[left_index]
		var left_radius := float(left.get_meta("scenery_radius", 10.0))
		for right_index in range(left_index + 1, buildings.size()):
			var right := buildings[right_index]
			var right_radius := float(right.get_meta("scenery_radius", 10.0))
			var distance := Vector2(left.global_position.x, left.global_position.z).distance_to(Vector2(right.global_position.x, right.global_position.z))
			if distance < left_radius + right_radius + 2.0:
				overlaps += 1
	check(overlaps == 0, "aligned building footprints do not overlap")


func _validate_unique_landmarks(race: Node) -> void:
	var counts := {}
	for value in get_nodes_in_group("unique_landmark"):
		if not race.is_ancestor_of(value):
			continue
		var landmark_id := str(value.get_meta("unique_landmark_id", ""))
		counts[landmark_id] = int(counts.get(landmark_id, 0)) + 1
	for landmark_id: String in UNIQUE_LANDMARK_IDS:
		check(int(counts.get(landmark_id, 0)) == 1, "unique landmark appears exactly once: %s" % landmark_id)
