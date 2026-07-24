extends SceneTree

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
	check(load("res://scenes/ui/boot_splash.tscn") is PackedScene, "two-card boot scene loads")
	var boot_constants := (load("res://scripts/ui/boot_splash.gd") as Script).get_script_constant_map()
	check(is_equal_approx(float(boot_constants.FADE_SECONDS), 1.0), "loading cards use a slower one-second fade")
	check(is_equal_approx(float(boot_constants.HOLD_SECONDS), 4.0), "each loading card remains fully visible for four seconds")
	check(ResourceLoader.exists("res://assets/generated/ui/loading-vladikus-clean.png"), "clean first loading card is imported")
	check(ResourceLoader.exists("res://assets/generated/ui/loading-bralis-games.png"), "second loading card is imported")
	check(str(ProjectSettings.get_setting("application/run/main_scene")).ends_with("boot_splash.tscn"), "boot sequence is the project entry scene")
	check(ResourceLoader.exists("res://assets/generated/ui/car-selection-retro-grid.png"), "car selector uses a dedicated retro backdrop")

	var music: Node = root.get_node("MusicController")
	music.call("prepare_race", "iskra")
	check(int(music.call("track_count")) == 20, "all twenty non-Slow songs form the normal-car playlist")
	var unique_tracks := {}
	for path in music.get("race_sequence"):
		unique_tracks[path] = true
	check(unique_tracks.size() == 20, "the generated race sequence contains no duplicate songs")
	music.call("start_prepared_race")
	var first_track := (music.get("player").stream as AudioStream).resource_path
	music.call("set_ducked", true, false)
	check(music.get("player").playing and absf(float(music.get("player").volume_db) + 10.5) < 0.01, "pause/results duck the current song by roughly 70 percent without restarting it")
	music.call("set_ducked", false, false)
	check((music.get("player").stream as AudioStream).resource_path == first_track and is_zero_approx(float(music.get("player").volume_db)), "resuming restores the same song at race volume")
	music.call("next_track")
	check((music.get("player").stream as AudioStream).resource_path != first_track, "P-style next advances within the shuffled sequence")
	music.call("previous_track")
	check((music.get("player").stream as AudioStream).resource_path == first_track, "O-style previous returns within the same sequence")
	music.call("prepare_race", "lilpoc")
	check(int(music.call("track_count")) == 1 and music.get("race_sequence")[0].ends_with("cadillac.mp3"), "Cadillac keeps its exclusive single-song loop")
	music.call("play_menu")
	check(bool(music.get("menu_active")) and music.get("player").playing, "Slow loops as the persistent menu and loading music")
	check(is_equal_approx(float(music.get("player").volume_db), -5.0), "menu music plays slightly below race-track level")

	print("MUSIC AND BOOT QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
