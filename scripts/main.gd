extends Node3D

const CourseLayoutScript := preload("res://scripts/course_layout.gd")
const WorldBuilderScript := preload("res://scripts/world_builder.gd")
const MainMenuScene := preload("res://scenes/ui/main_menu_overlay.tscn")
const TrackMinimapScene := preload("res://scenes/ui/track_minimap.tscn")
const CarSelectionScene := preload("res://scenes/ui/car_selection_overlay.tscn")
const CarFactory := preload("res://scripts/cars/car_visual_factory.gd")
const PauseMenuScript := preload("res://scripts/ui/pause_menu_overlay.gd")
const GameModeScript := preload("res://scripts/ui/game_mode_overlay.gd")
const RaceResultsScript := preload("res://scripts/ui/race_results_overlay.gd")
const VehicleAudioScript := preload("res://scripts/audio/vehicle_audio_controller.gd")
const EDITABLE_WORLD_PATH := "res://scenes/world/editable_world.tscn"
const RUNTIME_WORLD_PATH := "res://scenes/world/runtime_world_optimized.scn"
const MENU_BACKGROUND_PATH := "res://assets/generated/ui/main-menu-synthwave-v1.png"
const CAR_SELECTION_BACKGROUND_PATH := "res://assets/generated/ui/car-selection-retro-grid.png"
const CADILLAC_MUSIC_PATH := "res://assets/audio/music/cadillac.mp3"
const GENERATED_SCENERY_PATHS := [
	"res://scenes/world/neighborhood_details.tscn",
]
const ROAD_WIDTH := 17.0
const ROAD_SAMPLE_STEP := 2.0
const POWERUP_BOOST_DURATION := 6.5
const POWERUP_GHOST_DURATION := 6.0
const POWERUP_REPAIR_AMOUNT := 30.0
const BOOST_ACCELERATION_MULTIPLIER := 1.4
const BOOST_MAX_SPEED_MULTIPLIER := 1.05
const WALL_SLIDE_PENALTY_DELAY := 0.45
const WALL_SLIDE_SPEED_CAP := 55.0 # 198 km/h: still movable, never a fast line.
const REFUEL_CAPTURE_SECONDS := 5.0
const POWERUP_OBSTACLE_CLEARANCE := 28.0

var course: CourseLayout
var course_curve: Curve3D
var course_zones: Array[Dictionary] = []
var world_builder: WorldBuilder
var TRACK_LENGTH := 0.0
var car: CharacterBody3D
var chase_camera: Camera3D
var speed := 0.0
var base_max_speed := 500.0 / 3.6 # Selected profile's real forward-speed cap.
var fuel := 100.0
var elapsed := 0.0
var distance := 0.0
var course_offset := 0.0
var race_active := true
var shield_hits := 0
var collision_cooldown := 0.0
var wall_impact_cooldown := 0.0
var wall_scrape_audio_time := 0.0
var road_edge_contacting := false
var road_edge_contact_time := 0.0
var obstacle_slide_time := 0.0
var obstacle_block_normal := Vector3.ZERO
var boost_time := 0.0
var ghost_time := 0.0
var refuel_request: HTTPRequest
var refuel_in_progress := false
var refuel_key_down := false
var debug_refill_key_down := false
var refuel_cooldown := 0.0
var refuel_feedback_time := 0.0
var rng := RandomNumberGenerator.new()
var speed_label: Label
var timer_label: Label
var lap_label: Label
var distance_label: Label
var status_label: Label
var fuel_title: Label
var fuel_bar: ProgressBar
var durability_bar: ProgressBar
var powerup_status_label: Label
var powerup_icon_label: Label
var powerup_status_panel: PanelContainer
var game_over_label: Label
var fuel_warning_panel: PanelContainer
var refuel_panel: PanelContainer
var refuel_label: Label
var finish_portrait: TextureRect
var start_position := Vector3.ZERO
var countdown_label: Label
var countdown_time := 3.2
var last_countdown_number := 0
var go_flash_time := 0.0
var camera_orbit_yaw := 0.0
var camera_extra_height := 0.0
var camera_dragging := false
var game_started := false
var minimap: Control
var main_menu: CanvasLayer
var car_selector: CanvasLayer
var mode_selector: CanvasLayer
var pause_menu: CanvasLayer
var results_overlay: CanvasLayer
var car_visual: Node3D
var car_collider: CollisionShape3D
var selected_car_id := "iskra"
var selected_car_color := Color("e9234f")
var car_steering_mult := 1.08
var car_acceleration_mult := 1.0
var car_fuel_mult := 1.0
var car_damage_mult := 1.0
var car_max_speed_mps := 500.0 / 3.6
var durability := 100.0
var selected_game_mode := "free_run"
var powerups_enabled := false
var fuel_enabled := false
var realistic_fueling_enabled := false
var selected_laps := 2
var current_lap := 1
var lap_start_time := 0.0
var lap_times: Array[float] = []
var lap_average_speeds: Array[float] = []
var collision_count := 0
var damage_sustained := 0.0
var gameplay_content: Node3D
var obstacle_materials: Dictionary = {}
var powerup_toast := ""
var powerup_toast_time := 0.0
var powerup_display_type := ""
var vehicle_audio: VehicleAudioController
var race_music: AudioStreamPlayer
var countdown_tick_audio: AudioStreamPlayer
var countdown_go_audio: AudioStreamPlayer
var refuel_pending := false
var refuel_countdown_time := 0.0
var refuel_request_elapsed := 0.0


func _music_controller() -> Node:
	return get_node("/root/MusicController")


func _ready() -> void:
	# Fresh session seed makes lane, spacing and hazard choices genuinely differ
	# between runs while the QA tests still assert safe density ranges.
	rng.randomize()
	course = CourseLayoutScript.load_default()
	course_curve = course.course_curve
	course_zones = course.course_zones
	TRACK_LENGTH = course.length()
	build_world()
	build_track()
	build_scenery()
	build_car()
	build_vehicle_audio()
	build_race_music()
	build_countdown_audio()
	build_hud()
	build_game_ui()
	build_refuel_client()
	print("Serega Racing: map course initialized (%.1f m)" % TRACK_LENGTH)
	var capture_distance := -1.0
	var capture_path := ""
	var menu_capture_path := ""
	var cars_capture_path := ""
	var pause_capture_path := ""
	var mode_capture_path := ""
	var results_capture_path := ""
	var refuel_capture_path := ""
	var settings_capture_path := ""
	var capture_car_index := 0
	var capture_color_index := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshot-distance="):
			capture_distance = float(argument.trim_prefix("--screenshot-distance="))
		elif argument.begins_with("--screenshot-z="):
			capture_distance = -float(argument.trim_prefix("--screenshot-z="))
		elif argument.begins_with("--screenshot="):
			capture_path = argument.trim_prefix("--screenshot=")
		elif argument.begins_with("--screenshot-menu="):
			menu_capture_path = argument.trim_prefix("--screenshot-menu=")
		elif argument.begins_with("--screenshot-cars="):
			cars_capture_path = argument.trim_prefix("--screenshot-cars=")
		elif argument.begins_with("--screenshot-pause="):
			pause_capture_path = argument.trim_prefix("--screenshot-pause=")
		elif argument.begins_with("--screenshot-mode="):
			mode_capture_path = argument.trim_prefix("--screenshot-mode=")
		elif argument.begins_with("--screenshot-results="):
			results_capture_path = argument.trim_prefix("--screenshot-results=")
		elif argument.begins_with("--screenshot-refuel="):
			refuel_capture_path = argument.trim_prefix("--screenshot-refuel=")
		elif argument.begins_with("--screenshot-settings="):
			settings_capture_path = argument.trim_prefix("--screenshot-settings=")
		elif argument.begins_with("--game-mode="):
			selected_game_mode = argument.trim_prefix("--game-mode=")
		elif argument.begins_with("--car-index="):
			capture_car_index = int(argument.trim_prefix("--car-index="))
		elif argument.begins_with("--car-color="):
			capture_color_index = int(argument.trim_prefix("--car-color="))
	if not results_capture_path.is_empty():
		_on_mode_confirmed("free_run", false, 2, false)
		apply_car_selection("iskra", selected_car_color)
		_start_game()
		countdown_time = 0.0
		elapsed = 124.321
		_complete_lap()
		elapsed = 247.876
		_complete_lap()
		capture_qa_screenshot.call_deferred(results_capture_path)
	elif not refuel_capture_path.is_empty():
		_on_mode_confirmed("obstacle_course", true, 2, true)
		apply_car_selection("iskra", selected_car_color)
		_start_game()
		countdown_time = 0.0
		fuel = 15.0
		request_refuel()
		refuel_pending = false
		refuel_in_progress = true
		refuel_request_elapsed = REFUEL_CAPTURE_SECONDS + 0.1
		_update_refuel_sequence(0.0)
		capture_qa_screenshot.call_deferred(refuel_capture_path)
	elif not settings_capture_path.is_empty():
		main_menu.call("_on_settings_pressed")
		capture_qa_screenshot.call_deferred(settings_capture_path)
	elif not cars_capture_path.is_empty():
		_open_car_selection()
		car_selector.call("_change_car", capture_car_index)
		car_selector.call("_select_color", capture_color_index)
		capture_qa_screenshot.call_deferred(cars_capture_path)
	elif not mode_capture_path.is_empty():
		_open_mode_selection()
		mode_selector.call("_select_mode", selected_game_mode)
		capture_qa_screenshot.call_deferred(mode_capture_path)
	elif not pause_capture_path.is_empty():
		_start_game()
		_pause_game()
		capture_qa_screenshot.call_deferred(pause_capture_path)
	elif not menu_capture_path.is_empty():
		capture_qa_screenshot.call_deferred(menu_capture_path)
	elif not capture_path.is_empty():
		_start_game()
		if capture_distance >= 0.0:
			course_offset = fposmod(capture_distance, TRACK_LENGTH)
			distance = course_offset
			var capture_transform := sample_course(course_offset)
			car.global_position = capture_transform.origin + capture_transform.basis.y * 0.55
			car.global_transform.basis = capture_transform.basis
			chase_camera.global_position = car.global_position + capture_transform.basis.z * 10.5 + capture_transform.basis.y * 5.2
			chase_camera.look_at(car.global_position - capture_transform.basis.z * 5.0 + capture_transform.basis.y * 0.55, capture_transform.basis.y)
		capture_qa_screenshot.call_deferred(capture_path)


