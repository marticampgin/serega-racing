extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if AudioServer.get_driver_name() == "Dummy":
		print("GAME ENGINE OUTPUT: skipped because the headless Dummy driver does not mix samples")
		quit(0)
		return
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	await process_frame
	var bus := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, 0.0)
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, capture, 0)
	game.call("_on_mode_confirmed", "free_run", false)
	game.call("_on_car_confirmed", "iskra", Color("e9234f"))
	# The countdown holds the car still and triggers no other gameplay effects,
	# leaving only the engine idle on the SFX bus.
	for frame in 90:
		await process_frame
	var controller = game.get("vehicle_audio")
	var available := capture.get_frames_available()
	var samples := capture.get_buffer(available)
	var peak := 0.0
	var sum_squared := 0.0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		sum_squared += sample.length_squared() * 0.5
	var rms := sqrt(sum_squared / maxf(float(samples.size()), 1.0))
	print("GAME ENGINE OUTPUT: driver=%s frames=%d peak=%.5f rms=%.5f idle_playing=%s idle_db=%.2f drive_playing=%s drive_db=%.2f" % [
		AudioServer.get_driver_name(), available, peak, rms,
		controller.engine_bed.playing, controller.engine_bed.volume_db,
		controller.engine.playing, controller.engine.volume_db,
	])
	print("GAME ENGINE STREAMS: idle_loop=%s idle_begin=%d idle_end=%d idle_length=%.2f drive_loop=%s drive_begin=%d drive_end=%d drive_length=%.2f" % [
		controller.engine_bed.stream.loop_mode, controller.engine_bed.stream.loop_begin,
		controller.engine_bed.stream.loop_end, controller.engine_bed.stream.get_length(),
		controller.engine.stream.loop_mode, controller.engine.stream.loop_begin,
		controller.engine.stream.loop_end, controller.engine.stream.get_length(),
	])
	AudioServer.remove_bus_effect(bus, 0)
	quit(0 if available > 0 and peak > 0.001 else 1)
