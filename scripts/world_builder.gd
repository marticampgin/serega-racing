class_name WorldBuilder
extends RefCounted

## Lightweight, deterministic scenery for the map-driven island course.
## All placements derive from CourseLayout baked distance. Scenery roots are
## grounded to a shaped sand/seabed heightfield beneath the racing surface.

const SEA_LEVEL := -1.4
const SEA_FLOOR := -3.8
const TERRAIN_TOP := 1.32
const PARTY_ISLAND_TOP := 0.0
const TERRAIN_GRID := 14.0
const OCEAN_GRID := 14.0
const ROAD_CLEARANCE := 14.0
const ROAD_GROUND_GAP := 0.65
const SUBMERGED_GROUND_GAP := 1.8
const SHORE_BLEND := 26.0
const ROUTE_BUCKET_SIZE := 192.0

var _parent: Node3D
var _course: CourseLayout
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _route_samples: Array[Dictionary] = []
var _route_buckets: Dictionary = {}
var _submerged_buckets: Dictionary = {}
var _ocean_grid_origin := Vector2.ZERO
var _terrain_grid_origin := Vector2.ZERO
var _ocean_render_cache: Dictionary = {}
var _terrain_render_cache: Dictionary = {}
var mesh_instance_count := 0


func build(parent: Node3D, course: CourseLayout) -> void:
	_parent = parent
	_course = course
	_rng.seed = 0x5E12E6A
	_build_materials()
	_cache_route_samples()
	_build_ocean_and_islands()
	_build_bridge()
	_build_underwater_tunnel()
	_build_elevated_flyovers()
	_build_start_coast()
	_build_party_town()
	_build_city_centre()
	_build_shopping_alley()
	_build_sport_complex()
	_build_north_coast()
	_build_district_infill()
	_build_party_island()
	_build_personalized_billboards()
	_build_roadside_rhythm()
	print("WorldBuilder: %d scenery meshes" % mesh_instance_count)


func terrain_height_at(world_xz: Vector2) -> float:
	return _ground_height_at(world_xz)


func ocean_rendered_height_at(world_xz: Vector2) -> float:
	# Match the exact diagonal used by _build_heightfield_mesh so QA validates
	# rendered triangle interpolation rather than only the height sampler.
	return _rendered_height_at(world_xz, _ocean_grid_origin, OCEAN_GRID, Callable(self, "_ocean_height_at"), _ocean_render_cache)


func terrain_rendered_height_at(world_xz: Vector2) -> float:
	return _rendered_height_at(world_xz, _terrain_grid_origin, TERRAIN_GRID, Callable(self, "_ground_height_at"), _terrain_render_cache)


func _rendered_height_at(world_xz: Vector2, origin: Vector2, spacing: float, sampler: Callable, cache: Dictionary) -> float:
	var grid := (world_xz - origin) / spacing
	var cell := Vector2(floorf(grid.x), floorf(grid.y))
	var uv := grid - cell
	var a_xz := origin + cell * spacing
	var b_xz := a_xz + Vector2(0.0, spacing)
	var c_xz := a_xz + Vector2(spacing, spacing)
	var d_xz := a_xz + Vector2(spacing, 0.0)
	var a := _cached_height_sample(a_xz, sampler, cache)
	var b := _cached_height_sample(b_xz, sampler, cache)
	var c := _cached_height_sample(c_xz, sampler, cache)
	var d := _cached_height_sample(d_xz, sampler, cache)
	if uv.y >= uv.x:
		return a * (1.0 - uv.y) + b * (uv.y - uv.x) + c * uv.x
	return a * (1.0 - uv.x) + c * uv.y + d * (uv.x - uv.y)


func _cached_height_sample(position: Vector2, sampler: Callable, cache: Dictionary) -> float:
	var key := Vector2i(roundi(position.x * 10.0), roundi(position.y * 10.0))
	if not cache.has(key):
		cache[key] = float(sampler.call(position))
	return float(cache[key])


func _cache_route_samples() -> void:
	_route_samples.clear()
	_route_buckets.clear()
	_submerged_buckets.clear()
	var offset := 0.0
	while offset < _course.length():
		var point := _course.point_at(offset)
		var zone := _course.zone_at(offset)
		var truly_submerged_tunnel := zone == "underwater_tunnel" and point.y < SEA_LEVEL - 0.8
		var water_route := zone == "bridge" or truly_submerged_tunnel
		# Only the enclosed tunnel needs the sea surface lowered. Extending this
		# profile into Loop 2 exposed the seabed as large purple wedges and cyan
		# puddles when viewed from the elevated crossing around 3234 m.
		var submerged_route := truly_submerged_tunnel
		var route_sample := {"offset": offset, "point": point, "zone": zone, "water": water_route, "submerged": submerged_route}
		_route_samples.append(route_sample)
		_add_to_bucket(_route_buckets, _bucket_key(Vector2(point.x, point.z)), route_sample)
		if submerged_route:
			_add_to_bucket(_submerged_buckets, _bucket_key(Vector2(point.x, point.z)), point)
		offset += 12.0


func _bucket_key(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / ROUTE_BUCKET_SIZE), floori(position.y / ROUTE_BUCKET_SIZE))


func _add_to_bucket(buckets: Dictionary, key: Vector2i, value: Variant) -> void:
	if not buckets.has(key):
		buckets[key] = []
	(buckets[key] as Array).append(value)


func _nearby_route_samples(position: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var center := _bucket_key(position)
	for bucket_x in range(center.x - 1, center.x + 2):
		for bucket_y in range(center.y - 1, center.y + 2):
			var key := Vector2i(bucket_x, bucket_y)
			if _route_buckets.has(key):
				for sample: Dictionary in _route_buckets[key]:
					result.append(sample)
	return result


func _nearby_submerged_samples(position: Vector2) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var center := _bucket_key(position)
	for bucket_x in range(center.x - 1, center.x + 2):
		for bucket_y in range(center.y - 1, center.y + 2):
			var key := Vector2i(bucket_x, bucket_y)
			if _submerged_buckets.has(key):
				for point: Vector3 in _submerged_buckets[key]:
					result.append(point)
	return result


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
		"ocean": _material(Color("087f9f"), 0.0, 0.78),
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
		"foam": _emissive(Color("c8fbff"), 1.05),
		"tunnel_glass": _material(Color("174f6f"), 0.35, 0.16),
	}
	# Two-sided terrain and sea stay visible at low shoreline angles and through
	# steep tunnel depressions in the Compatibility renderer.
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
	instance.visibility_range_end = maxf(visibility * 1.45, 1200.0)
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
	position.y = _ground_height_at(Vector2(position.x, position.z))
	var root := _grounded_root(name, position, groups)
	var target := Vector3(road.x, position.y, road.z)
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


