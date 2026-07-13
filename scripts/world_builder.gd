class_name WorldBuilder
extends RefCounted

## Lightweight, deterministic scenery for the map-driven island course.
## All placements derive from CourseLayout baked distance. Scenery roots are
## grounded at y=0; road elevation is deliberately never used as terrain height.

const SEA_LEVEL := -1.4
const SEA_FLOOR := -3.2
const TERRAIN_TOP := 0.0

var _parent: Node3D
var _course: CourseLayout
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var mesh_instance_count := 0


func build(parent: Node3D, course: CourseLayout) -> void:
	_parent = parent
	_course = course
	_rng.seed = 0x5E12E6A
	_build_materials()
	_build_ocean_and_islands()
	_build_bridge()
	_build_underwater_tunnel()
	_build_start_coast()
	_build_party_town()
	_build_city_centre()
	_build_shopping_alley()
	_build_sport_complex()
	_build_north_coast()
	_build_party_island()
	_build_roadside_rhythm()
	print("WorldBuilder: %d scenery meshes" % mesh_instance_count)


func terrain_height_at(_world_xz: Vector2) -> float:
	## Authored islands share a level top. Callers only place scenery from course
	## sectors or the Party Island landmark, so this is deterministic by design.
	return TERRAIN_TOP


func _build_materials() -> void:
	_materials = {
		"ocean": _material(Color("087f9f"), 0.15, 0.18),
		"sand": _material(Color("d7a866"), 0.0, 0.92),
		"rock": _material(Color("59476f"), 0.0, 0.88),
		"asphalt": _material(Color("242832"), 0.0, 0.9),
		"cream": _material(Color("f2d8b5"), 0.0, 0.76),
		"coral": _material(Color("ff8066"), 0.0, 0.68),
		"mint": _material(Color("4ed7bd"), 0.0, 0.68),
		"lavender": _material(Color("9b78cf"), 0.0, 0.68),
		"night": _material(Color("34204f"), 0.05, 0.72),
		"glass": _material(Color("123a68"), 0.35, 0.16),
		"steel": _material(Color("273044"), 0.55, 0.3),
		"wood": _material(Color("825137"), 0.0, 0.8),
		"green": _material(Color("087f65"), 0.0, 0.8),
		"leaf": _material(Color("19d39b"), 0.0, 0.7),
		"white": _material(Color("f7f0dd"), 0.0, 0.72),
		"field": _material(Color("2b9b64"), 0.0, 0.9),
		"court": _material(Color("cf5b76"), 0.0, 0.85),
		"cyan": _emissive(Color("35e0dd"), 1.35),
		"pink": _emissive(Color("ff3fcf"), 1.4),
		"orange": _emissive(Color("ff9c42"), 1.25),
		"yellow": _emissive(Color("ffe45e"), 1.2),
		"tunnel_glass": _transparent(Color(0.12, 0.82, 0.94, 0.24)),
	}


