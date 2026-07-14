extends SceneTree

const CatalogScript := preload("res://scripts/manual_scenery_catalog.gd")
const FORBIDDEN_GROUPS := [
	&"track", &"bridge", &"tunnel", &"tunnel_boundary", &"ocean_scenery",
	&"island_terrain", &"road_boundary", &"flyover", &"bridge_support",
]
const REQUIRED_CATEGORIES := [
	"Buildings", "Landmarks", "Vegetation", "Street Props", "Signs and Posters",
	"Boats and Waterfront", "Sky",
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
	var entries: Array[Dictionary] = CatalogScript.entries()
	check(entries.size() >= 50, "catalog exposes the complete decorative scenery library")
	var ids := {}
	var paths := {}
	var categories := {}
	var catalog_paths: Array[String] = []
	for entry: Dictionary in entries:
		var id := str(entry.id)
		var scene_path := CatalogScript.scene_path(entry)
		check(not ids.has(id), "catalog id is unique: %s" % id)
		check(not paths.has(scene_path), "catalog path is unique: %s" % scene_path)
		ids[id] = true
		paths[scene_path] = true
		categories[str(entry.category)] = true
		catalog_paths.append(scene_path)
		_check_preset(entry, scene_path)
	for category in REQUIRED_CATEGORIES:
		check(categories.has(category), "catalog includes %s" % category)
	var disk_paths: Array[String] = []
	_collect_scenes("res://scenes/manual_scenery/presets", disk_paths)
	catalog_paths.sort()
	disk_paths.sort()
	check(catalog_paths == disk_paths, "catalog entries exactly match checked-in draggable PackedScenes")

	var packed_main := load("res://scenes/main.tscn") as PackedScene
	check(packed_main != null, "main scene loads with manual scenery workspace")
	var race := packed_main.instantiate()
	var manual_root := race.get_node_or_null("ManualScenery") as Node3D
	var guide := race.get_node_or_null("EditorPlacementGuide") as Node3D
	check(manual_root != null, "ManualScenery is serialized as a direct Race child")
	check(manual_root != null and manual_root.get_parent() == race, "ManualScenery has the expected owner hierarchy")
	check(manual_root != null and manual_root.get_child_count() == 0, "default manual layer starts empty")
	check(guide != null, "editor placement guide is serialized in the main scene")
	root.add_child(race)
	await process_frame
	await process_frame
	check(guide != null and guide.find_children("*", "MeshInstance3D", true, false).is_empty(), "placement guide contributes zero runtime meshes")
	check(guide != null and guide.find_children("*", "CollisionObject3D", true, false).is_empty(), "placement guide contributes zero runtime collision")
	check(manual_root != null and manual_root.is_in_group("manual_scenery_root"), "manual layer registers its editor/runtime contract")
	check(race.find_children("*", "MeshInstance3D", true, false).size() == 5046, "empty manual layer leaves procedural mesh baseline unchanged")
	traced_cleanup(race)

	print("MANUAL SCENERY QA: %d presets, %d failures" % [entries.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check_preset(entry: Dictionary, scene_path: String) -> void:
	check(ResourceLoader.exists(scene_path, "PackedScene"), "preset exists: %s" % scene_path)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return
	var instance := packed.instantiate() as Node3D
	check(instance != null, "%s instantiates as Node3D" % entry.id)
	if instance == null:
		return
	root.add_child(instance)
	check(instance.is_in_group("manual_scenery_preset"), "%s carries manual preset group" % entry.id)
	check(str(instance.get("catalog_id")) == str(entry.id), "%s carries matching catalog metadata" % entry.id)
	check(str(instance.get("category")) == str(entry.category), "%s carries matching catalog category" % entry.id)
	check(int(instance.get("surface")) == int(entry.surface), "%s carries matching placement surface" % entry.id)
	check(float(instance.get("footprint_radius")) > 0.0, "%s has a positive clearance footprint" % entry.id)
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	var sprites := instance.find_children("*", "Sprite3D", true, false)
	check(not meshes.is_empty() or not sprites.is_empty(), "%s has visible editor geometry" % entry.id)
	check(instance.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s is visual-only by default" % entry.id)
	for forbidden_group in FORBIDDEN_GROUPS:
		check(not _tree_uses_group(instance, forbidden_group), "%s excludes infrastructure group %s" % [entry.id, forbidden_group])
	for value in meshes:
		var mesh_instance := value as MeshInstance3D
		check(mesh_instance.mesh != null, "%s mesh resource is valid" % entry.id)
		check(mesh_instance.visibility_range_end >= 1200.0, "%s retains long-distance visibility" % entry.id)
		var bounds := mesh_instance.get_aabb()
		check(bounds.size.is_finite() and bounds.size.length_squared() > 0.0, "%s mesh bounds are finite" % entry.id)
	for value in sprites:
		var sprite := value as Sprite3D
		check(sprite.texture != null, "%s poster/banner texture loads" % entry.id)
	if entry.has("texture") and not sprites.is_empty():
		var replacement := load("res://assets/generated/friends/8608460d-bd44-4e25-b2dc-ccf8a5003e87.jpg") as Texture2D
		instance.set("poster_texture", replacement)
		var updated := true
		for value in sprites:
			updated = updated and (value as Sprite3D).texture == replacement
		check(updated, "%s artwork is editable from the preset root Inspector" % entry.id)
	instance.queue_free()


func _tree_uses_group(node: Node, group_name: StringName) -> bool:
	if node.is_in_group(group_name):
		return true
	for child in node.get_children():
		if _tree_uses_group(child, group_name):
			return true
	return false


func _collect_scenes(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		var path := directory_path.path_join(name)
		if directory.current_is_dir():
			_collect_scenes(path, output)
		elif name.ends_with(".tscn"):
			output.append(path)
		name = directory.get_next()
	directory.list_dir_end()


func traced_cleanup(node: Node) -> void:
	root.remove_child(node)
	node.free()
