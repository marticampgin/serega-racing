class_name WorldBuilder
extends RefCounted

## Lightweight, deterministic scenery for the map-driven island course.
## All placements derive from CourseLayout baked distance. Scenery roots are
## grounded at y=0; road elevation is deliberately never used as terrain height.

const SEA_LEVEL := -1.4
const SEA_FLOOR := -3.2
const TERRAIN_TOP := 1.7
const PARTY_ISLAND_TOP := 0.0
const TERRAIN_GRID := 12.0
const OCEAN_GRID := 18.0
const ROAD_CLEARANCE := 14.0

var _parent: Node3D
var _course: CourseLayout
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _route_samples: Array[Dictionary] = []
var _water_route_samples: Array[Vector3] = []
var _submerged_route_samples: Array[Vector3] = []
var mesh_instance_count := 0


func build(parent: Node3D, course: CourseLayout) -> void:
	_parent = parent
	_course = course
	_rng.seed = 0x5E12E6A
	_build_materials()
	_cache_route_samples()
	_build_ocean_and_islands()
	_build_submerged_trench()
	_build_bridge()
	_build_underwater_tunnel()
	_build_elevated_flyovers()
	_build_start_coast()
	_build_party_town()
	_build_city_centre()
	_build_shopping_alley()
	_build_sport_complex()
	_build_north_coast()
	_build_party_island()
	_build_personalized_billboards()
	_build_roadside_rhythm()
	print("WorldBuilder: %d scenery meshes" % mesh_instance_count)


func terrain_height_at(_world_xz: Vector2) -> float:
	## The main island mesh uses one authored grade just below the normal road.
	return TERRAIN_TOP


func _cache_route_samples() -> void:
	_route_samples.clear()
	_water_route_samples.clear()
	_submerged_route_samples.clear()
	var offset := 0.0
	while offset < _course.length():
		var point := _course.point_at(offset)
		var zone := _course.zone_at(offset)
		var below_island_grade := point.y < TERRAIN_TOP - 0.2
		var water_route := zone in ["bridge", "underwater_tunnel"] or _offset_near_water_zone(offset, 95.0) or below_island_grade
		_route_samples.append({"offset": offset, "point": point, "zone": zone, "water": water_route})
		if water_route:
			_water_route_samples.append(point)
		if zone == "underwater_tunnel" or below_island_grade:
			_submerged_route_samples.append(point)
		offset += 24.0


func _offset_near_water_zone(offset: float, buffer: float) -> bool:
	for span: Dictionary in _course.course_zones:
		if str(span.name) not in ["bridge", "underwater_tunnel"]:
			continue
		if offset >= float(span.start_distance) - buffer and offset <= float(span.end_distance) + buffer:
			return true
	return false


func _build_personalized_billboards() -> void:
	var placements := [
		{"zone": "start_coast", "side": -1.0, "texture": "res://assets/generated/friends/friend-glasses-racing.png"},
		{"zone": "party_town", "side": 1.0, "texture": "res://assets/generated/friends/friend-beard-racing.png"},
		{"zone": "city_centre", "side": -1.0, "texture": "res://assets/generated/friends/friend-dark-hair-racing.png"},
	]
	for placement: Dictionary in placements:
		var offset := _zone_midpoint(str(placement.zone))
		var side := float(placement.side)
		var frame_root := _roadside_root("PortraitBillboard", offset, side, 24.0, ["portrait_scenery"])
		_box(frame_root, Vector3(8.8, 6.8, 0.35), Vector3(0.0, 4.0, 0.0), _materials["night"], 480.0)
		_box(frame_root, Vector3(9.4, 0.35, 0.6), Vector3(0.0, 7.5, 0.0), _materials["pink"], 480.0)
		var portrait := Sprite3D.new()
		portrait.texture = load(str(placement.texture))
		portrait.pixel_size = 0.0048
		portrait.position = Vector3(0.0, 4.0, -0.22)
		portrait.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		portrait.no_depth_test = false
		portrait.add_to_group("portrait_scenery")
		frame_root.add_child(portrait)