func _road_prism_is_clear(position: Vector3, own_offset: float, radius: float, bottom: float, top: float) -> bool:
	var required_clearance := 8.5 + radius + 1.0
	var sample_offset := 0.0
	while sample_offset < _course.length():
		var arc_distance := absf(sample_offset - own_offset)
		arc_distance = minf(arc_distance, _course.length() - arc_distance)
		if arc_distance < 110.0:
			sample_offset += 4.0
			continue
		var point: Vector3 = _course.point_at(sample_offset)
		if point.y < bottom - 1.0 or point.y > top + 1.0:
			sample_offset += 4.0
			continue
		if Vector2(position.x, position.z).distance_to(Vector2(point.x, point.z)) < required_clearance:
			return false
		sample_offset += 4.0
	return true


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
	var ocean_min := center - ocean_size * 0.5
	var ocean_max := center + ocean_size * 0.5
	_ocean_grid_origin = Vector2(floorf(ocean_min.x / OCEAN_GRID) * OCEAN_GRID, floorf(ocean_min.y / OCEAN_GRID) * OCEAN_GRID)
	_terrain_grid_origin = Vector2(floorf(ocean_min.x / TERRAIN_GRID) * TERRAIN_GRID, floorf(ocean_min.y / TERRAIN_GRID) * TERRAIN_GRID)
	# Both layers are connected indexed heightfields. Sand slopes continuously to
	# the seabed; the opaque sea overlays it and depresses smoothly beneath the
	# enclosed tunnel. No cells are deleted, so there are no horizon holes.
	var ocean_mesh := _build_heightfield_mesh(ocean_min, ocean_max, OCEAN_GRID, Callable(self, "_ocean_height_at"))
	var ocean := _mesh_instance(ocean_mesh, _materials.ocean, 5200.0)
	ocean.name = "OceanSurface"
	_parent.add_child(ocean)
	ocean.add_to_group("ocean_scenery")
	_build_shoreline_contour(ocean_min, ocean_max)
	var terrain_mesh := _build_heightfield_mesh(ocean_min, ocean_max, TERRAIN_GRID, Callable(self, "_ground_height_at"))
	var terrain := MeshInstance3D.new()
	terrain.name = "IslandTerrain"
	terrain.mesh = terrain_mesh
	terrain.material_override = _materials.sand
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	terrain.visibility_range_end = 5200.0
	terrain.add_to_group("island_terrain")
	_parent.add_child(terrain)
	mesh_instance_count += 1


func _terrain_half_width(zone: String) -> float:
	if zone in ["city_centre", "sport_complex"]:
		return 155.0
	if zone in ["party_town", "start_coast", "north_coast", "party_island_view", "shopping_alley"]:
		return 112.0
	return 78.0


func _build_heightfield_mesh(minimum: Vector2, maximum: Vector2, spacing: float, height_sampler: Callable) -> ArrayMesh:
	var aligned_min := Vector2(floorf(minimum.x / spacing) * spacing, floorf(minimum.y / spacing) * spacing)
	var columns := ceili((maximum.x - aligned_min.x) / spacing) + 1
	var rows := ceili((maximum.y - aligned_min.y) / spacing) + 1
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(rows):
		for column in range(columns):
			var x := aligned_min.x + column * spacing
			var z := aligned_min.y + row * spacing
			surface.set_uv(Vector2(x, z) * 0.025)
			surface.add_vertex(Vector3(x, float(height_sampler.call(Vector2(x, z))), z))
	for row in range(rows - 1):
		for column in range(columns - 1):
			var a := row * columns + column
			var b := (row + 1) * columns + column
			var c := b + 1
			var d := a + 1
			for index in [a, b, c, a, c, d]:
				surface.add_index(index)
	surface.generate_normals()
	return surface.commit()


func _ground_height_at(world_xz: Vector2) -> float:
	var nearest_land_distance := INF
	var nearest_land_zone := ""
	var nearest_water_distance := INF
	var nearest_route_distance := INF
	var road_ceiling := INF
	for sample: Dictionary in _nearby_route_samples(world_xz):
		var point: Vector3 = sample.point
		var distance := world_xz.distance_to(Vector2(point.x, point.z))
		nearest_route_distance = minf(nearest_route_distance, distance)
		if bool(sample.water):
			nearest_water_distance = minf(nearest_water_distance, distance)
		else:
			if distance < nearest_land_distance:
				nearest_land_distance = distance
				nearest_land_zone = str(sample.zone)
		if distance < 23.0:
			var submerged := bool(sample.get("submerged", false))
			var gap := SUBMERGED_GROUND_GAP if submerged else ROAD_GROUND_GAP
			road_ceiling = minf(road_ceiling, point.y - gap)
	var island_width := _terrain_half_width(nearest_land_zone)
	var island_weight := smoothstep(-SHORE_BLEND, SHORE_BLEND, island_width - nearest_land_distance)
	var height := lerpf(SEA_FLOOR, TERRAIN_TOP, island_weight)
	var channel_weight := 1.0 - smoothstep(22.0, 48.0, nearest_water_distance)
	height = lerpf(height, SEA_FLOOR, channel_weight)
	var noise := sin(world_xz.x * 0.025) * cos(world_xz.y * 0.031) * 0.34
	noise += sin((world_xz.x + world_xz.y) * 0.011) * 0.18
	var noise_weight := smoothstep(0.62, 0.9, island_weight) * smoothstep(18.0, 58.0, nearest_route_distance)
	height += noise * noise_weight
	if road_ceiling < INF:
		height = minf(height, road_ceiling)
	return height


