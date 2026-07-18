extends SceneTree

const CourseLayoutScript := preload("res://scripts/course_layout.gd")

const FRIEND_GROUPS := [&"poster_scenery", &"portrait_scenery", &"tunnel_wall_poster", &"air_banner_scenery"]
const PALM_IDS := ["palm_small", "palm_tall", "palm_wide"]
const FLAT_SURFACE_IDS := [
	"boardwalk_section", "stepping_stone_path", "sidewalk_straight", "sidewalk_corner",
	"walking_trail", "driveway", "plaza_tile", "side_road_straight", "side_road_corner",
]
const EXPECTED_MANUAL_FRIENDS := ["BralisBillboard", "MilkRacerWallPoster", "PunkHedgehogBillboard", "CrewCollageBillboard"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/world/editable_world.tscn") as PackedScene
	if packed == null:
		push_error("FINAL WORLD AUDIT: editable world does not load")
		quit(1)
		return
	var world := packed.instantiate()
	root.add_child(world)
	await process_frame
	var manual_friend_roots := _manual_friend_roots(world)
	var generated_friend_roots := _generated_friend_roots(world)
	var unauthorized_friend_sprites := _unauthorized_friend_sprites(world)
	var palms := _catalog_roots(world, PALM_IDS)
	var duplicate_pairs := _duplicate_pairs(palms, 1.35)
	var failures := 0
	print("FINAL WORLD AUDIT: manual friend media=%d generated friend roots=%d unauthorized friend sprites=%d manual palms=%d near-duplicate palm pairs=%d" % [
		manual_friend_roots.size(), generated_friend_roots.size(), unauthorized_friend_sprites.size(), palms.size(), duplicate_pairs.size()
	])
	for node in manual_friend_roots:
		print("MANUAL FRIEND: %s catalog=%s" % [node.name, node.get_meta("catalog_id")])
	for node in generated_friend_roots:
		print("GENERATED FRIEND: %s path=%s" % [node.name, node.get_path()])
	for sprite in unauthorized_friend_sprites:
		print("UNAUTHORIZED FRIEND SPRITE: %s texture=%s" % [sprite.get_path(), sprite.texture.resource_path])
	for expected_name in EXPECTED_MANUAL_FRIENDS:
		if manual_friend_roots.all(func(node: Node3D) -> bool: return node.name != expected_name):
			push_error("FINAL WORLD AUDIT: missing manual friend placement %s" % expected_name)
			failures += 1
	if not generated_friend_roots.is_empty() or not unauthorized_friend_sprites.is_empty() or world.get_node_or_null("Sky/SkyTraffic") != null:
		push_error("FINAL WORLD AUDIT: procedural friend media remains")
		failures += 1
	if not duplicate_pairs.is_empty():
		print("FINAL WORLD AUDIT: authored palm copies detected; preserving them for manual editing")
	var sprinkle_count := 0
	for child in world.get_children():
		if child.has_meta("final_sprinkle"):
			sprinkle_count += 1
			if absf((child as Node3D).global_position.y - 1.36) > 0.02:
				print("AUTHORED SPRINKLE HEIGHT: %s y=%.3f" % [child.name, (child as Node3D).global_position.y])
	print("FINAL WORLD AUDIT: authored sprinkle items=%d" % sprinkle_count)
	if world.get_node_or_null("BoardwalkSection11") != null:
		push_error("FINAL WORLD AUDIT: malformed floating boardwalk remains")
		failures += 1
	for pair: Array in duplicate_pairs:
		print("DUPLICATE PALM: %s <-> %s distance=%.3f" % [pair[0].name, pair[1].name, pair[2]])
	for node in _catalog_roots(world, FLAT_SURFACE_IDS):
		if node.global_position.y > 2.4 or node.global_position.y < -0.2:
			print("SUSPICIOUS SURFACE: %s catalog=%s y=%.3f position=(%.1f, %.1f)" % [
				node.name, node.get_meta("catalog_id"), node.global_position.y,
				node.global_position.x, node.global_position.z,
			])
	var course: CourseLayout = CourseLayoutScript.load_default()
	var roots := _scenery_roots(world)
	var candidates: Array[Dictionary] = []
	var offset := 260.0
	while offset < course.length() - 180.0:
		var zone := course.zone_at(offset)
		if zone not in ["underwater_tunnel", "bridge"]:
			var frame: Transform3D = course.sample_course(offset)
			for side in [-1.0, 1.0]:
				var position: Vector3 = frame.origin + frame.basis.x * side * 42.0
				var nearby := _nearby_count(roots, position, 38.0)
				if nearby <= 2:
					candidates.append({"offset": offset, "zone": zone, "side": side, "position": position, "nearby": nearby})
		offset += 170.0
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.nearby) < int(b.nearby))
	print("FINAL WORLD AUDIT: sparse roadside candidates=%d" % candidates.size())
	for index in range(mini(24, candidates.size())):
		var candidate: Dictionary = candidates[index]
		print("SPARSE: offset=%.0f zone=%s side=%+.0f nearby=%d position=(%.1f, %.1f, %.1f)" % [
			candidate.offset, candidate.zone, candidate.side, candidate.nearby,
			candidate.position.x, candidate.position.y, candidate.position.z,
		])
	print("FINAL WORLD AUDIT: %d failures" % failures)
	quit(0 if failures == 0 else 1)