func capture_qa_screenshot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("QA screenshot: %s (%s)" % [path, error_string(error)])
	get_tree().quit(0 if error == OK else 1)


func _unhandled_input(event: InputEvent) -> void:
	if not game_started:
		return
	if event.is_action_pressed("ui_cancel"):
		_pause_game()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P and countdown_time <= 0.0:
		_music_controller().call("next_track")
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O and countdown_time <= 0.0:
		_music_controller().call("previous_track")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		camera_dragging = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if camera_dragging else Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and camera_dragging:
		camera_orbit_yaw = wrapf(camera_orbit_yaw - event.relative.x * 0.009, -PI, PI)
		# Vertical dragging can return to the standard chase height, but never lower.
		camera_extra_height = clampf(camera_extra_height - event.relative.y * 0.055, -1.4, 14.0)
		get_viewport().set_input_as_handled()


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
	panorama.panorama = load("res://assets/generated/backgrounds/synthwave-polygon-sunset-v5.png")
	panorama.energy_multiplier = 0.56
	var synthwave_sky := Sky.new()
	synthwave_sky.sky_material = panorama
	env.sky = synthwave_sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b59ac8")
	env.ambient_light_energy = 0.29
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.9
	env.adjustment_saturation = 0.94
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-29, -38, 0)
	sun.light_color = Color("ffd1b0")
	sun.light_energy = 0.68
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
	var packed := load(RUNTIME_WORLD_PATH) as PackedScene if ResourceLoader.exists(RUNTIME_WORLD_PATH) else null
	var editable_world := packed.instantiate() as Node3D if packed != null else null
	if editable_world != null and (
		not bool(editable_world.get_meta("runtime_optimized", false))
		or str(editable_world.get_meta("runtime_source_sha256", "")) != FileAccess.get_sha256(EDITABLE_WORLD_PATH)
	):
		editable_world.free()
		editable_world = null
		push_warning("Optimized runtime world is stale; using editable authoring scene")
	if editable_world == null:
		packed = load(EDITABLE_WORLD_PATH) as PackedScene
		editable_world = packed.instantiate() as Node3D if packed != null else null
	if packed == null:
		push_error("Editable scenery is missing: %s" % EDITABLE_WORLD_PATH)
		return
	if editable_world == null:
		push_error("Scenery could not be instantiated")
		return
	var is_runtime_optimized := bool(editable_world.get_meta("runtime_optimized", false))
	editable_world.name = "EditableWorld"
	editable_world.add_to_group("editable_world")
	add_child(editable_world)
	_configure_authored_runtime_scenery(editable_world)
	if not is_runtime_optimized:
		_load_generated_scenery_overlays(editable_world)
		_apply_manual_scenery_reservations(editable_world)


func _configure_authored_runtime_scenery(editable_world: Node3D) -> void:
	for vehicle_node in editable_world.find_children("*", "ManualSceneryItem", true, false):
		var vehicle := vehicle_node as Node3D
		var catalog_id := str(vehicle.get("catalog_id"))
		var moving_aircraft := false
		if catalog_id.ends_with("__banner_plane"):
			vehicle.set("movement_axis", vehicle.transform.basis.x.normalized())
			vehicle.set("movement_span", 650.0)
			vehicle.set("movement_speed", 13.0)
			vehicle.set("movement_bob", 0.6)
			vehicle.set("movement_enabled", true)
			moving_aircraft = true
		elif catalog_id.ends_with("__zeppelin"):
			vehicle.set("movement_axis", vehicle.transform.basis.x.normalized())
			vehicle.set("movement_span", 400.0)
			vehicle.set("movement_speed", 4.0)
			vehicle.set("movement_bob", 1.2)
			vehicle.set("movement_enabled", true)
			moving_aircraft = true
		# Static authored presets do not need an idle _process callback. Hundreds
		# of decorative scripts can otherwise consume frame time doing no work.
		vehicle.set_process(moving_aircraft)
		vehicle.set_notify_transform(false)

		# Any friend-media carrier may have been mirrored or non-uniformly scaled
		# in the editor. Repair reflected winding for the supports, not just the
		# original motorcycle billboard, so towers and frames stay renderable.
		if catalog_id.begins_with("art_") and vehicle.transform.basis.determinant() < 0.0:
			var repaired := vehicle.transform
			repaired.basis.z = -repaired.basis.z
			vehicle.transform = repaired
		if catalog_id.begins_with("art_"):
			for geometry_node in vehicle.find_children("*", "GeometryInstance3D", true, false):
				var geometry := geometry_node as GeometryInstance3D
				geometry.visibility_range_end = maxf(geometry.visibility_range_end, 3200.0)
				geometry.visibility_range_end_margin = maxf(geometry.visibility_range_end_margin, 250.0)

	var motorcycle_carrier := editable_world.get_node_or_null("MotorcycleRiderBillboard") as Node3D
	if motorcycle_carrier != null:
		for geometry_node in motorcycle_carrier.find_children("*", "GeometryInstance3D", true, false):
			var geometry := geometry_node as GeometryInstance3D
			geometry.visibility_range_end = maxf(geometry.visibility_range_end, 3200.0)
			geometry.visibility_range_end_margin = maxf(geometry.visibility_range_end_margin, 250.0)


func _load_generated_scenery_overlays(editable_world: Node3D) -> void:
	# Fully editable worlds carry their connective scenery as local block
	# children. The compact overlay remains only as a legacy/runtime fallback.
	if editable_world.get_node_or_null("EditableBlocks") != null:
		return
	# Older editable scenes may contain a moved or overridden external instance.
	# Always replace it with the canonical generated scene at identity so authored
	# edits and generated connective scenery cannot accidentally move each other.
	for legacy_name in ["NeighborhoodDetails"]:
		var legacy := editable_world.get_node_or_null(legacy_name)
		if legacy != null:
			editable_world.remove_child(legacy)
			legacy.free()
	for path in GENERATED_SCENERY_PATHS:
		if not ResourceLoader.exists(path):
			push_warning("Generated scenery overlay is missing: %s" % path)
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			push_warning("Generated scenery overlay could not load: %s" % path)
			continue
		var overlay := packed.instantiate() as Node3D
		overlay.transform = Transform3D.IDENTITY
		overlay.set_meta("generated_overlay", true)
		editable_world.add_child(overlay)


func _apply_manual_scenery_reservations(editable_world: Node) -> void:
	# The decorative baseline is baked for editor visibility, so resolve authored
	# additions after instancing it. A deliberately placed manual item wins over
	# any baseline decoration occupying the same footprint.
	var manual_items := get_tree().get_nodes_in_group("manual_scenery")
	var removals: Array[Node] = []
	var generated_candidates := get_tree().get_nodes_in_group("editable_scenery")
	for detail in get_tree().get_nodes_in_group("neighborhood_detail_scenery"):
		# Compacted path/fence/plant networks intentionally allow authored paths to
		# cross them; removing a whole district network for one overlap is worse
		# than the harmless surface intersection. Standalone lamps, driveways,
		# docks and boats still yield to manual scenery.
		if not detail.has_meta("detail_count"):
			generated_candidates.append(detail)
	for value in generated_candidates:
		if not value is Node3D or not editable_world.is_ancestor_of(value):
			continue
		var generated := value as Node3D
		if generated.is_in_group("natural_landscape_scenery"):
			continue
		var generated_radius := float(generated.get_meta("scenery_radius", 4.0))
		for manual_value in manual_items:
			if not manual_value is Node3D or manual_value == generated:
				continue
			var manual := manual_value as Node3D
			# Paths, palms and furniture are meant to decorate buildings, not replace
			# them. Only a deliberately authored building may displace a baked one.
			var manual_is_building := manual.is_in_group("building_scenery") or str(manual.get("category")) == "Buildings"
			if generated.is_in_group("building_scenery") and not manual_is_building:
				continue
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
	var sand := make_material(Color("c77d68"), 0.0, 0.93)
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
	car_collider = CollisionShape3D.new()
	var body_shape := BoxShape3D.new()
	body_shape.size = Vector3(1.8, 0.7, 4.1)
	car_collider.shape = body_shape
	car.add_child(car_collider)
	apply_car_selection(selected_car_id, selected_car_color)
	chase_camera = Camera3D.new()
	chase_camera.current = true
	chase_camera.fov = 70.0
	chase_camera.far = 7000.0
	add_child(chase_camera)
	chase_camera.global_position = car.global_position + start_frame.basis.z * 10.5 + start_frame.basis.y * 5.4
	chase_camera.look_at(car.global_position - start_frame.basis.z * 5.0 + start_frame.basis.y * 0.5, start_frame.basis.y)


