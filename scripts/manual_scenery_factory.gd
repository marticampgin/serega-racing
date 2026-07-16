class_name ManualSceneryFactory
extends RefCounted

## Builds the checked-in PackedScene catalog. These primitives intentionally
## mirror WorldBuilder's low-poly synthwave language without coupling editor
## presets to the runtime course generator.

var _m: Dictionary = {}


func populate(root: Node3D, archetype: String, variant: int, texture: Texture2D = null) -> void:
	_build_materials()
	match archetype:
		"villa": _villa(root, variant > 0)
		"nightclub": _generic_building(root, 24, 15, 10, _m.night, _m.pink, 4, 2, true)
		"tower": _generic_building(root, 17, 16, 36, _m.lavender, _m.cyan, 3, 7, false)
		"storefront_row": _storefront_row(root)
		"city_block": _city_block(root)
		"beach_bar": _beach_bar(root)
		"grand_hotel": _grand_hotel(root)
		"theatre": _theatre(root)
		"twin_towers": _twin_towers(root)
		"market_hall": _generic_building(root, 38, 19, 12, _m.cream, _m.coral, 5, 2, true)
		"arena": _arena(root)
		"marina_hotel": _generic_building(root, 30, 17, 30, _m.mint, _m.pink, 5, 6, false)
		"diner": _generic_building(root, 22, 14, 7, _m.coral, _m.cyan, 3, 1, true)
		"motel": _motel(root, variant > 0)
		"marina_office": _generic_building(root, 23, 15, 9, _m.mint, _m.white, 3, 2, true)
		"bungalow": _villa(root, false)
		"midrise": _generic_building(root, 21, 16, 23, _m.coral, _m.cyan, 4, 5, false)
		"apartment": _generic_building(root, 24, 17, 21, _m.cream, _m.mint, 4, 4, false)
		"party_hotel": _generic_building(root, 30, 18, 26, _m.lavender, _m.pink, 5, 5, false)
		"city_complex": _city_complex(root)
		"market_arcade": _storefront_row(root)
		"sport_hall": _generic_building(root, 36, 24, 16, _m.white, _m.cyan, 5, 2, true)
		"lighthouse": _lighthouse(root)
		"monument": _monument(root)
		"sport_complex": _sport_complex(root)
		"sport_facility": _sport_facility(root)
		"drive_in": _drive_in(root)
		"pavilion": _pavilion(root)
		"skate_park": _skate_park(root)
		"party_club": _party_club(root)
		"promenade": _promenade(root)
		"party_patio": _party_patio(root)
		"marina_docks": _marina_docks(root)
		"palm": _palm(root, [0.78, 1.25, 1.05][variant])
		"bush": _bush(root)
		"flowering_bush": _flowering_bush(root, variant)
		"hedge": _hedge(root, variant)
		"planter": _planter(root, variant)
		"agave": _agave(root)
		"tropical_plant": _tropical_plant(root, variant)
		"flower_bed": _flower_bed(root)
		"trellis": _trellis(root)
		"lamp": _lamp(root)
		"floodlight": _floodlight(root)
		"fence": _fence(root)
		"trail": _box(root, Vector3(4.0, 0.16, 13.0), Vector3(0, 0.08, 0), _m.wood, 1500, false)
		"bench": _bench(root)
		"umbrella": _umbrella(root)
		"cabana": _cabana(root)
		"fence_variant": _fence_variant(root, variant)
		"traffic_cone": _traffic_cone(root)
		"barricade": _barricade(root)
		"bollard": _bollard(root)
		"lamp_variant": _lamp_variant(root, variant)
		"bin": _bin(root, variant)
		"hydrant": _hydrant(root)
		"bike_rack": _bike_rack(root)
		"bus_stop": _bus_stop(root)
		"phone_booth": _phone_booth(root)
		"vending": _vending(root)
		"newspaper": _newspaper(root)
		"picnic": _picnic(root)
		"fountain": _drinking_fountain(root)
		"wayfinding": _wayfinding(root)
		"surface_piece": _surface_piece(root, variant)
		"waterfront_prop": _waterfront_prop(root, variant)
		"billboard": _billboard(root, texture)
		"wall_poster": _wall_poster(root, texture)
		"motorboat": _motorboat(root)
		"sailboat": _sailboat(root)
		"yacht": _yacht(root, variant > 0)
		"ferry": _ferry(root)
		"fishing_boat": _fishing_boat(root)
		"zeppelin": _zeppelin(root, texture)
		"banner_plane": _banner_plane(root, texture)
		"air_banner": _air_banner(root, texture, Vector3.ZERO, 10.0)
		_:
			_box(root, Vector3.ONE * 2.0, Vector3.UP, _m.pink)


func _build_materials() -> void:
	if not _m.is_empty():
		return
	_m = {
		"sand": _material(Color("c77d68"), 0.0, 0.93), "rock": _material(Color("59476f")),
		"asphalt": _material(Color("242832")), "cream": _material(Color("f2d8b5")),
		"coral": _material(Color("ff8066")), "mint": _material(Color("4ed7bd")),
		"lavender": _material(Color("9b78cf")), "night": _material(Color("34204f")),
		"glass": _material(Color("123a68"), 0.35, 0.16), "steel": _material(Color("273044"), 0.55, 0.3),
		"wood": _material(Color("825137")), "green": _material(Color("087f65")),
		"leaf": _material(Color("20a779")), "leaf_dark": _material(Color("116553")), "white": _material(Color("f7f0dd")),
		"field": _material(Color("2b9b64")), "court": _material(Color("cf5b76")),
		"cyan": _emissive(Color("35e0dd"), 1.35), "pink": _emissive(Color("ff3fcf"), 1.4),
		"orange": _emissive(Color("ff9c42"), 1.25), "yellow": _emissive(Color("ffe45e"), 1.2),
	}


