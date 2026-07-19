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
	check(CarFactory.PROFILES.size() == 6, "five bolids and one secret SUV are available")
	check(CarFactory.COLORS.size() >= 7, "cars offer a useful color palette including black")
	var signatures: Dictionary = {}
	for profile in CarFactory.PROFILES:
		check(float(profile.max_speed_kmh) >= 450.0, "%s has at least a 450 km/h maximum" % profile.name)
		check(int(profile.acceleration) >= 1 and int(profile.tolerance) >= 1, "%s defines acceleration and damage tolerance" % profile.name)
		var holder := Node3D.new()
		root.add_child(holder)
		var visual := CarFactory.build(holder, str(profile.id), CarFactory.COLORS[0])
		var meshes := visual.find_children("*", "MeshInstance3D", true, false)
		var round_wheels := 0
		var signature := ""
		for value in meshes:
			var mesh := (value as MeshInstance3D).mesh
			if mesh != null:
				if mesh is CylinderMesh: round_wheels += 1
				signature += var_to_str(mesh.get_aabb().size.snapped(Vector3.ONE * 0.01))
		signatures[signature] = true
		check(meshes.size() >= 10, "%s has a complete low-poly visual" % profile.name)
		check(round_wheels >= 4, "%s uses round wheels with separate rim details" % profile.name)
		holder.queue_free()
	check(signatures.size() == 6, "all six cars have distinct silhouettes")

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
	check(not selector.get("unlock_row").visible, "secret code field is hidden for regular bolids")
	selector.set("selected_car", 5)
	selector.call("_refresh_selection")
	check(selector.get("unlock_row").visible, "secret code field appears only on the Cadillac-style SUV")
	check(is_equal_approx(float(CarFactory.PROFILES[5].max_speed_kmh), 800.0), "secret SUV reaches the 800 km/h maximum")
	check(selector.get("confirm_button").disabled, "secret SUV starts locked")
	selector.get("code_edit").text = "wrong"
	selector.call("_try_unlock")
	check(selector.get("confirm_button").disabled, "wrong code does not unlock the SUV")
	selector.get("code_edit").text = "LILPOC_"
	selector.call("_try_unlock")
	check(not selector.get("confirm_button").disabled, "exact easter-egg code unlocks the SUV")

	print("CAR SELECTION QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