func build_gameplay_mode() -> void:
	if is_instance_valid(gameplay_content): gameplay_content.free()
	gameplay_content = Node3D.new()
	gameplay_content.name = "GameplayModeContent"
	add_child(gameplay_content)
	obstacle_materials = {
		"dark": make_material(Color("10131d"), 0.25, 0.32),
		"glass": make_material(Color("183451"), 0.45, 0.18),
		"yellow": make_material(Color("f4c542"), 0.18, 0.38),
		"orange": make_material(Color("ef6b2e"), 0.12, 0.46),
		"cyan": make_material(Color("29cbe8"), 0.2, 0.32),
		"white": make_material(Color("e8e6df"), 0.1, 0.55),
	}
	rng.randomize()
	if selected_game_mode == "obstacle_course": build_obstacles()
	if powerups_enabled: build_powerups()


func build_obstacles() -> void:
	var lane_offsets := [-5.1, 0.0, 5.1]
	var kinds := ["cone", "taxi", "car", "truck", "bulldozer", "wrecked_bolid"]
	var offset := 150.0
	var row := 0
	while offset < TRACK_LENGTH - 80.0:
		var progress := offset / TRACK_LENGTH
		var safe_lane := rng.randi_range(0, 2)
		var available := [0, 1, 2]
		available.erase(safe_lane)
		available.shuffle()
		var count := 2 if progress > 0.22 and rng.randf() < lerpf(0.18, 0.42, progress) else 1
		for index in range(count):
			var kind: String = kinds[row] if row < kinds.size() and index == 0 else kinds[rng.randi_range(0, kinds.size() - 1)]
			if course.zone_at(offset) == "underwater_tunnel" and kind in ["truck", "bulldozer"]: kind = "cone"
			_create_road_obstacle(kind, offset, lane_offsets[available[index]])
		row += 1
		offset += lerpf(108.0, 76.0, progress) + rng.randf_range(-8.0, 10.0)


func _create_road_obstacle(kind: String, offset: float, lateral: float) -> void:
	var frame := course.sample_course(offset)
	var body := StaticBody3D.new()
	body.name = "Obstacle_%s_%d" % [kind, int(offset)]
	body.transform = Transform3D(frame.basis, frame.origin + frame.basis.x * lateral + frame.basis.y * 0.05)
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("course_offset", offset)
	body.set_meta("lateral_offset", lateral)
	body.add_to_group("obstacle")
	gameplay_content.add_child(body)
	var size := Vector3(1.25, 1.7, 1.25)
	match kind:
		"taxi", "car": size = Vector3(2.25, 1.45, 4.3)
		"truck": size = Vector3(2.7, 3.0, 6.5)
		"bulldozer": size = Vector3(3.0, 2.4, 4.8)
		"wrecked_bolid": size = Vector3(2.8, 0.8, 4.5)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position.y = size.y * 0.5
	body.add_child(collider)
	var dark: Material = obstacle_materials.dark
	var glass: Material = obstacle_materials.glass
	var yellow: Material = obstacle_materials.yellow
	var orange: Material = obstacle_materials.orange
	var cyan: Material = obstacle_materials.cyan
	match kind:
		"cone":
			add_cylinder(body, 0.62, 1.6, Vector3(0, 0.8, 0), orange, 0.12)
			add_box(body, Vector3(1.45, 0.12, 1.45), Vector3(0, 0.06, 0), dark)
		"taxi", "car":
			var paint := yellow if kind == "taxi" else cyan
			add_box(body, Vector3(2.15, 0.65, 4.05), Vector3(0, 0.5, 0), paint)
			add_box(body, Vector3(1.82, 0.62, 1.95), Vector3(0, 1.08, 0.15), glass)
			if kind == "taxi": add_box(body, Vector3(0.62, 0.22, 0.35), Vector3(0, 1.51, 0), yellow)
			_obstacle_wheels(body, 1.12, [-1.25, 1.25], dark)
		"truck":
			add_box(body, Vector3(2.6, 2.75, 3.8), Vector3(0, 1.4, 1.15), obstacle_materials.white)
			add_box(body, Vector3(2.55, 2.1, 2.25), Vector3(0, 1.05, -2.05), orange)
			add_box(body, Vector3(2.2, 0.65, 0.08), Vector3(0, 1.48, -3.2), glass)
			_obstacle_wheels(body, 1.35, [-2.0, 1.8], dark)
		"bulldozer":
			add_box(body, Vector3(2.75, 0.75, 3.8), Vector3(0, 0.5, 0.3), yellow)
			add_box(body, Vector3(1.8, 1.45, 1.6), Vector3(0, 1.45, 0.5), glass)
			add_box(body, Vector3(3.5, 1.25, 0.28), Vector3(0, 0.72, -2.5), orange)
			for x in [-1.42, 1.42]: add_box(body, Vector3(0.42, 0.72, 4.0), Vector3(x, 0.38, 0.25), dark)
		"wrecked_bolid":
			var wreck := Node3D.new()
			wreck.position.y = 0.42
			wreck.rotation.y = 0.22
			body.add_child(wreck)
			add_box(wreck, Vector3(1.7, 0.32, 3.7), Vector3.ZERO, obstacle_materials.white)
			add_box(wreck, Vector3(0.5, 0.22, 1.55), Vector3(0, 0.18, -2.1), obstacle_materials.white)
			add_box(wreck, Vector3(2.7, 0.12, 0.55), Vector3(0, 0.02, -2.38), orange)
			add_box(wreck, Vector3(2.3, 0.16, 0.38), Vector3(0, 0.52, 1.6), dark)
			_obstacle_wheels(wreck, 1.1, [-1.2, 1.25], dark)


func _obstacle_wheels(parent: Node3D, x: float, z_values: Array, material: Material) -> void:
	for side in [-1.0, 1.0]:
		for z in z_values: add_box(parent, Vector3(0.38, 0.65, 0.75), Vector3(side * x, 0.28, float(z)), material)


func build_powerups() -> void:
	var types := ["boost", "repair", "shield", "ghost"]
	types.shuffle()
	var lanes := [-4.9, 0.0, 4.9]
	var offset := 600.0
	var index := 0
	while offset < TRACK_LENGTH - 100.0:
		var candidate := offset
		var placed := false
		for attempt in range(80):
			candidate = offset + float(attempt) * 4.0
			if candidate >= TRACK_LENGTH - 100.0:
				break
			if _powerup_offset_is_clear(candidate):
				_create_powerup(types[index % types.size()], candidate, lanes[rng.randi_range(0, 2)])
				index += 1
				placed = true
				break
		if not placed:
			push_warning("Skipped power-up near %.1fm: no obstacle-safe position was available" % offset)
		offset += rng.randf_range(1050.0, 1350.0)


func _powerup_offset_is_clear(offset: float) -> bool:
	for obstacle_value in get_tree().get_nodes_in_group("obstacle"):
		var obstacle := obstacle_value as Node3D
		if obstacle == null or not obstacle.has_meta("course_offset"):
			continue
		var separation := absf(offset - float(obstacle.get_meta("course_offset")))
		separation = minf(separation, TRACK_LENGTH - separation)
		if separation < POWERUP_OBSTACLE_CLEARANCE:
			return false
	return true


func _create_powerup(type: String, offset: float, lateral: float) -> void:
	var frame := course.sample_course(offset)
	var pickup := Area3D.new()
	pickup.name = "Powerup_%s_%d" % [type, int(offset)]
	pickup.transform = Transform3D(frame.basis, frame.origin + frame.basis.x * lateral + frame.basis.y * 1.65)
	pickup.collision_layer = 2
	pickup.collision_mask = 1
	pickup.set_meta("powerup_type", type)
	pickup.set_meta("course_offset", offset)
	pickup.set_meta("lateral_offset", lateral)
	pickup.set_meta("float_phase", rng.randf_range(0.0, TAU))
	pickup.add_to_group("powerup")
	gameplay_content.add_child(pickup)
	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	shape_node.shape = sphere
	pickup.add_child(shape_node)
	var colors := {"boost": Color("ff5c3d"), "repair": Color("5df07e"), "shield": Color("45dcff"), "ghost": Color("c96cff")}
	var material := make_material(colors[type], 0.28, 0.18)
	material.emission_enabled = true
	material.emission = colors[type]
	material.emission_energy_multiplier = 1.8
	var visual := Node3D.new()
	visual.name = "Visual"
	visual.scale = Vector3.ONE * 1.28
	pickup.add_child(visual)
	_build_powerup_icon(visual, type, material)
	pickup.body_entered.connect(_on_powerup_body_entered.bind(pickup, type))


