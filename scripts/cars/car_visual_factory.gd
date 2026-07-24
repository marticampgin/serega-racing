class_name CarVisualFactory
extends RefCounted

const PROFILES := [
	{
		"id": "iskra", "name": "ИСКРА", "subtitle": "Сбалансированное ретро-купе",
		"description": "Предсказуемый дорожный спорткар с быстрым откликом и ровным расходом топлива.",
		"control": 4, "speed": 2, "max_speed_kmh": 500.0, "acceleration": 3, "efficiency": 3, "tolerance": 3,
		"steering_mult": 1.08, "acceleration_mult": 1.0, "fuel_mult": 1.0, "damage_mult": 1.0,
		"collider_size": Vector3(1.95, 1.0, 4.1),
	},
	{
		"id": "molniya", "name": "МОЛНИЯ", "subtitle": "Максимальная скорость",
		"description": "Длинный и широкий суперкар: разгоняется яростно, но требует точного пилотажа.",
		"control": 2, "speed": 5, "max_speed_kmh": 650.0, "acceleration": 5, "efficiency": 2, "tolerance": 2,
		"steering_mult": 0.82, "acceleration_mult": 1.34, "fuel_mult": 1.22, "damage_mult": 1.18,
		"collider_size": Vector3(2.1, 0.95, 4.75),
	},
	{
		"id": "prizrak", "name": "ПРИЗРАК", "subtitle": "Манёвренность и запас хода",
		"description": "Компактное неоновое купе легко меняет направление и экономит топливо на длинной гонке.",
		"control": 5, "speed": 1, "max_speed_kmh": 450.0, "acceleration": 2, "efficiency": 5, "tolerance": 3,
		"steering_mult": 1.26, "acceleration_mult": 0.88, "fuel_mult": 0.72, "damage_mult": 0.92,
		"collider_size": Vector3(1.9, 1.1, 3.85),
	},
	{
		"id": "titan", "name": "ТИТАН", "subtitle": "Прочность и стабильность",
		"description": "Усиленный широкий гран-турер сохраняет темп после контакта со стенами и препятствиями.",
		"control": 3, "speed": 3, "max_speed_kmh": 550.0, "acceleration": 3, "efficiency": 2, "tolerance": 5,
		"steering_mult": 0.96, "acceleration_mult": 1.05, "fuel_mult": 1.18, "damage_mult": 0.42,
		"collider_size": Vector3(2.15, 1.1, 4.4),
	},
	{
		"id": "strela", "name": "СТРЕЛА", "subtitle": "Аэродинамический спринтер",
		"description": "Острый нос, цепкая реакция и быстрый разгон для смелых скоростных траекторий.",
		"control": 4, "speed": 4, "max_speed_kmh": 600.0, "acceleration": 4, "efficiency": 3, "tolerance": 2,
		"steering_mult": 1.14, "acceleration_mult": 1.2, "fuel_mult": 1.05, "damage_mult": 1.15,
		"collider_size": Vector3(2.0, 0.95, 4.65),
	},
	{
		"id": "lilpoc", "name": "CADILLAC", "subtitle": "Секретный городской внедорожник",
		"description": "Тяжёлый SUV с огромной решёткой, вертикальной оптикой и почти запредельными характеристиками.",
		"control": 5, "speed": 5, "max_speed_kmh": 800.0, "acceleration": 5, "efficiency": 5, "tolerance": 5,
		"steering_mult": 1.25, "acceleration_mult": 1.42, "fuel_mult": 0.65, "damage_mult": 0.3,
		"collider_size": Vector3(2.3, 1.1, 5.15), "locked": true,
	},
]

const COLORS := [
	Color("e9234f"), Color("20c9e8"), Color("d946ef"),
	Color("f5c542"), Color("70e05a"), Color("f1f1eb"), Color("11131a"),
]


static func profile(profile_id: String) -> Dictionary:
	for value in PROFILES:
		if str(value.id) == profile_id:
			return value
	return PROFILES[0]


