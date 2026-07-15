extends Node3D

const CourseLayoutScript := preload("res://scripts/course_layout.gd")
const WorldBuilderScript := preload("res://scripts/world_builder.gd")
const EDITABLE_WORLD_PATH := "res://scenes/world/editable_world.tscn"
const ROAD_WIDTH := 17.0
const ROAD_SAMPLE_STEP := 2.0

var course: CourseLayout
var course_curve: Curve3D
var course_zones: Array[Dictionary] = []
var world_builder: WorldBuilder
var TRACK_LENGTH := 0.0
var car: CharacterBody3D
var chase_camera: Camera3D
var speed := 0.0
var base_max_speed := 43.0 # Retained for QA/API compatibility; forward speed has no hard cap.
var fuel := 100.0
var elapsed := 0.0
var distance := 0.0
var course_offset := 0.0
var race_active := true
var shield_hits := 1
var collision_cooldown := 0.0
var collision_stop_time := 0.0
var obstacle_slide_time := 0.0
var obstacle_block_normal := Vector3.ZERO
var boost_time := 0.0
var ghost_time := 0.0
var refuel_request: HTTPRequest
var refuel_in_progress := false
var refuel_key_down := false
var debug_refill_key_down := false
var refuel_cooldown := 0.0
var rng := RandomNumberGenerator.new()
var speed_label: Label
var timer_label: Label
var distance_label: Label
var status_label: Label
var fuel_bar: ProgressBar
var finish_portrait: TextureRect
var start_position := Vector3.ZERO
var countdown_label: Label
var countdown_time := 3.2
var go_flash_time := 0.0


func _ready() -> void:
	rng.seed = 8675309
	course = CourseLayoutScript.load_default()
	course_curve = course.course_curve
	course_zones = course.course_zones
	TRACK_LENGTH = course.length()
	build_world()
	build_track()
	build_scenery()
	build_car()
	build_hud()
	build_refuel_client()
	print("Serega Racing: map course initialized (%.1f m, no obstacles)" % TRACK_LENGTH)
	for argument in OS.get_cmdline_user_args():
		var capture_distance := -1.0
		if argument.begins_with("--screenshot-distance="):
			capture_distance = float(argument.trim_prefix("--screenshot-distance="))
		elif argument.begins_with("--screenshot-z="):
			capture_distance = -float(argument.trim_prefix("--screenshot-z="))
		if capture_distance >= 0.0:
			course_offset = fposmod(capture_distance, TRACK_LENGTH)
			var capture_transform := sample_course(course_offset)
			car.global_position = capture_transform.origin + capture_transform.basis.y * 0.55
			car.global_transform.basis = capture_transform.basis
			chase_camera.global_position = car.global_position + capture_transform.basis.z * 10.5 + capture_transform.basis.y * 5.2
			chase_camera.look_at(car.global_position - capture_transform.basis.z * 5.0 + capture_transform.basis.y * 0.55, capture_transform.basis.y)
		if argument.begins_with("--screenshot="):
			capture_qa_screenshot.call_deferred(argument.trim_prefix("--screenshot="))


func capture_qa_screenshot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("QA screenshot: %s (%s)" % [path, error_string(error)])
	get_tree().quit(0 if error == OK else 1)


func sector_window(distance: float, start: float, finish: float, fade: float) -> float:
	return smoothstep(start, start + fade, distance) * (1.0 - smoothstep(finish - fade, finish, distance))


func course_position(offset: float) -> Vector3:
	return course.point_at(offset)


func sample_course(offset: float) -> Transform3D:
	return course.sample_course(offset)


func course_transform(offset: float) -> Transform3D:
	return course.sample_course(offset)


func center_x(z: float) -> float:
	return course.point_at(-z).x


func track_y(z: float) -> float:
	return course.height_at(-z)


func track_bank(z: float) -> float:
	var offset := -z
	var before := course.tangent_at(offset - 8.0)
	var after := course.tangent_at(offset + 8.0)
	return clampf(atan2(before.cross(after).y, before.dot(after)) * 0.55, -0.2, 0.2)


func track_heading(z: float) -> float:
	return course.heading_at(-z)


func track_pitch(z: float) -> float:
	var tangent := course.tangent_at(-z)
	return asin(clampf(tangent.y, -1.0, 1.0))


