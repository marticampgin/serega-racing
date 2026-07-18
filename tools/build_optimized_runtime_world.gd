extends SceneTree

## Produces a play-only world from the editable authoring scene.
##
## The source scene is never modified. Locally-authored static MeshInstance3D
## nodes are combined by spatial cell, material and render state. Externally
## instanced presets are deliberately retained as instances so scripts, friend
## artwork and moving sky traffic continue to work at runtime.

const SOURCE_PATH := "res://scenes/world/editable_world.tscn"
const OUTPUT_PATH := "res://scenes/world/runtime_world_optimized.scn"
const CELL_SIZE := 320.0
const VISIBILITY_RANGE_END := 3200.0

var _batches: Dictionary = {}
var _resource_signatures: Dictionary = {}
var _batched_meshes := 0
var _batched_surfaces := 0


func _initialize() -> void:
	call_deferred("_build")


func _build() -> void:
	var source := load(SOURCE_PATH) as PackedScene
	if source == null:
		push_error("Cannot load editable authoring world: %s" % SOURCE_PATH)
		quit(1)
		return
	var authored_world := source.instantiate() as Node3D
	if authored_world == null:
		push_error("Editable authoring world has no Node3D root")
		quit(1)
		return
	# Packing an instantiated scene root directly creates inherited-scene
	# overrides. Use a fresh root so generated batches are serialized as real
	# runtime content while external preset descendants stay referenced.
	var world := Node3D.new()
	root.add_child(world)
	world.name = "RuntimeWorldOptimized"
	for group: StringName in authored_world.get_groups():
		world.add_to_group(group, true)
	for child in authored_world.get_children():
		var authored_nodes: Array[Node] = []
		_collect_owned_nodes(child, authored_world, authored_nodes)
		for authored_node in authored_nodes:
			authored_node.owner = null
		authored_world.remove_child(child)
		world.add_child(child)
		for authored_node in authored_nodes:
			authored_node.owner = world
	authored_world.free()
	world.add_to_group("runtime_world", true)
	world.add_to_group("editable_world", true)
	world.set_meta("runtime_optimized", true)
	world.set_meta("runtime_source_path", SOURCE_PATH)
	world.set_meta("runtime_source_sha256", FileAccess.get_sha256(SOURCE_PATH))
	world.set_meta("runtime_batch_cell_size", CELL_SIZE)

	_remove_editor_only_nodes(world)
	print("RUNTIME WORLD: loaded source; collecting static meshes...")
	_collect_static_meshes(world)
	print("RUNTIME WORLD: collected %d meshes; committing %d batches..." % [_batched_meshes, _batches.size()])
	var batch_root := Node3D.new()
	batch_root.name = "StaticRuntimeBatches"
	batch_root.add_to_group("runtime_static_batches", true)
	world.add_child(batch_root)
	batch_root.owner = world
	_commit_batches(batch_root, world)
	print("RUNTIME WORLD: pruning authoring-only shells...")
	_prune_empty_local_nodes(world, world)

	var packed := PackedScene.new()
	var pack_error := packed.pack(world)
	if pack_error != OK:
		push_error("Could not pack optimized runtime world: %s" % error_string(pack_error))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var save_error := ResourceSaver.save(packed, OUTPUT_PATH, ResourceSaver.FLAG_COMPRESS)
	if save_error != OK:
		push_error("Could not save optimized runtime world: %s" % error_string(save_error))
		quit(1)
		return
	print("RUNTIME WORLD: batched %d meshes / %d surfaces into %d draw batches" % [
		_batched_meshes,
		_batched_surfaces,
		batch_root.get_child_count(),
	])
	print("RUNTIME WORLD: saved %d nodes / %d mesh instances to %s" % [
		_count_nodes(world),
		world.find_children("*", "MeshInstance3D", true, false).size(),
		OUTPUT_PATH,
	])
	_batches.clear()
	root.remove_child(world)
	world.free()
	quit(0)


func _remove_editor_only_nodes(world: Node) -> void:
	var removals: Array[Node] = []
	for value in world.find_children("*", "Node", true, false):
		if value.is_in_group("editor_placement_guide") or value.name == &"EditorPlacementGuide":
			removals.append(value)
	for value in removals:
		value.get_parent().remove_child(value)
		value.free()


