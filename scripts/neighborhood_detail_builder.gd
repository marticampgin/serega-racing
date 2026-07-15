class_name NeighborhoodDetailBuilder
extends RefCounted

const SEA_LEVEL := -1.4
const SIDEWALK_SETBACK := 18.5
const LAMP_SETBACK := 13.0
const PANEL_STEP := 7.5

var _course: CourseLayout
var _terrain: WorldBuilder
var _source: Node3D
var _parent: Node3D
var _materials: Dictionary = {}
var _folders: Dictionary = {}
var _buildings: Array[Node3D] = []
var _layout_buildings: Array[Node3D] = []
var _landmark_reservations: Array[Node3D] = []
var _manual_items: Array[Node3D] = []
var _existing_lamps: Array[Node3D] = []
var _road_grid: Dictionary = {}
var _counter := 0
var detail_count := 0


func build(parent: Node3D, course: CourseLayout, terrain: WorldBuilder, source: Node3D) -> void:
	_parent = parent
	_course = course
	_terrain = terrain
	_source = source
	_build_materials()
	_cache_road_grid()
	_collect_reservations()
	var blocks := _collect_blocks()
	for block_id: String in blocks:
		print("NEIGHBORHOOD DETAILS: building %s" % block_id)
		_build_block(block_id, blocks[block_id] as Array[Node3D])
		print("NEIGHBORHOOD DETAILS: %s complete (%d roots)" % [block_id, detail_count])
	_build_standalone_building_details()


func _collect_reservations() -> void:
	for value in _source.find_children("*", "Node3D", true, false):
		var node := value as Node3D
		if node.is_in_group("building_scenery"):
			_buildings.append(node)
		if node.is_in_group("building_layout"):
			_layout_buildings.append(node)
		if node.is_in_group("unique_landmark") and not node.is_in_group("building_scenery"):
			_landmark_reservations.append(node)
		if node.is_in_group("manual_scenery"):
			_manual_items.append(node)
		if node.is_in_group("lamp_scenery"):
			_existing_lamps.append(node)


func _collect_blocks() -> Dictionary:
	var blocks: Dictionary = {}
	var seen: Dictionary = {}
	for building in _layout_buildings:
		if not building.has_meta("layout_block_id"):
			continue
		var block_id := str(building.get_meta("layout_block_id"))
		var signature := "%s/%d/%d/%d" % [
			block_id,
			int(signf(float(building.get_meta("layout_side", 0.0)))),
			int(building.get_meta("layout_row", -1)),
			int(building.get_meta("layout_slot", -1)),
		]
		# User-duplicated buildings remain authored scenery. Their repeated layout
		# metadata must not multiply the deterministic connective grid.
		if seen.has(signature):
			continue
		seen[signature] = true
		if not blocks.has(block_id):
			blocks[block_id] = [] as Array[Node3D]
		(blocks[block_id] as Array[Node3D]).append(building)
	return blocks


func _build_standalone_building_details() -> void:
	var standalone_index := 0
	for building in _buildings:
		if building.is_in_group("building_layout") or not building.has_meta("course_offset"):
			continue
		# Standalone buildings are frequently moved by hand. Their baked metadata
		# may still describe the old location, so derive context from the authored
		# transform instead of sending paths back to the former site.
		var offset := _nearest_course_offset(building.global_position)
		var road := _course.point_at(offset)
		var lateral := _course.lateral_at(offset)
		var tangent := _course.tangent_at(offset)
		var delta := building.global_position - road
		var side := int(signf(delta.dot(lateral)))
		if side == 0:
			side = 1
		var setback := absf(delta.dot(lateral))
		var scale := building.global_transform.basis.get_scale()
		var radius := float(building.get_meta("scenery_radius", 9.0)) * maxf(absf(scale.x), absf(scale.z))
		var district := _course.zone_at(offset)
		var block_id := "standalone_%s_%03d" % [district, standalone_index]
		var front_clearance := clampf(radius * 0.62, 5.0, 15.0)
		var path_start := _course.road_half_width + 4.8
		var path_finish := setback - front_clearance
		if path_finish > path_start + 3.0:
			_add_standalone_path(block_id, district, building, offset, side, path_start, path_finish, standalone_index)

		# A small, deliberate garden frame makes isolated landmarks feel connected
		# without pretending every one belongs to a repeated residential block.
		var front := building.global_position - lateral * float(side) * front_clearance
		for corner in [-1, 1]:
			var bush_position := front + tangent * float(corner) * clampf(radius * 0.42, 4.0, 10.0)
			_add_standalone_bush(block_id, district, building, offset, side, bush_position, standalone_index * 2 + (1 if corner > 0 else 0))
		_add_standalone_fence(block_id, district, building, offset, side, front, radius, standalone_index)
		standalone_index += 1


