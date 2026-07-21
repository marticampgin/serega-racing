extends SceneTree

const AudioController := preload("res://scripts/audio/vehicle_audio_controller.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if AudioServer.get_driver_name() == "Dummy":
		print("CONTINUOUS AUDIO OUTPUT: skipped because the headless Dummy driver does not mix samples")
		quit(0)
		return
	var bus := AudioServer.get_bus_index("SFX")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "SFX")
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, 0.0)
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(bus, capture, 0)
	var controller := AudioController.new()
	root.add_child(controller)
	await process_frame
	var profile := "iskra"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profile="):
			profile = argument.trim_prefix("--profile=")
	controller.set_profile(profile)
	controller.set_active(true)
	var rated_max_speed := (800.0 if profile == "lilpoc" else 500.0) / 3.6
	var started_at := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < 6400:
		# Isolate the engine: no tyre, scrape, impact, or interface effects.
		controller.update_vehicle(rated_max_speed, rated_max_speed, true, false, false, maxf(root.get_process_delta_time(), 1.0 / 120.0))
		await process_frame
	var available := capture.get_frames_available()
	var samples := capture.get_buffer(available)
	var peak := 0.0
	var sum_squared := 0.0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		sum_squared += sample.length_squared() * 0.5
	var rms := sqrt(sum_squared / maxf(float(samples.size()), 1.0))
	print("CONTINUOUS AUDIO OUTPUT: profile=%s driver=%s frames=%d peak=%.5f rms=%.5f idle_playing=%s drive_playing=%s max_roar_playing=%s" % [
		profile, AudioServer.get_driver_name(), available, peak, rms,
		controller.engine_bed.playing, controller.engine.playing, controller.max_roar.playing,
	])
	AudioServer.remove_bus_effect(bus, 0)
	quit(0 if available > 0 and peak > 0.001 and not controller.engine_bed.playing and not controller.engine.playing and controller.max_roar.playing else 1)
