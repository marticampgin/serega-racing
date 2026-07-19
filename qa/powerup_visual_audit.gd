extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.call("_on_mode_confirmed", "obstacle_course", true)
	game.call("_on_car_confirmed", "iskra", Color("e9234f"))
	await process_frame
	game.set_physics_process(false)
	var pickups := get_nodes_in_group("powerup")
	if pickups.is_empty():
		push_error("POWERUP VISUAL AUDIT: no pickup generated")
		quit(1)
		return
	var pickup := pickups[0] as Area3D
	var camera := game.get("chase_camera") as Camera3D
	var forward := pickup.global_transform.basis.z.normalized()
	camera.global_position = pickup.global_position + forward * 6.5 + Vector3.UP * 1.8
	camera.look_at(pickup.global_position, Vector3.UP)
	await process_frame
	await process_frame
	await create_timer(0.35).timeout
	var image := root.get_viewport().get_texture().get_image()
	var error := image.save_png("res://qa/screenshots/powerup-3d-audit.png")
	print("POWERUP VISUAL AUDIT: ", error_string(error))
	quit(0 if error == OK else 1)