func _nearest_course_offset(position: Vector3) -> float:
	var best_offset := 0.0
	var best_distance := INF
	var offset := 0.0
	while offset < _course.length():
		var point := _course.point_at(offset)
		var distance := Vector2(position.x, position.z).distance_squared_to(Vector2(point.x, point.z))
		if distance < best_distance:
			best_distance = distance
			best_offset = offset
		offset += 8.0
	return best_offset


func _add_standalone_path(block_id: String, district: String, building: Node3D, offset: float, side: int, start_setback: float, finish_setback: float, station: int) -> void:
	var length := finish_setback - start_setback
	var centre_setback := (start_setback + finish_setback) * 0.5
	var position := _course.point_at(offset) + _course.lateral_at(offset) * float(side) * centre_setback
	if not _valid_land_detail_except(position, offset, maxf(2.1, length * 0.45), building):
		return
	position.y = _terrain.terrain_height_at(Vector2(position.x, position.z)) + 0.11
	var root := _detail_root(block_id, district, "standalone_path", offset, side, station, position, Vector2(2.0, length * 0.5))
	root.look_at(_course.point_at(offset), Vector3.UP)
	_add_box(root, Vector3(4.0, 0.2, length), Vector3.ZERO, _path_material(district), 1500.0)


func _add_standalone_bush(block_id: String, district: String, building: Node3D, offset: float, side: int, position: Vector3, station: int) -> void:
	if not _valid_land_detail_except(position, offset, 1.55, building):
		return
	position.y = _terrain.terrain_height_at(Vector2(position.x, position.z))
	var root := _detail_root(block_id, district, "standalone_bush", offset, side, station, position, Vector2(1.45, 1.45))
	_add_sphere(root, 1.25 + float(station % 2) * 0.2, Vector3(0, 0.95, 0), _materials.leaves, 1250.0)
	_add_sphere(root, 0.72, Vector3(0.75, 0.68, 0.18), _materials.flower if station % 3 == 0 else _materials.leaves_dark, 1250.0)


func _add_standalone_fence(block_id: String, district: String, building: Node3D, offset: float, side: int, front: Vector3, radius: float, station: int) -> void:
	var tangent := _course.tangent_at(offset)
	var length := clampf(radius * 0.75, 6.0, 14.0)
	var position := front + _course.lateral_at(offset) * float(side) * 2.8
	if not _valid_land_detail_except(position, offset, length * 0.45, building):
		return
	position.y = _terrain.terrain_height_at(Vector2(position.x, position.z))
	var root := _detail_root(block_id, district, "standalone_fence", offset, side, station, position, Vector2(length * 0.5, 0.3))
	root.look_at(position + tangent, Vector3.UP)
	var material := _fence_material(district)
	for y in [0.62, 1.22]:
		_add_box(root, Vector3(length, 0.14, 0.16), Vector3(0, y, 0), material, 1250.0)
	for x in [-length * 0.5, 0.0, length * 0.5]:
		_add_box(root, Vector3(0.2, 1.5, 0.2), Vector3(x, 0.75, 0), material, 1250.0)