func _ocean_height_at(world_xz: Vector2) -> float:
	# The sea stays level at shore. Sand supplies the elevation variation; waves
	# here would repeatedly cross the sloped beach and create cyan polygon islands.
	var open_sea_height := SEA_LEVEL
	var nearest_distance := INF
	var nearest_point := Vector3.ZERO
	for point: Vector3 in _nearby_submerged_samples(world_xz):
		var distance := world_xz.distance_to(Vector2(point.x, point.z))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_point = point
	if nearest_distance == INF:
		return open_sea_height
	# OCEAN_GRID is intentionally coarse outside the playable view. Its triangles
	# span almost 20 m diagonally, so every vertex that can interpolate across the
	# 19 m tunnel must already be below the road. A broad, deep plateau prevents
	# those triangles from cutting back through the tunnel floor and shoulders.
	var depression := minf(SEA_LEVEL, nearest_point.y - 2.2)
	var weight := 1.0 - smoothstep(32.0, 48.0, nearest_distance)
	return lerpf(open_sea_height, depression, weight)


func _build_shoreline_contour(minimum: Vector2, maximum: Vector2) -> void:
	# Marching-squares produces a narrow continuous foam line exactly where the
	# shaped sand crosses sea level. It makes the beach readable without adding a
	# second flat slab that could z-fight with either terrain surface.
	const SPACING := 6.0
	var aligned_min := Vector2(floorf(minimum.x / SPACING) * SPACING, floorf(minimum.y / SPACING) * SPACING)
	var columns := ceili((maximum.x - aligned_min.x) / SPACING) + 1
	var rows := ceili((maximum.y - aligned_min.y) / SPACING) + 1
	var values := PackedFloat32Array()
	values.resize(columns * rows)
	for row in range(rows):
		for column in range(columns):
			var point := aligned_min + Vector2(column * SPACING, row * SPACING)
			values[row * columns + column] = terrain_rendered_height_at(point) - ocean_rendered_height_at(point)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segment_count := 0
	for row in range(rows - 1):
		for column in range(columns - 1):
			var center := aligned_min + Vector2((column + 0.5) * SPACING, (row + 0.5) * SPACING)
			# Leave only the sealed inner tunnel corridor contour-free. The former
			# 50 m exclusion created obvious missing shoreline stretches at portals.
			if _submerged_distance(center) < 13.0:
				continue
			var corners := [
				aligned_min + Vector2(column * SPACING, row * SPACING),
				aligned_min + Vector2((column + 1) * SPACING, row * SPACING),
				aligned_min + Vector2((column + 1) * SPACING, (row + 1) * SPACING),
				aligned_min + Vector2(column * SPACING, (row + 1) * SPACING),
			]
			var scalar := [
				values[row * columns + column],
				values[row * columns + column + 1],
				values[(row + 1) * columns + column + 1],
				values[(row + 1) * columns + column],
			]
			var crossings: Array[Vector2] = []
			for edge in range(4):
				var next := (edge + 1) % 4
				if (float(scalar[edge]) >= 0.0) == (float(scalar[next]) >= 0.0):
					continue
				var amount: float = float(scalar[edge]) / (float(scalar[edge]) - float(scalar[next]))
				crossings.append((corners[edge] as Vector2).lerp(corners[next] as Vector2, amount))
			if crossings.size() == 2:
				_append_shoreline_segment(surface, crossings[0], crossings[1])
				segment_count += 1
			elif crossings.size() == 4:
				_append_shoreline_segment(surface, crossings[0], crossings[1])
				_append_shoreline_segment(surface, crossings[2], crossings[3])
				segment_count += 2
	if segment_count == 0:
		return
	surface.generate_normals()
	var contour := _mesh_instance(surface.commit(), _materials.foam, 5200.0)
	contour.name = "ShorelineContour"
	contour.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	contour.add_to_group("shoreline_contour")
	_parent.add_child(contour)


func _append_shoreline_segment(surface: SurfaceTool, from: Vector2, to: Vector2) -> void:
	var direction := (to - from).normalized()
	if direction.length_squared() < 0.5:
		return
	# Slightly overlap neighbouring marching-square segments so sharp turns do
	# not leave pinholes between independent quads.
	from -= direction * 0.42
	to += direction * 0.42
	var normal := Vector2(-direction.y, direction.x) * 0.34
	var from_y := ocean_rendered_height_at(from) + 0.07
	var to_y := ocean_rendered_height_at(to) + 0.07
	var a := Vector3(from.x - normal.x, from_y, from.y - normal.y)
	var b := Vector3(to.x - normal.x, to_y, to.y - normal.y)
	var c := Vector3(to.x + normal.x, to_y, to.y + normal.y)
	var d := Vector3(from.x + normal.x, from_y, from.y + normal.y)
	_add_surface_quad(surface, a, b, c, d)


func _submerged_distance(world_xz: Vector2) -> float:
	var nearest := INF
	for point: Vector3 in _nearby_submerged_samples(world_xz):
		nearest = minf(nearest, world_xz.distance_to(Vector2(point.x, point.z)))
	return nearest


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
		var promenade_offset := start + 55.0
		var promenade_index := 0
		while promenade_offset < finish:
			# Closed-lap scenery must also clear the first sector. The final
			# promenade previously overlapped the Villa at 45 m across the seam.
			if promenade_offset > _course.length() - 80.0:
				break
			_add_coastal_promenade(promenade_offset, 1.0 if promenade_index % 2 == 0 else -1.0, promenade_index)
			promenade_offset += 176.0
			promenade_index += 1
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
		var patio_offset := float(span.start_distance) + 76.0
		var patio_index := 0
		while patio_offset < float(span.end_distance) - 35.0:
			_add_party_patio(patio_offset, 1.0 if patio_index % 2 == 0 else -1.0, patio_index)
			patio_offset += 140.0
			patio_index += 1


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
	for placement in [
		[middle - 265.0, -1.0, 0],
		[middle - 205.0, 1.0, 1],
		[middle + 205.0, -1.0, 2],
		[middle + 265.0, 1.0, 3],
	]:
		_add_city_block(float(placement[0]), float(placement[1]), int(placement[2]))


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
		var start := float(span.start_distance)
		var finish := float(span.end_distance)
		var middle := (float(span.start_distance) + float(span.end_distance)) * 0.5
		for side in [-1.0, 1.0]:
			_add_storefront_row(middle, side, 27.0, 6)
		var placements := [start + 78.0, start + 218.0, finish - 218.0, finish - 78.0]
		for index in range(placements.size()):
			_add_storefront_row(float(placements[index]), -1.0 if index % 2 == 0 else 1.0, 29.0, 4)


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
	var spans := _zone_spans("sport_complex")
	if spans.is_empty():
		return
	var start := float(spans[0].start_distance)
	var finish := float(spans[0].end_distance)
	var middle := (start + finish) * 0.5
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
	_add_sport_facility(start + 105.0, -1.0, 0)
	_add_sport_facility(start + 345.0, 1.0, 1)
	_add_sport_facility(finish - 345.0, -1.0, 2)
	_add_sport_facility(finish - 105.0, 1.0, 3)


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
				else:
					_add_beach_bar(d, -1.0 if index % 2 == 0 else 1.0, index)
				d += 118.0
				index += 1