func _material(color: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result


func _emissive(color: Color, multiplier: float) -> StandardMaterial3D:
	var result := _material(color, 0.1, 0.32)
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = multiplier
	return result


func _transparent(color: Color) -> StandardMaterial3D:
	var result := _material(color, 0.0, 0.12)
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result


func _mesh_instance(mesh: PrimitiveMesh, material: Material, visibility := 280.0) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = visibility
	mesh_instance_count += 1
	return instance


func _box(parent: Node, size: Vector3, position: Vector3, material: Material, visibility := 280.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh_instance(mesh, material, visibility)
	instance.position = position
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node, radius: float, height: float, position: Vector3, material: Material, top_radius := -1.0, visibility := 320.0, radial_segments := 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	var instance := _mesh_instance(mesh, material, visibility)
	instance.position = position
	parent.add_child(instance)
	return instance


func _grounded_root(name: String, position: Vector3, groups: Array[String] = []) -> Node3D:
	var root := Node3D.new()
	root.name = name
	root.position = Vector3(position.x, TERRAIN_TOP, position.z)
	root.set_meta("ground_y", TERRAIN_TOP)
	root.add_to_group("grounded_scenery")
	for group in groups:
		root.add_to_group(group)
	_parent.add_child(root)
	return root


func _roadside_root(name: String, offset: float, side: float, setback: float, groups: Array[String] = []) -> Node3D:
	var road := _course.point_at(offset)
	var position := road + _course.lateral_at(offset) * side * setback
	var root := _grounded_root(name, position, groups)
	var target := Vector3(road.x, TERRAIN_TOP, road.z)
	root.look_at(target, Vector3.UP)
	return root


func _zone_spans(zone_name: String) -> Array[Dictionary]:
	var spans: Array[Dictionary] = []
	for entry: Dictionary in _course.course_zones:
		if str(entry.get("name", "")) == zone_name:
			spans.append(entry)
	return spans


func _zone_midpoint(zone_name: String, occurrence := 0) -> float:
	var spans := _zone_spans(zone_name)
	if spans.is_empty():
		return 0.0
	var span: Dictionary = spans[clampi(occurrence, 0, spans.size() - 1)]
	return (float(span["start_distance"]) + float(span["end_distance"])) * 0.5


func _build_ocean_and_islands() -> void:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var sample := 0.0
	while sample < _course.length():
		var point := _course.point_at(sample)
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.z)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.z)
		sample += 80.0
	var center := (minimum + maximum) * 0.5
	var ocean_size := maximum - minimum + Vector2(650.0, 650.0)
	var ocean := _box(_parent, Vector3(ocean_size.x, 0.35, ocean_size.y), Vector3(center.x, SEA_LEVEL, center.y), _materials.ocean, 2400.0)
	ocean.add_to_group("ocean_scenery")

	# Overlapping low-poly sand keys form continuous land without a giant flat slab.
	# Bridge and tunnel remain open water so their height/depth is visually legible.
	sample = 0.0
	while sample < _course.length():
		var zone := _course.zone_at(sample)
		if zone != "bridge" and zone != "underwater_tunnel":
			var point := _course.point_at(sample)
			var radius := 74.0
			if zone in ["city_centre", "sport_complex", "party_town"]:
				radius = 105.0
			var island := _cylinder(_parent, radius, 1.2, Vector3(point.x, -0.6, point.z), _materials.sand, radius * 0.9, 900.0, 16)
			island.add_to_group("island_terrain")
		sample += 92.0


func _build_start_coast() -> void:
	for span: Dictionary in _zone_spans("start_coast"):
		var start := float(span.start_distance) + 45.0
		var finish := float(span.end_distance) - 25.0
		var d := start
		var index := 0
		while d < finish:
			_add_villa(d, -1.0 if index % 2 == 0 else 1.0, 31.0 + (index % 2) * 8.0, index, false)
			d += 88.0
			index += 1
	var lighthouse_offset := _zone_midpoint("start_coast")
	var lighthouse := _roadside_root("StartCoast_Lighthouse", lighthouse_offset, -1.0, 72.0, ["start_coast_scenery"])
	_cylinder(lighthouse, 4.2, 17.0, Vector3.UP * 8.5, _materials.white, 2.8, 650.0, 14)
	_cylinder(lighthouse, 4.35, 1.2, Vector3.UP * 11.0, _materials.coral, 4.35, 650.0, 14)
	_cylinder(lighthouse, 3.1, 3.0, Vector3.UP * 17.5, _materials.glass, 3.1, 650.0, 14)
	_cylinder(lighthouse, 3.8, 0.7, Vector3.UP * 19.2, _materials.pink, 2.0, 650.0, 14)


func _add_villa(offset: float, side: float, setback: float, variant: int, large: bool) -> Node3D:
	var group := "hotel_scenery" if large else "house_scenery"
	var root := _roadside_root("Hotel" if large else "Villa", offset, side, setback, [group])
	var body: Material = [_materials.cream, _materials.mint, _materials.coral, _materials.lavender][variant % 4]
	var width := 17.0 if large else 11.0
	var height := 16.0 if large else 7.0
	_box(root, Vector3(width, height, 9.0), Vector3(0, height * 0.5, 0), body, 520.0 if large else 280.0)
	_box(root, Vector3(width * 0.56, height * 0.72, 6.0), Vector3(width * 0.35, height * 0.36, 5.6), _materials.cream)
	_box(root, Vector3(width + 1.2, 0.55, 10.0), Vector3(0, height + 0.2, 0), _materials.white)
	for window_x in [-0.28, 0.0, 0.28]:
		_box(root, Vector3(width * 0.18, 2.0, 0.18), Vector3(window_x * width, 3.8, -4.58), _materials.glass)
	_box(root, Vector3(2.0, 2.8, 0.24), Vector3(-width * 0.34, 1.4, -4.62), _materials.night)
	_box(root, Vector3(width * 0.72, 0.3, 2.2), Vector3(0, 5.7, -5.5), _materials.coral)
	_box(root, Vector3(8.0, 0.18, 4.5), Vector3(-width * 0.7, 0.12, 1.0), _materials.cyan)
	return root