func _build_block(block_id: String, buildings: Array[Node3D]) -> void:
	if buildings.is_empty():
		return
	var district := str(buildings[0].get_meta("layout_district", "other"))
	var offsets := _unique_offsets(buildings)
	if offsets.size() < 2:
		return
	var rows_by_side := _rows_by_side(buildings)
	_build_sidewalks(block_id, district, offsets, rows_by_side)
	_build_driveways(block_id, district, buildings)
	_build_back_lanes(block_id, district, offsets, rows_by_side)
	_build_property_edges(block_id, district, offsets, rows_by_side)
	_build_landscaping(block_id, district, buildings)
	_build_lamp_rhythm(block_id, district, offsets)
	_build_waterfront_spur(block_id, district, offsets, rows_by_side)


func _unique_offsets(buildings: Array[Node3D]) -> Array[float]:
	var values: Array[float] = []
	for building in buildings:
		var offset := float(building.get_meta("course_offset", -1.0))
		var found := false
		for existing in values:
			if absf(existing - offset) < 1.0:
				found = true
				break
		if not found:
			values.append(offset)
	values.sort()
	return values


func _rows_by_side(buildings: Array[Node3D]) -> Dictionary:
	var result := {-1: {}, 1: {}}
	for building in buildings:
		var side := int(signf(float(building.get_meta("layout_side", 0.0))))
		if side == 0:
			continue
		var row := int(building.get_meta("layout_row", 0))
		var side_rows: Dictionary = result[side]
		if not side_rows.has(row):
			side_rows[row] = [] as Array[Node3D]
		(side_rows[row] as Array[Node3D]).append(building)
	return result


func _build_sidewalks(block_id: String, district: String, offsets: Array[float], rows_by_side: Dictionary) -> void:
	for side in [-1, 1]:
		if (rows_by_side[side] as Dictionary).is_empty():
			continue
		var offset: float = offsets.front()
		var station := 0
		while offset <= offsets.back() + 0.1:
			_add_path_panel(block_id, district, offset, side, SIDEWALK_SETBACK, 3.6, PANEL_STEP + 0.35, station, "sidewalk")
			offset += PANEL_STEP
			station += 1


func _build_driveways(block_id: String, district: String, buildings: Array[Node3D]) -> void:
	for building in buildings:
		if int(building.get_meta("layout_row", 0)) != 0:
			continue
		var offset := float(building.get_meta("course_offset"))
		var side := int(signf(float(building.get_meta("layout_side"))))
		var setback := float(building.get_meta("layout_setback"))
		var half_extents := building.get_meta("building_half_extents", Vector2(8.0, 6.0)) as Vector2
		var start_setback := SIDEWALK_SETBACK + 1.0
		var finish_setback := setback - half_extents.y - 1.4
		if finish_setback <= start_setback + 2.0:
			continue
		_add_lateral_path(block_id, district, offset, side, start_setback, finish_setback, 3.0, int(building.get_meta("layout_slot", 0)), "driveway")


func _build_back_lanes(block_id: String, district: String, offsets: Array[float], rows_by_side: Dictionary) -> void:
	for side in [-1, 1]:
		var side_rows: Dictionary = rows_by_side[side]
		var row_ids: Array = side_rows.keys()
		row_ids.sort()
		for row_pair in range(row_ids.size() - 1):
			var near_row := side_rows[row_ids[row_pair]] as Array[Node3D]
			var far_row := side_rows[row_ids[row_pair + 1]] as Array[Node3D]
			if near_row.is_empty() or far_row.is_empty():
				continue
			var near_setback := float(near_row[0].get_meta("layout_setback"))
			var far_setback := float(far_row[0].get_meta("layout_setback"))
			var lane_setback := (near_setback + far_setback) * 0.5
			var offset: float = offsets.front()
			var station := 0
			while offset <= offsets.back() + 0.1:
				_add_path_panel(block_id, district, offset, side, lane_setback, 2.7, PANEL_STEP + 0.3, station, "rear_walk")
				offset += PANEL_STEP
				station += 1
		# Cross paths sit at lot boundaries, not through the buildings themselves.
		for index in range(2, offsets.size(), 3):
			var boundary_offset := (offsets[index - 1] + offsets[index]) * 0.5
			var maximum := _maximum_setback(side_rows) + 8.0
			_add_lateral_path(block_id, district, boundary_offset, side, SIDEWALK_SETBACK, maximum, 2.4, index, "cross_path")