func _collect_static_meshes(world: Node3D) -> void:
	var removals: Array[MeshInstance3D] = []
	for value in world.find_children("*", "MeshInstance3D", true, false):
		var instance := value as MeshInstance3D
		if instance.mesh == null or _belongs_to_external_instance(instance, world):
			continue
		# A mesh with per-instance blend shapes or a skeleton is not static scenery.
		if instance.skin != null or not instance.skeleton.is_empty():
			continue
		var origin := instance.global_position
		var cell_x := floori(origin.x / CELL_SIZE)
		var cell_z := floori(origin.z / CELL_SIZE)
		for surface_index in range(instance.mesh.get_surface_count()):
			var material := instance.get_active_material(surface_index)
			var key := "%d|%d|%s|%d|%d|%d|%d" % [
				cell_x,
				cell_z,
				_resource_signature(material),
				int(instance.cast_shadow),
				instance.layers,
				roundi(instance.visibility_range_begin),
				roundi(instance.visibility_range_end),
			]
			if not _batches.has(key):
				var surface_tool := SurfaceTool.new()
				surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				if material != null:
					surface_tool.set_material(material)
				_batches[key] = {
					"surface": surface_tool,
					"cast_shadow": instance.cast_shadow,
					"layers": instance.layers,
					"visibility_begin": instance.visibility_range_begin,
					"visibility_end": instance.visibility_range_end,
					"cell_x": cell_x,
					"cell_z": cell_z,
				}
			(_batches[key]["surface"] as SurfaceTool).append_from(
				instance.mesh,
				surface_index,
				instance.global_transform
			)
			_batched_surfaces += 1
		removals.append(instance)
		_batched_meshes += 1
	for instance in removals:
		instance.get_parent().remove_child(instance)
		instance.free()


func _commit_batches(batch_root: Node3D, scene_owner: Node) -> void:
	var keys := _batches.keys()
	keys.sort()
	var index := 0
	for key_value in keys:
		var key := str(key_value)
		var data := _batches[key] as Dictionary
		var combined_mesh := (data["surface"] as SurfaceTool).commit()
		if combined_mesh == null or combined_mesh.get_surface_count() == 0:
			continue
		var combined := MeshInstance3D.new()
		combined.name = "StaticBatch_%04d_C%d_%d" % [index, int(data["cell_x"]), int(data["cell_z"])]
		combined.mesh = combined_mesh
		combined.cast_shadow = int(data["cast_shadow"])
		combined.layers = int(data["layers"])
		combined.visibility_range_begin = float(data["visibility_begin"])
		var authored_end := float(data["visibility_end"])
		combined.visibility_range_end = maxf(authored_end, VISIBILITY_RANGE_END) if authored_end > 0.0 else VISIBILITY_RANGE_END
		combined.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		combined.add_to_group("runtime_static_batch", true)
		batch_root.add_child(combined)
		combined.owner = scene_owner
		index += 1


func _belongs_to_external_instance(node: Node, world: Node) -> bool:
	var cursor := node.get_parent()
	while cursor != null and cursor != world:
		if not cursor.scene_file_path.is_empty():
			return true
		cursor = cursor.get_parent()
	return false


func _collect_owned_nodes(node: Node, scene_owner: Node, result: Array[Node]) -> void:
	if node.owner == scene_owner:
		result.append(node)
	for child in node.get_children():
		_collect_owned_nodes(child, scene_owner, result)


func _resource_signature(resource: Resource) -> String:
	if resource == null:
		return "none"
	var instance_id := resource.get_instance_id()
	if _resource_signatures.has(instance_id):
		return str(_resource_signatures[instance_id])
	var entries: PackedStringArray = [resource.get_class()]
	for property in resource.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name := str(property.name)
		if property_name in ["resource_local_to_scene", "resource_name", "resource_path", "script"]:
			continue
		var property_value = resource.get(property_name)
		if property_value is Resource:
			var nested := property_value as Resource
			entries.append("%s=%s" % [property_name, nested.resource_path if not nested.resource_path.is_empty() else nested.get_class()])
		else:
			entries.append("%s=%s" % [property_name, var_to_str(property_value)])
	var signature := "|".join(entries).sha256_text()
	_resource_signatures[instance_id] = signature
	return signature


func _prune_empty_local_nodes(node: Node, world: Node) -> void:
	for child in node.get_children():
		_prune_empty_local_nodes(child, world)
	if node == world or node.get_child_count() > 0:
		return
	if not node.scene_file_path.is_empty() or node.get_script() != null:
		return
	# Only empty organizational shells are expendable. MeshInstance3D,
	# Sprite3D and every other Node3D subclass are actual runtime content.
	if node.get_class() != "Node3D":
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
		node.free()


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