func _build_party_town() -> void:
	for span: Dictionary in _zone_spans("party_town"):
		var d := float(span.start_distance) + 40.0
		var index := 0
		while d < float(span.end_distance) - 30.0:
			_add_nightclub(d, -1.0 if index % 2 == 0 else 1.0, 30.0 + (index % 3) * 6.0, index)
			if index % 2 == 0:
				_add_villa(d + 24.0, 1.0 if index % 2 == 0 else -1.0, 39.0, index + 1, true)
			d += 70.0
			index += 1


func _add_nightclub(offset: float, side: float, setback: float, variant: int) -> void:
	var root := _roadside_root("PartyTown_Nightclub", offset, side, setback, ["neighborhood_scenery", "party_town_scenery"])
	var accent: Material = _materials.pink if variant % 2 == 0 else _materials.cyan
	_box(root, Vector3(17.0, 9.0, 11.0), Vector3(0, 4.5, 0), _materials.night)
	_box(root, Vector3(12.0, 5.0, 7.0), Vector3(0, 11.5, 1.5), _materials.lavender)
	_box(root, Vector3(13.0, 1.0, 0.35), Vector3(0, 8.0, -5.7), accent)
	_box(root, Vector3(5.5, 3.2, 0.2), Vector3(0, 4.0, -5.62), _materials.glass)
	_box(root, Vector3(3.0, 3.2, 0.24), Vector3(-5.2, 1.6, -5.65), _materials.orange)
	_cylinder(root, 3.4, 0.6, Vector3(0, 14.4, 1.5), accent, 3.4, 400.0, 16)
	for pole_x in [-7.0, 7.0]:
		_box(root, Vector3(0.15, 4.5, 0.15), Vector3(pole_x, 2.25, -8.0), _materials.steel)
		_box(root, Vector3(0.45, 0.35, 0.45), Vector3(pole_x, 4.5, -8.0), accent)


func _build_city_centre() -> void:
	var middle := _zone_midpoint("city_centre")
	for index in range(7):
		var offset := middle + (index - 3) * 44.0
		var side := -1.0 if index % 2 == 0 else 1.0
		_add_tower(offset, side, 48.0 + (index % 3) * 17.0, index)
	var plaza := _roadside_root("CityCentre_Plaza", middle, 1.0, 28.0, ["city_centre_scenery"])
	_cylinder(plaza, 10.0, 0.35, Vector3.UP * 0.18, _materials.white, 10.0, 500.0, 18)
	_cylinder(plaza, 5.0, 1.4, Vector3.UP * 0.7, _materials.cyan, 5.0, 500.0, 18)
	_cylinder(plaza, 1.0, 6.0, Vector3.UP * 3.0, _materials.pink, 0.35, 500.0, 12)


func _add_tower(offset: float, side: float, setback: float, variant: int) -> void:
	var root := _roadside_root("ArtDecoTower", offset, side, setback, ["skyline_scenery", "city_centre_scenery"])
	var body: Material = [_materials.cream, _materials.coral, _materials.mint, _materials.lavender][variant % 4]
	var height := 25.0 + (variant % 3) * 8.0
	_box(root, Vector3(17.0, 6.0, 14.0), Vector3(0, 3.0, 0), _materials.night, 700.0)
	_box(root, Vector3(13.5, height, 11.0), Vector3(0, 6.0 + height * 0.5, 0.5), body, 700.0)
	_box(root, Vector3(9.0, height * 0.45, 8.0), Vector3(0, 6.0 + height + height * 0.225, 0.5), _materials.cream, 700.0)
	for x in [-4.2, 0.0, 4.2]:
		_box(root, Vector3(1.3, height * 0.82, 0.2), Vector3(x, 7.0 + height * 0.5, -5.08), _materials.glass, 700.0)
	_box(root, Vector3(10.0, 0.8, 0.35), Vector3(0, 6.0 + height, -5.3), _materials.cyan if variant % 2 else _materials.pink, 700.0)
	_box(root, Vector3(5.0, 1.0, 4.0), Vector3(0, 6.0 + height * 1.48, 0.5), _materials.yellow, 700.0)