func _build_materials() -> void:
	_materials = {
		# Opaque water prevents the panorama and underwater geometry from being
		# alpha-sorted through each other. The tunnel supplies its own interior.
		"ocean": _material(Color("087f9f"), 0.18, 0.2),
		"sand": _material(Color("b97457"), 0.0, 0.9),
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
		"tunnel_glass": _material(Color("174f6f"), 0.35, 0.16),
	}
	# The procedural terrain grid is visible from both winding conventions and
	# from low coastal camera angles.
	(_materials["sand"] as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	(_materials["ocean"] as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED


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


func _mesh_instance(mesh: Mesh, material: Material, visibility := 280.0) -> MeshInstance3D:
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	if not mesh is PrimitiveMesh:
		instance.material_override = material
	var substantial := visibility >= 500.0
	if mesh is BoxMesh:
		substantial = substantial or (mesh as BoxMesh).size.length() > 9.0
	elif mesh is CylinderMesh:
		var cylinder := mesh as CylinderMesh
		substantial = substantial or cylinder.height > 5.0 or cylinder.bottom_radius > 5.0
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if substantial else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Compound buildings used to lose windows/roofs before their main body. A
	# shared minimum range keeps silhouettes intact while retaining distance culls.
	instance.visibility_range_end = maxf(visibility, 620.0)
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
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
	root.position = position
	root.set_meta("ground_y", position.y)
	root.add_to_group("grounded_scenery")
	for group in groups:
		root.add_to_group(group)
	_parent.add_child(root)
	return root


func _roadside_root(name: String, offset: float, side: float, setback: float, groups: Array[String] = []) -> Node3D:
	var road := _course.point_at(offset)
	var lateral := _course.lateral_at(offset)
	var position := road + lateral * side * setback
	for candidate in [
		[side, setback], [-side, setback],
		[side, setback + 24.0], [-side, setback + 24.0],
	]:
		var candidate_position := road + lateral * float(candidate[0]) * float(candidate[1])
		if _other_road_clearance(candidate_position, offset) >= ROAD_CLEARANCE:
			position = candidate_position
			break
	position.y = TERRAIN_TOP
	var root := _grounded_root(name, position, groups)
	var target := Vector3(road.x, TERRAIN_TOP, road.z)
	root.look_at(target, Vector3.UP)
	root.set_meta("course_offset", offset)
	return root


func _other_road_clearance(position: Vector3, own_offset: float) -> float:
	var best := INF
	for sample: Dictionary in _route_samples:
		var sample_offset := float(sample.offset)
		var arc_distance := absf(sample_offset - own_offset)
		arc_distance = minf(arc_distance, _course.length() - arc_distance)
		if arc_distance < 110.0:
			continue
		var point: Vector3 = sample.point
		best = minf(best, Vector2(position.x, position.z).distance_to(Vector2(point.x, point.z)))
	return best


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
	for sample: Dictionary in _route_samples:
		var point: Vector3 = sample.point
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.z)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.z)
	var center := (minimum + maximum) * 0.5
	var ocean_size := maximum - minimum + Vector2(650.0, 650.0)
	# One opaque grid surface avoids alpha sorting and vertical horizon faces. A
	# narrow opening follows the submerged tunnel, preventing the water surface
	# from being drawn over the descending car and tunnel portals.
	var ocean_surface := SurfaceTool.new()
	ocean_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ocean_min := center - ocean_size * 0.5
	var ocean_max := center + ocean_size * 0.5
	var ocean_x := floorf(ocean_min.x / OCEAN_GRID) * OCEAN_GRID
	while ocean_x < ocean_max.x:
		var ocean_z := floorf(ocean_min.y / OCEAN_GRID) * OCEAN_GRID
		while ocean_z < ocean_max.y:
			var cell_center := Vector2(ocean_x + OCEAN_GRID * 0.5, ocean_z + OCEAN_GRID * 0.5)
			var tunnel_distance := INF
			for tunnel_point: Vector3 in _submerged_route_samples:
				tunnel_distance = minf(tunnel_distance, cell_center.distance_squared_to(Vector2(tunnel_point.x, tunnel_point.z)))
			if tunnel_distance > 26.0 * 26.0:
				_add_flat_cell(ocean_surface, ocean_x, ocean_z, OCEAN_GRID, SEA_LEVEL)
			ocean_z += OCEAN_GRID
		ocean_x += OCEAN_GRID
	var ocean := _mesh_instance(ocean_surface.commit(), _materials.ocean, 2600.0)
	ocean.name = "OceanSurface"
	_parent.add_child(ocean)
	ocean.add_to_group("ocean_scenery")

	# Build one non-overlapping grid surface instead of hundreds of coplanar
	# cylinders. Cells near the complete bridge/tunnel route (including buffered
	# approaches) are removed, so land cannot cover a submerged road from another
	# branch of the course.
	var terrain_surface := SurfaceTool.new()
	terrain_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var terrain_min := minimum - Vector2(190.0, 190.0)
	var terrain_max := maximum + Vector2(190.0, 190.0)
	var x := floorf(terrain_min.x / TERRAIN_GRID) * TERRAIN_GRID
	while x < terrain_max.x:
		var z := floorf(terrain_min.y / TERRAIN_GRID) * TERRAIN_GRID
		while z < terrain_max.y:
			var cell_center := Vector2(x + TERRAIN_GRID * 0.5, z + TERRAIN_GRID * 0.5)
			var nearest_land_distance := INF
			var nearest_zone := ""
			for route_sample: Dictionary in _route_samples:
				var route_point: Vector3 = route_sample.point
				var route_distance := cell_center.distance_squared_to(Vector2(route_point.x, route_point.z))
				if route_distance < nearest_land_distance and not bool(route_sample.water):
					nearest_land_distance = route_distance
					nearest_zone = str(route_sample.zone)
			var nearest_water_distance := INF
			for water_point: Vector3 in _water_route_samples:
				nearest_water_distance = minf(nearest_water_distance, cell_center.distance_squared_to(Vector2(water_point.x, water_point.z)))
			var half_width := _terrain_half_width(nearest_zone)
			if nearest_land_distance <= half_width * half_width and nearest_water_distance > 34.0 * 34.0:
				_add_terrain_cell(terrain_surface, x, z)
			z += TERRAIN_GRID
		x += TERRAIN_GRID
	var terrain := MeshInstance3D.new()
	terrain.name = "IslandTerrain"
	terrain.mesh = terrain_surface.commit()
	terrain.material_override = _materials.sand
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.visibility_range_end = 2600.0
	terrain.add_to_group("island_terrain")
	_parent.add_child(terrain)
	mesh_instance_count += 1