func _build_district_infill() -> void:
	# A second, collision-aware population layer turns the named map zones into
	# continuous districts. These are deliberately irregular rather than a rigid
	# prop fence, and every footprint is checked against existing scenery plus all
	# non-local road branches before it is built.
	var settings := {
		"start_coast": {"spacing": 46.0, "setback": 50.0, "radius": 10.5},
		"party_town": {"spacing": 43.0, "setback": 49.0, "radius": 10.0},
		"city_centre": {"spacing": 47.0, "setback": 68.0, "radius": 14.0},
		"shopping_alley": {"spacing": 42.0, "setback": 47.0, "radius": 11.0},
		"sport_complex": {"spacing": 52.0, "setback": 68.0, "radius": 14.0},
		"north_coast": {"spacing": 48.0, "setback": 54.0, "radius": 10.5},
		"party_island_view": {"spacing": 48.0, "setback": 54.0, "radius": 10.5},
	}
	var feature_index := 0
	for zone_name: String in settings:
		var setting: Dictionary = settings[zone_name]
		for span: Dictionary in _zone_spans(zone_name):
			var offset := float(span.start_distance) + float(setting.spacing) * 0.5
			while offset < float(span.end_distance) - float(setting.spacing) * 0.35:
				var preferred_side := -1.0 if feature_index % 2 == 0 else 1.0
				var root := _try_infill_root(zone_name, offset, preferred_side, float(setting.setback), float(setting.radius), feature_index)
				if root != null:
					_populate_infill_root(root, zone_name, feature_index)
				offset += float(setting.spacing)
				feature_index += 1


func _try_infill_root(zone_name: String, offset: float, preferred_side: float, setback: float, radius: float, variant: int) -> Node3D:
	var road := _course.point_at(offset)
	var lateral := _course.lateral_at(offset)
	var candidate_position := Vector3.ZERO
	var found := false
	for extra_setback in [0.0, 22.0, 42.0]:
		for side in [preferred_side, -preferred_side]:
			var position := road + lateral * float(side) * (setback + float(extra_setback))
			position.y = _ground_height_at(Vector2(position.x, position.z))
			if position.y <= SEA_LEVEL + 0.12:
				continue
			if _other_road_clearance(position, offset) < radius + 11.0:
				continue
			if not _scenery_footprint_is_clear(position, radius):
				continue
			candidate_position = position
			found = true
			break
		if found:
			break
	if not found:
		return null
	var root := _grounded_root("%s_Infill_%03d" % [zone_name, variant], candidate_position, ["district_infill", "%s_scenery" % zone_name])
	root.look_at(Vector3(road.x, candidate_position.y, road.z), Vector3.UP)
	root.set_meta("course_offset", offset)
	root.set_meta("scenery_radius", radius)
	return root


func _scenery_footprint_is_clear(position: Vector3, radius: float) -> bool:
	for value in _parent.get_tree().get_nodes_in_group("grounded_scenery"):
		if not value is Node3D or not _parent.is_ancestor_of(value):
			continue
		var root := value as Node3D
		var existing_radius := 0.0
		if root.has_meta("scenery_radius"):
			existing_radius = float(root.get_meta("scenery_radius"))
		else:
			existing_radius = _estimate_scenery_radius(root)
			root.set_meta("scenery_radius", existing_radius)
		if Vector2(position.x, position.z).distance_to(Vector2(root.global_position.x, root.global_position.z)) < radius + existing_radius + 2.5:
			return false
	return true


func _estimate_scenery_radius(root: Node3D) -> float:
	var radius := 3.0
	var inverse := root.global_transform.affine_inverse()
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var bounds := mesh_instance.get_aabb()
		for corner_index in range(8):
			var corner := bounds.position + Vector3(
				bounds.size.x if corner_index & 1 else 0.0,
				bounds.size.y if corner_index & 2 else 0.0,
				bounds.size.z if corner_index & 4 else 0.0
			)
			var local_corner: Vector3 = inverse * (mesh_instance.global_transform * corner)
			radius = maxf(radius, Vector2(local_corner.x, local_corner.z).length())
	return minf(radius, 38.0)


func _populate_infill_root(root: Node3D, zone_name: String, variant: int) -> void:
	if zone_name in ["start_coast", "north_coast", "party_island_view"]:
		if zone_name != "start_coast" and variant % 4 == 0:
			_add_infill_marina(root, variant)
		else:
			_add_infill_bungalow(root, variant)
	elif zone_name == "party_town":
		_add_infill_bar(root, variant)
	elif zone_name == "city_centre":
		_add_infill_midrise(root, variant)
	elif zone_name == "shopping_alley":
		_add_infill_shop_pair(root, variant)
	elif zone_name == "sport_complex":
		_add_infill_sport_lot(root, variant)


func _add_infill_bungalow(root: Node3D, variant: int) -> void:
	var body: Material = [_materials.cream, _materials.mint, _materials.coral, _materials.lavender][variant % 4]
	_box(root, Vector3(13.0, 5.4, 9.0), Vector3(0, 2.7, 0), body, 900.0)
	_box(root, Vector3(14.5, 0.5, 10.2), Vector3(0, 5.65, 0), _materials.white, 900.0)
	_box(root, Vector3(8.0, 2.5, 0.2), Vector3(0, 2.5, -4.58), _materials.glass, 900.0)
	_box(root, Vector3(3.0, 2.8, 0.24), Vector3(-4.5, 1.4, -4.62), _materials.night, 900.0)
	_box(root, Vector3(10.0, 0.35, 2.1), Vector3(1.0, 4.5, -5.25), _materials.pink if variant % 2 == 0 else _materials.cyan, 900.0)
	_box(root, Vector3(16.0, 0.18, 6.0), Vector3(0, 0.09, -7.2), _materials.wood, 900.0)
	_cylinder(root, 2.1, 0.42, Vector3(5.0, 2.5, -7.0), _materials.orange, 0.16, 900.0, 10)