func _build_shopping_alley() -> void:
	for span: Dictionary in _zone_spans("shopping_alley"):
		var middle := (float(span.start_distance) + float(span.end_distance)) * 0.5
		for side in [-1.0, 1.0]:
			_add_storefront_row(middle, side, 27.0, 6)


func _add_storefront_row(offset: float, side: float, setback: float, count: int) -> void:
	var row := _roadside_root("ShoppingAlley_Row", offset, side, setback, ["neighborhood_scenery"])
	for index in range(count):
		var bay := Node3D.new()
		bay.name = "Storefront_%02d" % index
		bay.position.x = (index - (count - 1) * 0.5) * 9.2 + (3.2 if index >= 3 else 0.0)
		bay.add_to_group("shop_scenery")
		row.add_child(bay)
		var body: Material = [_materials.cream, _materials.mint, _materials.coral, _materials.lavender][index % 4]
		var accent: Material = _materials.pink if index % 2 == 0 else _materials.cyan
		_box(bay, Vector3(8.8, 6.5, 8.0), Vector3(0, 3.25, 0), body)
		_box(bay, Vector3(6.8, 3.0, 0.2), Vector3(0, 2.25, -4.08), _materials.glass)
		_box(bay, Vector3(9.1, 0.35, 2.0), Vector3(0, 4.6, -4.7), accent)
		_box(bay, Vector3(6.6, 0.9, 0.28), Vector3(0, 6.2, -4.18), _materials.orange if index % 3 == 0 else accent)
		_box(bay, Vector3(1.3, 2.7, 0.24), Vector3(-3.2, 1.35, -4.15), _materials.night)
	var alley := Node3D.new()
	alley.name = "ShoppingAlley_Gap"
	alley.position = Vector3(1.6, 0.0, 2.0)
	alley.add_to_group("alley_scenery")
	row.add_child(alley)
	_box(alley, Vector3(3.2, 0.12, 17.0), Vector3(0, 0.06, 0), _materials.asphalt)


func _build_sport_complex() -> void:
	var middle := _zone_midpoint("sport_complex")
	var root := _roadside_root("SportComplex", middle, 1.0, 76.0, ["sport_complex_scenery"])
	var stadium := _cylinder(root, 31.0, 8.0, Vector3(0, 4.0, 0), _materials.white, 25.0, 750.0, 20)
	stadium.scale.x = 1.42
	var field := _box(root, Vector3(54.0, 0.35, 24.0), Vector3(0, 8.2, 0), _materials.field, 750.0)
	field.add_to_group("sport_field_scenery")
	for side in [-1.0, 1.0]:
		for level in range(3):
			_box(root, Vector3(47.0 - level * 5.0, 1.2, 4.0), Vector3(0, 8.8 + level, side * (16.0 + level * 2.0)), _materials.night, 750.0)
	for court_index in range(2):
		var x := -42.0 + court_index * 28.0
		_box(root, Vector3(22.0, 0.2, 11.0), Vector3(x, 0.12, -43.0), _materials.court, 600.0)
		_box(root, Vector3(0.14, 0.04, 10.0), Vector3(x, 0.25, -43.0), _materials.white, 600.0)
		_box(root, Vector3(0.18, 1.1, 11.0), Vector3(x, 0.7, -43.0), _materials.cyan, 600.0)
	_box(root, Vector3(33.0, 0.22, 14.0), Vector3(34.0, 0.12, -38.0), _materials.cyan, 600.0)
	for position in [Vector3(-35, 0, -25), Vector3(35, 0, -25), Vector3(-35, 0, 25), Vector3(35, 0, 25)]:
		_add_floodlight(root, position)


func _add_floodlight(parent: Node, position: Vector3) -> void:
	_box(parent, Vector3(0.3, 15.0, 0.3), position + Vector3.UP * 7.5, _materials.steel, 650.0)
	_box(parent, Vector3(5.0, 1.0, 0.5), position + Vector3.UP * 15.0, _materials.yellow, 650.0)