func _material(color: Color, metallic := 0.0, roughness := 0.78) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.1, 0.32)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _box(parent: Node, size: Vector3, position: Vector3, material: Material, visibility := 1800.0, shadow := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.visibility_range_end = visibility
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow and size.y > 0.35 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _cylinder(parent: Node, radius: float, height: float, position: Vector3, material: Material, top_radius := -1.0, visibility := 1800.0, segments := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0 else top_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.visibility_range_end = visibility
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if height > 0.4 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _capsule(parent: Node, radius: float, height: float, position: Vector3, material: Material, visibility := 2600.0) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.visibility_range_end = visibility
	parent.add_child(instance)
	return instance


func _generic_building(root: Node3D, width: float, depth: float, height: float, body: Material, accent: Material, columns: int, levels: int, awning: bool) -> void:
	_box(root, Vector3(width + 2, 1.0, depth + 2), Vector3(0, -0.25, 0), _m.rock)
	_box(root, Vector3(width, height, depth), Vector3(0, height * 0.5, 0), body)
	_box(root, Vector3(width + 0.8, 0.55, depth + 0.8), Vector3(0, height + 0.28, 0), accent)
	for level in range(levels):
		var y := (level + 0.55) * height / levels
		for column in range(columns):
			var x := lerpf(-width * 0.38, width * 0.38, 0.5 if columns == 1 else float(column) / (columns - 1))
			_box(root, Vector3(maxf(1.2, width / columns * 0.5), maxf(1.2, height / levels * 0.48), 0.22), Vector3(x, y, -depth * 0.505), _m.glass)
	if awning:
		_box(root, Vector3(width * 0.75, 0.45, 2.4), Vector3(0, height * 0.62, -depth * 0.58), accent)


func _villa(root: Node3D, large: bool) -> void:
	var width := 25.0 if large else 17.0
	var height := 16.0 if large else 7.0
	_generic_building(root, width, 14.0, height, _m.cream, _m.mint if large else _m.coral, 4, 3 if large else 1, true)
	_box(root, Vector3(10, 0.18, 5), Vector3(width * 0.35, 0.1, -11), _m.cyan, 1600, false)
	_box(root, Vector3(4, 0.18, 11), Vector3(-width * 0.25, 0.1, -12), _m.wood, 1600, false)


func _storefront_row(root: Node3D) -> void:
	for index in range(4):
		var x := (index - 1.5) * 8.2
		var body: Material = [_m.cream, _m.coral, _m.mint, _m.lavender][index]
		_box(root, Vector3(7.5, 8 + index % 2 * 2, 12), Vector3(x, 4 + index % 2, 0), body)
		_box(root, Vector3(5.7, 3.3, 0.2), Vector3(x, 2.8, -6.08), _m.glass)
		_box(root, Vector3(7.2, 0.4, 1.7), Vector3(x, 6.1, -6.7), _m.pink if index % 2 == 0 else _m.cyan)


func _city_block(root: Node3D) -> void:
	_generic_building(root, 28, 20, 18, _m.night, _m.pink, 5, 4, true)
	_generic_building(root, 13, 14, 29, _m.lavender, _m.cyan, 3, 6, false)
	root.get_child(root.get_child_count() - 1).position.x += 9.0


func _beach_bar(root: Node3D) -> void:
	_generic_building(root, 17, 10, 6, _m.mint, _m.pink, 3, 1, true)
	_box(root, Vector3(24, 0.2, 8), Vector3(0, 0.1, -8), _m.wood, 1600, false)
	for x in [-7.0, 0.0, 7.0]:
		_umbrella_at(root, Vector3(x, 0, -8))


func _grand_hotel(root: Node3D) -> void:
	_generic_building(root, 34, 18, 7, _m.night, _m.cyan, 5, 1, true)
	for side in [-1.0, 1.0]:
		_generic_building(root, 12, 12, 24 if side < 0 else 29, _m.cream if side < 0 else _m.mint, _m.white, 2, 5, false)
		var wing := root.get_child(root.get_child_count() - 1) as Node3D
		wing.position.x += side * 9.0


func _theatre(root: Node3D) -> void:
	_generic_building(root, 36, 18, 13, _m.night, _m.pink, 5, 2, true)
	for side in [-1.0, 1.0]:
		_box(root, Vector3(4, 22, 8), Vector3(side * 13, 11, 1), _m.lavender)
		_box(root, Vector3(1, 16, 0.3), Vector3(side * 13, 11, -3.2), _m.cyan)


func _twin_towers(root: Node3D) -> void:
	_box(root, Vector3(40, 7, 20), Vector3(0, 3.5, 0), _m.night)
	for side in [-1.0, 1.0]:
		var height := 48.0 if side < 0 else 58.0
		_generic_building(root, 14, 14, height, _m.cream if side < 0 else _m.lavender, _m.cyan if side < 0 else _m.pink, 3, 9, false)
		for child in root.get_children().slice(root.get_child_count() - (3 * 9 + 3)):
			if child is Node3D:
				(child as Node3D).position.x += side * 11.0


func _arena(root: Node3D) -> void:
	var foundation := _cylinder(root, 23, 1.2, Vector3(0, 0.1, 0), _m.rock, 20, 2300, 24)
	foundation.scale.z = 0.82
	var body := _cylinder(root, 22, 13, Vector3(0, 7, 0), _m.white, 18, 2300, 24)
	body.scale.z = 0.82
	var crown := _cylinder(root, 18, 3, Vector3(0, 15, 0), _m.night, 14, 2300, 24)
	crown.scale.z = 0.82
	_box(root, Vector3(25, 1, 2), Vector3(0, 10, -19), _m.cyan, 2300)


func _motel(root: Node3D, extended: bool) -> void:
	var width := 34.0 if extended else 28.0
	_generic_building(root, width, 15, 11, _m.cream, _m.mint, 5, 2, false)
	for y in [3.3, 8.4]:
		_box(root, Vector3(width + 1, 0.35, 2.1), Vector3(0, y, -8.1), _m.coral)


func _city_complex(root: Node3D) -> void:
	for side in [-1.0, 1.0]:
		var height := 29.0 if side < 0 else 38.0
		var start := root.get_child_count()
		_generic_building(root, 16, 16, height, _m.lavender if side < 0 else _m.cream, _m.pink if side < 0 else _m.cyan, 3, 6, false)
		for index in range(start, root.get_child_count()):
			(root.get_child(index) as Node3D).position.x += side * 10.0
	_box(root, Vector3(14, 4, 5), Vector3(0, 15, 0), _m.glass)


func _lighthouse(root: Node3D) -> void:
	_cylinder(root, 5.5, 1.0, Vector3.UP * 0.5, _m.rock, 5.5, 2200, 16)
	_cylinder(root, 3.2, 25, Vector3.UP * 13, _m.cream, 2.2, 2400, 16)
	_cylinder(root, 4.2, 1.2, Vector3.UP * 26, _m.night, 4.2, 2400, 16)
	_cylinder(root, 3.2, 3.2, Vector3.UP * 28, _m.glass, 3.2, 2400, 16)
	_cylinder(root, 4.0, 0.7, Vector3.UP * 30, _m.pink, 0.8, 2400, 16)


func _monument(root: Node3D) -> void:
	_cylinder(root, 8.5, 0.45, Vector3.UP * 0.23, _m.white, 8.5, 1900, 18)
	_cylinder(root, 4.5, 1, Vector3.UP * 0.75, _m.night, 4.5, 1900, 16)
	_cylinder(root, 1.5, 14, Vector3.UP * 7.8, _m.lavender, 0.45, 2000, 10)
	_cylinder(root, 2.6, 0.8, Vector3.UP * 15.2, _m.pink, 0.6, 2000, 12)


func _sport_complex(root: Node3D) -> void:
	var stadium := _cylinder(root, 31, 8, Vector3.UP * 4, _m.white, 25, 2200, 22)
	stadium.scale.x = 1.4
	_box(root, Vector3(54, 0.3, 24), Vector3(0, 8.2, 0), _m.field, 2200, false)
	for side in [-1.0, 1.0]:
		for level in range(3):
			_box(root, Vector3(47 - level * 5, 1.2, 4), Vector3(0, 8.8 + level, side * (16 + level * 2)), _m.night)


func _sport_facility(root: Node3D) -> void:
	for x in [-12.0, 12.0]:
		_box(root, Vector3(20, 0.25, 11), Vector3(x, 0.13, 0), _m.court, 1800, false)
		_box(root, Vector3(0.2, 1.8, 10), Vector3(x, 1.2, 0), _m.white)
	for x in [-18.0, 18.0]:
		_floodlight_at(root, Vector3(x, 0, 8))


func _drive_in(root: Node3D) -> void:
	_box(root, Vector3(30, 0.2, 24), Vector3(0, 0.1, 0), _m.asphalt, 1800, false)
	_box(root, Vector3(24, 12, 0.8), Vector3(0, 7, 7.5), _m.night)
	_box(root, Vector3(21.5, 9.5, 0.25), Vector3(0, 7, 7), _m.lavender)
	for x in [-9.0, -3.0, 3.0, 9.0]:
		_box(root, Vector3(3.4, 1, 2), Vector3(x, 0.6, -5), _m.coral if int(x) % 2 else _m.mint)


func _pavilion(root: Node3D) -> void:
	_cylinder(root, 11, 0.7, Vector3.UP * 0.35, _m.rock, 11, 1900, 18)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		_cylinder(root, 0.45, 9, Vector3(cos(angle) * 8, 4.5, sin(angle) * 8), _m.white, 0.45, 1900, 8)
	var roof := _cylinder(root, 12, 3, Vector3.UP * 10.1, _m.coral, 0.8, 2100, 18)
	roof.scale.z = 0.82


func _skate_park(root: Node3D) -> void:
	_box(root, Vector3(34, 0.25, 24), Vector3(0, 0.13, 0), _m.asphalt, 1800, false)
	for side in [-1.0, 1.0]:
		var bowl := _cylinder(root, 7, 1.2, Vector3(side * 9, 0.6, 0), _m.lavender, 5.2, 1800, 16)
		bowl.scale.z = 0.75
	_box(root, Vector3(9, 1.8, 6), Vector3(0, 0.9, -7), _m.coral)
	_box(root, Vector3(11, 4.5, 0.5), Vector3(0, 6, 10), _m.night)


func _party_club(root: Node3D) -> void:
	_generic_building(root, 30, 19, 10, _m.night, _m.pink, 4, 2, true)
	_cylinder(root, 2.2, 27, Vector3(0, 24.5, 2), _m.night, 1.5, 2600, 12)
	_cylinder(root, 5.8, 1.4, Vector3(0, 38.2, 2), _m.pink, 5.8, 2600, 16)
	_cylinder(root, 3.4, 3.8, Vector3(0, 40.5, 2), _m.glass, 3.4, 2600, 16)


func _promenade(root: Node3D) -> void:
	_box(root, Vector3(30, 0.22, 8), Vector3(0, 0.11, 0), _m.wood, 1700, false)
	for x in [-10.0, 0.0, 10.0]:
		_bench_at(root, Vector3(x, 0, 0))


func _party_patio(root: Node3D) -> void:
	_box(root, Vector3(26, 0.25, 18), Vector3(0, 0.13, 0), _m.night, 1800, false)
	for x in [-8.0, 0.0, 8.0]:
		_umbrella_at(root, Vector3(x, 0, 0))
	_box(root, Vector3(24, 0.4, 0.4), Vector3(0, 6, 8), _m.pink)


func _marina_docks(root: Node3D) -> void:
	_box(root, Vector3(5, 0.35, 34), Vector3(0, 0, 0), _m.wood, 2200, false)
	for side in [-1.0, 1.0]:
		for z in [-10.0, 0.0, 10.0]:
			_box(root, Vector3(8, 0.28, 2.5), Vector3(side * 6, 0, z), _m.wood, 2200, false)
			_cylinder(root, 0.2, 3, Vector3(side * 10, 1, z), _m.steel, 0.2, 2200, 8)


func _palm(root: Node3D, scale_factor: float) -> void:
	var height := 8.0 * scale_factor
	_cylinder(root, 0.35 * scale_factor, height, Vector3.UP * height * 0.5, _m.wood, 0.2 * scale_factor, 1700, 9)
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var material: Material = _m.leaf if index % 2 == 0 else _m.leaf_dark
		var frond := _box(root, Vector3(0.42, 0.14, 5.2) * scale_factor, Vector3.UP * height, material, 1900, true)
		frond.rotation = Vector3(-0.17, angle, 0.0)


func _bush(root: Node3D) -> void:
	_cylinder(root, 1.5, 1.5, Vector3.UP * 0.75, _m.green, 1.1, 1400, 10)
	_cylinder(root, 1.0, 1.2, Vector3(1.1, 0.6, 0.2), _m.leaf, 0.7, 1400, 10)


func _flowering_bush(root: Node3D, variant: int) -> void:
	_bush(root)
	var flower: Material = _m.pink if variant == 0 else _m.cyan
	for point in [Vector3(-1.0, 1.35, 0.2), Vector3(0.0, 1.55, -0.5), Vector3(1.0, 1.2, 0.4), Vector3(0.5, 1.45, 0.8)]:
		_cylinder(root, 0.18, 0.22, point, flower, 0.18, 1600, 8)


func _hedge(root: Node3D, variant: int) -> void:
	var length := 12.0 if variant > 0 else 6.0
	_box(root, Vector3(length, 1.55, 1.5), Vector3.UP * 0.78, _m.green)
	for x in range(-int(length * 0.5) + 1, int(length * 0.5), 2):
		_cylinder(root, 0.65, 1.7, Vector3(x, 0.85, 0), _m.leaf, 0.65, 1600, 8)


func _planter(root: Node3D, variant: int) -> void:
	if variant == 0:
		_box(root, Vector3(5.0, 0.7, 1.8), Vector3.UP * 0.35, _m.cream)
		_box(root, Vector3(4.5, 0.35, 1.4), Vector3.UP * 0.72, _m.rock)
		for x in [-1.5, 0.0, 1.5]:
			_cylinder(root, 0.45, 1.2, Vector3(x, 1.25, 0), _m.leaf, 0.25, 1500, 8)
	else:
		_cylinder(root, 1.6, 0.8, Vector3.UP * 0.4, _m.coral, 1.8)
		_cylinder(root, 1.25, 0.35, Vector3.UP * 0.85, _m.rock, 1.25)
		_agave_at(root, Vector3.UP * 0.9, 0.75)


func _agave(root: Node3D) -> void:
	_agave_at(root, Vector3.ZERO, 1.0)


func _agave_at(root: Node3D, at: Vector3, scale_factor: float) -> void:
	for index in range(9):
		var angle := TAU * index / 9.0
		var leaf := _box(root, Vector3(0.25, 0.16, 2.5) * scale_factor, at + Vector3(cos(angle), 0.65, sin(angle)) * 0.65 * scale_factor, _m.leaf, 1600, false)
		leaf.rotation.y = -angle
		leaf.rotation.x = -0.38


func _tropical_plant(root: Node3D, variant: int) -> void:
	var count := 9 if variant == 0 else 13
	var height := 2.8 if variant == 0 else 1.55
	for index in range(count):
		var angle := TAU * index / count
		var blade := _box(root, Vector3(0.16, height, 0.38), Vector3(cos(angle), height * 0.5, sin(angle)) * (0.55 + (index % 3) * 0.15), _m.leaf, 1500, false)
		blade.rotation.z = 0.18 * sin(angle)
	if variant == 0:
		for angle in [0.0, 2.1, 4.2]:
			_cylinder(root, 0.22, 0.65, Vector3(cos(angle) * 0.65, 2.75, sin(angle) * 0.65), _m.orange, 0.08, 1500, 8)


func _flower_bed(root: Node3D) -> void:
	_box(root, Vector3(7.0, 0.25, 3.0), Vector3.UP * 0.13, _m.rock, 1500, false)
	for x in [-2.5, -1.25, 0.0, 1.25, 2.5]:
		for z in [-0.75, 0.75]:
			_cylinder(root, 0.22, 0.55, Vector3(x, 0.55, z), _m.pink if int(x * 4 + z * 2) % 2 == 0 else _m.cyan, 0.12, 1500, 8)


func _trellis(root: Node3D) -> void:
	for x in [-4.0, 0.0, 4.0]:
		_box(root, Vector3(0.2, 4.0, 0.2), Vector3(x, 2.0, 0), _m.white)
	for y in [0.7, 1.8, 2.9, 3.9]:
		_box(root, Vector3(8.2, 0.14, 0.14), Vector3(0, y, 0), _m.white, 1600, false)
	for x in [-3.2, -1.6, 0.0, 1.6, 3.2]:
		_cylinder(root, 0.45, 0.5, Vector3(x, 1.2 + fmod(abs(x), 1.5), 0), _m.pink, 0.45, 1600, 8)


func _lamp(root: Node3D) -> void:
	_box(root, Vector3(0.2, 6, 0.2), Vector3(0, 3, 0), _m.steel)
	_box(root, Vector3(2.2, 0.2, 0.2), Vector3(-1, 5.8, 0), _m.steel)
	_box(root, Vector3(0.7, 0.4, 0.5), Vector3(-2, 5.6, 0), _m.pink)


func _floodlight(root: Node3D) -> void:
	_floodlight_at(root, Vector3.ZERO)


func _floodlight_at(root: Node3D, at: Vector3) -> void:
	_box(root, Vector3(0.3, 15, 0.3), at + Vector3.UP * 7.5, _m.steel)
	_box(root, Vector3(5, 1, 0.5), at + Vector3.UP * 15, _m.yellow)


func _fence(root: Node3D) -> void:
	for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		_box(root, Vector3(0.18, 2, 0.18), Vector3(x, 1, 0), _m.steel)
	for y in [0.55, 1.45]:
		_box(root, Vector3(12.2, 0.14, 0.14), Vector3(0, y, 0), _m.cyan, 1500, false)


func _fence_variant(root: Node3D, variant: int) -> void:
	if variant == 3:
		_box(root, Vector3(10.0, 1.2, 0.6), Vector3.UP * 0.6, _m.coral)
		_box(root, Vector3(10.3, 0.18, 0.8), Vector3.UP * 1.25, _m.white, 1500, false)
		return
	var post_material: Material = _m.white if variant == 0 else _m.steel
	for x in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		_box(root, Vector3(0.18, 1.8 if variant != 2 else 2.5, 0.18), Vector3(x, 0.9 if variant != 2 else 1.25, 0), post_material)
	if variant == 0:
		for x in range(-5, 6):
			_box(root, Vector3(0.12, 1.35, 0.12), Vector3(x, 0.7, 0), _m.white, 1500, false)
		for y in [0.45, 1.15]: _box(root, Vector3(10.2, 0.12, 0.12), Vector3(0, y, 0), _m.white, 1500, false)
	elif variant == 1:
		for y in [0.45, 1.25]: _box(root, Vector3(10.2, 0.16, 0.16), Vector3(0, y, 0), _m.cyan, 1500, false)
	else:
		for y in [0.45, 0.9, 1.35, 1.8, 2.25]: _box(root, Vector3(10.0, 0.06, 0.06), Vector3(0, y, 0), _m.steel, 1500, false)


func _traffic_cone(root: Node3D) -> void:
	_cylinder(root, 0.42, 0.9, Vector3.UP * 0.45, _m.orange, 0.08, 1400, 10)
	_box(root, Vector3(1.0, 0.12, 1.0), Vector3.UP * 0.06, _m.night, 1400, false)
	_cylinder(root, 0.3, 0.12, Vector3.UP * 0.55, _m.white, 0.22, 1400, 10)


func _barricade(root: Node3D) -> void:
	for x in [-2.1, 2.1]:
		_box(root, Vector3(0.25, 1.4, 0.25), Vector3(x, 0.7, 0), _m.steel)
		_box(root, Vector3(1.1, 0.18, 0.7), Vector3(x, 0.1, 0), _m.night, 1400, false)
	_box(root, Vector3(4.8, 0.75, 0.24), Vector3(0, 1.15, 0), _m.coral)
	for x in [-1.4, 0.0, 1.4]: _box(root, Vector3(0.45, 0.82, 0.28), Vector3(x, 1.15, -0.02), _m.white, 1400, false)


func _bollard(root: Node3D) -> void:
	_cylinder(root, 0.32, 1.05, Vector3.UP * 0.53, _m.night, 0.32, 1400, 10)
	_cylinder(root, 0.38, 0.16, Vector3.UP * 1.02, _m.pink, 0.38, 1400, 10)


func _lamp_variant(root: Node3D, variant: int) -> void:
	var height := 6.5 if variant == 0 else 4.0
	_box(root, Vector3(0.18, height, 0.18), Vector3.UP * height * 0.5, _m.steel)
	if variant == 0:
		_box(root, Vector3(4.2, 0.18, 0.18), Vector3(0, height - 0.25, 0), _m.steel)
		for x in [-2.0, 2.0]: _box(root, Vector3(0.65, 0.4, 0.5), Vector3(x, height - 0.45, 0), _m.cyan)
	else:
		_cylinder(root, 0.55, 0.8, Vector3.UP * (height - 0.2), _m.pink, 0.3, 1600, 10)


func _bin(root: Node3D, variant: int) -> void:
	var color: Material = _m.cyan if variant > 0 else _m.night
	_box(root, Vector3(0.9, 1.15, 0.9), Vector3.UP * 0.58, color)
	_box(root, Vector3(1.0, 0.15, 1.0), Vector3.UP * 1.18, _m.pink if variant > 0 else _m.steel, 1400, false)


func _hydrant(root: Node3D) -> void:
	_cylinder(root, 0.34, 0.9, Vector3.UP * 0.45, _m.coral, 0.34, 1400, 10)
	_cylinder(root, 0.48, 0.22, Vector3.UP * 0.9, _m.coral, 0.3, 1400, 10)
	_box(root, Vector3(1.1, 0.28, 0.28), Vector3(0, 0.55, 0), _m.coral)


func _bike_rack(root: Node3D) -> void:
	for x in [-1.5, -0.5, 0.5, 1.5]:
		_cylinder(root, 0.07, 2.2, Vector3(x, 0.6, 0), _m.steel, 0.07, 1400, 8).rotation_degrees.z = 90
	_box(root, Vector3(4.0, 0.12, 0.12), Vector3(0, 0.15, 0), _m.steel, 1400, false)


func _bus_stop(root: Node3D) -> void:
	_box(root, Vector3(8.0, 0.25, 2.8), Vector3(0, 3.3, 0), _m.cyan)
	for x in [-3.7, 3.7]: _box(root, Vector3(0.2, 3.2, 0.2), Vector3(x, 1.6, 0), _m.steel)
	_box(root, Vector3(7.4, 2.8, 0.16), Vector3(0, 1.55, 1.25), _m.glass)
	_bench_at(root, Vector3(0, 0, 0.4))


func _phone_booth(root: Node3D) -> void:
	_box(root, Vector3(2.2, 2.9, 2.0), Vector3.UP * 1.45, _m.pink)
	_box(root, Vector3(1.6, 2.2, 0.12), Vector3(0, 1.35, -1.02), _m.glass)
	_box(root, Vector3(1.6, 0.4, 0.16), Vector3(0, 2.55, -1.05), _m.cyan)


func _vending(root: Node3D) -> void:
	_box(root, Vector3(1.7, 2.25, 1.0), Vector3.UP * 1.13, _m.coral)
	_box(root, Vector3(1.2, 1.15, 0.12), Vector3(0, 1.35, -0.52), _m.glass)
	_box(root, Vector3(0.45, 0.45, 0.14), Vector3(0.45, 0.45, -0.54), _m.cyan)


func _newspaper(root: Node3D) -> void:
	_box(root, Vector3(0.9, 0.9, 0.7), Vector3.UP * 0.65, _m.cyan)
	_box(root, Vector3(0.75, 0.45, 0.08), Vector3(0, 0.75, -0.37), _m.white)
	_box(root, Vector3(0.3, 0.4, 0.3), Vector3.UP * 0.2, _m.steel)


func _picnic(root: Node3D) -> void:
	_box(root, Vector3(4.5, 0.25, 2.0), Vector3.UP * 1.1, _m.wood)
	for z in [-1.7, 1.7]: _box(root, Vector3(4.8, 0.22, 0.7), Vector3(0, 0.65, z), _m.wood)
	for x in [-1.7, 1.7]: _box(root, Vector3(0.25, 1.1, 0.25), Vector3(x, 0.55, 0), _m.steel)


func _drinking_fountain(root: Node3D) -> void:
	_box(root, Vector3(0.8, 1.0, 0.7), Vector3.UP * 0.5, _m.steel)
	_cylinder(root, 0.45, 0.18, Vector3.UP * 1.05, _m.cyan, 0.45, 1400, 10)
	_cylinder(root, 0.08, 0.25, Vector3(0.2, 1.28, 0), _m.white, 0.08, 1400, 8)


func _wayfinding(root: Node3D) -> void:
	_box(root, Vector3(0.18, 3.2, 0.18), Vector3.UP * 1.6, _m.steel)
	for data in [[2.2, 2.7, 0.35], [-2.0, 2.1, -0.35]]:
		var sign := _box(root, Vector3(2.5, 0.55, 0.18), Vector3(float(data[0]) * 0.45, float(data[1]), 0), _m.pink if float(data[0]) > 0 else _m.cyan)
		sign.rotation.z = float(data[2])


func _surface_piece(root: Node3D, variant: int) -> void:
	var y := 0.06
	match variant:
		0: _box(root, Vector3(8.0, 0.12, 16.0), Vector3.UP * y, _m.asphalt, 1800, false)
		1:
			_box(root, Vector3(8.0, 0.12, 12.0), Vector3(0, y, 2.0), _m.asphalt, 1800, false)
			_box(root, Vector3(12.0, 0.12, 8.0), Vector3(2.0, y, -2.0), _m.asphalt, 1800, false)
		2: _box(root, Vector3(3.0, 0.16, 12.0), Vector3.UP * 0.08, _m.white, 1800, false)
		3:
			_box(root, Vector3(3.0, 0.16, 9.0), Vector3(0, 0.08, 1.5), _m.white, 1800, false)
			_box(root, Vector3(9.0, 0.16, 3.0), Vector3(1.5, 0.08, -1.5), _m.white, 1800, false)
		4: _box(root, Vector3(6.0, 0.14, 9.0), Vector3.UP * 0.07, _m.asphalt, 1800, false)
		5:
			_box(root, Vector3(12.0, 0.14, 7.0), Vector3.UP * 0.07, _m.asphalt, 1800, false)
			for x in [-4.0, 0.0, 4.0]: _box(root, Vector3(0.12, 0.05, 6.0), Vector3(x, 0.15, 0), _m.white, 1800, false)
		6:
			for z in [-3.5, -2.3, -1.1, 0.1, 1.3, 2.5, 3.7]: _box(root, Vector3(7.0, 0.08, 0.65), Vector3(0, 0.04, z), _m.white, 1800, false)
		7:
			for z in range(-5, 6): _box(root, Vector3(5.0, 0.18, 0.82), Vector3(0, 0.09, z), _m.wood, 1800, false)
		8: _box(root, Vector3(9.0, 0.12, 9.0), Vector3.UP * 0.06, _m.lavender, 1800, false)
		9:
			for index in range(7): _cylinder(root, 0.85, 0.16, Vector3(sin(index * 1.7) * 0.9, 0.08, (index - 3) * 1.5), _m.rock, 0.85, 1800, 10)


func _waterfront_prop(root: Node3D, variant: int) -> void:
	match variant:
		0: _box(root, Vector3(4.0, 0.3, 12.0), Vector3.UP * 0.15, _m.wood, 2000, false)
		1:
			_box(root, Vector3(4.0, 0.3, 10.0), Vector3(0, 0.15, 2.0), _m.wood, 2000, false)
			_box(root, Vector3(10.0, 0.3, 4.0), Vector3(2.0, 0.15, -2.0), _m.wood, 2000, false)
		2: _cylinder(root, 0.42, 0.9, Vector3.UP * 0.45, _m.night, 0.34, 1600, 10)
		3, 4:
			_cylinder(root, 0.65, 1.2, Vector3.UP * 0.6, _m.coral if variant == 3 else _m.cyan, 0.42, 2000, 10)
			_box(root, Vector3(0.15, 1.1, 0.15), Vector3.UP * 1.65, _m.steel)
		5:
			_box(root, Vector3(0.16, 2.2, 0.16), Vector3.UP * 1.1, _m.steel)
			_cylinder(root, 0.7, 0.22, Vector3(0, 1.7, 0), _m.coral, 0.7, 1600, 12).rotation_degrees.x = 90
		6:
			_box(root, Vector3(0.18, 2.7, 0.18), Vector3.UP * 1.35, _m.steel)
			_box(root, Vector3(1.4, 0.18, 0.18), Vector3(0.6, 2.55, 0), _m.steel)
		7:
			for x in [-1.5, -0.5, 0.5, 1.5]:
				var board := _box(root, Vector3(0.35, 2.0, 0.75), Vector3(x, 1.0, 0), _m.coral if int(x * 2) % 2 == 0 else _m.cyan)
				board.rotation.z = 0.08 * x
			_box(root, Vector3(4.5, 0.18, 0.18), Vector3(0, 0.5, 0), _m.wood)
		8:
			var seat := _box(root, Vector3(1.8, 0.18, 3.2), Vector3(0, 0.55, 0), _m.coral)
			seat.rotation.x = -0.22
			_box(root, Vector3(2.0, 0.18, 1.4), Vector3(0, 0.2, 1.9), _m.white)
		9:
			for x in [-1.0, 1.0]: _box(root, Vector3(0.2, 3.5, 0.2), Vector3(x, 1.75, 0), _m.white)
			_box(root, Vector3(2.5, 0.35, 2.0), Vector3(0, 3.0, 0), _m.coral)
			_box(root, Vector3(2.8, 0.4, 2.4), Vector3(0, 4.0, 0), _m.cyan)


func _bench(root: Node3D) -> void:
	_bench_at(root, Vector3.ZERO)


func _bench_at(root: Node3D, at: Vector3) -> void:
	_box(root, Vector3(4, 0.35, 1.3), at + Vector3(0, 1.1, 0), _m.wood)
	_box(root, Vector3(4, 1.2, 0.3), at + Vector3(0, 1.8, 0.5), _m.wood)
	for x in [-1.5, 1.5]:
		_box(root, Vector3(0.25, 1.1, 0.25), at + Vector3(x, 0.55, 0), _m.steel)


func _umbrella(root: Node3D) -> void:
	_umbrella_at(root, Vector3.ZERO)


func _umbrella_at(root: Node3D, at: Vector3) -> void:
	_cylinder(root, 0.12, 2.6, at + Vector3.UP * 1.3, _m.steel, 0.12, 1500, 8)
	_cylinder(root, 2.3, 0.5, at + Vector3.UP * 2.8, _m.coral, 0.18, 1500, 12)
	_cylinder(root, 1.2, 0.2, at + Vector3.UP * 0.8, _m.white, 1.2, 1500, 12)


func _cabana(root: Node3D) -> void:
	_box(root, Vector3(11, 0.25, 8), Vector3(0, 0.13, 0), _m.wood, 1700, false)
	for x in [-4.5, 4.5]:
		_box(root, Vector3(0.3, 4.2, 0.3), Vector3(x, 2.1, 0), _m.steel)
	_box(root, Vector3(11.5, 0.5, 8.5), Vector3(0, 4.3, 0), _m.coral)
	_box(root, Vector3(7, 1, 2.2), Vector3(0, 0.65, 1.8), _m.white)


func _billboard(root: Node3D, texture: Texture2D) -> void:
	var size := _poster_size(texture, 6.3)
	var y := 1.2 + size.y * 0.5
	_box(root, Vector3(size.x + 0.7, size.y + 0.7, 0.35), Vector3(0, y, 0), _m.night)
	_box(root, Vector3(size.x + 1.1, 0.32, 0.58), Vector3(0, y + size.y * 0.5 + 0.42, 0), _m.pink)
	for x in [-size.x * 0.38, size.x * 0.38]:
		_box(root, Vector3(0.24, 1.4, 0.24), Vector3(x, 0.7, 0.08), _m.steel)
	_add_double_sided_art(root, texture, Vector3(0, y, 0), size.y, 0.34)


func _wall_poster(root: Node3D, texture: Texture2D) -> void:
	var size := _poster_size(texture, 5.0)
	_box(root, Vector3(size.x + 0.65, size.y + 0.65, 0.24), Vector3(0, size.y * 0.5, 0), _m.night)
	_add_double_sided_art(root, texture, Vector3(0, size.y * 0.5, 0), size.y, 0.28)


func _poster_size(texture: Texture2D, height: float) -> Vector2:
	if texture == null or texture.get_height() <= 0:
		return Vector2(height * 1.3, height)
	return Vector2(height * texture.get_width() / float(texture.get_height()), height)


func _sprite(root: Node3D, texture: Texture2D, position: Vector3, height: float, label: String) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = label
	sprite.texture = texture
	sprite.pixel_size = height / maxf(1.0, float(texture.get_height()) if texture != null else 512.0)
	sprite.position = position
	sprite.double_sided = true
	sprite.visibility_range_end = 2800
	root.add_child(sprite)
	return sprite


func _add_double_sided_art(root: Node3D, texture: Texture2D, center: Vector3, height: float, offset: float) -> void:
	for side in [-1.0, 1.0]:
		var sprite := _sprite(root, texture, center + Vector3(0, 0, side * offset), height, "PosterFace%s" % ("Front" if side < 0 else "Back"))
		sprite.rotation.y = 0.0 if side < 0 else PI


func _motorboat(root: Node3D) -> void:
	_box(root, Vector3(3.5, 0.8, 8.5), Vector3.ZERO, _m.coral, 2200)
	_box(root, Vector3(2.4, 1.5, 3.2), Vector3(0, 0.9, 0.7), _m.white, 2200)
	_box(root, Vector3(1.8, 0.9, 0.2), Vector3(0, 1.1, -0.92), _m.glass, 2200)


func _sailboat(root: Node3D) -> void:
	_box(root, Vector3(4.4, 1.1, 13), Vector3(0, -0.15, 0), _m.white, 2400)
	_box(root, Vector3(2.8, 1.2, 5), Vector3(0, 0.8, 1.2), _m.cream, 2400)
	_cylinder(root, 0.16, 14, Vector3(0, 7, 0.6), _m.steel, 0.16, 2400, 8)
	var sail := _box(root, Vector3(0.18, 10, 6.8), Vector3(0.18, 8.2, -2.8), _m.coral, 2500)
	sail.rotation.x = -0.14


func _yacht(root: Node3D, party: bool) -> void:
	_box(root, Vector3(6.5, 1.4, 20), Vector3(0, -0.2, 0), _m.coral if party else _m.white, 2600)
	_box(root, Vector3(5.2, 2.5, 10), Vector3(0, 1.55, 1.2), _m.white, 2600)
	_box(root, Vector3(4.4, 1.5, 6), Vector3(0, 3.45, 2.3), _m.glass, 2600)
	_box(root, Vector3(6.2, 0.25, 12), Vector3(0, 4.35, 0.2), _m.pink if party else _m.cyan, 2700, false)


func _ferry(root: Node3D) -> void:
	_box(root, Vector3(11, 2, 34), Vector3(0, -0.25, 0), _m.night, 2900)
	_box(root, Vector3(9.5, 4.5, 23), Vector3(0, 2.3, 1.5), _m.white, 2900)
	_box(root, Vector3(8.5, 3, 13), Vector3(0, 6, 3), _m.cream, 2900)
	for side in [-1.0, 1.0]:
		for z in [-7.0, 0.0, 7.0]:
			_box(root, Vector3(0.18, 1.2, 4.5), Vector3(side * 4.84, 3, z), _m.glass, 2900)
	_cylinder(root, 1, 5, Vector3(0, 9.6, 5), _m.coral, 0.8, 2900, 12)


func _fishing_boat(root: Node3D) -> void:
	_box(root, Vector3(5.4, 1.3, 15), Vector3(0, -0.15, 0), _m.mint, 2400)
	_box(root, Vector3(4, 3.2, 5.5), Vector3(0, 1.8, 2.2), _m.cream, 2400)
	_box(root, Vector3(3.4, 1.2, 0.2), Vector3(0, 2.2, -0.58), _m.glass, 2400)
	_cylinder(root, 0.13, 7, Vector3(0, 5.2, 2), _m.steel, 0.13, 2400, 8)


func _zeppelin(root: Node3D, texture: Texture2D) -> void:
	var hull := _capsule(root, 6.5, 30, Vector3.ZERO, _m.lavender, 3200)
	hull.rotation.z = PI * 0.5
	_box(root, Vector3(10, 3, 4), Vector3(0, -7, 0), _m.night, 3200)
	for z in [-1.0, 1.0]:
		var fin := _box(root, Vector3(5, 0.4, 6), Vector3(-14, 0, z * 2.7), _m.pink, 3200)
		fin.rotation.x = z * 0.12
	_air_banner(root, texture, Vector3(-30, -7, 0), 11)


func _banner_plane(root: Node3D, texture: Texture2D) -> void:
	var fuselage := _capsule(root, 1.35, 13, Vector3.ZERO, _m.white, 2900)
	fuselage.rotation.z = PI * 0.5
	_box(root, Vector3(4, 0.35, 17), Vector3.ZERO, _m.coral, 2900)
	_box(root, Vector3(3.2, 0.3, 7), Vector3(-5.2, 1.1, 0), _m.pink, 2900)
	_box(root, Vector3(3, 1.8, 2.2), Vector3(1.8, 1.2, 0), _m.glass, 2900)
	_air_banner(root, texture, Vector3(-27, -3, 0), 10)


func _air_banner(root: Node3D, texture: Texture2D, center: Vector3, height: float) -> void:
	var size := _poster_size(texture, height)
	_box(root, Vector3(size.x + 4, height + 0.8, 0.25), center, _m.pink, 3000, false)
	for side in [-1.0, 1.0]:
		var sprite := _sprite(root, texture, center + Vector3(0, 0, side * 0.38), height, "PosterFace_%s" % ("Front" if side < 0 else "Back"))
		sprite.rotation.y = 0 if side < 0 else PI
