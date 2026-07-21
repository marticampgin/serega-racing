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
	controller.set_profile("iskra")
	controller.set_active(true)
	for frame in 90:
		controller.update_vehicle(120.0, 180.0, true, true, true, 1.0 / 60.0)
		await process_frame
	var available := capture.get_frames_available()
	var samples := capture.get_buffer(available)
	var peak := 0.0
	var sum_squared := 0.0
	for sample in samples:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		sum_squared += sample.length_squared() * 0.5
	var rms := sqrt(sum_squared / maxf(float(samples.size()), 1.0))
	print("CONTINUOUS AUDIO OUTPUT: driver=%s frames=%d peak=%.5f rms=%.5f" % [AudioServer.get_driver_name(), available, peak, rms])
	AudioServer.remove_bus_effect(bus, 0)
	quit(0 if available > 0 and peak > 0.001 else 1)
