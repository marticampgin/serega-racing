extends SceneTree

const CatalogScript := preload("res://scripts/manual_scenery_catalog.gd")
const OUTPUT_DIRECTORY := "res://qa/artifacts/manual_scenery_catalog"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("manual scenery visual audit requires a rendering display")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.current = true
	camera.far = 4000.0
	stage.add_child(camera)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-52, -28, 0)
	sunlight.light_energy = 1.25
	sunlight.shadow_enabled = true
	stage.add_child(sunlight)
	var fill := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("5c176f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d69de8")
	environment.ambient_light_energy = 0.72
	fill.environment = environment
	stage.add_child(fill)

	var by_category := {}
	for entry: Dictionary in CatalogScript.entries():
		var category := str(entry.category)
		if category == "Friend Media":
			category = "Friend Media %s" % str(entry.artwork_id)
		if not by_category.has(category):
			by_category[category] = []
		(by_category[category] as Array).append(entry)
	var capture_count := 0
	for category: String in by_category:
		var showcase := Node3D.new()
		showcase.name = "Showcase"
		stage.add_child(showcase)
		var entries := by_category[category] as Array
		var columns := mini(6, entries.size())
		if category == "Landmarks":
			columns = mini(4, entries.size())
		elif category == "Vegetation":
			columns = mini(2, entries.size())
		elif category == "Street Props":
			columns = mini(4, entries.size())
		elif category == "Boats and Waterfront":
			columns = mini(3, entries.size())
		elif category.begins_with("Friend Media"):
			columns = mini(3, entries.size())
		var rows := ceili(float(entries.size()) / columns)
		var spacing := 42.0
		match category:
			"Vegetation": spacing = 18.0
			"Street Props": spacing = 20.0
			"Signs and Posters": spacing = 24.0
			"Boats and Waterfront": spacing = 36.0
			"Sky": spacing = 55.0
		if category.begins_with("Friend Media"):
			spacing = 55.0
		var width := maxf(spacing, (columns - 1) * spacing)
		var depth := maxf(spacing, (rows - 1) * spacing)
		_add_ground(showcase, Vector2(width + spacing, depth + spacing), category == "Boats and Waterfront")
		var maximum_height := 10.0
		for index in range(entries.size()):
			var entry: Dictionary = entries[index]
			var packed := load(CatalogScript.scene_path(entry)) as PackedScene
			var instance := packed.instantiate() as Node3D
			var column := index % columns
			var row := index / columns
			instance.position = Vector3(column * spacing - width * 0.5, 0, row * spacing - depth * 0.5)
			if int(entry.surface) == CatalogScript.AIR:
				instance.position.y = 18.0
			showcase.add_child(instance)
			maximum_height = maxf(maximum_height, float(entry.height) + instance.position.y)
			var label := Label3D.new()
			label.text = str(entry.name)
			label.font_size = 48
			label.pixel_size = 0.025
			label.outline_size = 8
			label.modulate = Color.WHITE
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = instance.position + Vector3.UP * (float(entry.height) + 4.0)
			showcase.add_child(label)
		var center := Vector3(0, maximum_height * 0.32, 0)
		camera.global_position = center + Vector3(width * 0.7 + 20.0, maximum_height + depth * 0.55 + 35.0, depth + 65.0)
		camera.look_at(center, Vector3.UP)
		camera.size = maxf(width / 1.55 + 20.0, depth * 0.8 + maximum_height * 0.65 + 20.0)
		await process_frame
		RenderingServer.force_draw(false)
		await process_frame
		RenderingServer.force_draw(false)
		var image := root.get_texture().get_image()
		var output := ProjectSettings.globalize_path(OUTPUT_DIRECTORY.path_join("%02d_%s.png" % [capture_count, category.to_snake_case()]))
		var error := image.save_png(output)
		if error != OK:
			push_error("Could not save %s: %s" % [output, error_string(error)])
			quit(1)
			return
		print("MANUAL SCENERY VISUAL: %s (%d presets)" % [category, entries.size()])
		stage.remove_child(showcase)
		showcase.free()
		capture_count += 1
	print("MANUAL SCENERY VISUAL QA: %d category captures" % capture_count)
	quit(0)


func _add_ground(parent: Node3D, size: Vector2, water: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.5, size.y)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("087f9f") if water else Color("b97457")
	material.roughness = 0.85
	mesh.material = material
	var ground := MeshInstance3D.new()
	ground.mesh = mesh
	ground.position.y = -0.55
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ground)