func _manual_friend_roots(world: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for value in world.find_children("*", "Node3D", true, false):
		var node := value as Node3D
		if node.has_meta("catalog_id") and str(node.get_meta("catalog_id")).begins_with("art_") and str(node.get_meta("catalog_id")).contains("__"):
			result.append(node)
	return result


func _generated_friend_roots(world: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for value in world.find_children("*", "Node3D", true, false):
		var node := value as Node3D
		if node.has_meta("catalog_id"):
			continue
		var is_friend := false
		for group: StringName in FRIEND_GROUPS:
			is_friend = is_friend or node.is_in_group(group)
		if is_friend and _top_friend_root(node) == node and not result.has(node):
			result.append(node)
	return result


func _unauthorized_friend_sprites(world: Node) -> Array[Sprite3D]:
	var result: Array[Sprite3D] = []
	for value in world.find_children("*", "Sprite3D", true, false):
		var sprite := value as Sprite3D
		if sprite.texture == null or not sprite.texture.resource_path.begins_with("res://assets/generated/friends/"):
			continue
		var ancestor: Node = sprite
		var is_manual := false
		while ancestor != null and ancestor != world:
			if ancestor.has_meta("catalog_id"):
				var catalog_id := str(ancestor.get_meta("catalog_id"))
				if catalog_id.begins_with("art_") and catalog_id.contains("__"):
					is_manual = true
					break
			ancestor = ancestor.get_parent()
		if not is_manual:
			result.append(sprite)
	return result


func _top_friend_root(node: Node3D) -> Node3D:
	var result := node
	var parent := node.get_parent()
	while parent is Node3D and not parent.is_in_group("editable_district") and not parent.is_in_group("editable_world"):
		var parent_3d := parent as Node3D
		if parent_3d.has_meta("catalog_id"):
			return parent_3d
		result = parent_3d
		parent = parent.get_parent()
	return result


func _catalog_roots(world: Node, ids: Array) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for value in world.find_children("*", "Node3D", true, false):
		var node := value as Node3D
		if node.has_meta("catalog_id") and str(node.get_meta("catalog_id")) in ids:
			result.append(node)
	return result


func _duplicate_pairs(nodes: Array[Node3D], threshold: float) -> Array[Array]:
	var result: Array[Array] = []
	for left_index in range(nodes.size()):
		for right_index in range(left_index + 1, nodes.size()):
			var left := nodes[left_index]
			var right := nodes[right_index]
			if str(left.get_meta("catalog_id")) != str(right.get_meta("catalog_id")):
				continue
			var distance := left.global_position.distance_to(right.global_position)
			if distance < threshold:
				result.append([left, right, distance])
	return result


func _scenery_roots(world: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in world.get_children():
		if not child is Node3D:
			continue
		if child.is_in_group("editable_district"):
			for district_child in child.get_children():
				if district_child is Node3D:
					result.append(district_child)
		elif child.has_meta("catalog_id"):
			result.append(child)
	return result


func _nearby_count(nodes: Array[Node3D], position: Vector3, radius: float) -> int:
	var count := 0
	var xz := Vector2(position.x, position.z)
	for node in nodes:
		if Vector2(node.global_position.x, node.global_position.z).distance_to(xz) < radius:
			count += 1
	return count
