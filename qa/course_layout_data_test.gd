extends SceneTree

const CourseLayoutScript := preload("res://scripts/course_layout.gd")
const EXPECTED_ZONES := [
	"start_coast", "loop_1", "underwater_tunnel", "loop_2", "bridge",
	"party_town", "city_centre", "loop_3_lower", "loop_3_upper",
	"shopping_alley", "sport_complex", "north_coast", "party_island_view"
]

var failures: Array[String] = []


func _initialize() -> void:
	var layout: RefCounted = CourseLayoutScript.load_default()
	check(layout != null, "default course layout loads")
	if layout == null:
		finish()
		return
	var length: float = layout.call("length")
	check(length > 1000.0, "map control points bake into a substantial lap")
	check(bool(layout.call("is_closed")), "layout is explicitly closed")
	var start := layout.call("point_at", 0.0) as Vector3
	var finish := layout.call("point_at", length) as Vector3
	check(start.distance_to(finish) < 0.01, "distance sampling wraps exactly at start/finish")
	var zones: Array = layout.get("course_zones")
	var names: Array[String] = []
	for zone in zones:
		if zone is Dictionary:
			names.append(String(zone.name))
	var previous := -1
	for expected in EXPECTED_ZONES:
		var index := names.find(expected)
		check(index >= 0, "layout includes zone: " + expected)
		if index >= 0:
			check(index > previous, "layout zone order is stable: " + expected)
			previous = index
	check(not names.has("party_island"), "Party Island remains an off-track landmark")
	var landmarks: Array = layout.get("landmarks")
	check(not landmarks.is_empty() and bool((landmarks[0] as Dictionary).get("off_track", false)), "Party Island landmark is marked off-track")

	var max_step := 0.0
	var previous_point := start
	var offset := 10.0
	while offset <= length:
		var point := layout.call("point_at", offset) as Vector3
		max_step = maxf(max_step, point.distance_to(previous_point))
		previous_point = point
		offset += 10.0
	check(max_step < 12.0, "baked racing line has no discontinuities")

	# The local closest-point search must stay on the hinted branch at Loop 3's
	# vertically separated crossing, even when another branch is close in X/Z.
	var lower_zone := find_zone(zones, "loop_3_lower")
	var upper_zone := find_zone(zones, "loop_3_upper")
	if not lower_zone.is_empty() and not upper_zone.is_empty():
		var lower_offset := midpoint(lower_zone)
		var upper_offset := midpoint(upper_zone)
		var lower_point := layout.call("point_at", lower_offset) as Vector3
		var recovered_lower: float = layout.call("closest_offset_local", lower_point, lower_offset, 90.0, 4.0)
		var incorrectly_upper: float = circular_distance(recovered_lower, upper_offset, length)
		check(circular_distance(recovered_lower, lower_offset, length) < 3.0, "local progress search recovers the hinted Loop 3 branch")
		check(incorrectly_upper > 8.0, "Loop 3 branch search does not jump to the overpass")
	finish()


func find_zone(zones: Array, name: String) -> Dictionary:
	for zone in zones:
		if zone is Dictionary and String(zone.get("name", "")) == name:
			return zone
	return {}


func midpoint(zone: Dictionary) -> float:
	return (float(zone.start_distance) + float(zone.end_distance)) * 0.5


func circular_distance(a: float, b: float, length: float) -> float:
	var direct := absf(a - b)
	return minf(direct, length - direct)


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func finish() -> void:
	if failures.is_empty():
		print("COURSE LAYOUT DATA QA: PASS")
		quit(0)
	else:
		print("COURSE LAYOUT DATA QA: FAIL (%d issues)" % failures.size())
		quit(1)