static func build(parent: Node3D, profile_id: String, body_color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "CarVisual"
	parent.add_child(root)
	var body := _material(body_color, 0.62, 0.2)
	var body_dark := _material(body_color.darkened(0.48), 0.45, 0.25)
	var dark := _material(Color("0b0d18"), 0.3, 0.24)
	var glass := _material(Color("211b45"), 0.55, 0.12)
	var accent := _material(Color("ffe45f"), 0.22, 0.3)
	var neon := _material(body_color.lightened(0.28), 0.2, 0.25, true)
	match profile_id:
		"molniya": _build_molniya(root, body, body_dark, dark, glass, accent, neon)
		"prizrak": _build_prizrak(root, body, body_dark, dark, glass, accent, neon)
		"titan": _build_titan(root, body, body_dark, dark, glass, accent, neon)
		"strela": _build_strela(root, body, body_dark, dark, glass, accent, neon)
		"lilpoc": _build_lilpoc(root, body, body_dark, dark, glass, accent, neon)
		_: _build_iskra(root, body, body_dark, dark, glass, accent, neon)
	if profile_id == "lilpoc":
		root.position.y = -0.05
	else:
		# The player origin rides 0.55 m above the analytical road surface. Lower
		# the sports-car art so the tyre bottoms, rather than the chassis origin,
		# actually meet the pavement during gameplay.
		root.position.y = -0.3
	return root


static func _build_iskra(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	# Balanced 1980s wedge coupe with a full cabin and road-car proportions.
	_tapered_box(root, Vector3(1.98, 0.42, 4.14), Vector3(1.76, 0.42, 3.78), Vector3(0, 0.28, 0), Vector3(0, 0, 0.12), body)
	var hood := _box(root, Vector3(1.8, 0.14, 1.55), Vector3(0, 0.54, -1.38), body_dark)
	hood.rotation.x = 0.04
	_box(root, Vector3(1.52, 0.12, 1.28), Vector3(0, 0.91, 0.27), body_dark)
	var windshield := _box(root, Vector3(1.5, 0.42, 0.08), Vector3(0, 0.72, -0.46), glass)
	windshield.rotation.x = -0.58
	for x in [-0.77, 0.77]:
		_box(root, Vector3(0.055, 0.34, 0.69), Vector3(x, 0.73, 0.26), glass)
		_box(root, Vector3(0.08, 0.11, 2.7), Vector3(x * 1.22, 0.2, 0.05), neon)
	var rear_glass := _box(root, Vector3(1.51, 0.36, 0.08), Vector3(0, 0.72, 0.9), glass)
	rear_glass.rotation.x = 0.48
	_box(root, Vector3(1.94, 0.16, 0.2), Vector3(0, 0.16, -2.11), dark)
	_box(root, Vector3(1.75, 0.11, 0.08), Vector3(0, 0.4, 2.09), neon)
	_road_wheels(root, 1.0, [-1.3, 1.32], 0.38, 0.36, dark)
	var cyan := _material(Color("36e7f2"), 0.25, 0.24, true)
	for x in [-0.57, 0.57]: _box(root, Vector3(0.46, 0.11, 0.08), Vector3(x, 0.4, -2.12), cyan)
	for x in [-0.2, 0.2]: _box(root, Vector3(0.08, 0.04, 2.9), Vector3(x, 0.62, -0.38), cyan)
	# Pop-up lamp pods and rear-window louvers make Iskra unmistakably eighties.
	for x in [-0.58, 0.58]:
		var pod := _box(root, Vector3(0.42, 0.12, 0.34), Vector3(x, 0.66, -1.66), body_dark)
		pod.rotation.x = -0.08
	for louver in 4:
		var slat := _box(root, Vector3(1.42, 0.045, 0.09), Vector3(0, 0.78 - louver * 0.07, 0.78 + louver * 0.14), dark)
		slat.rotation.x = 0.42


static func _build_molniya(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	# Wide mid-engine supercar: low canopy, side intakes and supported rear wing.
	_tapered_box(root, Vector3(2.2, 0.36, 4.66), Vector3(1.9, 0.36, 4.15), Vector3(0, 0.25, -0.02), Vector3(0, 0, 0.12), body)
	var hood := _box(root, Vector3(1.96, 0.12, 1.68), Vector3(0, 0.47, -1.56), body_dark)
	hood.rotation.x = 0.06
	_box(root, Vector3(1.4, 0.11, 1.35), Vector3(0, 0.82, 0.06), body_dark)
	var windshield := _box(root, Vector3(1.42, 0.38, 0.08), Vector3(0, 0.64, -0.58), glass)
	windshield.rotation.x = -0.64
	for x in [-0.76, 0.76]:
		_box(root, Vector3(0.055, 0.31, 0.66), Vector3(x * 0.94, 0.66, 0.08), glass)
		_box(root, Vector3(0.22, 0.3, 0.72), Vector3(x * 1.32, 0.42, 0.54), dark)
		_box(root, Vector3(0.1, 0.37, 0.1), Vector3(x * 0.92, 0.63, 1.8), dark)
	var rear_glass := _box(root, Vector3(1.42, 0.31, 0.08), Vector3(0, 0.64, 0.75), glass)
	rear_glass.rotation.x = 0.55
	_box(root, Vector3(2.34, 0.11, 0.34), Vector3(0, 0.85, 1.82), body_dark)
	_box(root, Vector3(2.12, 0.14, 0.18), Vector3(0, 0.14, -2.35), dark)
	_road_wheels(root, 1.1, [-1.43, 1.4], 0.4, 0.38, dark)
	var electric := _material(Color("58f3ff"), 0.18, 0.2, true)
	for x in [-0.78, 0.78]: _box(root, Vector3(0.12, 0.1, 2.8), Vector3(x, 0.18, -0.05), electric)
	for x in [-0.65, 0.65]: _box(root, Vector3(0.52, 0.1, 0.08), Vector3(x, 0.37, -2.36), accent)
	_box(root, Vector3(1.86, 0.1, 0.08), Vector3(0, 0.36, 2.3), electric)
	# Twin exhausts and dorsal spine reinforce Molniya's high-speed identity.
	for x in [-0.42, 0.42]:
		var exhaust := MeshInstance3D.new()
		var exhaust_mesh := CylinderMesh.new()
		exhaust_mesh.top_radius = 0.11
		exhaust_mesh.bottom_radius = 0.11
		exhaust_mesh.height = 0.24
		exhaust_mesh.radial_segments = 12
		exhaust_mesh.material = dark
		exhaust.mesh = exhaust_mesh
		exhaust.position = Vector3(x, 0.22, 2.4)
		exhaust.rotation.x = PI * 0.5
		root.add_child(exhaust)
	_box(root, Vector3(0.09, 0.07, 2.25), Vector3(0, 0.52, -0.62), electric)


static func _build_prizrak(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	# Compact squared-off synthwave coupe inspired by small 1980s rally cars.
	_tapered_box(root, Vector3(1.9, 0.44, 3.76), Vector3(1.7, 0.44, 3.48), Vector3(0, 0.3, 0.02), Vector3(0, 0, 0.06), body)
	var hood := _box(root, Vector3(1.72, 0.14, 1.2), Vector3(0, 0.56, -1.22), body_dark)
	hood.rotation.x = 0.04
	_box(root, Vector3(1.58, 0.12, 1.34), Vector3(0, 0.96, 0.3), body_dark)
	var windshield := _box(root, Vector3(1.57, 0.43, 0.08), Vector3(0, 0.75, -0.42), glass)
	windshield.rotation.x = -0.42
	for x in [-0.84, 0.84]:
		_box(root, Vector3(0.055, 0.37, 0.72), Vector3(x * 0.94, 0.78, 0.28), glass)
		_box(root, Vector3(0.09, 0.1, 2.42), Vector3(x * 1.09, 0.22, 0.1), neon)
	var rear_glass := _box(root, Vector3(1.59, 0.38, 0.08), Vector3(0, 0.77, 0.98), glass)
	rear_glass.rotation.x = 0.38
	_box(root, Vector3(1.9, 0.14, 0.2), Vector3(0, 0.17, -1.91), dark)
	_road_wheels(root, 0.97, [-1.1, 1.15], 0.37, 0.34, dark)
	var violet := _material(Color("d879ff"), 0.2, 0.18, true)
	for x in [-0.58, 0.58]: _box(root, Vector3(0.48, 0.12, 0.08), Vector3(x, 0.42, -1.92), violet)
	_box(root, Vector3(1.75, 0.11, 0.08), Vector3(0, 0.46, 1.9), violet)
	_box(root, Vector3(1.45, 0.07, 2.9), Vector3(0, 0.07, 0.0), neon)
	# Flush dark nose and a short hatch spoiler give the compact Prizrak a
	# stealthier silhouette instead of another long-hood coupe.
	_box(root, Vector3(1.64, 0.18, 0.42), Vector3(0, 0.38, -1.75), dark)
	_box(root, Vector3(1.84, 0.08, 0.28), Vector3(0, 0.63, 1.72), body_dark)


static func _build_titan(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	# Heavy grand tourer: broad shoulders, long hood and muscular wheel blocks.
	_tapered_box(root, Vector3(2.22, 0.54, 4.38), Vector3(2.08, 0.54, 4.08), Vector3(0, 0.34, 0), Vector3(0, 0, 0.04), body)
	var hood := _box(root, Vector3(2.04, 0.17, 1.6), Vector3(0, 0.64, -1.34), body_dark)
	hood.rotation.x = 0.035
	_box(root, Vector3(1.66, 0.13, 1.42), Vector3(0, 1.02, 0.42), body_dark)
	var windshield := _box(root, Vector3(1.65, 0.44, 0.08), Vector3(0, 0.82, -0.31), glass)
	windshield.rotation.x = -0.48
	for x in [-0.88, 0.88]:
		_box(root, Vector3(0.055, 0.36, 0.74), Vector3(x * 0.95, 0.84, 0.42), glass)
		for z in [-1.38, 1.35]: _box(root, Vector3(0.2, 0.17, 0.92), Vector3(x * 1.2, 0.36, z), body_dark)
	var rear_glass := _box(root, Vector3(1.68, 0.37, 0.08), Vector3(0, 0.83, 1.1), glass)
	rear_glass.rotation.x = 0.4
	_box(root, Vector3(2.12, 0.2, 0.2), Vector3(0, 0.22, -2.22), dark)
	_road_wheels(root, 1.11, [-1.35, 1.36], 0.43, 0.4, dark)
	var bronze := _material(Color("ff9a4f"), 0.52, 0.27)
	for x in [-0.63, 0.0, 0.63]: _box(root, Vector3(0.42, 0.11, 0.08), Vector3(x, 0.44, -2.23), bronze)
	for x in [-0.72, 0.72]: _box(root, Vector3(0.16, 0.06, 2.75), Vector3(x, 0.65, -0.25), bronze)
	_box(root, Vector3(1.9, 0.11, 0.08), Vector3(0, 0.46, 2.19), neon)
	# Reinforced hood scoop and shoulder rails visually explain Titan's extra
	# durability without making it SUV-tall.
	_tapered_box(root, Vector3(0.76, 0.2, 0.92), Vector3(0.52, 0.2, 0.7), Vector3(0, 0.76, -1.05), Vector3.ZERO, dark)
	for x in [-0.92, 0.92]: _box(root, Vector3(0.13, 0.1, 3.0), Vector3(x, 0.64, 0.05), bronze)


static func _build_strela(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	# Long-nose exotic road car with an arrow-like hood and fastback glass.
	_tapered_box(root, Vector3(2.04, 0.35, 4.74), Vector3(1.68, 0.35, 4.02), Vector3(0, 0.25, -0.05), Vector3(0, 0, 0.24), body)
	var hood := _box(root, Vector3(1.82, 0.12, 1.82), Vector3(0, 0.49, -1.43), body_dark)
	hood.rotation.x = 0.07
	_box(root, Vector3(1.42, 0.1, 1.22), Vector3(0, 0.82, 0.4), body_dark)
	var windshield := _box(root, Vector3(1.42, 0.37, 0.08), Vector3(0, 0.64, -0.23), glass)
	windshield.rotation.x = -0.66
	for x in [-0.76, 0.76]:
		_box(root, Vector3(0.055, 0.29, 0.62), Vector3(x * 0.92, 0.65, 0.39), glass)
		_box(root, Vector3(0.09, 0.08, 2.95), Vector3(x * 1.22, 0.17, -0.05), neon)
	var rear_glass := _box(root, Vector3(1.42, 0.3, 0.08), Vector3(0, 0.64, 0.97), glass)
	rear_glass.rotation.x = 0.59
	_box(root, Vector3(2.02, 0.13, 0.18), Vector3(0, 0.14, -2.43), dark)
	_road_wheels(root, 1.03, [-1.43, 1.38], 0.39, 0.36, dark)
	var white := _material(Color("f4f6ff"), 0.18, 0.3)
	_box(root, Vector3(0.16, 0.04, 3.4), Vector3(0, 0.56, -0.48), white)
	for x in [-0.58, 0.58]: _box(root, Vector3(0.48, 0.1, 0.08), Vector3(x, 0.39, -2.44), accent)
	_box(root, Vector3(1.8, 0.1, 0.08), Vector3(0, 0.39, 2.33), neon)
	# Arrowhead nose rails converge visually toward the front point.
	for x in [-0.46, 0.46]:
		var rail := _box(root, Vector3(0.08, 0.055, 2.05), Vector3(x, 0.57, -1.1), white)
		rail.rotation.y = (-0.08 if x < 0.0 else 0.08)


static func _build_lilpoc(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	# Long-wheelbase luxury SUV: high beltline, long roof, sloped windshield,
	# broad mesh grille and vertical running lights match the supplied reference.
	_box(root, Vector3(2.2, 0.72, 4.95), Vector3(0, 0.34, 0.05), body)
	# The passenger compartment and rear quarter are one continuous full-width
	# volume: no old-fashioned step or narrow cabin ledge along the sides/back.
	_box(root, Vector3(2.18, 0.9, 3.32), Vector3(0, 1.13, 0.55), body_dark)
	_box(root, Vector3(2.18, 0.13, 3.48), Vector3(0, 1.63, 0.53), body)
	var windshield := _box(root, Vector3(2.04, 0.82, 0.1), Vector3(0, 1.25, -1.08), glass)
	windshield.rotation.x = -0.25
	for x in [-1.075, 1.075]:
		# Two large door windows per side, separated by a visible B-pillar.
		_box(root, Vector3(0.06, 0.64, 1.04), Vector3(x, 1.28, -0.42), glass)
		_box(root, Vector3(0.06, 0.64, 1.12), Vector3(x, 1.28, 0.72), glass)
		_box(root, Vector3(0.075, 0.72, 0.12), Vector3(x * 1.002, 1.28, 0.14), dark)
		_box(root, Vector3(0.1, 0.1, 0.42), Vector3(x * 1.08, 1.02, -0.78), body)
	_box(root, Vector3(2.08, 0.53, 1.28), Vector3(0, 0.78, -2.2), body)
	# Cowl panel bridges the hood to the windshield instead of leaving a slot.
	_box(root, Vector3(2.08, 0.28, 0.62), Vector3(0, 0.84, -1.36), body)
	_box(root, Vector3(1.72, 0.72, 0.12), Vector3(0, 0.76, -2.87), dark)
	# Abstract crest and the signature vertical front lights.
	_box(root, Vector3(0.24, 0.17, 0.06), Vector3(0, 0.8, -2.95), accent)
	_box(root, Vector3(0.11, 0.12, 0.04), Vector3(-0.06, 0.8, -2.99), _material(Color("d62954"), 0.4, 0.25))
	_box(root, Vector3(0.11, 0.12, 0.04), Vector3(0.06, 0.8, -2.99), _material(Color("31c9e8"), 0.4, 0.25))
	for x in [-0.93, 0.93]:
		_box(root, Vector3(0.13, 0.9, 0.16), Vector3(x, 0.78, -2.91), neon)
		_box(root, Vector3(0.2, 0.16, 0.19), Vector3(x, 1.22, -2.9), accent)
	_box(root, Vector3(2.38, 0.16, 0.36), Vector3(0, 0.08, -2.72), dark)
	_box(root, Vector3(2.42, 0.1, 3.6), Vector3(0, -0.05, 0.1), neon)
	_box(root, Vector3(0.14, 0.16, 3.35), Vector3(-1.17, 0.28, 0.08), dark)
	_box(root, Vector3(0.14, 0.16, 3.35), Vector3(1.17, 0.28, 0.08), dark)
	# Full-height tailgate, rear glass and vertical lamps close the same slab-sided
	# silhouette seen in the side reference.
	_box(root, Vector3(2.16, 1.16, 0.16), Vector3(0, 1.02, 2.43), body_dark)
	_box(root, Vector3(1.9, 0.78, 0.07), Vector3(0, 1.24, 2.53), glass)
	var tail_material := _material(Color("ff345c"), 0.18, 0.2, true)
	for x in [-1.0, 1.0]: _box(root, Vector3(0.12, 1.02, 0.1), Vector3(x, 1.04, 2.53), tail_material)
	_box(root, Vector3(2.25, 0.18, 0.32), Vector3(0, 0.12, 2.55), dark)
	_cylinder_wheels(root, 1.15, [-1.62, 1.55], 0.5, 0.36, dark)


static func _road_wheels(root: Node3D, x: float, z_values: Array, radius: float, width: float, material: Material) -> void:
	for side in [-1.0, 1.0]:
		for z_value in z_values:
			_round_wheel(root, Vector3(side * x, 0.15, float(z_value)), radius, width, material)


static func _wheels(root: Node3D, x: float, z_values: Array, size: Vector3, material: Material) -> void:
	for side in [-1.0, 1.0]:
		for z in z_values:
			_round_wheel(root, Vector3(side * x, -0.08, float(z)), size.y * 0.55, size.x, material)


static func _cylinder_wheels(root: Node3D, x: float, z_values: Array, radius: float, width: float, material: Material) -> void:
	for side in [-1.0, 1.0]:
		for z in z_values:
			_round_wheel(root, Vector3(side * x, -0.03, float(z)), radius, width, material)


static func _round_wheel(root: Node3D, position: Vector3, radius: float, width: float, tire: Material) -> void:
	var wheel := MeshInstance3D.new()
	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = radius
	tire_mesh.bottom_radius = radius
	tire_mesh.height = width
	tire_mesh.radial_segments = 20
	tire_mesh.rings = 2
	tire_mesh.material = tire
	wheel.mesh = tire_mesh
	wheel.position = position
	wheel.rotation.z = PI * 0.5
	root.add_child(wheel)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = radius * 0.46
	hub_mesh.bottom_radius = radius * 0.46
	hub_mesh.height = width + 0.025
	hub_mesh.radial_segments = 12
	hub_mesh.material = _material(Color("b9c2d1"), 0.8, 0.18)
	hub.mesh = hub_mesh
	hub.position = position
	hub.rotation.z = PI * 0.5
	root.add_child(hub)


static func _box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	return instance


static func _tapered_box(parent: Node3D, bottom_size: Vector3, top_size: Vector3, position: Vector3, top_offset: Vector3, material: Material) -> MeshInstance3D:
	var bottom := bottom_size * 0.5
	var top := top_size * 0.5
	var vertices := PackedVector3Array([
		Vector3(-bottom.x, -bottom.y, -bottom.z), Vector3(bottom.x, -bottom.y, -bottom.z),
		Vector3(bottom.x, -bottom.y, bottom.z), Vector3(-bottom.x, -bottom.y, bottom.z),
		Vector3(-top.x, top.y, -top.z) + top_offset, Vector3(top.x, top.y, -top.z) + top_offset,
		Vector3(top.x, top.y, top.z) + top_offset, Vector3(-top.x, top.y, top.z) + top_offset,
	])
	var triangles := PackedInt32Array([
		0, 2, 1, 0, 3, 2,
		4, 5, 6, 4, 6, 7,
		0, 1, 5, 0, 5, 4,
		1, 2, 6, 1, 6, 5,
		2, 3, 7, 2, 7, 6,
		3, 0, 4, 3, 4, 7,
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for vertex_index in triangles:
		surface.set_uv(Vector2(vertices[vertex_index].x, vertices[vertex_index].z))
		surface.add_vertex(vertices[vertex_index])
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.position = position
	parent.add_child(instance)
	return instance


static func _material(color: Color, metallic: float, roughness: float, emission := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.4
	return material
