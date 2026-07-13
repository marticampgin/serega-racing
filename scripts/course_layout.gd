class_name CourseLayout
extends RefCounted

## Deterministic, map-driven closed course with arc-length queries.
##
## The JSON control points are smoothed as a closed Catmull-Rom spline and
## baked into short linear samples. Distances accepted and returned by this
## class are metres along the racing line, not a world-axis coordinate.

const DEFAULT_DATA_PATH := "res://data/course_layout.json"

var course_name := ""
var road_half_width := 9.0
var landmarks: Array[Dictionary] = []
var course_curve: Curve3D = Curve3D.new()
var course_zones: Array[Dictionary] = []

var _closed := true
var _world_scale := 1.0
var _bake_interval := 4.0
var _controls: Array[Vector3] = []
var _control_zones: Array[String] = []
var _sample_points: PackedVector3Array = PackedVector3Array()
var _sample_offsets: PackedFloat32Array = PackedFloat32Array()
var _sample_zones: PackedStringArray = PackedStringArray()
var _length := 0.0


static func load_default() -> CourseLayout:
	var layout := CourseLayout.new()
	var error := layout.load_from_file(DEFAULT_DATA_PATH)
	assert(error == OK, "Unable to load default course layout: %s" % error_string(error))
	return layout


func load_from_file(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return ERR_PARSE_ERROR
	var data: Dictionary = parsed
	if not data.has("points") or not data["points"] is Array:
		return ERR_INVALID_DATA

	course_name = str(data.get("name", "Untitled course"))
	_closed = bool(data.get("closed", true))
	_world_scale = float(data.get("world_scale", 1.0))
	_bake_interval = maxf(0.5, float(data.get("bake_interval", 4.0)))
	road_half_width = float(data.get("road_half_width", 9.0))
	landmarks.clear()
	for landmark: Variant in data.get("landmarks", []):
		if landmark is Dictionary:
			landmarks.append(landmark)

	_controls.clear()
	_control_zones.clear()
	for entry: Variant in data["points"]:
		if not entry is Dictionary:
			return ERR_INVALID_DATA
		var point_data: Variant = entry.get("position", [])
		if not point_data is Array or point_data.size() != 3:
			return ERR_INVALID_DATA
		_controls.append(Vector3(
			float(point_data[0]) * _world_scale,
			float(point_data[1]),
			float(point_data[2]) * _world_scale
		))
		_control_zones.append(str(entry.get("zone", "unmarked_coast")))
	if _controls.size() < 4:
		return ERR_INVALID_DATA
	_bake()
	return OK


func length() -> float:
	return _length


func is_closed() -> bool:
	return _closed


func point_at(offset: float) -> Vector3:
	if _sample_points.is_empty():
		return Vector3.ZERO
	var location := _sample_location(offset)
	var index: int = location.x as int
	return _sample_points[index].lerp(_sample_points[index + 1], location.y)


func tangent_at(offset: float, look_ahead := 2.0) -> Vector3:
	var span := maxf(0.1, look_ahead)
	var tangent := point_at(offset + span) - point_at(offset - span)
	if tangent.length_squared() < 0.000001:
		return Vector3.FORWARD
	return tangent.normalized()


func lateral_at(offset: float) -> Vector3:
	## Returns the course-right vector, kept horizontal for road generation.
	var forward := tangent_at(offset)
	var lateral := forward.cross(Vector3.UP)
	if lateral.length_squared() < 0.000001:
		return Vector3.RIGHT
	return lateral.normalized()


func heading_at(offset: float) -> float:
	## Godot yaw that points a Node3D's local -Z axis along the course tangent.
	var forward := tangent_at(offset)
	return atan2(-forward.x, -forward.z)


func height_at(offset: float) -> float:
	return point_at(offset).y


func sample_course(offset: float) -> Transform3D:
	## A road frame whose local -Z points forward and local +X points right.
	var forward := tangent_at(offset)
	var right := lateral_at(offset)
	var up := right.cross(forward).normalized()
	return Transform3D(Basis(right, up, -forward).orthonormalized(), point_at(offset))


func course_transform(offset: float) -> Transform3D:
	## Alias retained for callers that use noun-first query naming.
	return sample_course(offset)


func zone_at(offset: float) -> String:
	if _sample_zones.is_empty():
		return ""
	var location := _sample_location(offset)
	var index: int = location.x as int
	return _sample_zones[index if location.y < 0.5 else index + 1]


func closest_offset_local(world_position: Vector3, hint_offset: float, search_radius := 120.0, coarse_step := 6.0) -> float:
	## Finds the closest racing-line offset near a known progress hint. This local
	## search deliberately avoids jumping between branches at Loop 3's crossing.
	if _length <= 0.0:
		return 0.0
	var radius := clampf(search_radius, 0.0, _length * 0.49)
	var step := maxf(0.5, coarse_step)
	var best_offset := _wrap_offset(hint_offset)
	var best_distance := point_at(best_offset).distance_squared_to(world_position)
	var probe := -radius
	while probe <= radius + 0.001:
		var candidate := _wrap_offset(hint_offset + probe)
		var candidate_distance := point_at(candidate).distance_squared_to(world_position)
		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_offset = candidate
		probe += step

	# Golden-section refinement on the winning coarse interval.
	var low := best_offset - step
	var high := best_offset + step
	for iteration in 12:
		var left := low + (high - low) * 0.381966
		var right := low + (high - low) * 0.618034
		if point_at(left).distance_squared_to(world_position) < point_at(right).distance_squared_to(world_position):
			high = right
		else:
			low = left
	return _wrap_offset((low + high) * 0.5)


func _bake() -> void:
	_sample_points = PackedVector3Array()
	_sample_offsets = PackedFloat32Array()
	_sample_zones = PackedStringArray()
	_length = 0.0
	var segment_count := _controls.size() if _closed else _controls.size() - 1
	for segment in segment_count:
		var chord := _controls[segment].distance_to(_controls[(segment + 1) % _controls.size()])
		var divisions := maxi(8, ceili(chord / _bake_interval))
		for division in divisions:
			var t := float(division) / float(divisions)
			_append_sample(_catmull_rom(segment, t), _control_zones[segment])
	var final_index := 0 if _closed else _controls.size() - 1
	_append_sample(_controls[final_index], _control_zones[final_index])
	_build_public_curve()
	_build_zone_ranges()


func _append_sample(point: Vector3, zone: String) -> void:
	if not _sample_points.is_empty():
		_length += _sample_points[-1].distance_to(point)
	_sample_points.append(point)
	_sample_offsets.append(_length)
	_sample_zones.append(zone)


func _catmull_rom(segment: int, t: float) -> Vector3:
	var count := _controls.size()
	var p0 := _controls[(segment - 1 + count) % count]
	var p1 := _controls[segment % count]
	var p2 := _controls[(segment + 1) % count]
	var p3 := _controls[(segment + 2) % count]
	if not _closed:
		p0 = _controls[maxi(0, segment - 1)]
		p3 = _controls[mini(count - 1, segment + 2)]
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _build_public_curve() -> void:
	course_curve = Curve3D.new()
	course_curve.bake_interval = _bake_interval
	var count := _controls.size()
	for index in count:
		var previous := _controls[(index - 1 + count) % count]
		var following := _controls[(index + 1) % count]
		var outgoing := (following - previous) / 6.0
		course_curve.add_point(_controls[index], -outgoing, outgoing)
	if _closed:
		var first_outgoing := (_controls[1] - _controls[-1]) / 6.0
		course_curve.add_point(_controls[0], -first_outgoing, first_outgoing)


func _build_zone_ranges() -> void:
	course_zones.clear()
	if _sample_zones.is_empty():
		return
	var active_zone := _sample_zones[0]
	var range_start := 0.0
	for index in range(1, _sample_zones.size()):
		if _sample_zones[index] == active_zone:
			continue
		course_zones.append({
			"name": active_zone,
			"start_distance": range_start,
			"end_distance": float(_sample_offsets[index])
		})
		active_zone = _sample_zones[index]
		range_start = float(_sample_offsets[index])
	course_zones.append({
		"name": active_zone,
		"start_distance": range_start,
		"end_distance": _length
	})


func _sample_location(offset: float) -> Vector2:
	var target := _wrap_offset(offset)
	var low := 0
	var high := _sample_offsets.size() - 1
	while low + 1 < high:
		var middle := (low + high) / 2
		if _sample_offsets[middle] <= target:
			low = middle
		else:
			high = middle
	var span := _sample_offsets[low + 1] - _sample_offsets[low]
	var weight := 0.0 if span <= 0.000001 else (target - _sample_offsets[low]) / span
	return Vector2(low, weight)


func _wrap_offset(offset: float) -> float:
	if _length <= 0.0:
		return 0.0
	return fposmod(offset, _length) if _closed else clampf(offset, 0.0, _length)