func _terrain_half_width(zone: String) -> float:
	if zone in ["city_centre", "sport_complex"]:
		return 155.0
	if zone in ["party_town", "start_coast", "north_coast", "party_island_view", "shopping_alley"]:
		return 112.0
	return 78.0


func _add_terrain_cell(surface: SurfaceTool, x: float, z: float) -> void:
	_add_flat_cell(surface, x, z, TERRAIN_GRID, TERRAIN_TOP)


func _add_flat_cell(surface: SurfaceTool, x: float, z: float, size: float, height: float) -> void:
	var a := Vector3(x, height, z)
	var b := Vector3(x, height, z + size)
	var c := Vector3(x + size, height, z + size)
	var d := Vector3(x + size, height, z)
	for point in [a, b, c, a, c, d]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(point)


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
	for light_position: Vector3 in [Vector3(-35, 0, -25), Vector3(35, 0, -25), Vector3(-35, 0, 25), Vector3(35, 0, 25)]:
		_add_floodlight(root, light_position)


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
	# A tall club beacon makes this off-track landmark readable across the lagoon
	# without pretending it is part of the racing line.
	_cylinder(club, 2.2, 27.0, Vector3(0, 24.5, 2.0), _materials.night, 1.5, 1400.0, 12)
	_cylinder(club, 5.8, 1.4, Vector3(0, 38.2, 2.0), _materials.pink, 5.8, 1400.0, 16)
	_cylinder(club, 3.4, 3.8, Vector3(0, 40.5, 2.0), _materials.glass, 3.4, 1400.0, 16)
	_cylinder(club, 4.8, 0.8, Vector3(0, 42.8, 2.0), _materials.cyan, 1.4, 1400.0, 16)
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
				var position: Vector3 = road + _course.lateral_at(offset) * float(side) * (24.0 + (index % 3) * 5.0)
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
		var offset := start + 6.0
		var support_index := 0
		while offset < finish - 10.0:
			var point := _course.point_at(offset)
			var frame := _course.sample_course(offset)
			var rail_root := Node3D.new()
			rail_root.name = "BridgeRail"
			rail_root.transform = frame
			rail_root.add_to_group("bridge")
			_parent.add_child(rail_root)
			for side in [-1.0, 1.0]:
				var rail := _box(rail_root, Vector3(0.32, 1.15, 13.0), Vector3(side * 9.25, 0.58, 0), _materials.pink, 1200.0)
				rail.add_to_group("bridge_boundary")
			if support_index % 4 == 0:
				var column_height := maxf(1.0, point.y - SEA_FLOOR - 0.7)
				for side in [-1.0, 1.0]:
					var column_xz := point + _course.lateral_at(offset) * float(side) * 7.1
					var column := _cylinder(_parent, 0.9, column_height, Vector3(column_xz.x, SEA_FLOOR + column_height * 0.5, column_xz.z), _materials.lavender, 0.75, 1200.0, 10)
					column.add_to_group("bridge")
				var beam := _box(rail_root, Vector3(19.5, 0.8, 2.0), Vector3(0, -0.65, 0), _materials.night, 1200.0)
				beam.add_to_group("bridge")
			offset += 12.0
			support_index += 1
		for portal_offset in [start + 8.0, finish - 8.0]:
			var portal := Node3D.new()
			portal.name = "BridgeGateway"
			portal.transform = _course.sample_course(portal_offset)
			portal.add_to_group("bridge")
			_parent.add_child(portal)
			_box(portal, Vector3(1.0, 11.0, 1.0), Vector3(-10.0, 5.5, 0), _materials.lavender, 1100.0)
			_box(portal, Vector3(1.0, 11.0, 1.0), Vector3(10.0, 5.5, 0), _materials.lavender, 1100.0)
			_box(portal, Vector3(21.0, 0.65, 1.0), Vector3(0, 10.5, 0), _materials.pink, 1100.0)


