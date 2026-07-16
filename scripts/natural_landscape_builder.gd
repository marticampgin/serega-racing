class_name NaturalLandscapeBuilder
extends RefCounted

const SEA_LEVEL := -1.4
const SITE_SEARCH_STEP := 18.0

var _course: CourseLayout
var _terrain: WorldBuilder
var _source: Node3D
var _parent: Node3D
var _materials: Dictionary = {}
var _reservations: Array[Node3D] = []
var _manual_items: Array[Node3D] = []
var landscape_count := 0


func build(parent: Node3D, course: CourseLayout, terrain: WorldBuilder, source: Node3D) -> void:
	_parent = parent
	_course = course
	_terrain = terrain
	_source = source
	_build_materials()
	_collect_reservations()
	# These targets correspond to the first open areas marked by the user: two
	# start-coast headlands, the interiors of Loops 1 and 2, and both sides of
	# the bridge approach. A small local search keeps them clear of authored edits.
	var sites: Array[Dictionary] = [
		{"id": "start_west_headland", "kind": "coastal_hills", "target": Vector2(-1185, -975), "radius": 38.0, "height": 24.0},
		{"id": "start_interior_dunes", "kind": "dune_field", "target": Vector2(-840, -930), "radius": 36.0, "height": 12.0},
		{"id": "loop_one_oasis", "kind": "oasis", "target": Vector2(-675, -270), "radius": 32.0, "height": 4.0},
		{"id": "loop_two_highlands", "kind": "mountain", "target": Vector2(-1035, 830), "radius": 46.0, "height": 42.0},
		{"id": "bridge_west_dunes", "kind": "dune_field", "target": Vector2(-1035, 960), "radius": 24.0, "height": 7.5},
		{"id": "bridge_east_dunes", "kind": "dune_field", "target": Vector2(-930, 990), "radius": 24.0, "height": 8.0},
		{"id": "south_limestone_cliffs", "kind": "sharp_cliffs", "target": Vector2(-570, -1150), "radius": 36.0, "height": 38.0},
		{"id": "city_coastal_bluff", "kind": "coastal_bluff", "target": Vector2(190, 400), "radius": 40.0, "height": 25.0},
		{"id": "south_natural_arch", "kind": "limestone_arch", "target": Vector2(270, -750), "radius": 34.0, "height": 24.0},
		{"id": "north_mangrove_lagoon", "kind": "mangrove_lagoon", "target": Vector2(590, 650), "radius": 34.0, "height": 5.0},
		{"id": "east_coastal_rock_garden", "kind": "rock_garden", "target": Vector2(670, -1070), "radius": 34.0, "height": 17.0},
	]
	for site in sites:
		var position := _find_site(site.target as Vector2, float(site.radius))
		if position == Vector2(INF, INF):
			push_warning("NATURAL LANDSCAPE: no safe placement for %s" % str(site.id))
			continue
		_build_site(str(site.id), str(site.kind), position, float(site.radius), float(site.height))


func _collect_reservations() -> void:
	for value in _source.find_children("*", "Node3D", true, false):
		var node := value as Node3D
		if node.is_in_group("building_scenery") or node.is_in_group("unique_landmark"):
			_reservations.append(node)
		if node.is_in_group("manual_scenery"):
			_manual_items.append(node)


func _find_site(target: Vector2, radius: float) -> Vector2:
	for ring in range(0, 6):
		var samples := 1 if ring == 0 else ring * 8
		for sample in range(samples):
			var angle := TAU * float(sample) / float(samples)
			var candidate := target + Vector2(cos(angle), sin(angle)) * float(ring) * SITE_SEARCH_STEP
			if _valid_site(candidate, radius):
				return candidate
	return Vector2(INF, INF)


