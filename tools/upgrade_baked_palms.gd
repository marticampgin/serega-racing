extends SceneTree

const EDITABLE_WORLD_PATH := "res://scenes/world/editable_world.tscn"


func _initialize() -> void:
	call_deferred("_upgrade")


func _upgrade() -> void:
	var output_path := EDITABLE_WORLD_PATH
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	var packed_world := load(EDITABLE_WORLD_PATH) as PackedScene
	if packed_world == null:
		push_error("Cannot load editable world: %s" % EDITABLE_WORLD_PATH)
		quit(1)
		return
	var editable := packed_world.instantiate() as Node3D
	root.add_child(editable)
	var leaf_materials := [_material(Color("20a779"), 0.84), _material(Color("116553"), 0.90)]
	var upgraded := 0
	for value in editable.find_children("*", "Node3D", true, false):
		var palm := value as Node3D
		if not palm.is_in_group("palm_scenery") or not palm.scene_file_path.is_empty():
			continue
		var trunk_height := 0.0
		var leaves: Array[MeshInstance3D] = []
		for child in palm.get_children():
			if not child is MeshInstance3D:
				continue
			var mesh_instance := child as MeshInstance3D
			if mesh_instance.mesh is CylinderMesh:
				trunk_height = maxf(trunk_height, (mesh_instance.mesh as CylinderMesh).height)
			elif mesh_instance.mesh is BoxMesh:
				leaves.append(mesh_instance)
		if trunk_height <= 0.0 or leaves.size() != 6:
			push_warning("PALM UPGRADE: skipped %s (height %.2f, %d leaves)" % [palm.get_path(), trunk_height, leaves.size()])
			continue
		var scale_factor := trunk_height / 7.0
		for index in range(leaves.size()):
			var leaf := leaves[index]
			var box := leaf.mesh as BoxMesh
			box.size = Vector3(0.42, 0.14, 5.2) * scale_factor
			box.material = leaf_materials[index % 2]
			leaf.position = Vector3(0, trunk_height, 0)
			leaf.rotation = Vector3(-0.17, TAU * float(index) / 6.0, 0)
			leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			leaf.visibility_range_end = 1900.0
		upgraded += 1
	var output := PackedScene.new()
	var pack_error := output.pack(editable)
	if pack_error != OK:
		push_error("Could not pack upgraded editable world: %s" % error_string(pack_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(output, output_path)
	if save_error != OK:
		push_error("Could not save upgraded editable world: %s" % error_string(save_error))
		quit(1)
		return
	print("PALM UPGRADE: updated %d baked standalone palms in %s" % [upgraded, output_path])
	quit(0)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