func _add_infill_marina(root: Node3D, variant: int) -> void:
	_box(root, Vector3(18.0, 0.25, 7.0), Vector3(0, 0.13, 2.0), _materials.wood, 1000.0)
	_box(root, Vector3(8.0, 4.2, 6.0), Vector3(-4.0, 2.1, 1.5), _materials.cream, 1000.0)
	_box(root, Vector3(8.8, 0.4, 6.8), Vector3(-4.0, 4.4, 1.5), _materials.coral, 1000.0)
	for index in range(3):
		var x := -6.0 + index * 6.0
		_box(root, Vector3(2.7, 0.65, 6.2), Vector3(x, 0.45, -4.8), _materials.cyan if (index + variant) % 2 == 0 else _materials.coral, 1000.0)
		_box(root, Vector3(1.7, 0.9, 2.2), Vector3(x, 1.0, -4.3), _materials.white, 1000.0)


func _add_infill_bar(root: Node3D, variant: int) -> void:
	_box(root, Vector3(15.0, 6.5, 10.0), Vector3(0, 3.25, 0), _materials.night, 1000.0)
	_box(root, Vector3(11.0, 3.0, 0.2), Vector3(0, 2.8, -5.08), _materials.glass, 1000.0)
	_box(root, Vector3(16.0, 0.5, 2.2), Vector3(0, 5.4, -5.8), _materials.pink if variant % 2 == 0 else _materials.cyan, 1000.0)
	_box(root, Vector3(10.0, 0.35, 0.3), Vector3(0, 7.2, -5.0), _materials.orange, 1000.0)
	for x in [-5.0, 0.0, 5.0]:
		_cylinder(root, 0.9, 0.45, Vector3(x, 0.45, -8.0), _materials.white, 0.9, 900.0, 10)


func _add_infill_midrise(root: Node3D, variant: int) -> void:
	var body: Material = [_materials.cream, _materials.mint, _materials.coral, _materials.lavender][variant % 4]
	_box(root, Vector3(19.0, 5.0, 13.0), Vector3(0, 2.5, 0), _materials.night, 1300.0)
	_box(root, Vector3(15.0, 18.0 + variant % 3 * 4.0, 10.0), Vector3(0, 14.0 + variant % 3 * 2.0, 0.5), body, 1300.0)
	for x in [-5.0, 0.0, 5.0]:
		_box(root, Vector3(2.4, 12.0, 0.2), Vector3(x, 14.0, -4.58), _materials.glass, 1300.0)
	_box(root, Vector3(13.0, 0.5, 1.7), Vector3(0, 5.0, -7.0), _materials.cyan if variant % 2 == 0 else _materials.pink, 1300.0)


func _add_infill_shop_pair(root: Node3D, variant: int) -> void:
	for index in range(2):
		var x := -5.2 if index == 0 else 5.2
		var body: Material = [_materials.cream, _materials.mint, _materials.coral, _materials.lavender][(variant + index) % 4]
		_box(root, Vector3(9.8, 6.0, 8.0), Vector3(x, 3.0, 0), body, 1000.0)
		_box(root, Vector3(7.4, 2.8, 0.2), Vector3(x, 2.3, -4.08), _materials.glass, 1000.0)
		_box(root, Vector3(10.0, 0.4, 2.0), Vector3(x, 4.8, -4.8), _materials.pink if index % 2 == 0 else _materials.cyan, 1000.0)
		_box(root, Vector3(7.0, 0.7, 0.25), Vector3(x, 6.1, -4.2), _materials.orange, 1000.0)


func _add_infill_sport_lot(root: Node3D, variant: int) -> void:
	_box(root, Vector3(25.0, 0.25, 15.0), Vector3(0, 0.13, 0), _materials.court if variant % 2 == 0 else _materials.field, 1100.0)
	_box(root, Vector3(26.0, 0.2, 0.2), Vector3(0, 0.32, -7.0), _materials.white, 1100.0)
	_box(root, Vector3(0.2, 0.05, 14.0), Vector3(0, 0.32, 0), _materials.white, 1100.0)
	for x in [-11.0, 11.0]:
		_box(root, Vector3(0.25, 7.0, 0.25), Vector3(x, 3.5, 6.0), _materials.steel, 1100.0)
		_box(root, Vector3(3.4, 0.7, 0.5), Vector3(x, 7.0, 6.0), _materials.yellow, 1100.0)
	_box(root, Vector3(18.0, 3.5, 4.5), Vector3(0, 1.75, 10.0), _materials.cream, 1100.0)


func _add_marina(offset: float, side: float) -> void:
	var root := _roadside_root("CoastalMarina", offset, side, 47.0, ["marina_scenery"])
	for dock_index in range(3):
		_box(root, Vector3(2.2, 0.3, 22.0), Vector3((dock_index - 1) * 10.0, -0.1, -9.0), _materials.wood, 420.0)
		for boat_index in range(2):
			var boat_x := (dock_index - 1) * 10.0 + (-3.0 if boat_index == 0 else 3.0)
			var boat_z := -5.0 - boat_index * 10.0
			_box(root, Vector3(2.8, 0.7, 6.0), Vector3(boat_x, -0.45, boat_z), _materials.coral if boat_index == 0 else _materials.cyan, 420.0)
			_box(root, Vector3(1.8, 1.1, 2.6), Vector3(boat_x, 0.25, boat_z + 0.3), _materials.white, 420.0)


func _add_coastal_promenade(offset: float, side: float, variant: int) -> void:
	var root := _roadside_root("CoastalPromenade", offset, side, 54.0, ["start_coast_scenery", "neighborhood_scenery"])
	_box(root, Vector3(30.0, 0.28, 12.0), Vector3(0, 0.14, 0), _materials.wood, 500.0)
	_box(root, Vector3(10.0, 5.0, 7.0), Vector3(-7.5, 2.5, 0), _materials.cream if variant % 2 == 0 else _materials.mint, 500.0)
	_box(root, Vector3(10.8, 0.45, 8.0), Vector3(-7.5, 5.2, 0), _materials.coral, 500.0)
	_box(root, Vector3(7.5, 2.2, 0.2), Vector3(-7.5, 2.3, -3.58), _materials.glass, 500.0)
	for index in range(3):
		var x := 4.0 + index * 5.0
		_cylinder(root, 0.14, 2.6, Vector3(x, 1.3, 0), _materials.steel, 0.14, 400.0, 8)
		_cylinder(root, 2.4, 0.55, Vector3(x, 2.7, 0), _materials.pink if index % 2 == 0 else _materials.cyan, 0.2, 400.0, 12)
	_box(root, Vector3(11.0, 0.45, 0.6), Vector3(7.0, 0.7, -4.0), _materials.white, 400.0)