func _valid_site(position: Vector2, radius: float) -> bool:
	var ground := _terrain.terrain_rendered_height_at(position)
	if ground - _terrain.ocean_rendered_height_at(position) < 0.18:
		return false
	for sample in range(12):
		var angle := TAU * float(sample) / 12.0
		var probe := position + Vector2(cos(angle), sin(angle)) * radius
		var probe_ground := _terrain.terrain_rendered_height_at(probe)
		if probe_ground - _terrain.ocean_rendered_height_at(probe) < 0.16 or absf(probe_ground - ground) > 2.2:
			return false
	var offset := 0.0
	while offset < _course.length():
		var road := _course.point_at(offset)
		if absf(road.y - ground) < 18.0 and position.distance_to(Vector2(road.x, road.z)) < radius + _course.road_half_width + 8.0:
			return false
		offset += 12.0
	for reservation in _reservations:
		if _overlaps_reservation(position, radius, reservation, 7.0):
			return false
	for item in _manual_items:
		if _overlaps_reservation(position, radius, item, 5.0):
			return false
	return true


func _overlaps_reservation(position: Vector2, radius: float, node: Node3D, margin: float) -> bool:
	var scale := node.global_transform.basis.get_scale()
	var reserve := float(node.get_meta("scenery_radius", 5.0)) * maxf(absf(scale.x), absf(scale.z))
	return position.distance_to(Vector2(node.global_position.x, node.global_position.z)) < radius + reserve + margin


func _build_site(id: String, kind: String, xz: Vector2, radius: float, height: float) -> void:
	var offset := _closest_course_offset(xz)
	var district := _course.zone_at(offset)
	var root := Node3D.new()
	root.name = id.to_pascal_case()
	root.position = Vector3(xz.x, _terrain.terrain_rendered_height_at(xz) + 0.03, xz.y)
	root.add_to_group("natural_landscape_scenery")
	root.add_to_group("natural_%s" % kind)
	root.add_to_group("editable_scenery")
	root.add_to_group("%s_scenery" % district)
	root.set_meta("natural_landscape", true)
	root.set_meta("landscape_id", id)
	root.set_meta("landscape_kind", kind)
	root.set_meta("landscape_radius", radius)
	root.set_meta("scenery_radius", radius)
	root.set_meta("course_offset", offset)
	root.set_meta("landscape_district", district)
	root.set_meta("ground_y", root.position.y)
	root.set_meta("size_hint", "Scale this root uniformly in X/Y/Z to resize the whole landscape")
	root.set_meta("default_radius", radius)
	root.set_meta("default_height", height)
	root.set_meta("_edit_group_", true)
	_parent.add_child(root, true)
	landscape_count += 1
	match kind:
		"oasis": _build_oasis(root, radius)
		"mountain": _build_mountain(root, radius, height)
		"dune_field": _build_dunes(root, radius, height)
		"sharp_cliffs": _build_sharp_cliffs(root, radius, height)
		"coastal_bluff": _build_coastal_bluff(root, radius, height)
		"limestone_arch": _build_limestone_arch(root, radius, height)
		"mangrove_lagoon": _build_mangrove_lagoon(root, radius)
		"rock_garden": _build_rock_garden(root, radius, height)
		_: _build_coastal_hills(root, radius, height)


func _closest_course_offset(position: Vector2) -> float:
	var best_offset := 0.0
	var best_distance := INF
	var offset := 0.0
	while offset < _course.length():
		var point := _course.point_at(offset)
		var distance := position.distance_squared_to(Vector2(point.x, point.z))
		if distance < best_distance:
			best_distance = distance
			best_offset = offset
		offset += 8.0
	return best_offset


func _build_coastal_hills(root: Node3D, radius: float, height: float) -> void:
	_add_multi_peak_landform(root, Vector2(radius * 0.92, radius * 0.72), [
		{"centre": Vector2(-0.34, -0.08), "spread": Vector2(0.23, 0.29), "height": height},
		{"centre": Vector2(0.35, 0.20), "spread": Vector2(0.21, 0.25), "height": height * 0.72},
		{"centre": Vector2(0.02, -0.34), "spread": Vector2(0.48, 0.30), "height": height * 0.18},
	], _materials.rock_warm, 3)
	_add_rocks(root, radius, 7)
	_add_palms(root, radius, 3)


func _build_dunes(root: Node3D, radius: float, height: float) -> void:
	_add_multi_peak_landform(root, Vector2(radius * 0.94, radius * 0.70), [
		{"centre": Vector2(-0.42, -0.10), "spread": Vector2(0.22, 0.55), "height": height * 0.78},
		{"centre": Vector2(0.02, 0.06), "spread": Vector2(0.24, 0.62), "height": height},
		{"centre": Vector2(0.43, -0.04), "spread": Vector2(0.21, 0.50), "height": height * 0.72},
	], _materials.sand_shadow, 23)
	_add_rocks(root, radius, 5)
	_add_palms(root, radius, 2)


