extends RefCounted


static func has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


static func find_course_curve(race: Node) -> Curve3D:
	if has_property(race, &"course_curve"):
		var direct := race.get("course_curve") as Curve3D
		if direct != null:
			return direct
	for child in race.find_children("*", "Path3D", true, false):
		var path := child as Path3D
		if path.curve != null:
			return path.curve
	return null


static func find_course_path(race: Node) -> Path3D:
	for child in race.find_children("*", "Path3D", true, false):
		var path := child as Path3D
		if path.curve != null:
			return path
	return null


static func course_position(race: Node, curve: Curve3D, distance: float) -> Vector3:
	if race.has_method("course_position"):
		return race.call("course_position", distance) as Vector3
	if race.has_method("sample_course"):
		var sample: Variant = race.call("sample_course", distance)
		if sample is Transform3D:
			return (sample as Transform3D).origin
		if sample is Vector3:
			return sample as Vector3
	var point := curve.sample_baked(clampf(distance, 0.0, curve.get_baked_length()), true)
	var path := find_course_path(race)
	return path.to_global(point) if path != null else race.to_global(point)


static func course_tangent(race: Node, curve: Curve3D, distance: float) -> Vector3:
	var length := curve.get_baked_length()
	var before := course_position(race, curve, fposmod(distance - 1.0, length))
	var after := course_position(race, curve, fposmod(distance + 1.0, length))
	var tangent := after - before
	return tangent.normalized() if tangent.length_squared() > 0.0001 else Vector3.FORWARD


static func course_up(race: Node, curve: Curve3D, distance: float) -> Vector3:
	if race.has_method("course_transform"):
		var transform: Variant = race.call("course_transform", distance)
		if transform is Transform3D:
			return (transform as Transform3D).basis.y.normalized()
	return Vector3.UP


static func course_zones(race: Node) -> Array:
	if has_property(race, &"course_zones"):
		var zones: Variant = race.get("course_zones")
		if zones is Array:
			return zones as Array
	if race.has_method("get_course_zones"):
		var zones: Variant = race.call("get_course_zones")
		if zones is Array:
			return zones as Array
	return []


static func zone_name(zone: Dictionary) -> String:
	return String(zone.get("name", zone.get("id", "")))


static func zone_start(zone: Dictionary, course_length: float) -> float:
	if zone.has("start_distance"):
		return float(zone.start_distance)
	if zone.has("start"):
		return float(zone.start)
	return float(zone.get("start_ratio", 0.0)) * course_length


static func zone_end(zone: Dictionary, course_length: float) -> float:
	if zone.has("end_distance"):
		return float(zone.end_distance)
	if zone.has("end"):
		return float(zone.end)
	return float(zone.get("end_ratio", 0.0)) * course_length


static func normalized_zone_name(value: String) -> String:
	return value.to_lower().replace("/", " ").replace("_", " ").replace("-", " ").strip_edges()


static func find_zone(zones: Array, wanted: String) -> Dictionary:
	var needle := normalized_zone_name(wanted)
	for value in zones:
		if value is Dictionary:
			var zone := value as Dictionary
			if normalized_zone_name(zone_name(zone)).contains(needle):
				return zone
	return {}


static func zone_span(zones: Array, wanted: String, course_length: float) -> Vector2:
	var needle := normalized_zone_name(wanted)
	var first := INF
	var last := -INF
	for value in zones:
		if value is Dictionary:
			var zone := value as Dictionary
			if normalized_zone_name(zone_name(zone)).contains(needle):
				first = minf(first, zone_start(zone, course_length))
				last = maxf(last, zone_end(zone, course_length))
	return Vector2(first, last) if is_finite(first) and is_finite(last) else Vector2(-1.0, -1.0)
