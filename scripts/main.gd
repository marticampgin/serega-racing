extends Node3D

const TRACK_LENGTH := 12000.0
const ROAD_WIDTH := 17.0
const SEGMENT_LENGTH := 20.0
const START_Z := 10.0

var car: CharacterBody3D
var chase_camera: Camera3D
var speed := 0.0
var base_max_speed := 43.0
var fuel := 100.0
var elapsed := 0.0
var distance := 0.0
var race_active := true
var shield_hits := 1
var collision_cooldown := 0.0
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
var start_position := Vector3.ZERO
var countdown_label: Label
var countdown_time := 3.2
var go_flash_time := 0.0


func _ready() -> void:
	rng.seed = Time.get_unix_time_from_system() as int
	build_world()
	build_track()
	build_scenery()
	build_car()
	build_obstacles()
	build_hud()
	build_refuel_client()
	print("Serega Racing: playable race initialized")
	for argument in OS.get_cmdline_user_args():
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


func center_x(z: float) -> float:
	var d := maxf(0.0, -z)
	return sin(d / 115.0) * 15.0 + sin(d / 47.0) * 3.0


func track_heading(z: float) -> float:
	var sample := 1.0
	var dx := center_x(z - sample) - center_x(z + sample)
	return -atan2(dx, sample * 2.0)


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


func build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("87bce8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d9e7ff")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	var ground_mat := make_material(Color("2d6a3f"))
	add_box(self, Vector3(300, 0.4, TRACK_LENGTH + 250), Vector3(0, -0.35, -TRACK_LENGTH * 0.5 + 30), ground_mat)


func build_track() -> void:
	var asphalt := make_material(Color("242832"), 0.0, 0.92)
	var curb_red := make_material(Color("e63746"), 0.0, 0.65)
	var curb_white := make_material(Color("f4f4ee"), 0.0, 0.65)
	var line_mat := make_material(Color("f6f0ce"))
	var barrier_mat := make_material(Color("a8b3bd"), 0.55, 0.35)
	var segments := int(TRACK_LENGTH / SEGMENT_LENGTH) + 2
	for i in range(segments):
		var z := START_Z - i * SEGMENT_LENGTH
		var x := center_x(z)
		var heading := track_heading(z)
		add_box(self, Vector3(ROAD_WIDTH, 0.25, SEGMENT_LENGTH + 0.6), Vector3(x, -0.12, z), asphalt, true, heading)
		for side in [-1.0, 1.0]:
			var lateral: Vector3 = Vector3(cos(heading), 0, -sin(heading)) * float(side)
			var curb_color := curb_red if i % 2 == 0 else curb_white
			add_box(self, Vector3(0.65, 0.16, SEGMENT_LENGTH), Vector3(x, 0.02, z) + lateral * (ROAD_WIDTH * 0.5), curb_color, false, heading)
			add_box(self, Vector3(0.35, 1.1, SEGMENT_LENGTH), Vector3(x, 0.48, z) + lateral * (ROAD_WIDTH * 0.5 + 1.05), barrier_mat, true, heading)
		if i % 2 == 0:
			add_box(self, Vector3(0.12, 0.025, 5.0), Vector3(x, 0.02, z), line_mat, false, heading)
	# Start and finish markings.
	for lane in range(-4, 5):
		var start_color := Color.WHITE if lane % 2 == 0 else Color("111111")
		add_box(self, Vector3(1.8, 0.04, 1.2), Vector3(center_x(-4.0) + lane * 1.8, 0.04, -4.0), make_material(start_color))
	for lane in range(-4, 5):
		var color := Color.WHITE if lane % 2 == 0 else Color("111111")
		add_box(self, Vector3(1.8, 0.04, 1.2), Vector3(center_x(-TRACK_LENGTH) + lane * 1.8, 0.04, -TRACK_LENGTH), make_material(color))