func _build_property_edges(block_id: String, district: String, offsets: Array[float], rows_by_side: Dictionary) -> void:
	for side in [-1, 1]:
		var side_rows: Dictionary = rows_by_side[side]
		if side_rows.is_empty():
			continue
		var maximum := _maximum_setback(side_rows) + 10.0
		for index in range(1, offsets.size()):
			# Every third boundary is an open pedestrian alley.
			if index % 3 == 2:
				continue
			var boundary_offset := (offsets[index - 1] + offsets[index]) * 0.5
			var setback := 25.0
			var segment := 0
			while setback < maximum:
				var finish := minf(setback + 5.5, maximum)
				_add_fence_segment(block_id, district, boundary_offset, side, setback, finish, index * 20 + segment)
				setback = finish
				segment += 1


func _build_landscaping(block_id: String, district: String, buildings: Array[Node3D]) -> void:
	for building in buildings:
		var offset := float(building.get_meta("course_offset"))
		var side := int(signf(float(building.get_meta("layout_side"))))
		var setback := float(building.get_meta("layout_setback"))
		var half_extents := building.get_meta("building_half_extents", Vector2(8.0, 6.0)) as Vector2
		var slot := int(building.get_meta("layout_slot", 0))
		var tangent_shift := half_extents.x * (0.72 if slot % 2 == 0 else -0.72)
		var centre := _course.point_at(offset)
		var position := centre + _course.lateral_at(offset) * float(side) * (setback - half_extents.y - 3.6)
		position += _course.tangent_at(offset) * tangent_shift
		_add_bush(block_id, district, offset, side, position, slot)


func _build_lamp_rhythm(block_id: String, district: String, offsets: Array[float]) -> void:
	for station in range(offsets.size()):
		var offset := offsets[station]
		for side in [-1, 1]:
			if _existing_lamp_near(offset, side):
				continue
			_add_lamp(block_id, district, offset, side, station)


func _build_waterfront_spur(block_id: String, district: String, offsets: Array[float], rows_by_side: Dictionary) -> void:
	if district not in ["start_coast", "north_coast", "party_island_view"]:
		return
	for side in [-1, 1]:
		var side_rows: Dictionary = rows_by_side[side]
		if side_rows.is_empty():
			continue
		var gap_index := maxi(1, offsets.size() / 2)
		var offset := (offsets[gap_index - 1] + offsets[min(gap_index, offsets.size() - 1)]) * 0.5
		var start_setback := _maximum_setback(side_rows) + 10.0
		var water_setback := -1.0
		var setback := start_setback
		while setback <= start_setback + 95.0:
			var point := _course.point_at(offset) + _course.lateral_at(offset) * float(side) * setback
			if not _is_land(Vector2(point.x, point.z)):
				water_setback = setback
				break
			setback += 5.0
		if water_setback < 0.0 or water_setback - start_setback < 15.0:
			continue
		var end_setback := water_setback + 22.0
		var panel_setback := start_setback
		var station := 0
		while panel_setback < end_setback:
			var finish := minf(panel_setback + 5.0, end_setback)
			_add_dock_panel(block_id, district, offset, side, panel_setback, finish, station)
			panel_setback = finish
			station += 1
		_add_moored_boat(block_id, district, offset, side, end_setback + 5.0)
		return # One purposeful waterfront spur per block.


