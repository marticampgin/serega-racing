class_name CarVisualFactory
extends RefCounted

const PROFILES := [
	{
		"id": "iskra", "name": "ИСКРА", "subtitle": "Сбалансированный болид",
		"description": "Предсказуемая машина с быстрым откликом и ровным расходом топлива.",
		"control": 4, "speed": 3, "efficiency": 3,
		"steering_mult": 1.08, "acceleration_mult": 1.0, "fuel_mult": 1.0,
	},
	{
		"id": "molniya", "name": "МОЛНИЯ", "subtitle": "Максимальная скорость",
		"description": "Длинный и широкий болид: разгоняется яростно, но требует точного пилотажа.",
		"control": 2, "speed": 5, "efficiency": 2,
		"steering_mult": 0.82, "acceleration_mult": 1.28, "fuel_mult": 1.22,
	},
	{
		"id": "prizrak", "name": "ПРИЗРАК", "subtitle": "Манёвренность и запас хода",
		"description": "Компактный болид легко меняет направление и экономит топливо на длинной гонке.",
		"control": 5, "speed": 2, "efficiency": 5,
		"steering_mult": 1.26, "acceleration_mult": 0.88, "fuel_mult": 0.72,
	},
]

const COLORS := [
	Color("e9234f"), Color("20c9e8"), Color("d946ef"),
	Color("f5c542"), Color("70e05a"), Color("f1f1eb"),
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
		"molniya":
			_build_molniya(root, body, body_dark, dark, glass, accent, neon)
		"prizrak":
			_build_prizrak(root, body, body_dark, dark, glass, accent, neon)
		_:
			_build_iskra(root, body, body_dark, dark, glass, accent, neon)
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


static func _build_molniya(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	_box(root, Vector3(1.82, 0.34, 4.35), Vector3(0, 0.0, -0.08), body)
	_box(root, Vector3(0.82, 0.3, 1.5), Vector3(0, 0.36, 0.32), glass)
	_box(root, Vector3(0.6, 0.2, 1.85), Vector3(0, 0.14, -2.75), body)
	_box(root, Vector3(3.05, 0.1, 0.72), Vector3(0, -0.02, -2.95), accent)
	_box(root, Vector3(2.72, 0.16, 0.48), Vector3(0, 0.72, 1.95), body_dark)
	for x in [-1.1, 1.1]:
		_box(root, Vector3(0.48, 0.18, 2.3), Vector3(x, 0.04, 0.15), body_dark)
		_box(root, Vector3(0.12, 0.54, 0.12), Vector3(x, 0.47, 1.95), dark)
	_box(root, Vector3(1.45, 0.08, 3.7), Vector3(0, -0.24, -0.1), neon)
	_wheels(root, 1.2, [-1.42, 1.5], Vector3(0.5, 0.64, 0.9), dark)


static func _build_prizrak(root: Node3D, body: Material, body_dark: Material, dark: Material, glass: Material, accent: Material, neon: Material) -> void:
	_box(root, Vector3(1.72, 0.48, 3.25), Vector3(0, 0.06, 0.15), body)
	_box(root, Vector3(1.05, 0.38, 1.28), Vector3(0, 0.48, 0.15), glass)
	_box(root, Vector3(1.18, 0.28, 1.15), Vector3(0, 0.13, -1.95), body)
	_box(root, Vector3(2.15, 0.12, 0.48), Vector3(0, 0.0, -2.12), accent)
	_box(root, Vector3(1.92, 0.18, 0.42), Vector3(0, 0.62, 1.55), body_dark)
	for x in [-0.78, 0.78]:
		_box(root, Vector3(0.22, 0.16, 2.55), Vector3(x, 0.26, -0.05), neon)
	_box(root, Vector3(1.2, 0.08, 2.7), Vector3(0, -0.25, 0.1), neon)
	_wheels(root, 0.98, [-0.95, 1.08], Vector3(0.42, 0.58, 0.72), dark)


static func _wheels(root: Node3D, x: float, z_values: Array, size: Vector3, material: Material) -> void:
	for side in [-1.0, 1.0]:
		for z in z_values:
			_box(root, size, Vector3(side * x, -0.08, float(z)), material)


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