func make_material(color: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func add_box(parent: Node, size: Vector3, position: Vector3, material: Material, collision := false, rotation_y := 0.0) -> Node3D:
	var root: Node3D
	if collision:
		root = StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		root.add_child(shape)
	else:
		root = Node3D.new()
	root.position = position
	root.rotation.y = rotation_y
	parent.add_child(root)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	root.add_child(mesh_instance)
	return root


func add_cylinder(parent: Node, radius: float, height: float, position: Vector3, material: Material, top_radius := -1.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)
	return instance


func is_water_crossing(z: float) -> bool:
	var d := absf(z)
	return (d > 1250.0 and d < 1650.0) or (d > 3500.0 and d < 3950.0) or (d > 6000.0 and d < 6550.0) or (d > 8800.0 and d < 9250.0)


func add_palm(position: Vector3, scale_factor: float, trunk: Material, leaves: Material, accent: Material, variant := 0) -> void:
	var height := 5.2 * scale_factor
	if variant == 1:
		height *= 1.28
	elif variant == 2:
		height *= 0.78
	var palm := add_cylinder(self, 0.22 * scale_factor, height, position + Vector3.UP * height * 0.5, trunk, 0.13 * scale_factor)
	palm.add_to_group("palm_scenery")
	palm.add_to_group("scenery_variant_%d" % variant)
	var blade_count := 7 if variant == 2 else 5
	for blade in range(blade_count):
		var angle := TAU * float(blade) / float(blade_count)
		var crown := position + Vector3.UP * (height + 0.1)
		var frond_length := 2.9 if variant == 1 else (4.1 if variant == 2 else 3.7)
		var frond := add_box(self, Vector3(0.42, 0.12, frond_length) * scale_factor, crown + Vector3(cos(angle), -0.15, sin(angle)) * 1.25 * scale_factor, leaves)
		frond.rotation.y = -angle
		frond.rotation.x = 0.13
	add_cylinder(self, 0.34 * scale_factor, 0.25 * scale_factor, position + Vector3.UP * height, accent, 0.18 * scale_factor)


func add_lamp(position: Vector3, neon: Material, steel: Material) -> void:
	var lamp := add_cylinder(self, 0.1, 4.6, position + Vector3.UP * 2.3, steel, 0.07)
	lamp.add_to_group("lamp_scenery")
	add_box(self, Vector3(1.5, 0.12, 0.12), position + Vector3(0.62, 4.45, 0), steel)
	add_box(self, Vector3(0.52, 0.18, 0.32), position + Vector3(1.28, 4.32, 0), neon)


func add_beach_house(position: Vector3, heading: float, body: Material, accent: Material, glass: Material, roof: Material, large := false) -> void:
	var width := 11.0 if large else 6.5
	var height := 12.0 if large else 5.0
	var depth := 8.0 if large else 5.5
	var house := add_box(self, Vector3(width, height, depth), position + Vector3.UP * height * 0.5, body, false, heading)
	house.add_to_group("hotel_scenery" if large else "house_scenery")
	# Flat stepped roof and canopy give the buildings an unmistakable Miami/art-deco profile.
	add_box(self, Vector3(width + 0.8, 0.45, depth + 0.8), position + Vector3.UP * (height + 0.2), roof, false, heading)
	add_box(self, Vector3(width * 0.58, 0.55, depth * 0.65), position + Vector3.UP * (height + 0.7), accent, false, heading)
	var floors := 4 if large else 2
	for floor_index in range(floors):
		var y := 1.35 + floor_index * 2.35
		for window_index in [-1, 0, 1]:
			var window_offset := Vector3(window_index * width * 0.25, y, -depth * 0.51).rotated(Vector3.UP, heading)
			add_box(self, Vector3(1.15, 1.25, 0.16), position + window_offset, glass, false, heading)
		if large or floor_index == 1:
			var balcony_offset := Vector3(0, y - 0.75, -depth * 0.62).rotated(Vector3.UP, heading)
			add_box(self, Vector3(width * 0.75, 0.18, 1.35), position + balcony_offset, accent, false, heading)


func add_shop(position: Vector3, heading: float, body: Material, awning: Material, glass: Material, sign_color: Material, variant := 0) -> void:
	var width := 7.5 + variant * 1.5
	var shop := add_box(self, Vector3(width, 4.1, 6.0), position + Vector3.UP * 2.05, body, false, heading)
	shop.add_to_group("shop_scenery")
	shop.add_to_group("neighborhood_scenery")
	var front := Vector3(0, 1.7, -3.08).rotated(Vector3.UP, heading)
	add_box(self, Vector3(width * 0.72, 2.25, 0.16), position + front, glass, false, heading)
	var canopy := Vector3(0, 3.15, -3.65).rotated(Vector3.UP, heading)
	add_box(self, Vector3(width + 0.45, 0.26, 1.25), position + canopy, awning, false, heading)
	var sign_offset := Vector3(0, 4.55, -3.1).rotated(Vector3.UP, heading)
	add_box(self, Vector3(width * 0.78, 0.72, 0.22), position + sign_offset, sign_color, false, heading)
	if variant == 2:
		add_cylinder(self, 0.9, 0.25, position + Vector3.UP * 5.1, sign_color)


func add_islet(position: Vector3, radius: float, sand: Material, trunk: Material, leaves: Material, accent: Material) -> void:
	var island := add_cylinder(self, radius, 0.45, position, sand, radius * 0.78)
	island.add_to_group("offshore_islet_scenery")
	for index in range(3):
		var offset := Vector3(cos(index * 2.1), 0.25, sin(index * 2.1)) * radius * 0.38
		add_palm(position + offset, 0.58 + index * 0.08, trunk, leaves, accent, index % 3)


func build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = load("res://assets/generated/backgrounds/synthwave-sky-only-v2.png")
	panorama.energy_multiplier = 0.72
	var synthwave_sky := Sky.new()
	synthwave_sky.sky_material = panorama
	env.sky = synthwave_sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9b5ff")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 0.92
	sun.shadow_enabled = true
	# District meshes remain visible for at least 1.2 km. Match the sunlight to
	# that baseline while retaining four progressively coarser near-to-far maps.
	# Small props already opt out of shadow casting in WorldBuilder, keeping this
	# substantially longer range practical for the Compatibility renderer.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 1200.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_fade_start = 0.82
	sun.directional_shadow_blend_splits = false
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.5
	add_child(sun)


func build_track() -> void:
	var asphalt := make_material(Color("242832"), 0.0, 0.92)
	var deck_side := make_material(Color("171b27"), 0.15, 0.72)
	var curb_red := make_material(Color("ff3f81"), 0.05, 0.5)
	var curb_white := make_material(Color("f4f4ee"), 0.0, 0.65)
	var line_mat := make_material(Color("f6f0ce"))
	# One continuous collider removes exact coplanar joins between the former 240 m
	# chunks. A finer ribbon sample also keeps inner curbs valid on the tight loops.
	var road_mesh := build_course_ribbon(0.0, TRACK_LENGTH, ROAD_WIDTH, 0.0, 0.0, asphalt)
	var body := StaticBody3D.new()
	body.name = "RoadCircuit"
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("track")
	add_child(body)
	body.add_child(road_mesh)
	var collision := CollisionShape3D.new()
	collision.shape = road_mesh.mesh.create_trimesh_shape()
	body.add_child(collision)
	# A slightly wider lower ribbon gives the zero-thickness racing surface a clear
	# dark deck edge at bridges, flyovers, and coastal shoulders.
	add_child(build_course_ribbon(0.0, TRACK_LENGTH, ROAD_WIDTH + 1.4, 0.0, -0.18, deck_side))
	add_child(build_course_side_skirt(-1.0, 0.38, deck_side))
	add_child(build_course_side_skirt(1.0, 0.38, deck_side))
	add_child(build_course_ribbon(0.0, TRACK_LENGTH, 0.6, ROAD_WIDTH * 0.5, 0.045, curb_red))
	add_child(build_course_ribbon(0.0, TRACK_LENGTH, 0.6, -ROAD_WIDTH * 0.5, 0.045, curb_white))
	# Dashed centre markings and a single start/finish checkerboard.
	var marker_offset := 18.0
	while marker_offset < TRACK_LENGTH:
		var frame := course.sample_course(marker_offset)
		var line := add_box(self, Vector3(0.16, 0.04, 5.0), frame.origin + frame.basis.y * 0.055, line_mat)
		line.global_transform.basis = frame.basis
		marker_offset += 24.0
	var start_frame := course.sample_course(0.0)
	for lane in range(-4, 5):
		var tile_color := Color.WHITE if lane % 2 == 0 else Color("111111")
		var tile := add_box(self, Vector3(1.8, 0.05, 1.2), start_frame.origin + start_frame.basis.x * (lane * 1.8) + start_frame.basis.y * 0.06, make_material(tile_color))
		tile.global_transform.basis = start_frame.basis


func build_course_ribbon(from_offset: float, to_offset: float, width: float, lateral_shift: float, vertical_shift: float, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sample_count := maxi(1, ceili((to_offset - from_offset) / ROAD_SAMPLE_STEP))
	for sample_index in range(sample_count):
		var offset_a := lerpf(from_offset, to_offset, float(sample_index) / sample_count)
		var offset_b := lerpf(from_offset, to_offset, float(sample_index + 1) / sample_count)
		var frame_a := course.sample_course(offset_a)
		var frame_b := course.sample_course(offset_b)
		var center_a := frame_a.origin + frame_a.basis.x * lateral_shift + frame_a.basis.y * vertical_shift
		var center_b := frame_b.origin + frame_b.basis.x * lateral_shift + frame_b.basis.y * vertical_shift
		var a_left := center_a - frame_a.basis.x * width * 0.5
		var a_right := center_a + frame_a.basis.x * width * 0.5
		var b_left := center_b - frame_b.basis.x * width * 0.5
		var b_right := center_b + frame_b.basis.x * width * 0.5
		add_surface_triangle(surface, a_left, b_left, b_right, frame_a.basis.y, frame_b.basis.y, frame_b.basis.y)
		add_surface_triangle(surface, a_left, b_right, a_right, frame_a.basis.y, frame_b.basis.y, frame_a.basis.y)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = material
	return instance


func build_course_side_skirt(side: float, depth: float, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sample_count := maxi(1, ceili(TRACK_LENGTH / ROAD_SAMPLE_STEP))
	var lateral := side * (ROAD_WIDTH + 1.4) * 0.5
	for sample_index in range(sample_count):
		var offset_a := TRACK_LENGTH * float(sample_index) / sample_count
		var offset_b := TRACK_LENGTH * float(sample_index + 1) / sample_count
		var frame_a := course.sample_course(offset_a)
		var frame_b := course.sample_course(offset_b)
		var top_a := frame_a.origin + frame_a.basis.x * lateral
		var top_b := frame_b.origin + frame_b.basis.x * lateral
		var bottom_a := top_a - frame_a.basis.y * depth
		var bottom_b := top_b - frame_b.basis.y * depth
		var normal_a := frame_a.basis.x * side
		var normal_b := frame_b.basis.x * side
		add_surface_triangle(surface, top_a, bottom_b, top_b, normal_a, normal_b, normal_b)
		add_surface_triangle(surface, top_a, bottom_a, bottom_b, normal_a, normal_a, normal_b)
	var instance := MeshInstance3D.new()
	instance.name = "RoadDeckSide"
	instance.mesh = surface.commit()
	instance.material_override = material
	return instance


func add_surface_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal_a: Vector3, normal_b: Vector3, normal_c: Vector3) -> void:
	for vertex_data in [[a, normal_a], [b, normal_b], [c, normal_c]]:
		surface.set_normal(vertex_data[1])
		surface.add_vertex(vertex_data[0])


func orient_track_piece(piece: Node3D, target: Vector3, bank: float) -> void:
	piece.look_at(target, Vector3.UP)
	piece.rotate_object_local(Vector3.BACK, bank)


func build_scenery() -> void:
	world_builder = WorldBuilderScript.new()
	world_builder.build_infrastructure(self, course)
	var packed := load(EDITABLE_WORLD_PATH) as PackedScene
	if packed == null:
		push_error("Editable scenery is missing: %s" % EDITABLE_WORLD_PATH)
		return
	var editable_world := packed.instantiate()
	editable_world.name = "EditableWorld"
	editable_world.add_to_group("editable_world")
	add_child(editable_world)
	_apply_manual_scenery_reservations(editable_world)


func _apply_manual_scenery_reservations(editable_world: Node) -> void:
	# The decorative baseline is baked for editor visibility, so resolve authored
	# additions after instancing it. A deliberately placed manual item wins over
	# any baseline decoration occupying the same footprint.
	var manual_items := get_tree().get_nodes_in_group("manual_scenery")
	var removals: Array[Node] = []
	for value in get_tree().get_nodes_in_group("editable_scenery"):
		if not value is Node3D or not editable_world.is_ancestor_of(value):
			continue
		var generated := value as Node3D
		var generated_radius := float(generated.get_meta("scenery_radius", 4.0))
		for manual_value in manual_items:
			if not manual_value is Node3D or manual_value == generated:
				continue
			var manual := manual_value as Node3D
			var manual_radius := float(manual.get_meta("scenery_radius", 3.0))
			var manual_scale := manual.global_transform.basis.get_scale()
			manual_radius *= maxf(absf(manual_scale.x), absf(manual_scale.z))
			var separation := Vector2(generated.global_position.x, generated.global_position.z).distance_to(
				Vector2(manual.global_position.x, manual.global_position.z)
			)
			if separation < generated_radius + manual_radius + 1.0:
				removals.append(generated)
				break
	for value in removals:
		var parent := value.get_parent()
		if parent != null:
			parent.remove_child(value)
		value.queue_free()


func build_landmarks(steel: Material, yellow: Material, red: Material, blue: Material) -> void:
	# Beach houses, hotels, tunnels and island bridges make every sector readable.
	var concrete := make_material(Color("5c507d"), 0.05, 0.75)
	var pink := make_material(Color("d94888"), 0.05, 0.55)
	var mint := make_material(Color("32bfa1"), 0.05, 0.55)
	var peach := make_material(Color("dc765b"), 0.05, 0.65)
	var cream := make_material(Color("d8c69f"), 0.0, 0.75)
	var glass := make_material(Color("143a68"), 0.45, 0.16)
	var purple := make_material(Color("863dba"), 0.2, 0.35)
	var coral := make_material(Color("ff8066"), 0.02, 0.6)
	var aqua := make_material(Color("35e0dd"), 0.08, 0.42)
	var sand := make_material(Color("d9ae65"), 0.0, 0.92)
	var trunk := make_material(Color("8d542f"))
	var leaves := make_material(Color("0c9b70"), 0.0, 0.72)
	# Offshore keys and tiny marinas replace the old giant tapered formations that
	# looked like floating traffic cones.
	for z in [-900.0, -2750.0, -4650.0, -8200.0, -10900.0]:
		var side := -1.0 if int(absf(z) / 100.0) % 2 == 0 else 1.0
		var island_pos := Vector3(center_x(z) + side * 70.0, -0.85, z)
		add_islet(island_pos, 12.0 + fmod(absf(z), 7.0), sand, trunk, leaves, coral)
		var dock := add_box(self, Vector3(2.2, 0.25, 14.0), island_pos + Vector3(-side * 10.0, 0.25, 8.0), concrete, false, 0.18 * side)
		dock.add_to_group("marina_scenery")
		for boat_index in range(2):
			var boat := add_box(self, Vector3(2.0, 0.55, 4.2), island_pos + Vector3(-side * (14.0 + boat_index * 3.5), 0.0, 6.0 + boat_index * 5.0), coral if boat_index == 0 else aqua, false, 0.12 * side)
			boat.add_to_group("marina_scenery")
	# Five long neon tunnel sequences distributed across the course.
	for tunnel_z in [-1750.0, -3150.0, -5050.0, -7350.0, -10150.0]:
		for arch_index in range(18):
			var z: float = tunnel_z - arch_index * 7.0
			var x := center_x(z); var y := track_y(z); var heading := track_heading(z)
			for arch_part in [
				add_box(self, Vector3(1.2, 7.0, 1.0), Vector3(x - 9.2, y + 3.4, z), concrete, false, heading),
				add_box(self, Vector3(1.2, 7.0, 1.0), Vector3(x + 9.2, y + 3.4, z), concrete, false, heading),
				add_box(self, Vector3(19.6, 1.0, 1.0), Vector3(x, y + 7.0, z), pink if arch_index % 3 == 0 else concrete, false, heading),
			]:
				arch_part.add_to_group("tunnel")
	# Four obvious water crossings: closely spaced piers and luminous gateway pylons.
	for crossing in [[-1250, -1650], [-3500, -3950], [-6000, -6550], [-8800, -9250]]:
		for z in range(crossing[0], crossing[1], -55):
			var road_y := track_y(float(z))
			for side in [-1.0, 1.0]:
				add_cylinder(self, 0.65, road_y + 1.0, Vector3(center_x(float(z)) + side * 7.2, (road_y - 1.0) * 0.5, float(z)), concrete)
				add_box(self, Vector3(0.35, 0.35, 7.0), Vector3(center_x(float(z)) + side * 8.7, road_y + 1.15, float(z)), pink, false, track_heading(float(z)))
		for gateway_z in [float(crossing[0]) - 18.0, float(crossing[1]) + 18.0]:
			var gx := center_x(gateway_z); var gy := track_y(gateway_z)
			add_box(self, Vector3(1.1, 8.0, 1.1), Vector3(gx - 10.0, gy + 4.0, gateway_z), purple)
			add_box(self, Vector3(1.1, 8.0, 1.1), Vector3(gx + 10.0, gy + 4.0, gateway_z), purple)
			add_box(self, Vector3(21.0, 0.55, 1.1), Vector3(gx, gy + 7.7, gateway_z), pink)
	# Build dense little neighborhoods separated by open beaches. Rows, alleys and
	# courtyards read as places rather than evenly spaced procedural props.
	var neighborhood_centers := [-620.0, -2350.0, -4250.0, -5520.0, -7820.0, -9650.0, -11300.0]
	var palette: Array[Material] = [pink, mint, peach, blue, cream]
	for neighborhood_index in range(neighborhood_centers.size()):
		var center_z: float = neighborhood_centers[neighborhood_index]
		if is_water_crossing(center_z):
			continue
		var heading := track_heading(center_z)
		var lateral := Vector3(cos(heading), 0, -sin(heading))
		var side := -1.0 if neighborhood_index % 2 == 0 else 1.0
		var anchor := Vector3(center_x(center_z), -0.25, center_z) + lateral * side * 22.0
		var district_root := Node3D.new()
		district_root.name = "Neighborhood_%02d" % neighborhood_index
		district_root.add_to_group("neighborhood_scenery")
		add_child(district_root)
		# Three storefronts make a lively main street frontage.
		for shop_index in range(3):
			var shop_z := center_z + (shop_index - 1) * 10.5
			var shop_pos := Vector3(center_x(shop_z), -0.25, shop_z) + lateral * side * 20.0
			add_shop(shop_pos, heading - side * PI * 0.5, palette[(neighborhood_index + shop_index) % palette.size()], coral if shop_index % 2 == 0 else aqua, glass, yellow if shop_index == 1 else purple, shop_index)
		# Homes step back to form an alley and a palm-lined courtyard.
		for house_index in range(3):
			var row_offset := Vector3(0, 0, (house_index - 1) * 13.0).rotated(Vector3.UP, heading)
			var setback := lateral * side * (10.0 + (house_index % 2) * 6.0)
			var house_pos := anchor + setback + row_offset
			add_beach_house(house_pos, heading - side * PI * 0.5, palette[(neighborhood_index + house_index + 2) % palette.size()], cream, glass, coral, false)
			if house_index != 1:
				add_palm(house_pos - lateral * side * 7.0, 0.72 + house_index * 0.12, trunk, leaves, coral, (neighborhood_index + house_index) % 3)
		# A shorter row on the opposite side turns each district into a real street
		# while leaving sightline gaps between neighborhoods.
		var opposite := -side
		for opposite_index in range(2):
			var opposite_z := center_z + (opposite_index - 0.5) * 12.0
			var opposite_shop := Vector3(center_x(opposite_z), -0.25, opposite_z) + lateral * opposite * 21.0
			add_shop(opposite_shop, heading - opposite * PI * 0.5, palette[(neighborhood_index + opposite_index + 1) % palette.size()], aqua, glass, coral, opposite_index)
			var opposite_house := opposite_shop + lateral * opposite * 12.0 + Vector3(0, 0, -10.0)
			add_beach_house(opposite_house, heading - opposite * PI * 0.5, palette[(neighborhood_index + opposite_index + 3) % palette.size()], cream, glass, purple, false)
		var alley_position := anchor + lateral * side * 12.0
		var alley := add_box(self, Vector3(3.2, 0.12, 28.0), alley_position + Vector3.UP * 0.02, concrete, false, heading)
		alley.add_to_group("alley_scenery")
		var courtyard := add_cylinder(self, 4.6, 0.16, anchor + lateral * side * 20.0 + Vector3.UP * 0.05, aqua, 4.6)
		courtyard.add_to_group("courtyard_scenery")
		# A landmark hotel punctuates every other neighborhood.
		if neighborhood_index % 2 == 1:
			var hotel_pos := anchor + lateral * side * 28.0 + Vector3(0, 0, -8.0)
			add_beach_house(hotel_pos, heading - side * PI * 0.5, cream, coral, glass, purple, true)
	# Standalone towers create a distant skyline at two urban sectors.
	for z in [-4400.0, -9850.0]:
		for tower_index in range(3):
			var side := -1.0 if tower_index % 2 == 0 else 1.0
			var p := Vector3(center_x(z) + side * (48.0 + tower_index * 13.0), 0.0, z - tower_index * 18.0)
			var tower := add_box(self, Vector3(9.0 + tower_index, 17.0 + tower_index * 6.0, 10.0), p + Vector3.UP * (8.5 + tower_index * 3.0), palette[tower_index], false, track_heading(z))
			tower.add_to_group("skyline_scenery")
			for floor_index in range(3 + tower_index):
				add_box(self, Vector3(6.2, 0.55, 0.18), p + Vector3(0, 3.0 + floor_index * 4.2, -5.1), aqua if floor_index % 2 == 0 else coral, false, track_heading(z))
	# Varied silhouettes: turbines and cylindrical city structures.
	for z in [-4500.0, -4800.0, -10200.0, -10700.0]:
		var side := -1.0 if int(absf(z)) % 2 == 0 else 1.0
		var p := Vector3(center_x(z) + side * 28.0, track_y(z), z)
		add_cylinder(self, 0.55, 14.0, p + Vector3.UP * 7.0, steel, 0.25)
		add_box(self, Vector3(9.0, 0.35, 0.35), p + Vector3.UP * 13.5, yellow, false, track_heading(z))
	for z in [-10800.0, -11000.0, -11300.0]:
		for side in [-1.0, 1.0]:
			var p := Vector3(center_x(z) + side * 25.0, 0.0, z)
			add_cylinder(self, 4.0, 12.0 + fmod(absf(z), 9.0), p + Vector3.UP * 6.0, [red, blue, steel][int(absf(z)) % 3])


func build_portrait_scenery(steel: Material, red: Material, yellow: Material, blue: Material) -> void:
	var portraits := [
		"res://assets/generated/friends/friend-glasses-racing.png",
		"res://assets/generated/friends/friend-beard-racing.png",
		"res://assets/generated/friends/friend-dark-hair-racing.png",
	]
	var placements := [
		Vector3(-14.0, 5.2, -18.0),
		Vector3(14.0, 5.2, -24.0),
		Vector3(-15.0, 5.2, -70.0),
		Vector3(15.0, 5.2, -170.0),
		Vector3(-15.5, 5.2, -290.0),
		Vector3(15.5, 5.2, -420.0),
	]
	var frame_materials := [red, yellow, blue]
	for index in range(placements.size()):
		var position: Vector3 = placements[index]
		position.x += center_x(position.z)
		add_box(self, Vector3(7.5, 0.4, 0.45), position + Vector3(0, 5.0, -0.1), frame_materials[index % 3])
		add_box(self, Vector3(0.4, 2.2, 0.4), position + Vector3(0, -5.8, -0.1), steel)
		var portrait := Sprite3D.new()
		portrait.texture = load(portraits[index % portraits.size()])
		portrait.pixel_size = 0.006
		portrait.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		portrait.shaded = false
		portrait.position = position + Vector3(0, 0, 0.05)
		add_child(portrait)


func build_car() -> void:
	car = CharacterBody3D.new()
	car.name = "PlayerCar"
	car.collision_layer = 1
	car.collision_mask = 1
	var start_frame := course.sample_course(0.0)
	start_position = start_frame.origin + start_frame.basis.y * 0.55
	car.transform = Transform3D(start_frame.basis, start_position)
	add_child(car)
	var collider := CollisionShape3D.new()
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(1.8, 0.7, 4.1)
	collider.shape = body_shape
	car.add_child(collider)
	var red := make_material(Color("e21f2f"), 0.65, 0.2)
	var dark := make_material(Color("11151d"), 0.25, 0.28)
	var accent := make_material(Color("f7d23e"), 0.25, 0.35)
	add_box(car, Vector3(1.65, 0.5, 3.8), Vector3(0, 0, 0), red)
	add_box(car, Vector3(0.75, 0.35, 2.0), Vector3(0, 0.35, -0.15), dark)
	add_box(car, Vector3(2.7, 0.12, 0.55), Vector3(0, 0.02, -2.05), accent)
	add_box(car, Vector3(2.35, 0.5, 0.2), Vector3(0, 0.55, 1.65), dark)
	for x in [-1.05, 1.05]:
		for z in [-1.15, 1.2]:
			add_box(car, Vector3(0.46, 0.62, 0.85), Vector3(x, -0.05, z), dark)
	chase_camera = Camera3D.new()
	chase_camera.current = true
	chase_camera.fov = 70.0
	chase_camera.far = 7000.0
	add_child(chase_camera)
	chase_camera.global_position = car.global_position + start_frame.basis.z * 10.5 + start_frame.basis.y * 5.4
	chase_camera.look_at(car.global_position - start_frame.basis.z * 5.0 + start_frame.basis.y * 0.5, start_frame.basis.y)


func build_obstacles() -> void:
	var obstacle_materials := [
		make_material(Color("ef6b2e"), 0.05, 0.65),
		make_material(Color("f1cb39"), 0.05, 0.65),
		make_material(Color("3e85d8"), 0.1, 0.55)
	]
	var lane_offsets := [-5.2, 0.0, 5.2]
	var row := 0
	var z := -105.0
	while z > -TRACK_LENGTH + 50:
		var progress := absf(z) / TRACK_LENGTH
		var blocked_count := 1 if progress < 0.28 else (2 if rng.randf() < 0.52 + progress * 0.28 else 1)
		var safe_lane := rng.randi_range(0, 2)
		var lanes: Array[int] = []
		for lane in range(3):
			if lane != safe_lane:
				lanes.append(lane)
		lanes.shuffle()
		for index in range(blocked_count):
			var lane := lanes[index]
			var heading := track_heading(z)
			var lateral := Vector3(cos(heading), 0.0, -sin(heading))
			var obstacle_position := Vector3(center_x(z), track_y(z), z) + lateral * float(lane_offsets[lane])
			var size := Vector3(2.2, 1.65, 2.2) if row % 3 else Vector3(2.8, 1.25, 1.7)
			obstacle_position.y += size.y * 0.5
			var obstacle := add_box(self, size, obstacle_position, obstacle_materials[row % obstacle_materials.size()], true, heading)
			obstacle.add_to_group("obstacle")
		row += 1
		# Spacing narrows gradually, while every row still has a guaranteed open lane.
		z -= lerpf(43.0, 27.0, progress) + rng.randf_range(-3.0, 5.0)


func make_label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var margin := MarginContainer.new()
	margin.position = Vector2.ZERO
	margin.size = Vector2(350, 265)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	layer.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var title := make_label("SEREGA GRAND PRIX", 18, Color("ffdf55"))
	column.add_child(title)
	timer_label = make_label("00:00.000", 32, Color.WHITE)
	column.add_child(timer_label)
	speed_label = make_label("0 KM/H", 48, Color("67e7ff"))
	column.add_child(speed_label)
	distance_label = make_label("0 / %d M" % int(TRACK_LENGTH), 17, Color("dce5ed"))
	column.add_child(distance_label)
	var fuel_title := make_label("FUEL", 14, Color("b8c4cf"))
	column.add_child(fuel_title)
	fuel_bar = ProgressBar.new()
	fuel_bar.custom_minimum_size = Vector2(285, 22)
	fuel_bar.max_value = 100
	fuel_bar.value = fuel
	fuel_bar.show_percentage = true
	column.add_child(fuel_bar)
	status_label = make_label("WASD DRIVE (S BRAKE/REVERSE) | SPACE BRAKE | F CAMERA FUEL | G DEBUG FILL | R RESET", 16, Color("f2f4f6"))
	status_label.anchor_right = 1.0
	status_label.anchor_top = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_top = -52.0
	status_label.offset_bottom = -18.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(status_label)
	finish_portrait = TextureRect.new()
	finish_portrait.texture = load("res://assets/generated/friends/friend-dark-hair-racing.png")
	finish_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	finish_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	finish_portrait.anchor_left = 1.0
	finish_portrait.anchor_top = 1.0
	finish_portrait.anchor_right = 1.0
	finish_portrait.anchor_bottom = 1.0
	finish_portrait.offset_left = -220.0
	finish_portrait.offset_top = -280.0
	finish_portrait.offset_right = -24.0
	finish_portrait.offset_bottom = -70.0
	finish_portrait.visible = false
	layer.add_child(finish_portrait)
	# Keep the countdown on a separate, modest font atlas for broad GL compatibility.
	countdown_label = Label.new()
	countdown_label.text = "3"
	countdown_label.add_theme_font_size_override("font_size", 82)
	countdown_label.add_theme_color_override("font_color", Color("fff27a"))
	countdown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(countdown_label)


func build_refuel_client() -> void:
	refuel_request = HTTPRequest.new()
	refuel_request.timeout = 75.0
	refuel_request.request_completed.connect(_on_refuel_request_completed)
	add_child(refuel_request)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(car):
		return
	collision_cooldown = maxf(0.0, collision_cooldown - delta)
	collision_stop_time = maxf(0.0, collision_stop_time - delta)
	obstacle_slide_time = maxf(0.0, obstacle_slide_time - delta)
	boost_time = maxf(0.0, boost_time - delta)
	ghost_time = maxf(0.0, ghost_time - delta)
	refuel_cooldown = maxf(0.0, refuel_cooldown - delta)
	car.collision_mask = 0 if ghost_time > 0.0 else 1
	var refuel_pressed := Input.is_key_pressed(KEY_F)
	if refuel_pressed and not refuel_key_down:
		request_refuel()
	refuel_key_down = refuel_pressed
	var debug_refill_pressed := Input.is_key_pressed(KEY_G)
	if debug_refill_pressed and not debug_refill_key_down:
		debug_refill()
	debug_refill_key_down = debug_refill_pressed
	if Input.is_key_pressed(KEY_R):
		reset_car()
	if countdown_time > 0.0:
		countdown_time = maxf(0.0, countdown_time - delta)
		countdown_label.text = str(maxi(1, ceili(minf(countdown_time, 3.0))))
		speed = 0.0
		car.velocity = Vector3.ZERO
		if countdown_time <= 0.0:
			go_flash_time = 0.8
			countdown_label.text = "GO!"
	elif go_flash_time > 0.0:
		go_flash_time = maxf(0.0, go_flash_time - delta)
		countdown_label.modulate.a = clampf(go_flash_time * 2.0, 0.0, 1.0)
		elapsed += delta
		update_car(delta)
		update_progress(delta)
	elif race_active:
		countdown_label.visible = false
		elapsed += delta
		update_car(delta)
		update_progress(delta)
	update_camera(delta)
	update_hud()


func update_car(delta: float) -> void:
	if collision_stop_time > 0.0:
		speed = 0.0
		car.velocity = Vector3.ZERO
		enforce_track_safety(delta)
		return
	if refuel_in_progress:
		speed = move_toward(speed, 0.0, 28.0 * delta)
		car.velocity = -car.global_transform.basis.z.normalized() * speed
		car.velocity.y = -1.0
		car.move_and_slide()
		return
	var throttle := 1.0 if Input.is_key_pressed(KEY_W) else 0.0
	var reverse_pressed := Input.is_key_pressed(KEY_S)
	var hard_braking := Input.is_key_pressed(KEY_SPACE)
	var steer := 0.0
	if Input.is_key_pressed(KEY_A): steer -= 1.0
	if Input.is_key_pressed(KEY_D): steer += 1.0
	var progress := clampf(distance / TRACK_LENGTH, 0.0, 1.0)
	speed = compute_drive_speed(speed, throttle, reverse_pressed, hard_braking, progress, delta)
	var speed_ratio := clampf(absf(speed) / 110.0, 0.0, 1.0)
	var steering_rate := lerpf(2.35, 0.78, speed_ratio)
	if absf(steer) > 0.01 and (absf(speed) > 0.6 or (obstacle_slide_time > 0.0 and throttle > 0.0)):
		var reverse_steering := -1.0 if speed < 0.0 else 1.0
		car.rotate_y(-steer * reverse_steering * steering_rate * delta)
	# Arcade stability gently aligns the car to the road while preserving sharp player input.
	var desired_heading := course.heading_at(course_offset)
	car.rotation.y = lerp_angle(car.rotation.y, desired_heading, delta * (0.18 if absf(steer) > 0.1 else 0.7))
	var forward := -car.global_transform.basis.z.normalized()
	var intended_motion := forward * speed
	if obstacle_slide_time > 0.0 and obstacle_block_normal.length_squared() > 0.1:
		intended_motion = project_motion_along_obstacle(intended_motion, obstacle_block_normal)
		var tangent := Vector3.UP.cross(obstacle_block_normal).normalized()
		var alignment := absf(forward.dot(tangent))
		speed = signf(speed) * minf(absf(speed), 3.0 + 28.0 * alignment)
		if intended_motion.length() > absf(speed):
			intended_motion = intended_motion.normalized() * absf(speed)
	# Substep at very high speed so thin obstacles cannot be skipped between ticks.
	var movement_steps := maxi(1, ceili(absf(speed) * delta / 1.25))
	for movement_step in range(movement_steps):
		car.velocity = intended_motion
		car.velocity.y = -7.0
		car.velocity /= float(movement_steps)
		car.move_and_slide()
		for collision_index in range(car.get_slide_collision_count()):
			var step_collision := car.get_slide_collision(collision_index)
			if step_collision.get_collider() is Node and step_collision.get_collider().is_in_group("obstacle"):
				handle_obstacle_hit(step_collision.get_normal(), intended_motion)
				break
	enforce_track_safety(delta)


func project_motion_along_obstacle(intended: Vector3, normal: Vector3) -> Vector3:
	var flat_normal := Vector3(normal.x, 0.0, normal.z)
	if flat_normal.length_squared() < 0.001:
		return intended
	flat_normal = flat_normal.normalized()
	return intended.slide(flat_normal) if intended.dot(flat_normal) < 0.0 else intended


func enforce_track_safety(delta: float) -> void:
	var search_radius := clampf(70.0 + absf(speed) * 0.75, 70.0, 220.0)
	var nearest_offset := course.closest_offset_local(car.global_position, course_offset, search_radius, 5.0)
	var frame := course.sample_course(nearest_offset)
	var lateral_axis := frame.basis.x
	var center := frame.origin + frame.basis.y * 0.55
	var lateral_distance := (car.global_position - center).dot(lateral_axis)
	var soft_edge := ROAD_WIDTH * 0.43
	var hard_edge := ROAD_WIDTH * 0.7
	if absf(lateral_distance) > hard_edge:
		# Local-offset recovery cannot jump to the wrong branch at Loop 3's crossing.
		car.global_position = center
		car.global_transform.basis = frame.basis
		speed *= 0.35
		status_label.text = "TRACK RECOVERY | CAR RETURNED TO RACING LINE"
	elif absf(lateral_distance) > soft_edge:
		var clamped_lateral := clampf(lateral_distance, -soft_edge, soft_edge)
		car.global_position -= lateral_axis * (lateral_distance - clamped_lateral)
		speed *= 0.985
	# The modular course is an arcade surface, so keep the chassis attached to its
	# analytical height. This prevents tunneling through pitched road seams.
	var target_height := center.y
	if car.global_position.y < target_height - 1.0 or car.global_position.y > target_height + 2.5:
		car.global_position.y = target_height
		car.velocity.y = 0.0
	else:
		car.global_position.y = lerpf(car.global_position.y, target_height, 1.0 - exp(-delta * 24.0))


func compute_drive_speed(current_speed: float, throttle: float, reverse_pressed: bool, hard_braking: bool, progress: float, delta: float) -> float:
	# Holding W continues to accelerate; tapering keeps extreme speeds controllable.
	var acceleration := (18.0 + progress * 3.0) / (1.0 + maxf(current_speed, 0.0) / 105.0)
	if boost_time > 0.0:
		acceleration *= 1.75
	if fuel <= 0.0:
		throttle = minf(throttle, 0.35)
	if throttle > 0.0:
		current_speed = move_toward(current_speed, 0.0, 34.0 * delta) if current_speed < 0.0 else current_speed + acceleration * delta
	elif reverse_pressed:
		# S brakes forward motion first and only selects reverse near a standstill.
		current_speed = move_toward(current_speed, 0.0, 42.0 * delta) if current_speed > 0.5 else move_toward(current_speed, -15.0, 11.0 * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, 5.5 * delta)
	if hard_braking:
		current_speed = move_toward(current_speed, 0.0, 55.0 * delta)
	# Numerical/physics guard only; normal play never reaches this value.
	return clampf(current_speed, -15.0, 300.0)


func handle_obstacle_hit(normal := Vector3.ZERO, _incoming := Vector3.ZERO) -> void:
	var flat_normal := Vector3(normal.x, 0.0, normal.z)
	if flat_normal.length_squared() > 0.001:
		obstacle_block_normal = flat_normal.normalized()
	if collision_cooldown > 0.0:
		obstacle_slide_time = maxf(obstacle_slide_time, 0.25)
		return
	collision_cooldown = 0.9
	collision_stop_time = 0.14
	obstacle_slide_time = 0.9
	speed = 0.0
	car.velocity = Vector3.ZERO
	if shield_hits > 0:
		shield_hits -= 1
		status_label.text = "SHIELD ABSORBED DAMAGE | CAR STOPPED"
	else:
		fuel = maxf(0.0, fuel - 8.0)
		elapsed += 2.0
		status_label.text = "COLLISION | FULL STOP | +2.0 SEC"


func update_progress(delta: float) -> void:
	var previous_offset := course_offset
	var next_offset := course.closest_offset_local(car.global_position, course_offset, clampf(80.0 + absf(speed), 80.0, 260.0), 4.0)
	var offset_delta := next_offset - previous_offset
	if offset_delta > TRACK_LENGTH * 0.5:
		offset_delta -= TRACK_LENGTH
	elif offset_delta < -TRACK_LENGTH * 0.5:
		offset_delta += TRACK_LENGTH
	course_offset = next_offset
	distance = clampf(distance + offset_delta, 0.0, TRACK_LENGTH)
	fuel = maxf(0.0, fuel - delta * (1.0 + distance / TRACK_LENGTH * 0.5))
	if distance >= TRACK_LENGTH - 2.0:
		race_active = false
		speed = 0.0
		finish_portrait.visible = true
		status_label.text = "FINISH!  %s  |  PRESS R TO RACE AGAIN" % format_time(elapsed)


func update_camera(delta: float) -> void:
	var basis := car.global_transform.basis
	# The normal chase rig is intentionally high, but that clearance was marginal
	# beneath the tunnel roof and could put the camera inside a portal/ceiling panel
	# on the entrance grades. Use a closer, lower rig for the complete tunnel zone.
	var in_tunnel := course.zone_at(course_offset) == "underwater_tunnel"
	var camera_distance := 8.4 if in_tunnel else 10.5
	var camera_height := 4.15 if in_tunnel else 5.2
	var target_position := car.global_position + basis.z * camera_distance + Vector3.UP * camera_height
	chase_camera.global_position = chase_camera.global_position.lerp(target_position, 1.0 - exp(-delta * 7.0))
	var look_target := car.global_position - basis.z * 5.0 + Vector3.UP * 0.55
	chase_camera.look_at(look_target, Vector3.UP)
	var before := course.tangent_at(course_offset - 8.0)
	var after := course.tangent_at(course_offset + 8.0)
	var curve_bank := clampf(atan2(before.cross(after).y, before.dot(after)) * 0.35, -0.16, 0.16)
	chase_camera.rotate_object_local(Vector3.BACK, curve_bank)


func update_hud() -> void:
	speed_label.text = ("REV %03d KM/H" % int(absf(speed) * 3.6)) if speed < -0.5 else ("%03d KM/H" % int(speed * 3.6))
	timer_label.text = format_time(elapsed)
	distance_label.text = "%04d / %d M" % [int(distance), int(TRACK_LENGTH)]
	fuel_bar.value = fuel
	if fuel < 22.0:
		fuel_bar.modulate = Color("ff5a5f")
	elif fuel < 50.0:
		fuel_bar.modulate = Color("ffd45a")
	else:
		fuel_bar.modulate = Color("67ef9a")


func format_time(value: float) -> String:
	var minutes := int(value) / 60
	var seconds := int(value) % 60
	var millis := int(fmod(value, 1.0) * 1000.0)
	return "%02d:%02d.%03d" % [minutes, seconds, millis]


func reset_car() -> void:
	var start_frame := course.sample_course(0.0)
	car.global_position = start_position
	car.global_transform.basis = start_frame.basis
	car.velocity = Vector3.ZERO
	speed = 0.0
	fuel = 100.0
	elapsed = 0.0
	distance = 0.0
	course_offset = 0.0
	shield_hits = 1
	boost_time = 0.0
	ghost_time = 0.0
	collision_cooldown = 0.0
	collision_stop_time = 0.0
	obstacle_slide_time = 0.0
	obstacle_block_normal = Vector3.ZERO
	race_active = true
	finish_portrait.visible = false
	status_label.text = "WASD DRIVE (S BRAKE/REVERSE) | SPACE BRAKE | F CAMERA FUEL | G DEBUG FILL | R RESET"
	refuel_in_progress = false
	refuel_cooldown = 0.0
	countdown_time = 3.2
	go_flash_time = 0.0
	countdown_label.visible = true
	countdown_label.modulate.a = 1.0
	countdown_label.text = "3"


# Public hook for the webcam/Gemini service integration.
func apply_drink_result(color_name: String) -> void:
	var normalized := color_name.strip_edges().to_lower()
	fuel = minf(100.0, fuel + 35.0)
	match normalized:
		"blue", "cyan":
			shield_hits += 1
			status_label.text = "BLUE FUEL  |  SHIELD CHARGED"
		"red", "orange":
			boost_time = 12.0
			status_label.text = "RED FUEL  |  TURBO BOOST"
		"purple", "violet":
			ghost_time = 12.0
			status_label.text = "PURPLE FUEL  |  GHOST MODE"
		"green":
			fuel = minf(100.0, fuel + 20.0)
			status_label.text = "GREEN FUEL  |  EXTRA REFILL"
		_:
			status_label.text = "FUEL ADDED"


func debug_refill() -> void:
	fuel = 100.0
	status_label.text = "DEBUG REFILL | FUEL 100%"


func request_refuel() -> void:
	if refuel_in_progress:
		status_label.text = "RACE CONTROL IS ALREADY ANALYZING..."
		return
	if refuel_cooldown > 0.0:
		status_label.text = "REFUEL SYSTEM COOLING DOWN"
		return
	refuel_in_progress = true
	status_label.text = "PIT LIMITER | DRINK NOW | RECORDING 5 SECONDS..."
	var error := refuel_request.request(
		"http://127.0.0.1:8765/analyze-drink",
		PackedStringArray(["Accept: application/json"]),
		HTTPClient.METHOD_POST,
		""
	)
	if error != OK:
		refuel_in_progress = false
		status_label.text = "REFUEL SERVICE OFFLINE | START THE PYTHON SERVICE"


func _on_refuel_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	refuel_in_progress = false
	refuel_cooldown = 8.0
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		fuel = minf(100.0, fuel + 10.0)
		status_label.text = "RACE CONTROL ERROR | EMERGENCY FUEL +10"
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		status_label.text = "INVALID FUEL REPORT | TRY AGAIN"
		return
	var report: Dictionary = parsed
	if not bool(report.get("drinking_detected", false)):
		status_label.text = "NO DRINK DETECTED | TRY AGAIN"
		return
	apply_drink_result(str(report.get("selected_color", "unknown")))