func _add_path_panel(block_id: String, district: String, offset: float, side: int, setback: float, width: float, length: float, station: int, kind: String) -> void:
	var position := _course.point_at(offset) + _course.lateral_at(offset) * float(side) * setback
	if not _valid_land_detail(position, offset, maxf(width, length) * 0.5, false):
		return
	position.y = _terrain.terrain_height_at(Vector2(position.x, position.z)) + 0.10
	var root := _detail_root(block_id, district, kind, offset, side, station, position, Vector2(width * 0.5, length * 0.5))
	root.look_at(position + _course.tangent_at(offset), Vector3.UP)
	_add_box(root, Vector3(width, 0.18, length), Vector3.ZERO, _path_material(district), 1200.0)


func _add_lateral_path(block_id: String, district: String, offset: float, side: int, start_setback: float, finish_setback: float, width: float, station: int, kind: String) -> void:
	var length := finish_setback - start_setback
	var centre_setback := (start_setback + finish_setback) * 0.5
	var position := _course.point_at(offset) + _course.lateral_at(offset) * float(side) * centre_setback
	if not _valid_land_detail(position, offset, maxf(width, length) * 0.45, true):
		return
	position.y = _terrain.terrain_height_at(Vector2(position.x, position.z)) + 0.11
	var root := _detail_root(block_id, district, kind, offset, side, station, position, Vector2(width * 0.5, length * 0.5))
	root.look_at(_course.point_at(offset), Vector3.UP)
	_add_box(root, Vector3(width, 0.2, length), Vector3.ZERO, _path_material(district), 1200.0)


func _add_fence_segment(block_id: String, district: String, offset: float, side: int, start_setback: float, finish_setback: float, station: int) -> void:
	var length := finish_setback - start_setback
	var centre_setback := (start_setback + finish_setback) * 0.5
	var position := _course.point_at(offset) + _course.lateral_at(offset) * float(side) * centre_setback
	if not _valid_land_detail(position, offset, length * 0.45, true):
		return
	position.y = _terrain.terrain_height_at(Vector2(position.x, position.z))
	var root := _detail_root(block_id, district, "fence", offset, side, station, position, Vector2(0.2, length * 0.5))
	root.look_at(_course.point_at(offset), Vector3.UP)
	var material := _fence_material(district)
	for y in [0.65, 1.3]:
		_add_box(root, Vector3(0.15, 0.14, length), Vector3(0, y, 0), material, 1100.0)
	for z in [-length * 0.5, length * 0.5]:
		_add_box(root, Vector3(0.22, 1.65, 0.22), Vector3(0, 0.82, z), material, 1100.0)


func _add_bush(block_id: String, district: String, offset: float, side: int, position: Vector3, station: int) -> void:
	if not _valid_land_detail(position, offset, 1.6, true):
		return
	position.y = _terrain.terrain_height_at(Vector2(position.x, position.z))
	var root := _detail_root(block_id, district, "bush", offset, side, station, position, Vector2(1.5, 1.5))
	var accent: Material = _materials.leaves if station % 3 else _materials.flower
	_add_sphere(root, 1.35 + float(station % 2) * 0.25, Vector3(0, 1.0, 0), accent, 1050.0)
	_add_sphere(root, 0.85, Vector3(0.9, 0.72, 0.25), _materials.leaves_dark, 1050.0)


func _add_lamp(block_id: String, district: String, offset: float, side: int, station: int) -> void:
	var position := _course.point_at(offset) + _course.lateral_at(offset) * float(side) * LAMP_SETBACK
	if not _valid_land_detail(position, offset, 1.2, true):
		return
	position.y = _terrain.terrain_height_at(Vector2(position.x, position.z))
	var root := _detail_root(block_id, district, "lamp", offset, side, station, position, Vector2(0.8, 0.8))
	root.add_to_group("lamp_scenery")
	root.look_at(_course.point_at(offset), Vector3.UP)
	_add_cylinder(root, 0.18, 5.8, Vector3(0, 2.9, 0), _materials.steel, 1450.0)
	_add_box(root, Vector3(0.16, 0.16, 1.8), Vector3(0, 5.65, -0.82), _materials.steel, 1450.0)
	_add_box(root, Vector3(0.85, 0.32, 0.5), Vector3(0, 5.48, -1.65), _materials.neon, 1450.0)