func _build_mountain(root: Node3D, radius: float, height: float) -> void:
	_add_multi_peak_landform(root, Vector2(radius * 0.94, radius * 0.82), [
		{"centre": Vector2(-0.37, -0.08), "spread": Vector2(0.18, 0.22), "height": height},
		{"centre": Vector2(0.36, 0.20), "spread": Vector2(0.17, 0.21), "height": height * 0.82},
		{"centre": Vector2(0.05, -0.40), "spread": Vector2(0.16, 0.18), "height": height * 0.58},
		{"centre": Vector2.ZERO, "spread": Vector2(0.66, 0.60), "height": height * 0.13},
	], _materials.rock, 47)
	_add_rocks(root, radius, 9)
	_add_palms(root, radius, 2)


func _build_sharp_cliffs(root: Node3D, radius: float, height: float) -> void:
	_add_multi_peak_landform(root, Vector2(radius * 0.98, radius * 0.72), [
		{"centre": Vector2(-0.38, -0.04), "spread": Vector2(0.13, 0.20), "height": height},
		{"centre": Vector2(-0.05, 0.13), "spread": Vector2(0.12, 0.18), "height": height * 0.82},
		{"centre": Vector2(0.34, -0.12), "spread": Vector2(0.14, 0.21), "height": height * 0.92},
		{"centre": Vector2.ZERO, "spread": Vector2(0.72, 0.55), "height": height * 0.10},
	], _materials.limestone, 71)
	for index in range(7):
		var angle := -1.05 + float(index) * 0.34
		_add_rock(root, Vector3(cos(angle) * radius * 0.72, 0.4, sin(angle) * radius * 0.58), 2.8 + float(index % 3), index)
	_add_palms(root, radius, 2)


func _build_coastal_bluff(root: Node3D, radius: float, height: float) -> void:
	_add_terraced_landform(root, Vector2(radius, radius * 0.76), height, _materials.rock_warm)
	_add_rocks(root, radius, 10)
	_add_shrubs_ring(root, radius * 0.64, 11)
	_add_palms(root, radius, 4)


func _build_limestone_arch(root: Node3D, radius: float, height: float) -> void:
	_add_multi_peak_landform(root, Vector2(radius * 0.98, radius * 0.70), [
		{"centre": Vector2(-0.48, 0.05), "spread": Vector2(0.18, 0.30), "height": height * 0.60},
		{"centre": Vector2(0.48, 0.05), "spread": Vector2(0.18, 0.30), "height": height * 0.60},
	], _materials.limestone, 83)
	for index in range(11):
		var fraction := float(index) / 10.0
		var angle := fraction * PI
		var arch_position := Vector3(cos(angle) * radius * 0.34, sin(angle) * height * 0.72 + height * 0.08, 0)
		_add_arch_rock(root, arch_position, radius * 0.085, index)
	_add_rocks(root, radius, 6)
	_add_palms(root, radius, 3)


func _build_mangrove_lagoon(root: Node3D, radius: float) -> void:
	var pond := MeshInstance3D.new()
	pond.name = "MangroveLagoonWater"
	var water := CylinderMesh.new()
	water.top_radius = radius * 0.72
	water.bottom_radius = radius * 0.74
	water.height = 0.10
	water.radial_segments = 48
	water.material = _materials.water
	pond.mesh = water
	pond.scale = Vector3(1.0, 1.0, 0.58)
	pond.position.y = 0.10
	pond.visibility_range_end = 3000.0
	root.add_child(pond)
	for index in range(14):
		var angle := TAU * float(index) / 14.0 + 0.15
		var distance := radius * (0.72 + float(index % 2) * 0.10)
		_add_mangrove(root, Vector3(cos(angle) * distance, 0, sin(angle) * distance * 0.62), index)
	_add_rocks(root, radius, 7)