func _build_submerged_trench() -> void:
	# The ocean has a narrow opening above the descending road. A dark road-following
	# bed closes that opening from below, so the sky panorama can never leak through
	# the water gap at either portal.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offset := 0.0
	while offset < _course.length() - 6.0:
		var next_offset := offset + 6.0
		var point_a := _course.point_at(offset)
		var point_b := _course.point_at(next_offset)
		var submerged_a := _course.zone_at(offset) == "underwater_tunnel" or point_a.y < TERRAIN_TOP - 0.2
		var submerged_b := _course.zone_at(next_offset) == "underwater_tunnel" or point_b.y < TERRAIN_TOP - 0.2
		if submerged_a and submerged_b:
			var frame_a := _course.sample_course(offset)
			var frame_b := _course.sample_course(next_offset)
			var center_a := frame_a.origin - frame_a.basis.y * 1.8
			var center_b := frame_b.origin - frame_b.basis.y * 1.8
			var a_left := center_a - frame_a.basis.x * 32.0
			var a_right := center_a + frame_a.basis.x * 32.0
			var b_left := center_b - frame_b.basis.x * 32.0
			var b_right := center_b + frame_b.basis.x * 32.0
			for vertex: Vector3 in [a_left, b_left, b_right, a_left, b_right, a_right]:
				surface.set_normal(Vector3.UP)
				surface.add_vertex(vertex)
			# Retaining walls close the vertical gap between this bed and the ocean
			# surface, which otherwise reveals the panorama below the horizon.
			if a_left.y < SEA_LEVEL and b_left.y < SEA_LEVEL:
				var a_left_top := Vector3(a_left.x, SEA_LEVEL, a_left.z)
				var b_left_top := Vector3(b_left.x, SEA_LEVEL, b_left.z)
				var a_right_top := Vector3(a_right.x, SEA_LEVEL, a_right.z)
				var b_right_top := Vector3(b_right.x, SEA_LEVEL, b_right.z)
				for vertex: Vector3 in [a_left, b_left_top, b_left, a_left, a_left_top, b_left_top, a_right, b_right, b_right_top, a_right, b_right_top, a_right_top]:
					surface.set_normal(Vector3.UP)
					surface.add_vertex(vertex)
		offset = next_offset
	var bed := _mesh_instance(surface.commit(), _materials.rock, 1400.0)
	bed.name = "SubmergedTrenchBed"
	bed.add_to_group("submerged_floor")
	_parent.add_child(bed)