func _add_party_patio(offset: float, side: float, variant: int) -> void:
	var root := _roadside_root("PartyTown_Patio", offset, side, 22.0, ["party_town_scenery", "neighborhood_scenery"])
	_box(root, Vector3(16.0, 0.22, 11.0), Vector3(0, 0.11, 0), _materials.asphalt, 450.0)
	_box(root, Vector3(13.0, 0.45, 7.0), Vector3(0, 5.2, 1.0), _materials.lavender, 450.0)
	for x in [-5.8, 5.8]:
		_box(root, Vector3(0.25, 5.0, 0.25), Vector3(x, 2.5, 1.0), _materials.steel, 450.0)
	_box(root, Vector3(11.0, 1.15, 2.4), Vector3(0, 0.7, 2.2), _materials.coral, 450.0)
	_box(root, Vector3(9.0, 0.3, 0.35), Vector3(0, 3.8, -4.0), _materials.cyan if variant % 2 == 0 else _materials.pink, 450.0)
	for x in [-4.0, 0.0, 4.0]:
		_cylinder(root, 1.0, 0.5, Vector3(x, 0.5, -2.0), _materials.white, 1.0, 400.0, 10)


func _add_city_block(offset: float, side: float, variant: int) -> void:
	var root := _roadside_root("CityCentre_MixedUseBlock", offset, side, 48.0, ["city_centre_scenery", "skyline_scenery"])
	var body: Material = [_materials.cream, _materials.mint, _materials.coral, _materials.lavender][variant % 4]
	_box(root, Vector3(25.0, 5.0, 14.0), Vector3(0, 2.5, 0), _materials.night, 700.0)
	_box(root, Vector3(13.0, 19.0, 11.0), Vector3(-5.0, 14.5, 0.5), body, 700.0)
	_box(root, Vector3(8.0, 13.0, 10.0), Vector3(7.0, 11.5, 1.0), _materials.cream, 700.0)
	for x in [-8.0, -3.0, 4.5, 8.0]:
		_box(root, Vector3(2.6, 2.5, 0.2), Vector3(x, 2.6, -7.08), _materials.glass, 700.0)
	_box(root, Vector3(18.0, 0.5, 1.8), Vector3(0, 5.0, -7.7), _materials.pink if variant % 2 == 0 else _materials.cyan, 700.0)


func _add_sport_facility(offset: float, side: float, variant: int) -> void:
	var root := _roadside_root("SportDistrict_Facility", offset, side, 58.0, ["sport_complex_scenery", "neighborhood_scenery"])
	if variant == 0:
		_box(root, Vector3(38.0, 0.35, 18.0), Vector3(0, 0.18, 0), _materials.cyan, 700.0)
		_box(root, Vector3(41.0, 3.8, 4.0), Vector3(0, 1.9, 11.0), _materials.white, 700.0)
		for x in [-14.0, -5.0, 5.0, 14.0]:
			_box(root, Vector3(4.5, 2.2, 0.2), Vector3(x, 2.0, 8.92), _materials.glass, 700.0)
	elif variant == 1:
		for x in [-13.0, 13.0]:
			_box(root, Vector3(22.0, 0.25, 11.0), Vector3(x, 0.13, 0), _materials.court, 650.0)
			_box(root, Vector3(0.18, 1.2, 11.0), Vector3(x, 0.65, 0), _materials.white, 650.0)
		_box(root, Vector3(51.0, 4.0, 4.5), Vector3(0, 2.0, 10.0), _materials.cream, 650.0)
	elif variant == 2:
		_box(root, Vector3(44.0, 0.28, 24.0), Vector3(0, 0.14, 0), _materials.asphalt, 650.0)
		for x in [-12.0, 0.0, 12.0]:
			var ramp := _box(root, Vector3(8.0, 1.0 + absf(x) * 0.03, 5.0), Vector3(x, 0.5, 0), _materials.lavender, 650.0)
			ramp.rotation.x = 0.12 if x >= 0.0 else -0.12
		_box(root, Vector3(18.0, 0.5, 0.4), Vector3(0, 4.0, -10.0), _materials.pink, 650.0)
	else:
		_box(root, Vector3(48.0, 0.28, 25.0), Vector3(0, 0.14, 0), _materials.field, 650.0)
		_box(root, Vector3(49.0, 0.22, 0.22), Vector3(0, 0.32, -12.0), _materials.white, 650.0)
		for x in [-22.0, 22.0]:
			_box(root, Vector3(0.3, 6.0, 0.3), Vector3(x, 3.0, 0), _materials.steel, 650.0)
			_box(root, Vector3(3.0, 0.6, 0.5), Vector3(x, 6.0, 0), _materials.yellow, 650.0)


func _add_beach_bar(offset: float, side: float, variant: int) -> void:
	var root := _roadside_root("NorthCoast_BeachBar", offset, side, 43.0, ["north_coast_scenery", "neighborhood_scenery"])
	var body: Material = _materials.mint if variant % 2 == 0 else _materials.coral
	_box(root, Vector3(16.0, 5.5, 9.0), Vector3(0, 2.75, 0), body, 520.0)
	_box(root, Vector3(18.0, 0.55, 10.0), Vector3(0, 5.7, 0), _materials.white, 520.0)
	_box(root, Vector3(12.0, 2.6, 0.2), Vector3(0, 2.4, -4.58), _materials.glass, 520.0)
	_box(root, Vector3(17.0, 0.45, 2.2), Vector3(0, 4.7, -5.4), _materials.pink if variant % 2 == 0 else _materials.cyan, 520.0)
	_box(root, Vector3(24.0, 0.25, 8.0), Vector3(0, 0.13, -8.0), _materials.wood, 520.0)
	for x in [-7.0, 0.0, 7.0]:
		_cylinder(root, 0.12, 2.5, Vector3(x, 1.25, -8.0), _materials.steel, 0.12, 420.0, 8)
		_cylinder(root, 2.2, 0.45, Vector3(x, 2.6, -8.0), _materials.orange, 0.18, 420.0, 10)