func _build_powerup_icon(parent: Node3D, type: String, material: Material) -> void:
	var icon_color := (material as StandardMaterial3D).albedo_color
	var disc_material := make_material(icon_color.darkened(0.72), 0.35, 0.22)
	disc_material.emission_enabled = true
	disc_material.emission = icon_color.darkened(0.58)
	disc_material.emission_energy_multiplier = 0.8
	var disc := add_cylinder(parent, 0.96, 0.28, Vector3.ZERO, disc_material)
	disc.rotation.x = PI * 0.5
	var halo := MeshInstance3D.new()
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 1.02
	halo_mesh.outer_radius = 1.14
	halo_mesh.rings = 28
	halo_mesh.ring_segments = 8
	halo_mesh.material = material
	halo.mesh = halo_mesh
	halo.rotation.x = PI * 0.5
	parent.add_child(halo)
	match type:
		"boost":
			for face_z in [-0.12, 0.12]:
				add_box(parent, Vector3(0.24, 1.25, 0.12), Vector3(0, -0.12, face_z), material)
				var left := add_box(parent, Vector3(0.22, 0.86, 0.12), Vector3(-0.3, 0.46, face_z), material)
				left.rotation.z = -0.72
				var right := add_box(parent, Vector3(0.22, 0.86, 0.12), Vector3(0.3, 0.46, face_z), material)
				right.rotation.z = 0.72
		"repair":
			for face_z in [-0.12, 0.12]:
				add_box(parent, Vector3(0.28, 1.35, 0.12), Vector3(0, 0, face_z), material)
				add_box(parent, Vector3(1.35, 0.28, 0.12), Vector3(0, 0, face_z), material)
		"shield":
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.56
			torus.outer_radius = 0.82
			torus.rings = 20
			torus.ring_segments = 10
			torus.material = material
			ring.mesh = torus
			ring.rotation.x = PI * 0.5
			parent.add_child(ring)
			for face_z in [-0.12, 0.12]:
				var diamond := add_box(parent, Vector3(0.62, 0.62, 0.12), Vector3(0, 0, face_z), material)
				diamond.rotation.z = PI * 0.25
		"ghost":
			var face := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.68
			sphere.height = 1.35
			sphere.radial_segments = 16
			sphere.rings = 8
			sphere.material = material
			face.mesh = sphere
			face.scale = Vector3(1.0, 1.0, 0.36)
			parent.add_child(face)
			var eye_material := make_material(Color("090418"), 0.1, 0.3)
			for x in [-0.25, 0.25]:
				add_box(parent, Vector3(0.16, 0.2, 0.12), Vector3(x, 0.14, -0.28), eye_material)
				add_box(parent, Vector3(0.16, 0.2, 0.12), Vector3(x, 0.14, 0.28), eye_material)


func _on_powerup_body_entered(body: Node3D, pickup: Area3D, type: String) -> void:
	if body != car or not is_instance_valid(pickup): return
	collect_powerup(type)
	pickup.queue_free()


func collect_powerup(type: String) -> void:
	powerup_toast_time = 2.2
	powerup_display_type = type
	if is_instance_valid(vehicle_audio): vehicle_audio.play_powerup()
	match type:
		"boost":
			boost_time = maxf(boost_time, POWERUP_BOOST_DURATION)
			powerup_toast = "ТУРБО"
		"repair":
			durability = minf(100.0, durability + POWERUP_REPAIR_AMOUNT)
			powerup_toast = "РЕМОНТ +%d%%" % int(POWERUP_REPAIR_AMOUNT)
		"shield":
			shield_hits = 1
			powerup_toast = "ЩИТ • 1 УДАР"
		"ghost":
			ghost_time = maxf(ghost_time, POWERUP_GHOST_DURATION)
			powerup_toast = "ПРИЗРАК"


func make_label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func build_vehicle_audio() -> void:
	vehicle_audio = VehicleAudioScript.new()
	vehicle_audio.name = "VehicleAudio"
	add_child(vehicle_audio)
	vehicle_audio.set_profile(selected_car_id)


func build_countdown_audio() -> void:
	countdown_tick_audio = AudioStreamPlayer.new()
	countdown_tick_audio.name = "CountdownTick"
	countdown_tick_audio.stream = load("res://assets/audio/ui/menu_move.wav")
	countdown_tick_audio.volume_db = -2.0
	countdown_tick_audio.pitch_scale = 0.82
	countdown_tick_audio.bus = "SFX"
	add_child(countdown_tick_audio)
	countdown_go_audio = AudioStreamPlayer.new()
	countdown_go_audio.name = "CountdownGo"
	countdown_go_audio.stream = load("res://assets/audio/ui/menu_select.wav")
	countdown_go_audio.volume_db = -1.0
	countdown_go_audio.pitch_scale = 1.18
	countdown_go_audio.bus = "SFX"
	add_child(countdown_go_audio)


func build_race_music() -> void:
	# Preserve the public QA/runtime hook while the persistent controller owns
	# menu music, shuffled race playlists and the Cadillac-exclusive loop.
	race_music = _music_controller().get("player") as AudioStreamPlayer


func start_race_music() -> void:
	_music_controller().call("start_prepared_race")


func stop_race_music() -> void:
	_music_controller().call("stop")


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
	timer_label = make_label("00:00.000", 32, Color.WHITE)
	column.add_child(timer_label)
	lap_label = make_label("КРУГ 1 / 2", 18, Color("ffe45f"))
	column.add_child(lap_label)
	speed_label = make_label("0 КМ/Ч", 48, Color("67e7ff"))
	column.add_child(speed_label)
	distance_label = make_label("0 / %d М" % int(TRACK_LENGTH), 17, Color("dce5ed"))
	column.add_child(distance_label)
	fuel_title = make_label("ТОПЛИВО", 14, Color("b8c4cf"))
	column.add_child(fuel_title)
	fuel_bar = ProgressBar.new()
	fuel_bar.custom_minimum_size = Vector2(285, 22)
	fuel_bar.max_value = 100
	fuel_bar.value = fuel
	fuel_bar.show_percentage = true
	column.add_child(fuel_bar)
	var durability_title := make_label("ПРОЧНОСТЬ", 14, Color("b8c4cf"))
	column.add_child(durability_title)
	durability_bar = ProgressBar.new()
	durability_bar.custom_minimum_size = Vector2(285, 22)
	durability_bar.max_value = 100
	durability_bar.value = durability
	durability_bar.show_percentage = true
	column.add_child(durability_bar)
	powerup_status_panel = PanelContainer.new()
	powerup_status_panel.anchor_left = 0.365
	powerup_status_panel.anchor_top = 0.025
	powerup_status_panel.anchor_right = 0.635
	powerup_status_panel.anchor_bottom = 0.088
	var powerup_row := HBoxContainer.new()
	powerup_row.alignment = BoxContainer.ALIGNMENT_CENTER
	powerup_row.add_theme_constant_override("separation", 14)
	powerup_status_panel.add_child(powerup_row)
	powerup_icon_label = make_label("", 28, Color("ffe45f"))
	powerup_icon_label.custom_minimum_size = Vector2(44, 40)
	powerup_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powerup_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	powerup_row.add_child(powerup_icon_label)
	powerup_status_label = make_label("", 17, Color("f5f7ff"))
	powerup_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	powerup_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	powerup_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var effect_style := StyleBoxFlat.new()
	effect_style.bg_color = Color(0.03, 0.015, 0.1, 0.78)
	effect_style.border_color = Color("54e7ff")
	effect_style.set_border_width_all(2)
	effect_style.set_corner_radius_all(12)
	effect_style.content_margin_left = 18.0
	effect_style.content_margin_right = 18.0
	effect_style.content_margin_top = 7.0
	effect_style.content_margin_bottom = 7.0
	powerup_status_panel.add_theme_stylebox_override("panel", effect_style)
	powerup_row.add_child(powerup_status_label)
	powerup_status_panel.visible = false
	layer.add_child(powerup_status_panel)
	status_label = make_label(driving_help_text(), 16, Color("f2f4f6"))
	status_label.anchor_right = 1.0
	status_label.anchor_top = 1.0
	status_label.anchor_bottom = 1.0
	status_label.offset_top = -52.0
	status_label.offset_bottom = -18.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(status_label)
	finish_portrait = TextureRect.new()
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
	game_over_label = make_label("", 46, Color("ff526e"))
	game_over_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.visible = false
	layer.add_child(game_over_label)
	fuel_warning_panel = PanelContainer.new()
	fuel_warning_panel.anchor_left = 0.31
	fuel_warning_panel.anchor_top = 0.76
	fuel_warning_panel.anchor_right = 0.69
	fuel_warning_panel.anchor_bottom = 0.84
	fuel_warning_panel.add_theme_stylebox_override("panel", _hud_panel(Color(0.12, 0.01, 0.03, 0.82), Color("ff4f6d")))
	var fuel_warning := make_label("МАЛО ТОПЛИВА — НАЖМИТЕ F ДЛЯ ЗАПРАВКИ", 20, Color("fff0c7"))
	fuel_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fuel_warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fuel_warning_panel.add_child(fuel_warning)
	fuel_warning_panel.visible = false
	layer.add_child(fuel_warning_panel)
	refuel_panel = PanelContainer.new()
	refuel_panel.anchor_left = 0.33
	refuel_panel.anchor_top = 0.38
	refuel_panel.anchor_right = 0.67
	refuel_panel.anchor_bottom = 0.61
	refuel_panel.add_theme_stylebox_override("panel", _hud_panel(Color(0.02, 0.005, 0.08, 0.88), Color("58eaff")))
	refuel_label = make_label("", 25, Color("fff27a"))
	refuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	refuel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	refuel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	refuel_panel.add_child(refuel_label)
	refuel_panel.visible = false
	layer.add_child(refuel_panel)