func _add_dock_panel(block_id: String, district: String, offset: float, side: int, start_setback: float, finish_setback: float, station: int) -> void:
	var length := finish_setback - start_setback
	var centre_setback := (start_setback + finish_setback) * 0.5
	var position := _course.point_at(offset) + _course.lateral_at(offset) * float(side) * centre_setback
	var xz := Vector2(position.x, position.z)
	var on_land := _is_land(xz)
	if not on_land and _terrain.ocean_rendered_height_at(xz) < SEA_LEVEL - 0.8:
		return
	if not _manual_clear(position, 2.6):
		return
	position.y = (_terrain.terrain_height_at(xz) + 0.22) if on_land else (_terrain.ocean_rendered_height_at(xz) + 0.85)
	var root := _detail_root(block_id, district, "dock", offset, side, station, position, Vector2(2.2, length * 0.5))
	root.look_at(_course.point_at(offset), Vector3.UP)
	_add_box(root, Vector3(4.4, 0.28, length + 0.12), Vector3.ZERO, _materials.wood, 1400.0)
	for z in [-length * 0.42, length * 0.42]:
		for x in [-1.8, 1.8]:
			_add_box(root, Vector3(0.2, 2.2, 0.2), Vector3(x, -0.85, z), _materials.wood_dark, 1400.0)


func _add_moored_boat(block_id: String, district: String, offset: float, side: int, setback: float) -> void:
	var position := _course.point_at(offset) + _course.lateral_at(offset) * float(side) * setback + _course.tangent_at(offset) * 6.5
	var xz := Vector2(position.x, position.z)
	if _is_land(xz) or not _manual_clear(position, 5.0):
		return
	position.y = _terrain.ocean_rendered_height_at(xz) + 0.55
	var root := _detail_root(block_id, district, "boat", offset, side, 0, position, Vector2(2.2, 4.5))
	root.look_at(position + _course.tangent_at(offset), Vector3.UP)
	_add_box(root, Vector3(3.8, 0.8, 8.0), Vector3(0, 0, 0), _materials.coral, 1500.0)
	_add_box(root, Vector3(2.8, 1.4, 3.4), Vector3(0, 1.05, 0.4), _materials.cream, 1500.0)
	_add_box(root, Vector3(2.3, 0.7, 1.8), Vector3(0, 1.9, -0.2), _materials.glass, 1500.0)


func _detail_root(block_id: String, district: String, kind: String, offset: float, side: int, station: int, position: Vector3, half_extents: Vector2) -> Node3D:
	_counter += 1
	detail_count += 1
	var root := Node3D.new()
	root.name = "%s_%s_%s_%04d" % [district.to_pascal_case(), kind.to_pascal_case(), "L" if side < 0 else "R", _counter]
	root.position = position
	root.add_to_group("neighborhood_detail_scenery")
	root.add_to_group("neighborhood_%s" % kind)
	root.add_to_group("%s_scenery" % district)
	root.set_meta("neighborhood_detail", true)
	root.set_meta("detail_kind", kind)
	root.set_meta("detail_district", district)
	root.set_meta("detail_block_id", block_id)
	root.set_meta("detail_station", station)
	root.set_meta("detail_side", side)
	root.set_meta("course_offset", offset)
	root.set_meta("scenery_radius", maxf(half_extents.x, half_extents.y))
	root.set_meta("detail_half_extents", half_extents)
	root.set_meta("_edit_group_", true)
	_folder_for(district).add_child(root, true)
	return root


