extends SceneTree

const CarFactory := preload("res://scripts/cars/car_visual_factory.gd")
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
	check(CarFactory.PROFILES.size() == 3, "three car profiles are available")
	check(CarFactory.COLORS.size() >= 6, "cars offer a useful color palette")
	var signatures: Dictionary = {}
	for profile in CarFactory.PROFILES:
		var holder := Node3D.new()
		root.add_child(holder)
		var visual := CarFactory.build(holder, str(profile.id), CarFactory.COLORS[0])
		var meshes := visual.find_children("*", "MeshInstance3D", true, false)
		var signature := ""
		for value in meshes:
			var mesh := (value as MeshInstance3D).mesh
			if mesh != null:
				signature += var_to_str(mesh.get_aabb().size.snapped(Vector3.ONE * 0.01))
		signatures[signature] = true
		check(meshes.size() >= 10, "%s has a complete low-poly visual" % profile.name)
		holder.queue_free()
	check(signatures.size() == 3, "all three cars have distinct silhouettes")

	var selector_scene := load("res://scenes/ui/car_selection_overlay.tscn") as PackedScene
	var selector := selector_scene.instantiate()
	root.add_child(selector)
	await process_frame
	selector.call("show_selector")
	var preview := selector.get("preview_root") as Node3D
	var before := preview.rotation.y
	selector.call("_process", 1.0)
	check(absf(preview.rotation.y - before) > 0.3, "showroom car rotates smoothly")
	selector.call("_change_car", 1)
	check(int(selector.get("selected_car")) == 1, "selection arrows change the car")
	selector.call("_select_color", 3)
	check(int(selector.get("selected_color")) == 3, "color swatches change the body color")

	print("CAR SELECTION QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