func _hud_panel(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func build_game_ui() -> void:
	var map_layer := CanvasLayer.new()
	map_layer.name = "MinimapLayer"
	map_layer.layer = 20
	add_child(map_layer)
	minimap = TrackMinimapScene.instantiate() as Control
	map_layer.add_child(minimap)
	minimap.call("set_course", course)
	minimap.visible = false

	main_menu = MainMenuScene.instantiate() as CanvasLayer
	add_child(main_menu)
	main_menu.call("set_background_path", MENU_BACKGROUND_PATH)
	main_menu.connect("start_requested", Callable(self, "_open_mode_selection"))
	main_menu.call_deferred("focus_start_button")
	mode_selector = GameModeScript.new()
	add_child(mode_selector)
	mode_selector.call("set_background_path", MENU_BACKGROUND_PATH)
	mode_selector.connect("mode_confirmed", Callable(self, "_on_mode_confirmed"))
	mode_selector.connect("back_requested", Callable(self, "_return_to_main_menu"))
	car_selector = CarSelectionScene.instantiate() as CanvasLayer
	add_child(car_selector)
	car_selector.call("set_background_path", CAR_SELECTION_BACKGROUND_PATH)
	car_selector.connect("car_confirmed", Callable(self, "_on_car_confirmed"))
	car_selector.connect("back_requested", Callable(self, "_back_to_main_menu"))
	pause_menu = PauseMenuScript.new()
	add_child(pause_menu)
	pause_menu.connect("resume_requested", Callable(self, "_resume_game"))
	pause_menu.connect("main_menu_requested", Callable(self, "_return_from_pause_to_main_menu"))
	pause_menu.connect("exit_requested", Callable(self, "_exit_game"))
	results_overlay = RaceResultsScript.new()
	add_child(results_overlay)
	results_overlay.connect("restart_requested", Callable(self, "_restart_from_results"))
	results_overlay.connect("main_menu_requested", Callable(self, "_return_from_results_to_main_menu"))
	var menu_root := main_menu.get_node_or_null("Root") as CanvasItem
	if menu_root != null:
		menu_root.modulate.a = 0.0
		var menu_fade := create_tween()
		menu_fade.tween_property(menu_root, "modulate:a", 1.0, 0.8)


func _open_car_selection() -> void:
	if is_instance_valid(main_menu):
		main_menu.hide()
	if is_instance_valid(car_selector):
		car_selector.call("show_selector")


func _open_mode_selection() -> void:
	if is_instance_valid(main_menu): main_menu.hide()
	if is_instance_valid(mode_selector): mode_selector.call("show_selector")


func _on_mode_confirmed(mode: String, _enable_powerups := true, laps := 2, realistic_fueling := false) -> void:
	selected_game_mode = mode
	powerups_enabled = mode == "obstacle_course"
	selected_laps = clampi(laps, 2, 5)
	realistic_fueling_enabled = mode == "obstacle_course" and realistic_fueling
	fuel_enabled = realistic_fueling_enabled
	if is_instance_valid(mode_selector): mode_selector.hide()
	_open_car_selection()


func _back_to_main_menu() -> void:
	if is_instance_valid(car_selector):
		car_selector.hide()
	if is_instance_valid(mode_selector):
		mode_selector.call("show_selector")


func _return_to_main_menu() -> void:
	if is_instance_valid(mode_selector): mode_selector.hide()
	if is_instance_valid(main_menu):
		main_menu.show()
		main_menu.call_deferred("focus_start_button")


func _on_car_confirmed(profile_id: String, color: Color) -> void:
	apply_car_selection(profile_id, color)
	_start_game()


func apply_car_selection(profile_id: String, color: Color) -> void:
	selected_car_id = profile_id
	selected_car_color = color
	var profile: Dictionary = CarFactory.profile(profile_id)
	car_steering_mult = float(profile.steering_mult)
	car_acceleration_mult = float(profile.acceleration_mult)
	car_fuel_mult = float(profile.fuel_mult)
	car_damage_mult = float(profile.damage_mult)
	car_max_speed_mps = float(profile.max_speed_kmh) / 3.6
	base_max_speed = car_max_speed_mps
	if is_instance_valid(car_collider) and car_collider.shape is BoxShape3D:
		(car_collider.shape as BoxShape3D).size = profile.collider_size
	if is_instance_valid(car_visual):
		car_visual.queue_free()
	car_visual = CarFactory.build(car, selected_car_id, selected_car_color)
	if is_instance_valid(vehicle_audio): vehicle_audio.set_profile(selected_car_id)


func _start_game() -> void:
	if game_started:
		return
	game_started = true
	if is_instance_valid(main_menu):
		main_menu.hide()
	if is_instance_valid(car_selector):
		car_selector.hide()
	if is_instance_valid(mode_selector): mode_selector.hide()
	build_gameplay_mode()
	stop_race_music()
	reset_car()
	if is_instance_valid(vehicle_audio): vehicle_audio.set_active(true)
	minimap.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _pause_game() -> void:
	if not game_started or get_tree().paused:
		return
	camera_dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	pause_menu.call("show_pause")


func _resume_game() -> void:
	get_tree().paused = false
	if is_instance_valid(pause_menu):
		pause_menu.hide()


func _exit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


func _return_from_pause_to_main_menu() -> void:
	get_tree().paused = false
	game_started = false
	race_active = false
	speed = 0.0
	car.velocity = Vector3.ZERO
	if is_instance_valid(pause_menu): pause_menu.hide()
	if is_instance_valid(mode_selector): mode_selector.hide()
	if is_instance_valid(car_selector): car_selector.hide()
	if is_instance_valid(minimap): minimap.hide()
	refuel_pending = false
	if refuel_in_progress and is_instance_valid(refuel_request): refuel_request.cancel_request()
	refuel_in_progress = false
	refuel_request_elapsed = 0.0
	if is_instance_valid(refuel_panel): refuel_panel.hide()
	if is_instance_valid(fuel_warning_panel): fuel_warning_panel.hide()
	if is_instance_valid(results_overlay): results_overlay.hide()
	if is_instance_valid(main_menu):
		main_menu.show()
		main_menu.call_deferred("focus_start_button")
	if is_instance_valid(vehicle_audio): vehicle_audio.set_active(false)
	_music_controller().call("play_menu")


func _restart_from_results() -> void:
	if is_instance_valid(results_overlay): results_overlay.hide()
	reset_car()
	if is_instance_valid(vehicle_audio): vehicle_audio.set_active(true)


func _return_from_results_to_main_menu() -> void:
	if is_instance_valid(results_overlay): results_overlay.hide()
	_return_from_pause_to_main_menu()


func build_refuel_client() -> void:
	refuel_request = HTTPRequest.new()
	refuel_request.timeout = 75.0
	refuel_request.request_completed.connect(_on_refuel_request_completed)
	add_child(refuel_request)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(car):
		return
	if not game_started:
		speed = 0.0
		car.velocity = Vector3.ZERO
		update_camera(delta)
		update_hud()
		return
	collision_cooldown = maxf(0.0, collision_cooldown - delta)
	wall_impact_cooldown = maxf(0.0, wall_impact_cooldown - delta)
	wall_scrape_audio_time = maxf(0.0, wall_scrape_audio_time - delta)
	obstacle_slide_time = maxf(0.0, obstacle_slide_time - delta)
	boost_time = maxf(0.0, boost_time - delta)
	ghost_time = maxf(0.0, ghost_time - delta)
	powerup_toast_time = maxf(0.0, powerup_toast_time - delta)
	for pickup_value in get_tree().get_nodes_in_group("powerup"):
		var pickup := pickup_value as Area3D
		if not is_instance_valid(pickup): continue
		var visual := pickup.get_node_or_null("Visual") as Node3D
		if visual != null:
			visual.rotate_y(delta * 1.55)
			visual.position.y = sin(Time.get_ticks_msec() * 0.0022 + float(pickup.get_meta("float_phase", 0.0))) * 0.12
	refuel_cooldown = maxf(0.0, refuel_cooldown - delta)
	refuel_feedback_time = maxf(0.0, refuel_feedback_time - delta)
	if refuel_feedback_time <= 0.0 and not refuel_pending and not refuel_in_progress and is_instance_valid(refuel_panel):
		refuel_panel.hide()
	_update_refuel_sequence(delta)
	car.collision_mask = 0 if ghost_time > 0.0 else 1
	var refuel_pressed := realistic_fueling_enabled and race_active and countdown_time <= 0.0 and Input.is_key_pressed(KEY_F)
	if refuel_pressed and not refuel_key_down:
		request_refuel()
	refuel_key_down = refuel_pressed
	var debug_refill_pressed := fuel_enabled and Input.is_key_pressed(KEY_G)
	if debug_refill_pressed and not debug_refill_key_down:
		debug_refill()
	debug_refill_key_down = debug_refill_pressed
	if Input.is_key_pressed(KEY_R):
		reset_car()
	if countdown_time > 0.0:
		countdown_time = maxf(0.0, countdown_time - delta)
		var countdown_number := maxi(1, ceili(minf(countdown_time, 3.0)))
		countdown_label.text = str(countdown_number)
		if countdown_number != last_countdown_number:
			last_countdown_number = countdown_number
			if is_instance_valid(countdown_tick_audio): countdown_tick_audio.play()
		speed = 0.0
		car.velocity = Vector3.ZERO
		if countdown_time <= 0.0:
			go_flash_time = 0.8
			countdown_label.text = "СТАРТ!"
			if is_instance_valid(countdown_go_audio): countdown_go_audio.play()
			start_race_music()
	elif go_flash_time > 0.0:
		go_flash_time = maxf(0.0, go_flash_time - delta)
		countdown_label.modulate.a = clampf(go_flash_time * 2.0, 0.0, 1.0)
		if refuel_pending or refuel_in_progress:
			update_car(delta)
		else:
			elapsed += delta
			update_car(delta)
			update_progress(delta)
	elif race_active:
		countdown_label.visible = false
		if refuel_pending or refuel_in_progress:
			# Network/model latency must not affect race time or consume fuel. The car
			# remains safely stopped until the recording result arrives.
			update_car(delta)
		else:
			elapsed += delta
			update_car(delta)
			update_progress(delta)
	update_camera(delta)
	update_hud()
	if is_instance_valid(vehicle_audio):
		# Obstacles create discrete body impacts only. Continuous metal scraping is
		# reserved for sustained contact with the road boundary/walls.
		var scraping := road_edge_contacting or wall_scrape_audio_time > 0.0
		vehicle_audio.update_vehicle(speed, car_max_speed_mps, Input.is_key_pressed(KEY_W), false, scraping, delta)


func update_car(delta: float) -> void:
	if refuel_pending or refuel_in_progress:
		# Fueling pauses the run, so physics must hold the exact position as well.
		speed = 0.0
		car.velocity = Vector3.ZERO
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
	var condition_ratio := clampf(durability / 100.0, 0.0, 1.0)
	var steering_condition := lerpf(0.62, 1.0, condition_ratio)
	var steering_rate := lerpf(2.35, 0.78, speed_ratio) * car_steering_mult * steering_condition
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
			var collider := step_collision.get_collider() as Node
			if collider != null and collider.is_in_group("obstacle"):
				handle_obstacle_hit(step_collision.get_normal(), intended_motion)
				break
			# The continuous road trimesh can produce lateral normals at pitched
			# triangle seams. It is ground, not a wall, so never damage or brake here.
			elif collider != null and not collider.is_in_group("track") and not collider.is_in_group("bridge") \
					and absf(step_collision.get_normal().y) < 0.55 \
					and Vector2(step_collision.get_normal().x, step_collision.get_normal().z).length() > 0.35:
				handle_wall_hit(step_collision.get_normal(), intended_motion, delta / float(movement_steps))
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
	var soft_edge := ROAD_WIDTH * 0.48
	var hard_edge := ROAD_WIDTH * 0.88
	var touching_edge := absf(lateral_distance) > soft_edge
	var outward_axis := lateral_axis * signf(lateral_distance)
	var drive_motion := -car.global_transform.basis.z.normalized() * speed
	var outward_speed := maxf(0.0, drive_motion.dot(outward_axis)) if touching_edge else 0.0
	var scrape_speed := drive_motion.slide(outward_axis).length() if touching_edge else 0.0
	if touching_edge and scrape_speed > 6.0:
		road_edge_contact_time += delta
	else:
		road_edge_contact_time = 0.0
	if absf(lateral_distance) > hard_edge:
		# Correct only the out-of-bounds component. Keeping longitudinal position and
		# heading avoids the visible despawn/centerline respawn that used to occur.
		var edge_position := signf(lateral_distance) * soft_edge
		car.global_position -= lateral_axis * (lateral_distance - edge_position)
		handle_road_edge_contact(outward_speed, scrape_speed, delta, not road_edge_contacting, true)
		if race_active: status_label.text = "ВЫЕЗД ЗА ГРАНИЦУ | МЯГКИЙ ВОЗВРАТ НА ТРАССУ"
	elif absf(lateral_distance) > soft_edge:
		var clamped_lateral := clampf(lateral_distance, -soft_edge, soft_edge)
		car.global_position -= lateral_axis * (lateral_distance - clamped_lateral)
		handle_road_edge_contact(outward_speed, scrape_speed, delta, not road_edge_contacting, false)
	road_edge_contacting = touching_edge
	# The modular course is an arcade surface, so keep the chassis attached to its
	# analytical height. This prevents tunneling through pitched road seams.
	var target_height := center.y
	if car.global_position.y < target_height - 1.0 or car.global_position.y > target_height + 2.5:
		car.global_position.y = target_height
		car.velocity.y = 0.0
	else:
		car.global_position.y = lerpf(car.global_position.y, target_height, 1.0 - exp(-delta * 24.0))


func compute_drive_speed(current_speed: float, throttle: float, reverse_pressed: bool, hard_braking: bool, progress: float, delta: float) -> float:
	# Acceleration controls time-to-cap; max speed is a genuine per-car limit.
	var condition_ratio := clampf(durability / 100.0, 0.0, 1.0)
	var active_max_speed := car_max_speed_mps * lerpf(0.58, 1.0, condition_ratio)
	var acceleration := (18.0 + progress * 3.0) * car_acceleration_mult * lerpf(0.72, 1.0, condition_ratio)
	if boost_time > 0.0 and not road_edge_contacting:
		acceleration *= BOOST_ACCELERATION_MULTIPLIER
		active_max_speed *= BOOST_MAX_SPEED_MULTIPLIER
	if fuel_enabled and fuel <= 0.0:
		throttle = minf(throttle, 0.35)
	if throttle > 0.0:
		current_speed = move_toward(current_speed, 0.0, 34.0 * delta) if current_speed < 0.0 else move_toward(current_speed, active_max_speed, acceleration * delta)
	elif reverse_pressed:
		# S brakes forward motion first and only selects reverse near a standstill.
		current_speed = move_toward(current_speed, 0.0, 42.0 * delta) if current_speed > 0.5 else move_toward(current_speed, -15.0, 11.0 * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, 5.5 * delta)
	if hard_braking:
		current_speed = move_toward(current_speed, 0.0, 55.0 * delta)
	return clampf(current_speed, -15.0, active_max_speed)


func handle_obstacle_hit(normal := Vector3.ZERO, _incoming := Vector3.ZERO) -> void:
	var flat_normal := Vector3(normal.x, 0.0, normal.z)
	if flat_normal.length_squared() > 0.001:
		obstacle_block_normal = flat_normal.normalized()
	if collision_cooldown > 0.0:
		obstacle_slide_time = maxf(obstacle_slide_time, 0.25)
		return
	collision_cooldown = 0.55 + 0.35 * car_damage_mult
	obstacle_slide_time = 0.72 + 0.18 * car_damage_mult
	var damaged := apply_vehicle_damage(15.0, "ПРЕПЯТСТВИЕ")
	if is_instance_valid(vehicle_audio): vehicle_audio.play_impact(clampf(absf(speed) / maxf(car_max_speed_mps, 1.0), 0.2, 1.0), true)
	if damaged:
		speed *= lerpf(0.18, 0.55, clampf((1.25 - car_damage_mult) / 0.95, 0.0, 1.0))
		car.velocity = Vector3.ZERO
		if race_active: status_label.text = "СТОЛКНОВЕНИЕ | ПРОЧНОСТЬ %d%%" % int(durability)
	else:
		speed *= 0.78


func handle_wall_hit(normal := Vector3.ZERO, incoming := Vector3.ZERO, delta := 1.0 / 60.0) -> void:
	var flat_normal := Vector3(normal.x, 0.0, normal.z)
	if flat_normal.length_squared() <= 0.01: return
	flat_normal = flat_normal.normalized()
	obstacle_block_normal = flat_normal
	obstacle_slide_time = 0.42
	var impact_speed := maxf(0.0, -incoming.dot(flat_normal))
	var scrape_speed := incoming.slide(flat_normal).length()
	if scrape_speed > 2.0:
		# Collision callbacks can alternate between wall and floor triangles. Hold
		# the scrape briefly so those one-frame gaps do not cut the audio out.
		wall_scrape_audio_time = 0.16
	handle_road_edge_contact(impact_speed, scrape_speed, delta, wall_impact_cooldown <= 0.0, false)


func handle_road_edge_contact(impact_speed: float, scrape_speed: float, delta: float, new_contact: bool, hard_edge: bool) -> void:
	# Damage is driven by the velocity into the wall, while a shallow slide causes
	# much lighter damage over time. Neither path applies percentage-per-frame
	# braking, which was able to overpower acceleration and make the car stop.
	if new_contact and impact_speed > 2.0 and wall_impact_cooldown <= 0.0:
		var impact_damage := clampf(1.0 + impact_speed * 0.11 + (2.0 if hard_edge else 0.0), 1.5, 24.0)
		if apply_vehicle_damage(impact_damage, "СТЕНА"):
			# Most real wall contacts are 5-45 m/s into the normal. Mapping against
			# 95 m/s forced nearly all of them to the same light thud.
			if is_instance_valid(vehicle_audio): vehicle_audio.play_impact(clampf(impact_speed / 45.0, 0.08, 1.0))
			var retention := lerpf(0.96, 0.68, clampf(impact_speed / 100.0, 0.0, 1.0))
			speed *= retention
			if race_active: status_label.text = "УДАР О СТЕНУ | ПРОЧНОСТЬ %d%%" % int(durability)
		wall_impact_cooldown = 0.22
	if scrape_speed > 2.0:
		var scrape_ratio := clampf(scrape_speed / 120.0, 0.0, 1.0)
		var scrape_damage := lerpf(0.35, 2.4, scrape_ratio) * maxf(delta, 0.0)
		if apply_continuous_vehicle_damage(scrape_damage, "ТРЕНИЕ О СТЕНУ"):
			var scrape_drag := lerpf(0.25, 2.4, scrape_ratio)
			speed = signf(speed) * maxf(0.0, absf(speed) - scrape_drag * maxf(delta, 0.0))
			if race_active: status_label.text = "ТРЕНИЕ О СТЕНУ | ПРОЧНОСТЬ %d%%" % int(durability)
	if road_edge_contact_time >= WALL_SLIDE_PENALTY_DELAY:
		# Riding the boundary must never become a faster alternative to steering.
		# After a short grace period, pull speed firmly toward a safe sliding cap.
		var slide_cap := minf(WALL_SLIDE_SPEED_CAP, car_max_speed_mps * 0.42)
		if absf(speed) > slide_cap:
			var penalized_speed := move_toward(absf(speed), slide_cap, 115.0 * maxf(delta, 0.0))
			speed = signf(speed) * penalized_speed
		if race_active: status_label.text = "ДОЛГИЙ КОНТАКТ СО СТЕНОЙ | СКОРОСТЬ СНИЖЕНА"


func apply_continuous_vehicle_damage(base_damage: float, _source: String) -> bool:
	if ghost_time > 0.0 or base_damage <= 0.0:
		return false
	if shield_hits > 0:
		shield_hits -= 1
		collision_count += 1
		status_label.text = "ТРЕНИЕ О СТЕНУ | ЩИТ ПОГЛОТИЛ УДАР"
		return false
	var actual_damage := base_damage * car_damage_mult
	var durability_before := durability
	durability = maxf(0.0, durability - actual_damage)
	damage_sustained += durability_before - durability
	if durability <= 0.0: wreck_car()
	return true


func apply_vehicle_damage(base_damage: float, source: String) -> bool:
	if ghost_time > 0.0:
		status_label.text = "%s | РЕЖИМ ПРИЗРАКА" % source
		return false
	if shield_hits > 0:
		shield_hits -= 1
		collision_count += 1
		status_label.text = "%s | ЩИТ ПОГЛОТИЛ УДАР" % source
		return false
	collision_count += 1
	var durability_before := durability
	durability = maxf(0.0, durability - base_damage * car_damage_mult)
	damage_sustained += durability_before - durability
	if durability <= 0.0:
		wreck_car()
	return true


func wreck_car() -> void:
	_finish_race(false, "МАШИНА РАЗБИТА")


func update_progress(delta: float) -> void:
	var previous_offset := course_offset
	var next_offset := course.closest_offset_local(car.global_position, course_offset, clampf(80.0 + absf(speed), 80.0, 260.0), 4.0)
	var offset_delta := next_offset - previous_offset
	if offset_delta > TRACK_LENGTH * 0.5:
		offset_delta -= TRACK_LENGTH
	elif offset_delta < -TRACK_LENGTH * 0.5:
		offset_delta += TRACK_LENGTH
	course_offset = next_offset
	distance = maxf(0.0, distance + offset_delta)
	if fuel_enabled:
		fuel = maxf(0.0, fuel - delta * (0.42 + clampf(distance / TRACK_LENGTH, 0.0, 1.0) * 0.18) * car_fuel_mult)
		if fuel <= 0.0:
			_finish_race(false, "ТОПЛИВО ЗАКОНЧИЛОСЬ")
			return
	if distance >= TRACK_LENGTH - 2.0:
		_complete_lap()


func _complete_lap() -> void:
	var lap_time := maxf(0.001, elapsed - lap_start_time)
	lap_times.append(lap_time)
	lap_average_speeds.append(TRACK_LENGTH / lap_time * 3.6)
	if current_lap >= selected_laps:
		_finish_race(true, "ФИНИШ!")
		return
	current_lap += 1
	lap_start_time = elapsed
	distance = 0.0
	status_label.text = "КРУГ %d / %d | ПРЕДЫДУЩИЙ %s" % [current_lap, selected_laps, format_time(lap_time)]


func _finish_race(completed: bool, reason: String) -> void:
	if not race_active: return
	race_active = false
	speed = 0.0
	car.velocity = Vector3.ZERO
	refuel_pending = false
	if refuel_in_progress and is_instance_valid(refuel_request): refuel_request.cancel_request()
	refuel_in_progress = false
	refuel_request_elapsed = 0.0
	if is_instance_valid(refuel_panel): refuel_panel.hide()
	if is_instance_valid(fuel_warning_panel): fuel_warning_panel.hide()
	finish_portrait.visible = completed and finish_portrait.texture != null
	status_label.text = reason
	if is_instance_valid(vehicle_audio): vehicle_audio.set_active(false)
	stop_race_music()
	if is_instance_valid(results_overlay):
		results_overlay.call("show_results", lap_times, lap_average_speeds, collision_count, damage_sustained, elapsed, completed)


func update_camera(delta: float) -> void:
	var basis := car.global_transform.basis
	# The normal chase rig is intentionally high, but that clearance was marginal
	# beneath the tunnel roof and could put the camera inside a portal/ceiling panel
	# on the entrance grades. Use a closer, lower rig for the complete tunnel zone.
	var in_tunnel := course.zone_at(course_offset) == "underwater_tunnel"
	var camera_distance := 8.4 if in_tunnel else 10.5
	var base_height := 4.15 if in_tunnel else 5.2
	var allowed_extra_height := clampf(camera_extra_height, -0.8, 0.0) if in_tunnel else camera_extra_height
	var orbit_back := basis.z.rotated(Vector3.UP, camera_orbit_yaw)
	var target_position := car.global_position + orbit_back * camera_distance + Vector3.UP * (base_height + allowed_extra_height)
	chase_camera.global_position = chase_camera.global_position.lerp(target_position, 1.0 - exp(-delta * 11.0))
	var look_target := car.global_position - orbit_back * 3.2 + Vector3.UP * (0.55 + allowed_extra_height * 0.18)
	chase_camera.look_at(look_target, Vector3.UP)
	var before := course.tangent_at(course_offset - 8.0)
	var after := course.tangent_at(course_offset + 8.0)
	var curve_bank := clampf(atan2(before.cross(after).y, before.dot(after)) * 0.35, -0.16, 0.16)
	chase_camera.rotate_object_local(Vector3.BACK, curve_bank)


func update_hud() -> void:
	speed_label.text = ("ЗАД %03d КМ/Ч" % int(absf(speed) * 3.6)) if speed < -0.5 else ("%03d КМ/Ч" % int(speed * 3.6))
	timer_label.text = format_time(elapsed)
	lap_label.text = "КРУГ %d / %d   •   %s" % [current_lap, selected_laps, format_time(maxf(0.0, elapsed - lap_start_time))]
	distance_label.text = "%04d / %d М" % [int(distance), int(TRACK_LENGTH)]
	fuel_title.visible = fuel_enabled
	fuel_bar.visible = fuel_enabled
	fuel_bar.value = fuel
	if is_instance_valid(fuel_warning_panel):
		fuel_warning_panel.visible = realistic_fueling_enabled and race_active and fuel <= 15.0 and not refuel_pending and not refuel_in_progress
	durability_bar.value = durability
	if is_instance_valid(minimap):
		minimap.call("set_player_distance", course_offset, TRACK_LENGTH)
	if fuel < 22.0:
		fuel_bar.modulate = Color("ff5a5f")
	elif fuel < 50.0:
		fuel_bar.modulate = Color("ffd45a")
	else:
		fuel_bar.modulate = Color("67ef9a")
	if durability < 25.0:
		durability_bar.modulate = Color("ff405c")
	elif durability < 55.0:
		durability_bar.modulate = Color("ffb84d")
	else:
		durability_bar.modulate = Color("59e7ff")
	var effect_text := ""
	var effect_icon := ""
	# A newly collected effect owns the tab briefly, even if another timed effect
	# is already active. Afterwards the tab falls back to the active timer.
	if powerup_toast_time > 0.0 and not powerup_toast.is_empty():
		match powerup_display_type:
			"boost": effect_icon = "⚡"; effect_text = "ТУРБО • %.1f С" % boost_time
			"repair": effect_icon = "+"; effect_text = powerup_toast
			"shield": effect_icon = "◆"; effect_text = "ЩИТ • %d УДАР" % shield_hits
			"ghost": effect_icon = "◉"; effect_text = "ПРИЗРАК • %.1f С" % ghost_time
	elif boost_time > 0.0:
		effect_icon = "⚡"; effect_text = "ТУРБО • %.1f С" % boost_time
	elif ghost_time > 0.0:
		effect_icon = "◉"; effect_text = "ПРИЗРАК • %.1f С" % ghost_time
	elif shield_hits > 0:
		effect_icon = "◆"; effect_text = "ЩИТ • %d УДАР" % shield_hits
	powerup_icon_label.text = effect_icon
	powerup_status_label.text = effect_text
	powerup_status_panel.visible = not effect_text.is_empty()


func format_time(value: float) -> String:
	var minutes := int(value) / 60
	var seconds := int(value) % 60
	var millis := int(fmod(value, 1.0) * 1000.0)
	return "%02d:%02d.%03d" % [minutes, seconds, millis]


func driving_help_text() -> String:
	if fuel_enabled:
		return "WASD — ЕЗДА | ПРОБЕЛ — ТОРМОЗ | ПКМ — КАМЕРА | O/P — МУЗЫКА | ESC — ПАУЗА | F — ЗАПРАВКА | G — ПОЛНЫЙ БАК | R — СБРОС"
	return "WASD — ЕЗДА | ПРОБЕЛ — ТОРМОЗ | ПКМ — КАМЕРА | O/P — МУЗЫКА | ESC — ПАУЗА | R — СБРОС"


func reset_car() -> void:
	stop_race_music()
	_music_controller().call("prepare_race", selected_car_id)
	var start_frame := course.sample_course(0.0)
	car.global_position = start_position
	car.global_transform.basis = start_frame.basis
	car.velocity = Vector3.ZERO
	speed = 0.0
	fuel = 100.0
	durability = 100.0
	elapsed = 0.0
	distance = 0.0
	course_offset = 0.0
	current_lap = 1
	lap_start_time = 0.0
	lap_times.clear()
	lap_average_speeds.clear()
	collision_count = 0
	damage_sustained = 0.0
	shield_hits = 0
	boost_time = 0.0
	ghost_time = 0.0
	powerup_toast = ""
	powerup_toast_time = 0.0
	powerup_display_type = ""
	collision_cooldown = 0.0
	wall_impact_cooldown = 0.0
	wall_scrape_audio_time = 0.0
	road_edge_contacting = false
	road_edge_contact_time = 0.0
	obstacle_slide_time = 0.0
	obstacle_block_normal = Vector3.ZERO
	race_active = true
	game_over_label.visible = false
	finish_portrait.visible = false
	status_label.text = driving_help_text()
	refuel_in_progress = false
	refuel_pending = false
	refuel_countdown_time = 0.0
	refuel_request_elapsed = 0.0
	refuel_cooldown = 0.0
	countdown_time = 3.2
	last_countdown_number = 0
	go_flash_time = 0.0
	countdown_label.visible = true
	countdown_label.modulate.a = 1.0
	countdown_label.text = "3"
	if is_instance_valid(results_overlay): results_overlay.hide()
	if is_instance_valid(refuel_panel): refuel_panel.hide()
	if is_instance_valid(fuel_warning_panel): fuel_warning_panel.hide()


# Public hook for the webcam/Gemini service integration. Realistic fueling is
# deliberately binary: a confirmed drinking gesture adds fuel, never a buff.
func apply_drink_result(_color_name := "unknown") -> void:
	fuel = minf(100.0, fuel + 40.0)
	status_label.text = "ЗАПРАВКА ПОДТВЕРЖДЕНА | ТОПЛИВО +40%"


func debug_refill() -> void:
	fuel = 100.0
	status_label.text = "ТЕСТОВАЯ ЗАПРАВКА | ТОПЛИВО 100%"


func request_refuel() -> void:
	if not realistic_fueling_enabled or not race_active:
		return
	if refuel_in_progress:
		status_label.text = "ГОНОЧНЫЙ ЦЕНТР УЖЕ АНАЛИЗИРУЕТ ВИДЕО..."
		return
	if refuel_cooldown > 0.0:
		status_label.text = "СИСТЕМА ЗАПРАВКИ ОХЛАЖДАЕТСЯ"
		return
	refuel_pending = true
	refuel_countdown_time = 3.0
	refuel_feedback_time = 0.0
	speed = 0.0
	car.velocity = Vector3.ZERO
	obstacle_slide_time = 0.0
	road_edge_contact_time = 0.0
	refuel_panel.visible = true
	refuel_label.text = "ПОДГОТОВЬТЕ КАНИСТРУ\nЗАПИСЬ НАЧНЁТСЯ ЧЕРЕЗ 3"
	status_label.text = "ПОДГОТОВКА К ЗАПРАВКЕ"


func _update_refuel_sequence(delta: float) -> void:
	if refuel_in_progress:
		refuel_request_elapsed += delta
		if refuel_request_elapsed < REFUEL_CAPTURE_SECONDS:
			var recording_left := maxi(1, ceili(REFUEL_CAPTURE_SECONDS - refuel_request_elapsed))
			refuel_label.text = "ИДЁТ ЗАПИСЬ — ПЕЙТЕ СЕЙЧАС\nОСТАЛОСЬ %d СЕКУНД" % recording_left
		else:
			var dots := ".".repeat(1 + int(refuel_request_elapsed * 2.0) % 3)
			refuel_label.text = "GEMINI АНАЛИЗИРУЕТ ВИДЕО%s\nПОЖАЛУЙСТА, ПОДОЖДИТЕ" % dots
			status_label.text = "ОЖИДАНИЕ ОТВЕТА GEMINI..."
		return
	if not refuel_pending:
		return
	refuel_countdown_time = maxf(0.0, refuel_countdown_time - delta)
	var seconds_left := maxi(1, ceili(refuel_countdown_time))
	refuel_label.text = "ПОДГОТОВЬТЕ КАНИСТРУ\nЗАПИСЬ НАЧНЁТСЯ ЧЕРЕЗ %d" % seconds_left
	if refuel_countdown_time <= 0.0:
		refuel_pending = false
		_begin_refuel_request()


func _begin_refuel_request() -> void:
	refuel_in_progress = true
	refuel_request_elapsed = 0.0
	refuel_panel.visible = true
	refuel_label.text = "ИДЁТ ЗАПИСЬ — ПЕЙТЕ СЕЙЧАС\nОСТАЛОСЬ 5 СЕКУНД"
	status_label.text = "ЗАПИСЬ ВИДЕО ДЛЯ ЗАПРАВКИ..."
	var error := refuel_request.request(
		"http://127.0.0.1:8765/analyze-drink",
		PackedStringArray(["Accept: application/json"]),
		HTTPClient.METHOD_POST,
		""
	)
	if error != OK:
		refuel_in_progress = false
		refuel_request_elapsed = 0.0
		_show_refuel_error("HTTPRequest could not start (error %d)" % error)
		status_label.text = "СЕРВИС ЗАПРАВКИ НЕДОСТУПЕН | ЗАПУСТИТЕ PYTHON-СЕРВИС"


func _on_refuel_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	refuel_in_progress = false
	refuel_request_elapsed = 0.0
	refuel_cooldown = 8.0
	refuel_panel.visible = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var raw_body := body.get_string_from_utf8()
		var detail := raw_body
		var error_report: Variant = JSON.parse_string(raw_body)
		if error_report is Dictionary:
			detail = str((error_report as Dictionary).get("detail", raw_body))
		_show_refuel_error("HTTP %d / result %d\n%s" % [response_code, result, detail])
		status_label.text = "ОШИБКА GEMINI | ТОПЛИВО НЕ ДОБАВЛЕНО"
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_show_refuel_error("Invalid JSON response\n%s" % body.get_string_from_utf8())
		status_label.text = "НЕВЕРНЫЙ ОТЧЁТ О ТОПЛИВЕ | ПОПРОБУЙТЕ ЕЩЁ РАЗ"
		return
	var report: Dictionary = parsed
	if not bool(report.get("drinking_detected", false)):
		status_label.text = "НАПИТОК НЕ ОБНАРУЖЕН | ПОПРОБУЙТЕ ЕЩЁ РАЗ"
		return
	apply_drink_result()


func _show_refuel_error(detail: String) -> void:
	var safe_detail := detail.strip_edges()
	if safe_detail.is_empty():
		safe_detail = "No error details were returned by the fueling service."
	push_error("Fueling failed: %s" % safe_detail)
	refuel_feedback_time = 12.0
	refuel_panel.visible = true
	refuel_label.text = "ЗАПРАВКА НЕ УДАЛАСЬ\n%s" % safe_detail.left(700)