func _add_island_cabana(parent: Node, position: Vector3, rotation_y: float, variant: int) -> void:
	var root := Node3D.new()
	root.name = "PartyIsland_Cabana"
	root.position = position
	root.rotation.y = rotation_y
	root.add_to_group("party_island_scenery")
	parent.add_child(root)
	_box(root, Vector3(11.0, 0.25, 8.0), Vector3(0, 0.13, 0), _materials.wood, 800.0)
	for x in [-4.5, 4.5]:
		_box(root, Vector3(0.3, 4.2, 0.3), Vector3(x, 2.1, 0), _materials.steel, 800.0)
	_box(root, Vector3(11.5, 0.5, 8.5), Vector3(0, 4.3, 0), _materials.coral if variant % 2 == 0 else _materials.lavender, 800.0)
	_box(root, Vector3(7.0, 1.0, 2.2), Vector3(0, 0.65, 1.8), _materials.white, 800.0)
	_box(root, Vector3(8.0, 0.3, 0.3), Vector3(0, 3.3, -4.0), _materials.cyan if variant % 2 == 0 else _materials.pink, 800.0)


func _add_boat(parent: Node, position: Vector3, rotation_y: float, variant: int) -> void:
	var root := Node3D.new()
	root.name = "PartyIsland_Boat"
	root.position = position
	root.rotation.y = rotation_y
	root.add_to_group("boat_scenery")
	parent.add_child(root)
	_box(root, Vector3(3.5, 0.8, 8.5), Vector3(0, 0, 0), _materials.coral if variant % 2 == 0 else _materials.cyan, 1000.0)
	_box(root, Vector3(2.4, 1.5, 3.2), Vector3(0, 0.9, 0.7), _materials.white, 1000.0)
	_box(root, Vector3(1.8, 0.9, 0.2), Vector3(0, 1.1, -0.92), _materials.glass, 1000.0)


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
	for index in range(3):
		var angle := -1.8 + index * 1.8
		_add_island_cabana(island, Vector3(cos(angle) * 38.0, 0.0, sin(angle) * 38.0), angle + PI * 0.5, index)
	for index in range(4):
		var angle := -0.9 + index * 0.55
		var boat_position := Vector3(cos(angle) * (82.0 + index * 4.0), -0.2, sin(angle) * (82.0 + index * 4.0))
		_add_boat(island, boat_position, angle + PI * 0.5, index)


func _build_roadside_rhythm() -> void:
	var offset := 70.0
	var index := 0
	while offset < _course.length():
		var zone := _course.zone_at(offset)
		if zone != "bridge" and zone != "underwater_tunnel":
			for side in [-1.0, 1.0]:
				var road := _course.point_at(offset)
				var position: Vector3 = road + _course.lateral_at(offset) * float(side) * (24.0 + (index % 3) * 5.0)
				# Rhythm palms used to bypass all route-clearance logic, allowing a
				# different loop branch to pass through trunks and fronds.
				position.y = _ground_height_at(Vector2(position.x, position.z))
				if position.y > SEA_LEVEL + 0.12 and _road_prism_is_clear(position, offset, 4.6, position.y, position.y + 11.0):
					var palm := _grounded_root("Palm", position, ["palm_scenery"])
					palm.set_meta("course_offset", offset)
					_add_palm_at(palm, Vector3.ZERO, 0.72 + (index % 4) * 0.11)
			if index % 2 == 0:
				var lamp_side := -1.0 if index % 4 == 0 else 1.0
				var lamp_road := _course.point_at(offset)
				var lamp_position := lamp_road + _course.lateral_at(offset) * lamp_side * 12.5
				if _ground_height_at(Vector2(lamp_position.x, lamp_position.z)) > SEA_LEVEL + 0.12:
					_add_lamp(offset, lamp_side)
		offset += 195.0
		index += 1


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
		for side in [-1.0, 1.0]:
			_build_course_prism("BridgeRail", start + 4.0, finish - 4.0, side * 9.25, 0.58, 0.32, 1.15, _materials.pink, "bridge_boundary", 1200.0)
			_build_course_prism("BridgeGirder", start + 4.0, finish - 4.0, side * 7.1, -0.65, 0.72, 0.8, _materials.night, "bridge_girder", 1200.0)
		var offset := start + 24.0
		while offset < finish - 18.0:
			var frame := _course.sample_course(offset)
			var cap := Node3D.new()
			cap.name = "BridgePierCap"
			cap.transform = frame
			cap.add_to_group("bridge")
			_parent.add_child(cap)
			var beam := _box(cap, Vector3(16.2, 0.8, 2.2), Vector3(0, -0.65, 0), _materials.night, 1200.0)
			beam.add_to_group("bridge_pier_cap")
			for side in [-1.0, 1.0]:
				# The contact is derived from the pitched cap underside, not a world-y
				# approximation. Columns therefore visibly meet the bridge on grades.
				var contact: Vector3 = frame * Vector3(side * 7.1, -1.07, 0.0)
				var ground_y := _ground_height_at(Vector2(contact.x, contact.z))
				var column_height := maxf(1.0, contact.y - ground_y + 0.12)
				var column := _cylinder(_parent, 0.95, column_height, Vector3(contact.x, ground_y + column_height * 0.5, contact.z), _materials.lavender, 0.78, 1200.0, 12)
				column.name = "BridgePier"
				column.add_to_group("bridge")
				column.add_to_group("bridge_support")
				column.set_meta("course_offset", offset)
				column.set_meta("contact_y", contact.y)
				if ground_y < SEA_LEVEL and contact.y > SEA_LEVEL:
					var collar := _cylinder(_parent, 1.22, 0.45, Vector3(contact.x, SEA_LEVEL, contact.z), _materials.steel, 1.22, 1200.0, 12)
					collar.name = "BridgePierWaterlineCollar"
					collar.add_to_group("bridge")
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