func build_scenery() -> void:
	var trunk := make_material(Color("6b4328"))
	var leaves_dark := make_material(Color("174f35"), 0.0, 0.9)
	var leaves_light := make_material(Color("2f8952"), 0.0, 0.9)
	var steel := make_material(Color("202936"), 0.55, 0.35)
	var yellow := make_material(Color("ffd43b"), 0.15, 0.45)
	var red := make_material(Color("e52c3c"), 0.15, 0.45)
	var blue := make_material(Color("2486d1"), 0.15, 0.45)
	# A start gantry and simple grandstands give the opening grid a race-day identity.
	var gantry_z := -24.0
	var gantry_x := center_x(gantry_z)
	add_box(self, Vector3(0.45, 5.5, 0.45), Vector3(gantry_x - 10.0, 2.7, gantry_z), steel)
	add_box(self, Vector3(0.45, 5.5, 0.45), Vector3(gantry_x + 10.0, 2.7, gantry_z), steel)
	add_box(self, Vector3(20.4, 0.55, 0.65), Vector3(gantry_x, 5.1, gantry_z), steel)
	add_box(self, Vector3(7.5, 1.35, 0.35), Vector3(gantry_x, 5.05, gantry_z - 0.38), red)
	for light_index in range(5):
		add_cylinder(self, 0.18, 0.18, Vector3(gantry_x - 1.45 + light_index * 0.72, 4.95, gantry_z - 0.65), yellow)
	for side in [-1.0, 1.0]:
		var stand_x: float = center_x(-58.0) + float(side) * 17.5
		for tier in range(4):
			add_box(self, Vector3(12.0, 0.65, 3.0), Vector3(stand_x, 0.5 + tier * 0.75, -58.0 + side * tier * 1.5), steel)
			for seat in range(6):
				var seat_mat: Material = [red, yellow, blue][(seat + tier) % 3]
				add_box(self, Vector3(1.2, 0.5, 0.8), Vector3(stand_x - 4.8 + seat * 1.9, 1.0 + tier * 0.75, -58.0 + side * tier * 1.5), seat_mat)
	# Sparse low-poly trees create speed cues without cluttering the racing line.
	var scenery_z := -115.0
	var tree_index := 0
	while scenery_z > -TRACK_LENGTH:
		var heading := track_heading(scenery_z)
		var lateral := Vector3(cos(heading), 0.0, -sin(heading))
		for side in [-1.0, 1.0]:
			var offset := float(side) * (15.0 + rng.randf_range(0.0, 11.0))
			var tree_position := Vector3(center_x(scenery_z), 0, scenery_z) + lateral * offset
			var height := rng.randf_range(3.8, 6.4)
			add_cylinder(self, 0.25, height * 0.42, tree_position + Vector3.UP * height * 0.21, trunk)
			add_cylinder(self, height * 0.27, height * 0.68, tree_position + Vector3.UP * height * 0.64, leaves_light if tree_index % 3 == 0 else leaves_dark, 0.05)
			tree_index += 1
		scenery_z -= rng.randf_range(75.0, 125.0)


