extends SceneTree

const CatalogScript := preload("res://scripts/manual_scenery_catalog.gd")
const FactoryScript := preload("res://scripts/manual_scenery_factory.gd")
const ItemScript := preload("res://scripts/editor/manual_scenery_item.gd")


func _initialize() -> void:
	call_deferred("_generate")


func _generate() -> void:
	var factory := FactoryScript.new()
	var generated := 0
	for entry: Dictionary in CatalogScript.entries():
		var scene_path := CatalogScript.scene_path(entry)
		var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scene_path.get_base_dir()))
		if directory_error != OK:
			push_error("Could not create %s: %s" % [scene_path.get_base_dir(), error_string(directory_error)])
			quit(1)
			return
		var root := Node3D.new()
		root.name = str(entry.name).to_pascal_case()
		root.set_script(ItemScript)
		root.set("catalog_id", str(entry.id))
		root.set("display_name", str(entry.name))
		root.set("category", str(entry.category))
		root.set("surface", int(entry.surface))
		root.set("footprint_radius", float(entry.radius))
		root.set("object_height", float(entry.height))
		root.set("allow_on_course", bool(entry.get("allow_on_course", false)))
		root.set("allow_manual_overlap", bool(entry.get("allow_overlap", false)))
		var texture: Texture2D = null
		if entry.has("texture"):
			texture = load(str(entry.texture)) as Texture2D
			root.set("poster_texture", texture)
		root.add_to_group("manual_scenery_preset", true)
		root.add_to_group("manual_scenery", true)
		factory.populate(root, str(entry.archetype), int(entry.variant), texture)
		_set_owned(root, root)
		var packed := PackedScene.new()
		var pack_error := packed.pack(root)
		if pack_error != OK:
			push_error("Could not pack %s: %s" % [scene_path, error_string(pack_error)])
			quit(1)
			return
		var save_error := ResourceSaver.save(packed, scene_path)
		if save_error != OK:
			push_error("Could not save %s: %s" % [scene_path, error_string(save_error)])
			quit(1)
			return
		generated += 1
		root.free()
	print("MANUAL SCENERY CATALOG: generated %d draggable scenes" % generated)
	quit(0)


func _set_owned(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owned(child, owner)