func _build_elevated_flyovers() -> void:
	var run_start := -1.0
	var offset := 0.0
	while offset <= _course.length():
		var elevated := offset < _course.length() and _is_flyover_offset(offset)
		if elevated and run_start < 0.0:
			run_start = offset
		elif not elevated and run_start >= 0.0:
			var finish := minf(offset, _course.length())
			if finish - run_start >= 12.0:
				for side in [-1.0, 1.0]:
					_build_course_prism("FlyoverRail", run_start, finish, side * 9.2, 0.37, 0.34, 0.72, _materials.steel, "flyover_boundary", 1000.0)
					_build_course_prism("FlyoverAccent", run_start, finish, side * 9.2, 0.8, 0.16, 0.13, _materials.cyan, "flyover_accent", 1000.0)
				_build_flyover_supports(run_start, finish)
			run_start = -1.0
		offset += 6.0


func _is_flyover_offset(offset: float) -> bool:
	var point := _course.point_at(offset)
	var zone := _course.zone_at(offset)
	return point.y > TERRAIN_TOP + 2.6 and zone not in ["bridge", "underwater_tunnel"]


func _build_flyover_supports(start: float, finish: float) -> void:
	var offset := start + 18.0
	while offset < finish - 8.0:
		var point := _course.point_at(offset)
		for side in [-1.0, 1.0]:
			var support_xz: Vector3 = point + _course.lateral_at(offset) * float(side) * 10.6
			var ground_y := _ground_height_at(Vector2(support_xz.x, support_xz.z))
			var support_height := point.y - ground_y - 0.35
			var candidate_position := Vector3(support_xz.x, ground_y + support_height * 0.5, support_xz.z)
			if support_height > 1.0 and _road_prism_is_clear(candidate_position, offset, 0.7, ground_y, point.y):
				var support := _cylinder(_parent, 0.7, support_height, candidate_position, _materials.steel, 0.62, 900.0, 10)
				support.add_to_group("flyover")
				support.add_to_group("flyover_support")
				support.set_meta("course_offset", offset)
		offset += 36.0


func _build_course_prism(name: String, start: float, finish: float, lateral: float, center_y: float, width: float, height: float, material: Material, group: String, visibility: float) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples := maxi(1, ceili((finish - start) / 2.0))
	for index in range(samples):
		var from_offset := lerpf(start, finish, float(index) / samples)
		var to_offset := lerpf(start, finish, float(index + 1) / samples)
		var from_frame := _course.sample_course(from_offset)
		var to_frame := _course.sample_course(to_offset)
		var from_center := from_frame.origin + from_frame.basis.x * lateral + from_frame.basis.y * center_y
		var to_center := to_frame.origin + to_frame.basis.x * lateral + to_frame.basis.y * center_y
		var fx := from_frame.basis.x * width * 0.5
		var fy := from_frame.basis.y * height * 0.5
		var tx := to_frame.basis.x * width * 0.5
		var ty := to_frame.basis.y * height * 0.5
		var p0 := from_center - fx - fy
		var p1 := from_center + fx - fy
		var p2 := from_center + fx + fy
		var p3 := from_center - fx + fy
		var q0 := to_center - tx - ty
		var q1 := to_center + tx - ty
		var q2 := to_center + tx + ty
		var q3 := to_center - tx + ty
		_add_surface_quad(surface, p1, q1, q2, p2)
		_add_surface_quad(surface, q0, p0, p3, q3)
		_add_surface_quad(surface, p0, q0, q1, p1)
		_add_surface_quad(surface, p3, p2, q2, q3)
		if index == 0:
			_add_surface_quad(surface, p0, p1, p2, p3)
		if index == samples - 1:
			_add_surface_quad(surface, q1, q0, q3, q2)
	surface.generate_normals()
	var rail := _mesh_instance(surface.commit(), material, visibility)
	rail.name = name
	rail.add_to_group(group)
	rail.add_to_group("bridge" if group.begins_with("bridge") else "flyover")
	_parent.add_child(rail)
	return rail


func _add_surface_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.add_vertex(vertex)


func _build_underwater_tunnel() -> void:
	for span: Dictionary in _zone_spans("underwater_tunnel"):
		var start := float(span.start_distance)
		var finish := float(span.end_distance)
		var enclosed_start := -1.0
		var enclosed_finish := -1.0
		var probe := start
		while probe <= finish:
			# Keep the 6.4 m roof only where its top is actually underwater. The
			# shallow exit roof used to protrude into open air below Loop 2.
			if _course.point_at(probe).y + 6.7 < SEA_LEVEL:
				if enclosed_start < 0.0:
					enclosed_start = probe
				enclosed_finish = probe
			probe += 2.0
		if enclosed_start < 0.0:
			continue
		_build_tunnel_approach_walls(start + 2.0, enclosed_start)
		_build_tunnel_approach_walls(enclosed_finish, finish - 2.0)
		var offset := enclosed_start
		var panel_index := 0
		while offset < enclosed_finish:
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
		for portal_offset in [enclosed_start + 1.0, enclosed_finish - 1.0]:
			var portal := Node3D.new()
			portal.name = "UnderwaterTunnelPortal"
			portal.transform = _course.sample_course(portal_offset)
			portal.add_to_group("tunnel")
			_parent.add_child(portal)
			_box(portal, Vector3(1.8, 9.0, 2.0), Vector3(-10.0, 4.5, 0), _materials.night, 1000.0)
			_box(portal, Vector3(1.8, 9.0, 2.0), Vector3(10.0, 4.5, 0), _materials.night, 1000.0)
			_box(portal, Vector3(21.8, 1.8, 2.0), Vector3(0, 8.2, 0), _materials.pink, 1000.0)


func _build_tunnel_approach_walls(start: float, finish: float) -> void:
	if finish - start < 2.0:
		return
	var offset := start
	while offset < finish:
		var frame := _course.sample_course(offset)
		var wall_height := clampf(SEA_LEVEL - frame.origin.y + 0.9, 1.1, 6.2)
		var root := Node3D.new()
		root.name = "UnderwaterTunnelOpenApproach"
		root.transform = frame
		root.add_to_group("tunnel")
		_parent.add_child(root)
		for side in [-1.0, 1.0]:
			var wall := _box(root, Vector3(0.55, wall_height, 14.5), Vector3(side * 9.5, wall_height * 0.5, 0), _materials.rock, 1100.0)
			wall.add_to_group("tunnel_boundary")
			_box(root, Vector3(0.18, 0.18, 14.5), Vector3(side * 9.22, wall_height + 0.05, 0), _materials.cyan, 1100.0)
		offset += 14.0
