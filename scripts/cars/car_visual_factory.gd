class_name CarVisualFactory
extends RefCounted

const PROFILES := [
	{
		"id": "iskra", "name": "ИСКРА", "subtitle": "Сбалансированный болид",
		"description": "Предсказуемая машина с быстрым откликом и ровным расходом топлива.",
		"control": 4, "speed": 2, "max_speed_kmh": 500.0, "acceleration": 3, "efficiency": 3, "tolerance": 3,
		"steering_mult": 1.08, "acceleration_mult": 1.0, "fuel_mult": 1.0, "damage_mult": 1.0,
		"collider_size": Vector3(1.8, 0.7, 4.1),
	},
	{
		"id": "molniya", "name": "МОЛНИЯ", "subtitle": "Максимальная скорость",
		"description": "Длинный и широкий болид: разгоняется яростно, но требует точного пилотажа.",
		"control": 2, "speed": 5, "max_speed_kmh": 650.0, "acceleration": 5, "efficiency": 2, "tolerance": 2,
		"steering_mult": 0.82, "acceleration_mult": 1.34, "fuel_mult": 1.22, "damage_mult": 1.18,
		"collider_size": Vector3(2.05, 0.7, 4.75),
	},
	{
		"id": "prizrak", "name": "ПРИЗРАК", "subtitle": "Манёвренность и запас хода",
		"description": "Компактный болид легко меняет направление и экономит топливо на длинной гонке.",
		"control": 5, "speed": 1, "max_speed_kmh": 450.0, "acceleration": 2, "efficiency": 5, "tolerance": 3,
		"steering_mult": 1.26, "acceleration_mult": 0.88, "fuel_mult": 0.72, "damage_mult": 0.92,
		"collider_size": Vector3(1.8, 0.8, 3.85),
	},
	{
		"id": "titan", "name": "ТИТАН", "subtitle": "Прочность и стабильность",
		"description": "Усиленный широкий болид сохраняет темп после контакта со стенами и препятствиями.",
		"control": 3, "speed": 3, "max_speed_kmh": 550.0, "acceleration": 3, "efficiency": 2, "tolerance": 5,
		"steering_mult": 0.96, "acceleration_mult": 1.05, "fuel_mult": 1.18, "damage_mult": 0.42,
		"collider_size": Vector3(2.1, 0.85, 4.4),
	},
	{
		"id": "strela", "name": "СТРЕЛА", "subtitle": "Аэродинамический спринтер",
		"description": "Острый нос, цепкая реакция и быстрый разгон для смелых скоростных траекторий.",
		"control": 4, "speed": 4, "max_speed_kmh": 600.0, "acceleration": 4, "efficiency": 3, "tolerance": 2,
		"steering_mult": 1.14, "acceleration_mult": 1.2, "fuel_mult": 1.05, "damage_mult": 1.15,
		"collider_size": Vector3(1.95, 0.7, 4.65),
	},
	{
		"id": "lilpoc", "name": "CADILLAC", "subtitle": "Секретный городской внедорожник",
		"description": "Тяжёлый чёрный SUV с огромной решёткой, вертикальной оптикой и почти запредельными характеристиками.",
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
	return root


static func _build_iskra(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	_box(root, Vector3(1.55, 0.38, 3.65), Vector3(0, 0.02, 0.05), body)
	_box(root, Vector3(0.72, 0.35, 1.72), Vector3(0, 0.38, 0.05), glass)
	_box(root, Vector3(0.48, 0.24, 1.35), Vector3(0, 0.18, -2.05), body)
	_box(root, Vector3(2.65, 0.11, 0.55), Vector3(0, 0.0, -2.38), accent)
	_box(root, Vector3(2.28, 0.48, 0.18), Vector3(0, 0.55, 1.65), dark)
	_box(root, Vector3(1.15, 0.09, 3.0), Vector3(0, -0.22, 0.1), neon)
	_wheels(root, 1.03, [-1.12, 1.18], Vector3(0.45, 0.62, 0.82), dark)
	_box(root, Vector3(0.1, 0.06, 2.9), Vector3(-0.38, 0.24, 0.1), body_dark)
	_box(root, Vector3(0.1, 0.06, 2.9), Vector3(0.38, 0.24, 0.1), body_dark)
	# Twin racing stripes and cyan nose markers give Iskra a classic team livery.
	var cyan := _material(Color("36e7f2"), 0.25, 0.24, true)
	for x in [-0.2, 0.2]: _box(root, Vector3(0.11, 0.045, 3.25), Vector3(x, 0.245, -0.18), cyan)
	for x in [-1.08, 1.08]: _box(root, Vector3(0.24, 0.16, 0.38), Vector3(x, 0.12, -2.35), cyan)


static func _build_molniya(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	_box(root, Vector3(1.82, 0.34, 4.35), Vector3(0, 0.0, -0.08), body)
	_box(root, Vector3(0.82, 0.3, 1.5), Vector3(0, 0.29, 0.32), glass)
	_box(root, Vector3(0.6, 0.2, 1.85), Vector3(0, 0.14, -2.75), body)
	_box(root, Vector3(3.05, 0.1, 0.72), Vector3(0, -0.02, -2.95), accent)
	_box(root, Vector3(2.72, 0.16, 0.48), Vector3(0, 0.72, 1.95), body_dark)
	for x in [-1.1, 1.1]:
		_box(root, Vector3(0.48, 0.18, 2.3), Vector3(x, 0.04, 0.15), body_dark)
		_box(root, Vector3(0.12, 0.54, 0.12), Vector3(x, 0.47, 1.95), dark)
	_box(root, Vector3(1.45, 0.08, 3.7), Vector3(0, -0.24, -0.1), neon)
	_wheels(root, 1.2, [-1.42, 1.5], Vector3(0.5, 0.64, 0.9), dark)
	# Offset lightning blades and a bright roll-hoop distinguish the speed car.
	var electric := _material(Color("58f3ff"), 0.18, 0.2, true)
	for x in [-0.48, 0.48]:
		var slash := _box(root, Vector3(0.12, 0.06, 1.55), Vector3(x, 0.22, -0.55), electric)
		slash.rotation.y = 0.28 * signf(x)
	_box(root, Vector3(0.48, 0.18, 0.18), Vector3(0, 0.72, 0.9), electric)


static func _build_prizrak(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	_box(root, Vector3(1.72, 0.48, 3.25), Vector3(0, 0.06, 0.15), body)
	_box(root, Vector3(1.05, 0.38, 1.28), Vector3(0, 0.48, 0.15), glass)
	_box(root, Vector3(1.18, 0.28, 1.15), Vector3(0, 0.13, -1.95), body)
	_box(root, Vector3(2.15, 0.12, 0.48), Vector3(0, 0.0, -2.12), accent)
	_box(root, Vector3(1.92, 0.18, 0.42), Vector3(0, 0.62, 1.55), body_dark)
	for x in [-0.78, 0.78]: _box(root, Vector3(0.22, 0.16, 2.55), Vector3(x, 0.26, -0.05), neon)
	_box(root, Vector3(1.2, 0.08, 2.7), Vector3(0, -0.25, 0.1), neon)
	_wheels(root, 0.98, [-0.95, 1.08], Vector3(0.42, 0.58, 0.72), dark)
	# Purple luminous spine and rear fins reinforce the compact ghost theme.
	var violet := _material(Color("d879ff"), 0.2, 0.18, true)
	_box(root, Vector3(0.18, 0.055, 2.65), Vector3(0, 0.34, -0.12), violet)
	for x in [-0.72, 0.72]:
		var fin := _box(root, Vector3(0.12, 0.42, 0.62), Vector3(x, 0.48, 1.18), violet)
		fin.rotation.z = 0.18 * signf(x)


static func _build_titan(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	_box(root, Vector3(1.95, 0.54, 3.95), Vector3(0, 0.08, 0.02), body)
	_box(root, Vector3(1.1, 0.48, 1.5), Vector3(0, 0.53, 0.12), glass)
	_box(root, Vector3(1.0, 0.34, 1.45), Vector3(0, 0.2, -2.35), body_dark)
	_box(root, Vector3(2.95, 0.18, 0.62), Vector3(0, 0.03, -2.58), accent)
	_box(root, Vector3(2.75, 0.2, 0.54), Vector3(0, 0.82, 1.78), body_dark)
	for x in [-1.08, 1.08]:
		_box(root, Vector3(0.44, 0.34, 2.55), Vector3(x, 0.12, 0.02), body_dark)
		_box(root, Vector3(0.15, 0.72, 0.15), Vector3(x, 0.46, 1.78), dark)
	_box(root, Vector3(1.48, 0.1, 3.35), Vector3(0, -0.25, 0.05), neon)
	_wheels(root, 1.22, [-1.24, 1.34], Vector3(0.58, 0.74, 0.92), dark)
	# Bronze armour ribs and intake blocks make Titan visibly heavier.
	var bronze := _material(Color("ff9a4f"), 0.52, 0.27)
	for z in [-1.25, -0.72, 0.92]: _box(root, Vector3(1.35, 0.08, 0.14), Vector3(0, 0.39, z), bronze)
	for x in [-0.76, 0.76]: _box(root, Vector3(0.28, 0.24, 0.68), Vector3(x, 0.38, -1.72), dark)


static func _build_strela(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	_box(root, Vector3(1.62, 0.32, 4.25), Vector3(0, 0.0, -0.12), body)
	_box(root, Vector3(0.66, 0.3, 1.42), Vector3(0, 0.34, 0.22), glass)
	_box(root, Vector3(0.32, 0.2, 2.1), Vector3(0, 0.12, -2.65), body)
	_box(root, Vector3(2.75, 0.08, 0.42), Vector3(0, -0.03, -3.05), accent)
	for x in [-0.86, 0.86]:
		var pod := _box(root, Vector3(0.34, 0.18, 2.65), Vector3(x, 0.02, 0.15), body_dark)
		pod.rotation.y = -0.08 * signf(x)
	_box(root, Vector3(2.35, 0.13, 0.34), Vector3(0, 0.6, 1.9), dark)
	_box(root, Vector3(1.1, 0.07, 3.75), Vector3(0, -0.23, -0.1), neon)
	_wheels(root, 1.08, [-1.36, 1.44], Vector3(0.44, 0.6, 0.78), dark)
	# A white arrow livery and yellow wing tips suit Strela's needle-like nose.
	var white := _material(Color("f4f6ff"), 0.18, 0.3)
	_box(root, Vector3(0.14, 0.05, 3.45), Vector3(0, 0.21, -0.25), white)
	for x in [-1.18, 1.18]: _box(root, Vector3(0.32, 0.11, 0.34), Vector3(x, 0.08, -3.03), accent)


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