func build_car() -> void:
	car = CharacterBody3D.new()
	car.name = "PlayerCar"
	car.collision_layer = 1
	car.collision_mask = 1
	start_position = Vector3(center_x(0), 0.55, 0)
	car.position = start_position
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
	add_child(chase_camera)
	chase_camera.global_position = car.global_position + Vector3(0, 5.4, 10.5)
	chase_camera.look_at(car.global_position + Vector3(0, 0.5, -5), Vector3.UP)


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
			var x: float = center_x(z) + float(lane_offsets[lane])
			var size := Vector3(2.2, 1.65, 2.2) if row % 3 else Vector3(2.8, 1.25, 1.7)
			var obstacle := add_box(self, size, Vector3(x, size.y * 0.5, z), obstacle_materials[row % obstacle_materials.size()], true)
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
	status_label = make_label("WASD DRIVE | SPACE BRAKE | F CAMERA FUEL | G DEBUG FILL | R RESET", 16, Color("f2f4f6"))
	status_label.anchor_right = 1.0
	status_label.anchor_top = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_top = -52.0
	status_label.offset_bottom = -18.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(status_label)
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
		countdown_label.text = str(maxi(1, ceili(countdown_time)))
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
	if refuel_in_progress:
		speed = move_toward(speed, 0.0, 28.0 * delta)
		car.velocity = -car.global_transform.basis.z.normalized() * speed
		car.velocity.y = -1.0
		car.move_and_slide()
		return
	var throttle := 1.0 if Input.is_key_pressed(KEY_W) else 0.0
	var braking := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE)
	var steer := 0.0
	if Input.is_key_pressed(KEY_A): steer -= 1.0
	if Input.is_key_pressed(KEY_D): steer += 1.0
	var progress := clampf(distance / TRACK_LENGTH, 0.0, 1.0)
	var current_max := base_max_speed + progress * 22.0
	if boost_time > 0.0:
		current_max += 17.0
	if fuel <= 0.0:
		current_max = 12.0
		throttle = minf(throttle, 0.35)
	if throttle > 0:
		speed = move_toward(speed, current_max, (18.0 + progress * 3.0) * delta)
	else:
		speed = move_toward(speed, 0.0, 7.0 * delta)
	if braking:
		speed = move_toward(speed, 0.0, 36.0 * delta)
	var speed_ratio := clampf(speed / maxf(current_max, 1.0), 0.0, 1.0)
	var steering_rate := lerpf(2.25, 1.25, speed_ratio)
	if absf(steer) > 0.01 and speed > 1.0:
		car.rotate_y(-steer * steering_rate * delta)
	# Arcade stability gently aligns the car to the road while preserving sharp player input.
	var desired_heading := track_heading(car.global_position.z)
	car.rotation.y = lerp_angle(car.rotation.y, desired_heading, delta * (0.18 if absf(steer) > 0.1 else 0.7))
	var forward := -car.global_transform.basis.z.normalized()
	car.velocity = forward * speed
	car.velocity.y = -1.0
	car.move_and_slide()
	for index in range(car.get_slide_collision_count()):
		var collision := car.get_slide_collision(index)
		if collision.get_collider() is Node and collision.get_collider().is_in_group("obstacle"):
			handle_obstacle_hit()


func handle_obstacle_hit() -> void:
	if collision_cooldown > 0.0:
		return
	collision_cooldown = 0.9
	if shield_hits > 0:
		shield_hits -= 1
		status_label.text = "SHIELD ABSORBED THE HIT!"
	else:
		speed *= 0.28
		fuel = maxf(0.0, fuel - 8.0)
		elapsed += 2.0
		status_label.text = "COLLISION  +2.0 SEC"


func update_progress(delta: float) -> void:
	distance = clampf(-car.global_position.z, 0.0, TRACK_LENGTH)
	fuel = maxf(0.0, fuel - delta * (1.0 + distance / TRACK_LENGTH * 0.5))
	if car.global_position.z <= -TRACK_LENGTH:
		race_active = false
		speed = 0.0
		status_label.text = "FINISH!  %s  |  PRESS R TO RACE AGAIN" % format_time(elapsed)


func update_camera(delta: float) -> void:
	var basis := car.global_transform.basis
	var target_position := car.global_position + basis.z * 10.5 + Vector3.UP * 5.2
	chase_camera.global_position = chase_camera.global_position.lerp(target_position, 1.0 - exp(-delta * 7.0))
	var look_target := car.global_position - basis.z * 5.0 + Vector3.UP * 0.55
	chase_camera.look_at(look_target, Vector3.UP)


func update_hud() -> void:
	speed_label.text = "%03d KM/H" % int(speed * 3.6)
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
	car.global_position = start_position
	car.rotation = Vector3.ZERO
	car.velocity = Vector3.ZERO
	speed = 0.0
	fuel = 100.0
	elapsed = 0.0
	distance = 0.0
	shield_hits = 1
	boost_time = 0.0
	ghost_time = 0.0
	race_active = true
	status_label.text = "WASD DRIVE | SPACE BRAKE | F CAMERA FUEL | G DEBUG FILL | R RESET"
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
