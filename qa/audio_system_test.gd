extends SceneTree

const AudioController := preload("res://scripts/audio/vehicle_audio_controller.gd")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _run() -> void:
	check(AudioController.ENGINE_PATHS.size() == 6, "every selectable car has an engine profile")
	var loaded_paths := {}
	var stream: AudioStream
	for profile_id in AudioController.ENGINE_PATHS:
		var path := str(AudioController.ENGINE_PATHS[profile_id])
		stream = load(path) as AudioStream
		check(stream != null, "%s engine stream imports" % profile_id)
		loaded_paths[path] = true
	stream = null
	check(loaded_paths.size() == 2, "sports cars share one source while Cadillac keeps its SUV source")
	check(AudioController.ENGINE_BED_PATHS.size() == 6, "every car has a smooth supporting engine loop")
	for path in [
		"res://assets/audio/engine/sports_idle_loop.wav",
		"res://assets/audio/engine/sports_high_loop.wav",
		"res://assets/audio/engine/suv_idle_loop.wav",
		"res://assets/audio/engine/suv_high_loop.wav",
		"res://assets/audio/vehicle/wall_scrape_generated.wav",
		"res://assets/audio/vehicle/sideswipe.wav",
		"res://assets/audio/vehicle/tire_skid.wav",
		"res://assets/audio/vehicle/brake_chirp.wav",
		"res://assets/audio/impacts/impact_light.wav",
		"res://assets/audio/impacts/impact_medium.wav",
		"res://assets/audio/impacts/impact_heavy.wav",
		"res://assets/audio/ui/powerup_short.wav",
	]:
		check(load(path) is AudioStream, "%s imports" % path.get_file())
	var pickup_stream := load("res://assets/audio/ui/powerup_short.wav") as AudioStream
	check(pickup_stream.get_length() < 1.0, "power-up pickup is a genuinely short one-shot")
	var controller := AudioController.new()
	root.add_child(controller)
	await process_frame
	controller.set_profile("lilpoc")
	check((controller.engine.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "driving engine is configured as a continuous loop")
	check((controller.engine_bed.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "idle engine is configured as a continuous loop")
	check((controller.engine.stream as AudioStreamWAV).loop_end > 0, "driving engine has a valid non-zero loop endpoint")
	check((controller.engine_bed.stream as AudioStreamWAV).loop_end > 0, "idle engine has a valid non-zero loop endpoint")
	check((controller.scrape.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "scrape is configured as a continuous loop")
	controller.set_active(true)
	check(controller.engine_bed.volume_db > -10.0, "engine idle becomes audible as soon as the countdown starts")
	for frame in 60:
		controller.update_vehicle(0.0, 220.0, false, false, false, 1.0 / 60.0)
	var idle_pitch := controller.engine.pitch_scale
	var before_ramp_db := controller.engine.volume_db
	controller.update_vehicle(200.0, 220.0, true, false, true, 1.0 / 60.0)
	check(absf(controller.engine.volume_db - before_ramp_db) <= 0.11, "engine volume begins its speed ramp without an abrupt jump")
	for frame in 240:
		controller.update_vehicle(200.0, 220.0, true, false, true, 1.0 / 60.0)
	check(controller.engine.pitch_scale > idle_pitch, "engine pitch rises progressively with speed")
	check(controller.engine_bed.playing, "smooth and recorded engine layers play together")
	check(controller.scrape.playing, "generated scrape loop reacts to wall contact")
	check(controller.scrape.volume_db > -30.0, "short scrape contacts start at an audible level")
	check(controller.sideswipe.playing, "wall contact onset triggers its sideswipe one-shot")
	controller.update_vehicle(200.0, 220.0, true, false, false, 1.0)
	await process_frame
	check(not controller.scrape.playing, "scrape loop stops when wall contact ends")
	controller.play_impact(0.1)
	var light_path := controller.impact_players[0].stream.resource_path
	controller.play_impact(0.3)
	var medium_path := controller.impact_players[1].stream.resource_path
	controller.play_impact(0.8)
	var heavy_path := controller.impact_players[2].stream.resource_path
	check(light_path != medium_path and medium_path != heavy_path, "wall speed selects distinct light, medium, and heavy impacts")
	check(controller.impact_players.any(func(player): return player.playing), "collision layer supports impact one-shots")
	controller.set_active(false)
	for player in controller.impact_players: player.stop()
	for player in [controller.engine, controller.engine_bed, controller.scrape, controller.sideswipe, controller.powerup]: player.stream = null
	for player in controller.impact_players: player.stream = null
	controller.free()
	print("AUDIO SYSTEM QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
