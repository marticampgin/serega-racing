extends SceneTree

const MAX_TOTAL_MESHES := 3700
const FILLER_GROUPS := [&"palm_scenery", &"lamp_scenery", &"portrait_scenery"]
const DENSITY_RULES := {
	"start_coast": {"min_featured": 2, "max_gap": 170.0},
	"party_town": {"min_featured": 6, "max_gap": 110.0},
	"city_centre": {"min_featured": 5, "max_gap": 240.0},
	"shopping_alley": {"min_featured": 4, "max_gap": 220.0},
	"sport_complex": {"min_featured": 3, "max_gap": 350.0},
	"north_coast": {"min_featured": 16, "max_gap": 200.0},
	"party_island_view": {"min_featured": 2, "max_gap": 200.0},
}

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
	var race := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(race)
	await process_frame
	await process_frame

	var course: Object = race.get("course")
	check(course != null, "course metadata is available for district density QA")
	if course == null:
		_finish()
		return

	var total_meshes := race.find_children("*", "MeshInstance3D", true, false).size()
	print("INFO: total MeshInstance3D nodes = %d (cap %d)" % [total_meshes, MAX_TOTAL_MESHES])
	check(total_meshes <= MAX_TOTAL_MESHES, "world remains within the generous scenery mesh budget")

	var zones: Array = course.get("course_zones")
	var spans: Array[Dictionary] = []
	for index in range(zones.size()):
		var zone: Dictionary = zones[index]
		spans.append({
			"index": index,
			"name": str(zone.get("name", "")),
			"start": float(zone.get("start_distance", 0.0)),
			"finish": float(zone.get("end_distance", 0.0)),
			"all_offsets": [],
			"featured_offsets": [],
			"mesh_count": 0,
		})

	var metadata_anchors := 0
	var offtrack_roots := 0
	for value in get_nodes_in_group("grounded_scenery"):
		if not value is Node3D or not race.is_ancestor_of(value):
			continue
		var anchor := value as Node3D
		if not anchor.has_meta("course_offset"):
			offtrack_roots += 1
			continue
		metadata_anchors += 1
		var offset := fposmod(float(anchor.get_meta("course_offset")), float(course.call("length")))
		var span_index := _span_index_for_offset(spans, offset)
		if span_index < 0:
			continue
		var span: Dictionary = spans[span_index]
		(span.all_offsets as Array).append(offset)
		span.mesh_count = int(span.mesh_count) + _mesh_count(anchor)
		if not _is_filler(anchor):
			(span.featured_offsets as Array).append(offset)
		spans[span_index] = span

	print("INFO: grounded metadata anchors = %d; off-track grounded roots = %d" % [metadata_anchors, offtrack_roots])
	for span in spans:
		var zone_name := str(span.name)
		if not DENSITY_RULES.has(zone_name):
			continue
		var all_offsets := span.all_offsets as Array
		var featured_offsets := span.featured_offsets as Array
		all_offsets.sort()
		featured_offsets.sort()
		var max_gap := _maximum_gap(float(span.start), float(span.finish), featured_offsets)
		var rule: Dictionary = DENSITY_RULES[zone_name]
		print(
			"INFO: district=%s span=%d range=%.1f-%.1f all_anchors=%d featured=%d meshes=%d max_featured_gap=%.1fm"
			% [zone_name, int(span.index), float(span.start), float(span.finish), all_offsets.size(), featured_offsets.size(), int(span.mesh_count), max_gap]
		)
		check(
			featured_offsets.size() >= int(rule.min_featured),
			"%s span %d has enough recognizable district anchors" % [zone_name, int(span.index)]
		)
		check(
			max_gap <= float(rule.max_gap),
			"%s span %d has no obvious long empty stretch" % [zone_name, int(span.index)]
		)

	_finish()


func _span_index_for_offset(spans: Array[Dictionary], offset: float) -> int:
	for index in range(spans.size()):
		var span: Dictionary = spans[index]
		if offset >= float(span.start) and offset < float(span.finish):
			return index
	return -1


func _mesh_count(anchor: Node) -> int:
	var count := 1 if anchor is MeshInstance3D else 0
	count += anchor.find_children("*", "MeshInstance3D", true, false).size()
	return count


func _is_filler(anchor: Node) -> bool:
	for group_name in FILLER_GROUPS:
		if anchor.is_in_group(group_name):
			return true
	return false


func _maximum_gap(start: float, finish: float, sorted_offsets: Array) -> float:
	if sorted_offsets.is_empty():
		return finish - start
	var maximum := maxf(0.0, float(sorted_offsets[0]) - start)
	for index in range(1, sorted_offsets.size()):
		maximum = maxf(maximum, float(sorted_offsets[index]) - float(sorted_offsets[index - 1]))
	return maxf(maximum, finish - float(sorted_offsets[-1]))


func _finish() -> void:
	if failures.is_empty():
		print("DISTRICT DENSITY QA: PASS")
		quit(0)
	else:
		print("DISTRICT DENSITY QA: FAIL (%d issues)" % failures.size())
		quit(1)