func _build_rock_garden(root: Node3D, radius: float, height: float) -> void:
	_add_multi_peak_landform(root, Vector2(radius * 0.94, radius * 0.72), [
		{"centre": Vector2.ZERO, "spread": Vector2(0.68, 0.58), "height": height * 0.18},
		{"centre": Vector2(-0.30, -0.10), "spread": Vector2(0.15, 0.18), "height": height * 0.46},
		{"centre": Vector2(0.34, 0.16), "spread": Vector2(0.14, 0.17), "height": height * 0.36},
	], _materials.sand_shadow, 97)
	for index in range(15):
		var angle := TAU * float(index) / 15.0 + 0.24
		var distance := radius * (0.26 + float(index % 4) * 0.16)
		_add_rock(root, Vector3(cos(angle) * distance, 0.35, sin(angle) * distance * 0.76), 2.0 + float(index % 5) * 0.65, index)
	_add_shrubs_ring(root, radius * 0.74, 9)
	_add_palms(root, radius, 3)


func _add_terraced_landform(root: Node3D, radii: Vector2, height: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 48
	var fractions := [0.0, 0.30, 0.58, 0.61, 0.84, 0.88, 1.0]
	var heights := [1.0, 0.96, 0.82, 0.55, 0.48, 0.16, 0.0]
	var vertices: Array[Vector3] = []
	for ring in range(fractions.size()):
		for segment in range(segments):
			var angle := TAU * float(segment) / float(segments)
			var wobble := 1.0 + sin(angle * 3.0) * 0.05 + cos(angle * 7.0) * 0.025
			vertices.append(Vector3(cos(angle) * radii.x * float(fractions[ring]) * wobble, height * float(heights[ring]), sin(angle) * radii.y * float(fractions[ring]) * wobble))
	for ring in range(fractions.size() - 1):
		for segment in range(segments):
			var next := (segment + 1) % segments
			for vertex in [vertices[ring * segments + segment], vertices[(ring + 1) * segments + segment], vertices[(ring + 1) * segments + next], vertices[ring * segments + segment], vertices[(ring + 1) * segments + next], vertices[ring * segments + next]]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	surface.set_material(material)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerracedBluff"
	mesh_instance.mesh = surface.commit()
	mesh_instance.visibility_range_end = 3200.0
	root.add_child(mesh_instance)


func _add_multi_peak_landform(root: Node3D, radii: Vector2, peaks: Array[Dictionary], material: Material, seed: int) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 40
	var rings := 12
	var vertices: Array[Vector3] = []
	for ring in range(rings):
		var fraction := float(ring) / float(rings - 1)
		for segment in range(segments):
			var angle := TAU * float(segment) / float(segments)
			var edge_wobble := 1.0 + sin(angle * 3.0 + float(seed)) * 0.055 + cos(angle * 5.0 - float(seed) * 0.3) * 0.03
			var u := cos(angle) * fraction * edge_wobble
			var v := sin(angle) * fraction * edge_wobble
			var height := 0.0
			for peak in peaks:
				var centre := peak.centre as Vector2
				var spread := peak.spread as Vector2
				var dx := (u - centre.x) / spread.x
				var dz := (v - centre.y) / spread.y
				height += float(peak.height) * exp(-0.5 * (dx * dx + dz * dz))
			var skirt := pow(maxf(0.0, 1.0 - fraction * fraction), 0.72)
			height *= skirt
			vertices.append(Vector3(u * radii.x, height, v * radii.y))
	for ring in range(rings - 1):
		for segment in range(segments):
			var next := (segment + 1) % segments
			var a := vertices[ring * segments + segment]
			var b := vertices[(ring + 1) * segments + segment]
			var c := vertices[(ring + 1) * segments + next]
			var d := vertices[ring * segments + next]
			for vertex in [a, b, c, a, c, d]:
				surface.add_vertex(vertex)
	surface.generate_normals()
	surface.set_material(material)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "ContinuousLandform"
	mesh_instance.mesh = surface.commit()
	mesh_instance.visibility_range_end = 2800.0
	mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	root.add_child(mesh_instance)


func _build_oasis(root: Node3D, radius: float) -> void:
	var pond := MeshInstance3D.new()
	pond.name = "OasisWater"
	var water := CylinderMesh.new()
	water.top_radius = radius * 0.56
	water.bottom_radius = radius * 0.58
	water.height = 0.12
	water.radial_segments = 40
	water.material = _materials.water
	pond.mesh = water
	pond.scale = Vector3(1.0, 1.0, 0.68)
	pond.position.y = 0.12
	pond.visibility_range_end = 2200.0
	root.add_child(pond)
	for index in range(18):
		var angle := TAU * float(index) / 18.0
		var edge := Vector3(cos(angle) * radius * 0.62, 0.12, sin(angle) * radius * 0.43)
		_add_rock(root, edge, 1.0 + float(index % 3) * 0.35, index)
	_add_palms(root, radius, 7)
	for index in range(8):
		var angle := TAU * float(index) / 8.0 + 0.22
		_add_shrub(root, Vector3(cos(angle) * radius * 0.78, 0, sin(angle) * radius * 0.60), index)


func _add_sculpted_mound(root: Node3D, centre: Vector3, radii: Vector2, height: float, material: Material, seed: int) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 28
	var ring_fractions := [0.10, 0.30, 0.56, 0.79, 1.0]
	var ring_heights := [0.94, 0.82, 0.52, 0.20, 0.0]
	var vertices: Array[Vector3] = []
	for ring in range(ring_fractions.size()):
		for segment in range(segments):
			var angle := TAU * float(segment) / float(segments)
			var wobble := 1.0 + sin(angle * 3.0 + float(seed)) * 0.08 + cos(angle * 5.0 - float(seed) * 0.4) * 0.045
			var fraction := float(ring_fractions[ring]) * wobble
			var skew := Vector2(cos(angle) * radii.x * fraction, sin(angle) * radii.y * fraction)
			var y := height * float(ring_heights[ring]) * (0.92 + sin(angle * 2.0 + float(seed)) * 0.08)
			vertices.append(centre + Vector3(skew.x, y, skew.y))
	for ring in range(ring_fractions.size() - 1):
		for segment in range(segments):
			var next := (segment + 1) % segments
			var a := vertices[ring * segments + segment]
			var b := vertices[(ring + 1) * segments + segment]
			var c := vertices[(ring + 1) * segments + next]
			var d := vertices[ring * segments + next]
			for vertex in [a, b, c, a, c, d]:
				surface.add_vertex(vertex)
	var crown := centre + Vector3(radii.x * 0.04, height, -radii.y * 0.05)
	for segment in range(segments):
		var next := (segment + 1) % segments
		for vertex in [crown, vertices[segment], vertices[next]]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	surface.set_material(material)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SculptedTerrain"
	mesh_instance.mesh = surface.commit()
	mesh_instance.visibility_range_end = 2600.0
	mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	root.add_child(mesh_instance)


func _add_rocks(root: Node3D, radius: float, count: int) -> void:
	for index in range(count):
		var angle := TAU * float(index) / float(count) + 0.37
		var distance := radius * (0.68 + float(index % 3) * 0.09)
		_add_rock(root, Vector3(cos(angle) * distance, 0.2, sin(angle) * distance), 1.2 + float(index % 4) * 0.45, index)


func _add_rock(root: Node3D, position: Vector3, size: float, variant: int) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "CoastalRock"
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _materials.rock if variant % 2 == 0 else _materials.rock_warm
	mesh_instance.mesh = mesh
	mesh_instance.position = position + Vector3(0, size * 0.45, 0)
	mesh_instance.scale = Vector3(size * 1.25, size * 0.62, size * (0.82 + float(variant % 3) * 0.13))
	mesh_instance.rotation.y = float(variant) * 0.71
	mesh_instance.visibility_range_end = 1800.0
	root.add_child(mesh_instance)


func _add_arch_rock(root: Node3D, position: Vector3, size: float, variant: int) -> void:
	var rock := MeshInstance3D.new()
	rock.name = "LimestoneArchRock"
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh.material = _materials.limestone
	rock.mesh = mesh
	rock.position = position
	rock.scale = Vector3(size * 1.35, size, size * 1.15)
	rock.rotation = Vector3(float(variant % 2) * 0.08, float(variant) * 0.37, float(variant - 5) * 0.025)
	rock.visibility_range_end = 2800.0
	root.add_child(rock)


func _add_mangrove(root: Node3D, position: Vector3, variant: int) -> void:
	var trunk_height := 4.0 + float(variant % 4) * 0.65
	for stem_index in range(3):
		var stem := MeshInstance3D.new()
		stem.name = "MangroveStem"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.14
		mesh.bottom_radius = 0.24
		mesh.height = trunk_height
		mesh.radial_segments = 7
		mesh.material = _materials.trunk
		stem.mesh = mesh
		stem.position = position + Vector3(float(stem_index - 1) * 0.42, trunk_height * 0.5, float((stem_index + variant) % 2) * 0.36)
		stem.rotation.z = float(stem_index - 1) * 0.10
		stem.visibility_range_end = 2400.0
		root.add_child(stem)
	var crown := MeshInstance3D.new()
	crown.name = "MangroveCrown"
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 1.0
	crown_mesh.height = 1.8
	crown_mesh.radial_segments = 10
	crown_mesh.rings = 5
	crown_mesh.material = _materials.leaves_dark if variant % 2 else _materials.leaves
	crown.mesh = crown_mesh
	crown.position = position + Vector3(0, trunk_height + 0.4, 0)
	crown.scale = Vector3(2.8, 1.35, 2.25)
	crown.visibility_range_end = 2400.0
	root.add_child(crown)


func _add_palms(root: Node3D, radius: float, count: int) -> void:
	for index in range(count):
		var angle := TAU * float(index) / float(count) + 0.83
		var distance := radius * (0.62 + float(index % 2) * 0.18)
		var base := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.22
		trunk_mesh.bottom_radius = 0.42
		trunk_mesh.height = 7.0 + float(index % 3)
		trunk_mesh.radial_segments = 8
		trunk_mesh.material = _materials.trunk
		trunk.mesh = trunk_mesh
		trunk.position = base + Vector3(0, trunk_mesh.height * 0.5, 0)
		trunk.visibility_range_end = 1900.0
		root.add_child(trunk)
		var crown_y := trunk_mesh.height
		for leaf_index in range(6):
			var leaf := MeshInstance3D.new()
			var leaf_mesh := BoxMesh.new()
			leaf_mesh.size = Vector3(0.42, 0.14, 5.2)
			leaf_mesh.material = _materials.leaves if leaf_index % 2 == 0 else _materials.leaves_dark
			leaf.mesh = leaf_mesh
			leaf.position = base + Vector3(0, crown_y, 0)
			leaf.rotation = Vector3(-0.17, TAU * float(leaf_index) / 6.0, 0)
			leaf.visibility_range_end = 1900.0
			root.add_child(leaf)


func _add_shrub(root: Node3D, position: Vector3, variant: int) -> void:
	var shrub := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.1
	mesh.height = 1.7
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _materials.flower if variant % 3 == 0 else _materials.leaves
	shrub.mesh = mesh
	shrub.position = position + Vector3(0, 0.75, 0)
	shrub.scale = Vector3(1.3, 0.8, 1.0)
	shrub.visibility_range_end = 1400.0
	root.add_child(shrub)


func _add_shrubs_ring(root: Node3D, radius: float, count: int) -> void:
	for index in range(count):
		var angle := TAU * float(index) / float(count) + 0.31
		_add_shrub(root, Vector3(cos(angle) * radius, 0, sin(angle) * radius * 0.76), index)


func _build_materials() -> void:
	_materials = {
		"sand_light": _material(Color("d8b58d"), 0.93),
		"sand_shadow": _material(Color("d8b58d"), 0.93),
		"rock": _material(Color("6c5473"), 0.9),
		"rock_warm": _material(Color("9a5f68"), 0.88),
		"limestone": _material(Color("d8b58d"), 0.93),
		"trunk": _material(Color("6f3d48"), 0.92),
		"leaves": _material(Color("20a779"), 0.84),
		"leaves_dark": _material(Color("116553"), 0.9),
		"flower": _material(Color("ef5b9d"), 0.7),
		"water": _material(Color("24cfe3"), 0.34),
	}
	var water := _materials.water as StandardMaterial3D
	water.metallic = 0.18
	water.emission_enabled = true
	water.emission = Color("087d99")
	water.emission_energy_multiplier = 0.6


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
