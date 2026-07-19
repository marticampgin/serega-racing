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
	check(loaded_paths.size() == 6, "engine profiles use six distinct source loops")
	for path in [
		"res://assets/audio/vehicle/wall_scrape.ogg",
		"res://assets/audio/vehicle/brake_skid.wav",
		"res://assets/audio/impacts/crash.ogg",
		"res://assets/audio/ui/powerup.wav",
	]:
		check(load(path) is AudioStream, "%s imports" % path.get_file())
	var controller := AudioController.new()
	root.add_child(controller)
	await process_frame
	controller.set_profile("lilpoc")
	controller.set_active(true)
	controller.update_vehicle(0.0, 220.0, false, false, false, 0.1)
	var idle_pitch := controller.engine.pitch_scale
	controller.update_vehicle(200.0, 220.0, true, true, true, 0.1)
	check(controller.engine.pitch_scale > idle_pitch, "engine pitch rises progressively with speed")
	check(controller.scrape.playing and controller.brake.playing, "scrape and brake layers react to their contacts")
	controller.play_impact(0.8, true)
	check(controller.impact_players.any(func(player): return player.playing), "collision layer supports impact one-shots")
	controller.set_active(false)
	for player in controller.impact_players: player.stop()
	for player in [controller.engine, controller.scrape, controller.brake, controller.powerup]: player.stream = null
	for player in controller.impact_players: player.stream = null
	controller.free()
	print("AUDIO SYSTEM QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
