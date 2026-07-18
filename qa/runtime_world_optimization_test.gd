extends SceneTree

const SOURCE_PATH := "res://scenes/world/editable_world.tscn"
const RUNTIME_PATH := "res://scenes/world/runtime_world_optimized.scn"
const MAX_RUNTIME_MESH_RATIO := 0.38
const MAX_RUNTIME_NODE_RATIO := 0.48

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _run() -> void:
	var source_scene := load(SOURCE_PATH) as PackedScene
	var runtime_scene := load(RUNTIME_PATH) as PackedScene
	_check(source_scene != null, "editable authoring scene loads")
	_check(runtime_scene != null, "optimized runtime scene loads")
	if source_scene == null or runtime_scene == null:
		quit(1)
		return

	var source_started := Time.get_ticks_msec()
	var source := source_scene.instantiate()
	root.add_child(source)
	await process_frame
	var source_load_ms := Time.get_ticks_msec() - source_started
	var source_nodes := _count_nodes(source)
	var source_meshes := source.find_children("*", "MeshInstance3D", true, false).size()
	var source_catalog := _catalog_snapshot(source)
	var source_sprites := source.find_children("*", "Sprite3D", true, false).size()
	root.remove_child(source)
	source.free()
	await process_frame

	var runtime_started := Time.get_ticks_msec()
	var runtime := runtime_scene.instantiate()
	root.add_child(runtime)
	await process_frame
	var runtime_load_ms := Time.get_ticks_msec() - runtime_started
	var runtime_nodes := _count_nodes(runtime)
	var runtime_meshes := runtime.find_children("*", "MeshInstance3D", true, false).size()
	var runtime_catalog := _catalog_snapshot(runtime)
	var runtime_sprites := runtime.find_children("*", "Sprite3D", true, false).size()

	_check(bool(runtime.get_meta("runtime_optimized", false)), "runtime artifact identifies itself as optimized")
	_check(str(runtime.get_meta("runtime_source_sha256", "")) == FileAccess.get_sha256(SOURCE_PATH), "runtime artifact was built from the current editable scene")
	_check(runtime.get_node_or_null("EditorPlacementGuide") == null, "editor preview helper is stripped")
	_check(not runtime.get_tree().get_nodes_in_group("runtime_static_batch").is_empty(), "static geometry is represented by draw batches")
	_check(runtime_meshes <= int(source_meshes * MAX_RUNTIME_MESH_RATIO), "mesh-instance count is reduced by at least 62 percent")
	_check(runtime_nodes <= int(source_nodes * MAX_RUNTIME_NODE_RATIO), "scene-node count is reduced by at least 52 percent")
	_check(runtime_catalog == source_catalog, "all externally instanced catalog objects and placements are preserved")
	_check(runtime_sprites == source_sprites, "all authored Sprite3D friend artwork is preserved")
	_check(_has_catalog(runtime, "art_friend_dark_hair__banner_plane"), "authored friend banner plane remains independent")
	_check(_has_catalog(runtime, "art_friend_beard__zeppelin"), "authored friend zeppelin remains independent")
	_check(_has_catalog(runtime, "art_motorcycle_rider__billboard"), "authored motorcycle friend billboard remains independent")

	print("INFO: source nodes=%d meshes=%d instantiate=%d ms" % [source_nodes, source_meshes, source_load_ms])
	print("INFO: runtime nodes=%d meshes=%d instantiate=%d ms" % [runtime_nodes, runtime_meshes, runtime_load_ms])
	print("RUNTIME WORLD OPTIMIZATION QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)


func _catalog_snapshot(parent: Node) -> Dictionary:
	var snapshot := {}
	for value in parent.find_children("*", "Node3D", true, false):
		var node := value as Node3D
		var catalog_id := str(node.get_meta("catalog_id", ""))
		if catalog_id.is_empty():
			continue
		var transform_values := PackedFloat32Array()
		for value_float in [
			node.global_position.x, node.global_position.y, node.global_position.z,
			node.global_transform.basis.x.x, node.global_transform.basis.x.y, node.global_transform.basis.x.z,
			node.global_transform.basis.y.x, node.global_transform.basis.y.y, node.global_transform.basis.y.z,
			node.global_transform.basis.z.x, node.global_transform.basis.z.y, node.global_transform.basis.z.z,
		]:
			transform_values.append(snappedf(float(value_float), 0.001))
		var key := "%s|%s|%s" % [catalog_id, node.name, var_to_str(transform_values)]
		snapshot[key] = true
	return snapshot


func _has_catalog(parent: Node, catalog_id: String) -> bool:
	for value in parent.find_children("*", "Node3D", true, false):
		if str(value.get_meta("catalog_id", "")) == catalog_id:
			return true
	return false


func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count
