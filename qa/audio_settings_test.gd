extends SceneTree

const SettingsScript := preload("res://scripts/audio/audio_settings.gd")
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
	var settings := SettingsScript.new()
	check(is_equal_approx(float(settings.music_percent), 30.0), "default music volume is 30 percent")
	check(is_equal_approx(float(settings.sfx_percent), 40.0), "default SFX volume is 40 percent")
	root.add_child(settings)
	await process_frame
	var old_music: float = settings.music_percent
	var old_sfx: float = settings.sfx_percent
	settings.set_music_percent(35.0)
	settings.set_sfx_percent(42.0)
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	check(music_bus >= 0 and sfx_bus >= 0, "dedicated Music and SFX buses exist")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(music_bus)) - 0.35) < 0.01, "music slider controls the Music bus")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(sfx_bus)) - 0.42) < 0.01, "SFX slider controls the SFX bus")
	settings.set_music_percent(old_music)
	settings.set_sfx_percent(old_sfx)
	settings.queue_free()
	print("AUDIO SETTINGS QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
