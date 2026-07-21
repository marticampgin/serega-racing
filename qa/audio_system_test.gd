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
		"res://assets/audio/engine/sports_idle.wav",
		"res://assets/audio/engine/sports_high.wav",
		"res://assets/audio/engine/suv_idle.wav",
		"res://assets/audio/engine/suv_high.wav",
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
	controller.set_active(true)
	check(controller.engine_bed.volume_db > -10.0, "engine idle becomes audible as soon as the countdown starts")
	controller.update_vehicle(0.0, 220.0, false, false, false, 0.1)
	var idle_pitch := controller.engine.pitch_scale
	controller.update_vehicle(200.0, 220.0, true, true, true, 0.1)
	check(controller.engine.pitch_scale > idle_pitch, "engine pitch rises progressively with speed")
	check(controller.engine_bed.playing, "smooth and recorded engine layers play together")
	check(controller.scrape.playing and controller.brake.playing, "generated scrape and tyre loops react to their contacts")
	check(controller.scrape.volume_db > -30.0, "short scrape contacts start at an audible level")
	check(controller.sideswipe.playing and controller.brake_chirp.playing, "contact onset triggers sideswipe and brake chirp one-shots")
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
	for player in [controller.engine, controller.engine_bed, controller.scrape, controller.brake, controller.sideswipe, controller.brake_chirp, controller.powerup]: player.stream = null
	for player in controller.impact_players: player.stream = null
	controller.free()
	print("AUDIO SYSTEM QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