func _build_elevated_flyovers() -> void:
	var offset := 0.0
	var elevated_index := 0
	while offset < _course.length():
		var point := _course.point_at(offset)
		var zone := _course.zone_at(offset)
		if point.y > TERRAIN_TOP + 2.6 and zone not in ["bridge", "underwater_tunnel"]:
			var frame := _course.sample_course(offset)
			var rail_root := Node3D.new()
			rail_root.name = "FlyoverDeck"
			rail_root.transform = frame
			rail_root.add_to_group("flyover")
			_parent.add_child(rail_root)
			for side in [-1.0, 1.0]:
				var rail := _box(rail_root, Vector3(0.3, 1.05, 13.0), Vector3(side * 9.2, 0.54, 0), _materials.cyan, 1000.0)
				rail.add_to_group("flyover_boundary")
			if elevated_index % 3 == 0:
				var support_height := point.y - TERRAIN_TOP - 0.35
				if support_height > 1.0:
					for side in [-1.0, 1.0]:
						var support_xz := point + _course.lateral_at(offset) * float(side) * 6.5
						var support := _cylinder(_parent, 0.7, support_height, Vector3(support_xz.x, TERRAIN_TOP + support_height * 0.5, support_xz.z), _materials.steel, 0.62, 900.0, 10)
						support.add_to_group("flyover")
			elevated_index += 1
		offset += 12.0


func _build_underwater_tunnel() -> void:
	for span: Dictionary in _zone_spans("underwater_tunnel"):
		var start := float(span.start_distance)
		var finish := float(span.end_distance)
		var offset := start + 2.0
		var panel_index := 0
		while offset < finish - 2.0:
			var shell := Node3D.new()
			shell.name = "UnderwaterTunnelShell"
			shell.transform = _course.sample_course(offset)
			shell.add_to_group("tunnel")
			_parent.add_child(shell)
			# Thin, opaque/reflective panels form a hollow tube. The previous 19x6x7
			# transparent cubes filled the lane and corrupted the panorama via alpha sorting.
			for side in [-1.0, 1.0]:
				var wall := _box(shell, Vector3(0.42, 6.4, 14.8), Vector3(side * 9.55, 3.2, 0), _materials.tunnel_glass, 1000.0)
				wall.add_to_group("tunnel_boundary")
				_box(shell, Vector3(0.18, 0.28, 14.8), Vector3(side * 9.28, 1.0, 0), _materials.cyan, 1000.0)
			var roof := _box(shell, Vector3(19.5, 0.45, 14.8), Vector3(0, 6.35, 0), _materials.night, 1000.0)
			roof.add_to_group("tunnel_boundary")
			if panel_index % 3 == 0:
				_box(shell, Vector3(0.6, 6.2, 0.72), Vector3(-9.22, 3.1, 0), _materials.cyan, 1000.0)
				_box(shell, Vector3(0.6, 6.2, 0.72), Vector3(9.22, 3.1, 0), _materials.cyan, 1000.0)
				_box(shell, Vector3(18.7, 0.6, 0.72), Vector3(0, 6.05, 0), _materials.cyan, 1000.0)
			offset += 14.0
			panel_index += 1
		for portal_offset in [start + 3.0, finish - 3.0]:
			var portal := Node3D.new()
			portal.name = "UnderwaterTunnelPortal"
			portal.transform = _course.sample_course(portal_offset)
			portal.add_to_group("tunnel")
			_parent.add_child(portal)
			_box(portal, Vector3(1.8, 9.0, 2.0), Vector3(-10.0, 4.5, 0), _materials.night, 1000.0)
			_box(portal, Vector3(1.8, 9.0, 2.0), Vector3(10.0, 4.5, 0), _materials.night, 1000.0)
			_box(portal, Vector3(21.8, 1.8, 2.0), Vector3(0, 8.2, 0), _materials.pink, 1000.0)