func _build_north_coast() -> void:
	for zone in ["north_coast", "party_island_view"]:
		for span: Dictionary in _zone_spans(zone):
			var d := float(span.start_distance) + 65.0
			var index := 0
			while d < float(span.end_distance) - 35.0:
				if index % 3 == 0:
					_add_villa(d, -1.0, 38.0, index + 2, index % 6 == 0)
				elif index % 3 == 1:
					_add_marina(d, 1.0)
				d += 118.0
				index += 1


func _add_marina(offset: float, side: float) -> void:
	var root := _roadside_root("CoastalMarina", offset, side, 47.0, ["marina_scenery"])
	for dock_index in range(3):
		_box(root, Vector3(2.2, 0.3, 22.0), Vector3((dock_index - 1) * 10.0, -0.1, -9.0), _materials.wood, 420.0)
		for boat_index in range(2):
			var boat_x := (dock_index - 1) * 10.0 + (-3.0 if boat_index == 0 else 3.0)
			var boat_z := -5.0 - boat_index * 10.0
			_box(root, Vector3(2.8, 0.7, 6.0), Vector3(boat_x, -0.45, boat_z), _materials.coral if boat_index == 0 else _materials.cyan, 420.0)
			_box(root, Vector3(1.8, 1.1, 2.6), Vector3(boat_x, 0.25, boat_z + 0.3), _materials.white, 420.0)


func _build_party_island() -> void:
	var position := _course.landmark_position(&"party_island")
	var island := _grounded_root("PartyIsland", position, ["offshore_islet_scenery", "party_island_scenery"])
	var land := _cylinder(island, 72.0, 1.4, Vector3.DOWN * 0.7, _materials.sand, 62.0, 1100.0, 20)
	land.add_to_group("offshore_islet_scenery")
	_cylinder(island, 42.0, 2.2, Vector3.DOWN * 1.3, _materials.rock, 48.0, 1100.0, 18)
	var club := Node3D.new()
	club.position = Vector3(0, 0, 3)
	island.add_child(club)
	_box(club, Vector3(30.0, 10.0, 19.0), Vector3(0, 5.0, 0), _materials.night, 1000.0)
	_box(club, Vector3(25.0, 1.2, 0.4), Vector3(0, 8.0, -9.7), _materials.pink, 1000.0)
	_box(club, Vector3(13.0, 5.0, 0.25), Vector3(0, 4.2, -9.65), _materials.glass, 1000.0)
	_cylinder(club, 8.0, 0.8, Vector3(0, 11.0, 0), _materials.cyan, 8.0, 1000.0, 18)
	_box(island, Vector3(5.0, 0.4, 52.0), Vector3(0, 0.1, 49.0), _materials.wood, 900.0)
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		_add_palm_at(island, Vector3(cos(angle) * 52.0, 0, sin(angle) * 52.0), 0.85 + (index % 3) * 0.12)


func _build_roadside_rhythm() -> void:
	var offset := 70.0
	var index := 0
	while offset < _course.length():
		var zone := _course.zone_at(offset)
		if zone != "bridge" and zone != "underwater_tunnel":
			for side in [-1.0, 1.0]:
				var road := _course.point_at(offset)
				var position := road + _course.lateral_at(offset) * side * (24.0 + (index % 3) * 5.0)
				position.y = TERRAIN_TOP
				_add_palm_world(position, 0.72 + (index % 4) * 0.11)
			if index % 2 == 0:
				_add_lamp(offset, -1.0 if index % 4 == 0 else 1.0)
		offset += 195.0
		index += 1


func _add_palm_world(position: Vector3, scale_factor: float) -> void:
	var root := _grounded_root("Palm", position, ["palm_scenery"])
	_add_palm_at(root, Vector3.ZERO, scale_factor)


func _add_palm_at(parent: Node, position: Vector3, scale_factor: float) -> void:
	var height := 7.0 * scale_factor
	_cylinder(parent, 0.32 * scale_factor, height, position + Vector3.UP * height * 0.5, _materials.wood, 0.18 * scale_factor)
	for blade in range(6):
		var angle := TAU * float(blade) / 6.0
		var frond := _box(parent, Vector3(0.45, 0.14, 4.8) * scale_factor, position + Vector3.UP * height + Vector3(cos(angle), -0.15, sin(angle)) * 1.5 * scale_factor, _materials.leaf)
		frond.rotation.y = -angle
		frond.rotation.x = 0.16


