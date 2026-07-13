extends SceneTree

const QAUtil := preload("res://qa/map_course_qa_util.gd")
const ROAD_SAMPLE_SPACING := 30.0
const RAIL_SAMPLE_SPACING := 10.0
const REQUIRED_ZONE_ORDER := [
	"start", "loop 1", "underwater tunnel", "loop 2", "bridge",
	"party town", "city centre", "loop 3", "shopping alley", "sport complex"
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "production scene loads")
	if packed == null:
		quit(1)
		return
	var race := packed.instantiate()
	root.add_child(race)
	await physics_frame
	await physics_frame

	var curve := QAUtil.find_course_curve(race)
	check(curve != null, "map-driven Curve3D is exposed")
	if curve == null:
		_finish()
		return
	var length := curve.get_baked_length()
	check(length > 1000.0, "course has a substantial baked lap length")
	var start := QAUtil.course_position(race, curve, 0.0)
	var finish := QAUtil.course_position(race, curve, length)
	check(start.distance_to(finish) < 3.0, "course racing line closes at start/finish")

	var zones := QAUtil.course_zones(race)
	check(zones.size() >= REQUIRED_ZONE_ORDER.size(), "course exposes named map zones")
	check_zone_order(zones)
	check_loop_geometry(race, curve, zones, length)
	check_special_elevations(race, curve, zones, length)
	check_rail_continuity(race, curve, length)
	await check_road_coverage(race, curve, length)
	check(get_nodes_in_group("obstacle").is_empty(), "map-validation build has zero obstacles")
	_finish()


func check_zone_order(zones: Array) -> void:
	var previous_index := -1
	for required in REQUIRED_ZONE_ORDER:
		var found_index := -1
		for index in range(zones.size()):
			if not zones[index] is Dictionary:
				continue
			var name := QAUtil.normalized_zone_name(QAUtil.zone_name(zones[index]))
			if name.contains(required):
				found_index = index
				break
		check(found_index >= 0, "zone exists: " + required)
		if found_index >= 0:
			check(found_index > previous_index, "zone follows map lap order: " + required)
			previous_index = found_index
	check(QAUtil.find_zone(zones, "party island").is_empty(), "Party Island is not part of the racing-line zone sequence")


func check_loop_geometry(race: Node, curve: Curve3D, zones: Array, length: float) -> void:
	for loop_name in ["loop 1", "loop 2", "loop 3"]:
		var zone := QAUtil.find_zone(zones, loop_name)
		if zone.is_empty():
			continue
		var from := QAUtil.zone_start(zone, length)
		var to := QAUtil.zone_end(zone, length)
		var arc_length := to - from
		check(arc_length > 80.0, loop_name + " has driveable length")
		if arc_length <= 0.0:
			continue
		var min_x := INF
		var max_x := -INF
		var min_z := INF
		var max_z := -INF
		var total_turn := 0.0
		var previous := QAUtil.course_tangent(race, curve, from)
		for sample_index in range(1, 49):
			var offset := lerpf(from, to, sample_index / 48.0)
			var point := QAUtil.course_position(race, curve, offset)
			min_x = minf(min_x, point.x)
			max_x = maxf(max_x, point.x)
			min_z = minf(min_z, point.z)
			max_z = maxf(max_z, point.z)
			var tangent := QAUtil.course_tangent(race, curve, offset)
			total_turn += absf(atan2(previous.cross(tangent).y, previous.dot(tangent)))
			previous = tangent
		check(max_x - min_x > 20.0 and max_z - min_z > 20.0, loop_name + " spans both map axes")
		check(total_turn > PI * 1.3, loop_name + " visibly changes heading around a circle")


func check_special_elevations(race: Node, curve: Curve3D, zones: Array, length: float) -> void:
	var tunnel := QAUtil.find_zone(zones, "underwater tunnel")
	var bridge := QAUtil.find_zone(zones, "bridge")
	if tunnel.is_empty() or bridge.is_empty():
		return
	var tunnel_low := INF
	var bridge_high := -INF
	for sample_index in range(17):
		var ratio := sample_index / 16.0
		var tunnel_distance := lerpf(QAUtil.zone_start(tunnel, length), QAUtil.zone_end(tunnel, length), ratio)
		var bridge_distance := lerpf(QAUtil.zone_start(bridge, length), QAUtil.zone_end(bridge, length), ratio)
		tunnel_low = minf(tunnel_low, QAUtil.course_position(race, curve, tunnel_distance).y)
		bridge_high = maxf(bridge_high, QAUtil.course_position(race, curve, bridge_distance).y)
	check(tunnel_low < -0.5, "underwater tunnel descends below the waterline")
	check(bridge_high > 4.0, "bridge rises visibly above open water")
	check(bridge_high - tunnel_low > 6.0, "bridge and tunnel have distinct elevation silhouettes")


func check_rail_continuity(race: Node, curve: Curve3D, length: float) -> void:
	var previous := QAUtil.course_position(race, curve, 0.0)
	var max_step := 0.0
	var checked := 0
	var offset := RAIL_SAMPLE_SPACING
	while offset <= length:
		var point := QAUtil.course_position(race, curve, offset)
		max_step = maxf(max_step, previous.distance_to(point))
		previous = point
		checked += 1
		offset += RAIL_SAMPLE_SPACING
	check(checked > 100, "full-lap rail traversal sampled the entire curve")
	check(max_step < RAIL_SAMPLE_SPACING * 1.8, "full-lap racing line has no teleport gaps")


func check_road_coverage(race: Node, curve: Curve3D, length: float) -> void:
	var car := race.get_node_or_null("PlayerCar") as CollisionObject3D
	if car != null:
		car.collision_layer = 0
	await physics_frame
	var space := root.world_3d.direct_space_state
	var misses := 0
	var checked := 0
	var offset := 0.0
	while offset < length:
		var point := QAUtil.course_position(race, curve, offset)
		var up := QAUtil.course_up(race, curve, offset)
		var query := PhysicsRayQueryParameters3D.create(point + up * 3.0, point - up * 3.0, 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			misses += 1
		else:
			var collider := hit.get("collider") as Node
			if collider == null or not (collider.is_in_group("track") or collider.is_in_group("bridge")):
				misses += 1
		checked += 1
		offset += ROAD_SAMPLE_SPACING
	check(checked > 50, "road collider coverage sampled the full lap")
	check(misses == 0, "every racing-line sample has road collision (%d misses)" % misses)


func _finish() -> void:
	if failures.is_empty():
		print("MAP COURSE QA: PASS")
		quit(0)
	else:
		print("MAP COURSE QA: FAIL (%d issues)" % failures.size())
		quit(1)