func _folder_for(district: String) -> Node3D:
	if _folders.has(district):
		return _folders[district] as Node3D
	var folder := Node3D.new()
	folder.name = "%sDetails" % district.to_pascal_case()
	folder.add_to_group("neighborhood_detail_district")
	_parent.add_child(folder, true)
	_folders[district] = folder
	return folder


func _valid_land_detail(position: Vector3, offset: float, radius: float, check_buildings: bool) -> bool:
	var xz := Vector2(position.x, position.z)
	if not _is_land(xz) or not _manual_clear(position, radius):
		return false
	var centre_y := _terrain.terrain_height_at(xz)
	for dx in [-radius, radius]:
		for dz in [-radius, radius]:
			var sample := Vector2(position.x + dx, position.z + dz)
			if not _is_land(sample) or absf(_terrain.terrain_height_at(sample) - centre_y) > 0.85:
				return false
	if check_buildings and not _building_clear(position, radius):
		return false
	if not _other_road_clear(position, offset, radius):
		return false
	return true


func _valid_land_detail_except(position: Vector3, offset: float, radius: float, excluded_building: Node3D) -> bool:
	var xz := Vector2(position.x, position.z)
	if not _is_land(xz) or not _manual_clear(position, radius):
		return false
	var centre_y := _terrain.terrain_height_at(xz)
	for dx in [-radius, radius]:
		for dz in [-radius, radius]:
			var sample := Vector2(position.x + dx, position.z + dz)
			if not _is_land(sample) or absf(_terrain.terrain_height_at(sample) - centre_y) > 0.85:
				return false
	if not _building_clear(position, radius, excluded_building):
		return false
	if not _other_road_clear(position, offset, radius):
		return false
	return true


func _is_land(xz: Vector2) -> bool:
	return _terrain.terrain_height_at(xz) - _terrain.ocean_rendered_height_at(xz) >= 0.12


func _manual_clear(position: Vector3, radius: float) -> bool:
	for item in _manual_items:
		var item_radius := float(item.get_meta("scenery_radius", 4.0))
		var item_scale := item.global_transform.basis.get_scale()
		item_radius *= maxf(absf(item_scale.x), absf(item_scale.z))
		if Vector2(position.x, position.z).distance_to(Vector2(item.global_position.x, item.global_position.z)) < radius + item_radius + 1.0:
			return false
	return true


func _building_clear(position: Vector3, radius: float, excluded: Node3D = null) -> bool:
	for building in _buildings:
		if building == excluded:
			continue
		var local := building.global_transform.affine_inverse() * position
		var half_extents := building.get_meta("building_half_extents", Vector2.ZERO) as Vector2
		if half_extents == Vector2.ZERO:
			var scale := building.global_transform.basis.get_scale()
			var reserve := float(building.get_meta("scenery_radius", 8.0)) * maxf(absf(scale.x), absf(scale.z))
			half_extents = Vector2(reserve, reserve)
		if absf(local.x) < half_extents.x + radius + 0.7 and absf(local.z) < half_extents.y + radius + 0.7:
			return false
	for landmark in _landmark_reservations:
		var scale := landmark.global_transform.basis.get_scale()
		var reserve := float(landmark.get_meta("scenery_radius", 6.0)) * maxf(absf(scale.x), absf(scale.z))
		if Vector2(position.x, position.z).distance_to(Vector2(landmark.global_position.x, landmark.global_position.z)) < radius + reserve + 0.7:
			return false
	return true