func _add_lamp(offset: float, side: float) -> void:
	var root := _roadside_root("RoadsideLamp", offset, side, 12.5, ["lamp_scenery"])
	_box(root, Vector3(0.18, 6.0, 0.18), Vector3(0, 3.0, 0), _materials.steel)
	_box(root, Vector3(2.2, 0.18, 0.18), Vector3(-1.0, 5.8, 0), _materials.steel)
	_box(root, Vector3(0.6, 0.35, 0.45), Vector3(-2.0, 5.65, 0), _materials.pink)


func _build_bridge() -> void:
	for span: Dictionary in _zone_spans("bridge"):
		var start := float(span.start_distance)
		var finish := float(span.end_distance)
		var offset := start + 15.0
		while offset < finish - 10.0:
			var point := _course.point_at(offset)
			var frame := _course.sample_course(offset)
			var root := Node3D.new()
			root.name = "BridgeSupport"
			root.transform = frame
			root.add_to_group("bridge")
			_parent.add_child(root)
			var column_height := maxf(1.0, point.y - SEA_FLOOR - 0.8)
			for side in [-1.0, 1.0]:
				_cylinder(root, 0.9, column_height, Vector3(side * 7.1, -column_height * 0.5 - 0.6, 0), _materials.lavender, 0.75, 1000.0, 10)
			_box(root, Vector3(19.5, 0.8, 2.0), Vector3(0, -0.8, 0), _materials.night, 1000.0)
			for side in [-1.0, 1.0]:
				_box(root, Vector3(0.28, 1.1, 11.0), Vector3(side * 10.0, 0.55, 0), _materials.pink, 1000.0)
			offset += 48.0
		for portal_offset in [start + 8.0, finish - 8.0]:
			var portal := Node3D.new()
			portal.name = "BridgeGateway"
			portal.transform = _course.sample_course(portal_offset)
			portal.add_to_group("bridge")
			_parent.add_child(portal)
			_box(portal, Vector3(1.0, 11.0, 1.0), Vector3(-10.0, 5.5, 0), _materials.lavender, 1100.0)
			_box(portal, Vector3(1.0, 11.0, 1.0), Vector3(10.0, 5.5, 0), _materials.lavender, 1100.0)
			_box(portal, Vector3(21.0, 0.65, 1.0), Vector3(0, 10.5, 0), _materials.pink, 1100.0)


func _build_underwater_tunnel() -> void:
	for span: Dictionary in _zone_spans("underwater_tunnel"):
		var start := float(span.start_distance)
		var finish := float(span.end_distance)
		var offset := start + 8.0
		while offset < finish - 6.0:
			var rib := Node3D.new()
			rib.name = "UnderwaterTunnelRib"
			rib.transform = _course.sample_course(offset)
			rib.add_to_group("tunnel")
			_parent.add_child(rib)
			_box(rib, Vector3(0.75, 7.0, 0.75), Vector3(-9.8, 3.5, 0), _materials.cyan, 900.0)
			_box(rib, Vector3(0.75, 7.0, 0.75), Vector3(9.8, 3.5, 0), _materials.cyan, 900.0)
			_box(rib, Vector3(20.3, 0.75, 0.75), Vector3(0, 7.0, 0), _materials.cyan, 900.0)
			if int(offset / 18.0) % 2 == 0:
				_box(rib, Vector3(19.0, 6.0, 7.0), Vector3(0, 3.5, 0), _materials.tunnel_glass, 900.0)
			offset += 18.0
		for portal_offset in [start + 3.0, finish - 3.0]:
			var portal := Node3D.new()
			portal.name = "UnderwaterTunnelPortal"
			portal.transform = _course.sample_course(portal_offset)
			portal.add_to_group("tunnel")
			_parent.add_child(portal)
			_box(portal, Vector3(1.8, 9.0, 2.0), Vector3(-10.0, 4.5, 0), _materials.night, 1000.0)
			_box(portal, Vector3(1.8, 9.0, 2.0), Vector3(10.0, 4.5, 0), _materials.night, 1000.0)
			_box(portal, Vector3(21.8, 1.8, 2.0), Vector3(0, 8.2, 0), _materials.pink, 1000.0)