func _other_road_clear(position: Vector3, own_offset: float, radius: float) -> bool:
	var cell_size := 40.0
	var cell_x := floori(position.x / cell_size)
	var cell_z := floori(position.z / cell_size)
	var reach := ceili((_course.road_half_width + radius + 2.0) / cell_size) + 1
	for x in range(cell_x - reach, cell_x + reach + 1):
		for z in range(cell_z - reach, cell_z + reach + 1):
			var key := Vector2i(x, z)
			for sample in _road_grid.get(key, []):
				var probe := float(sample.offset)
				var wrapped_delta := absf(probe - own_offset)
				wrapped_delta = minf(wrapped_delta, _course.length() - wrapped_delta)
				if wrapped_delta <= 55.0:
					continue
				var road := sample.position as Vector3
				if absf(road.y - position.y) < 6.0 and Vector2(road.x, road.z).distance_to(Vector2(position.x, position.z)) < _course.road_half_width + radius + 2.0:
					return false
	return true


func _cache_road_grid() -> void:
	_road_grid.clear()
	var offset := 0.0
	while offset < _course.length():
		var position := _course.point_at(offset)
		var key := Vector2i(floori(position.x / 40.0), floori(position.z / 40.0))
		if not _road_grid.has(key):
			_road_grid[key] = []
		(_road_grid[key] as Array).append({"offset": offset, "position": position})
		offset += 18.0


func _existing_lamp_near(offset: float, side: int) -> bool:
	var road := _course.point_at(offset)
	var lateral := _course.lateral_at(offset)
	for lamp in _existing_lamps:
		var lamp_offset := float(lamp.get_meta("course_offset", -9999.0))
		if absf(lamp_offset - offset) > 4.0:
			continue
		if (lamp.global_position - road).dot(lateral) * float(side) > 0.0:
			return true
	return false


func _maximum_setback(side_rows: Dictionary) -> float:
	var maximum := 0.0
	for row in side_rows.values():
		var buildings := row as Array[Node3D]
		if not buildings.is_empty():
			maximum = maxf(maximum, float(buildings[0].get_meta("layout_setback", 0.0)))
	return maximum


func _path_material(district: String) -> Material:
	match district:
		"party_town": return _materials.prom_neon
		"city_centre": return _materials.pavement
		"shopping_alley": return _materials.cream
		"sport_complex": return _materials.pavement
		"north_coast": return _materials.boardwalk
		_: return _materials.stone


func _fence_material(district: String) -> Material:
	return _materials.neon if district == "party_town" else (_materials.steel if district in ["city_centre", "sport_complex"] else _materials.cream)


func _build_materials() -> void:
	_materials = {
		"stone": _material(Color("d7b7a6"), 0.0, 0.9),
		"pavement": _material(Color("655c7e"), 0.0, 0.88),
		"cream": _material(Color("f2e3cf"), 0.0, 0.82),
		"boardwalk": _material(Color("c98562"), 0.0, 0.9),
		"prom_neon": _material(Color("59446f"), 0.05, 0.74),
		"steel": _material(Color("30294c"), 0.12, 0.62),
		"wood": _material(Color("b76f50"), 0.0, 0.86),
		"wood_dark": _material(Color("714354"), 0.0, 0.9),
		"leaves": _material(Color("36a56f"), 0.0, 0.86),
		"leaves_dark": _material(Color("176451"), 0.0, 0.9),
		"flower": _material(Color("ec5c9e"), 0.03, 0.7),
		"coral": _material(Color("f46b77"), 0.02, 0.65),
		"glass": _material(Color("1f5a7a"), 0.35, 0.25),
	}
	var neon := _material(Color("69f5ef"), 0.1, 0.4)
	neon.emission_enabled = true
	neon.emission = Color("54eee8")
	neon.emission_energy_multiplier = 2.3
	_materials.neon = neon


func _material(color: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _add_box(parent: Node3D, size: Vector3, position: Vector3, material: Material, visibility: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	instance.visibility_range_end = visibility
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, radius: float, height: float, position: Vector3, material: Material, visibility: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.15
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	instance.visibility_range_end = visibility
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, radius: float, position: Vector3, material: Material, visibility: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.55
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	instance.visibility_range_end = visibility
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(instance)
	return instance
