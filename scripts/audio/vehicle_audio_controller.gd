class_name VehicleAudioController
extends Node

const ENGINE_PATHS := {
	"iskra": "res://assets/audio/engine/sports_high_loop.wav",
	"molniya": "res://assets/audio/engine/sports_high_loop.wav",
	"prizrak": "res://assets/audio/engine/sports_high_loop.wav",
	"titan": "res://assets/audio/engine/sports_high_loop.wav",
	"strela": "res://assets/audio/engine/sports_high_loop.wav",
	"lilpoc": "res://assets/audio/engine/suv_high_loop.wav",
}
const ENGINE_BED_PATHS := {
	"iskra": "res://assets/audio/engine/sports_idle_loop.wav",
	"molniya": "res://assets/audio/engine/sports_idle_loop.wav",
	"prizrak": "res://assets/audio/engine/sports_idle_loop.wav",
	"titan": "res://assets/audio/engine/sports_idle_loop.wav",
	"strela": "res://assets/audio/engine/sports_idle_loop.wav",
	"lilpoc": "res://assets/audio/engine/suv_idle_loop.wav",
}
const ENGINE_TONES := {
	"iskra": 0.95, "molniya": 1.08, "prizrak": 0.88,
	"titan": 0.8, "strela": 1.01, "lilpoc": 0.86,
}

var engine: AudioStreamPlayer
var engine_bed: AudioStreamPlayer
var scrape: AudioStreamPlayer
var sideswipe: AudioStreamPlayer
var impact_players: Array[AudioStreamPlayer] = []
var powerup: AudioStreamPlayer
var selected_profile := "iskra"
var active := false
var impact_cursor := 0
var impact_duck_time := 0.0
var was_scraping := false
var smoothed_speed_ratio := 0.0


func _ready() -> void:
	engine = _player("Engine", -45.0)
	engine_bed = _player("EngineBed", -45.0)
	scrape = _player("WallScrape", -50.0)
	sideswipe = _player("Sideswipe", -12.0)
	powerup = _player("Powerup", -4.0)
	scrape.stream = load("res://assets/audio/vehicle/wall_scrape_generated.wav")
	sideswipe.stream = load("res://assets/audio/vehicle/sideswipe.wav")
	powerup.stream = load("res://assets/audio/ui/powerup_short.wav")
	_set_loop(scrape.stream, true)
	for index in 3:
		var player := _player("Impact%d" % index, -8.0)
		impact_players.append(player)
	set_profile(selected_profile)


func set_profile(profile_id: String) -> void:
	selected_profile = profile_id if ENGINE_PATHS.has(profile_id) else "iskra"
	if not is_instance_valid(engine): return
	var was_active := active
	engine.stop()
	engine.stream = load(str(ENGINE_PATHS[selected_profile]))
	engine_bed.stop()
	engine_bed.stream = load(str(ENGINE_BED_PATHS[selected_profile]))
	_set_loop(engine.stream, true)
	_set_loop(engine_bed.stream, true)
	if was_active:
		engine.play()
		engine_bed.play()


func set_active(value: bool) -> void:
	active = value
	if not is_instance_valid(engine): return
	if active:
		smoothed_speed_ratio = 0.0
		engine.volume_db = -43.0
		engine_bed.volume_db = -1.0
		if not engine.playing: engine.play()
		if not engine_bed.playing: engine_bed.play()
	else:
		smoothed_speed_ratio = 0.0
		engine.stop()
		engine_bed.stop()
		scrape.stop()
		sideswipe.stop()
	was_scraping = false


func update_vehicle(speed_mps: float, _max_speed_mps: float, throttle: bool, _braking: bool, scraping: bool, delta: float) -> void:
	if not active or not is_instance_valid(engine): return
	impact_duck_time = maxf(0.0, impact_duck_time - delta)
	# Audio must react at speeds the player reaches during ordinary driving. Using
	# the 500-800 km/h car cap kept every continuous layer near silence until the
	# extreme end of a run. About 320 km/h now spans the useful sound range.
	var target_speed_ratio := clampf(absf(speed_mps) / 105.0, 0.0, 1.0)
	var response_rate := 0.48 if target_speed_ratio > smoothed_speed_ratio else 0.72
	smoothed_speed_ratio = lerpf(smoothed_speed_ratio, target_speed_ratio, 1.0 - exp(-delta * response_rate))
	var road_speed_ratio := smoothstep(0.0, 1.0, smoothed_speed_ratio)
	# Speed, not the throttle key, drives the engine. This gives a calm idle and a
	# progressive rise instead of an instant full-volume roar on the first frame.
	var tone := float(ENGINE_TONES.get(selected_profile, 0.9))
	var target_pitch := tone * lerpf(0.68, 1.16, road_speed_ratio)
	engine.pitch_scale = move_toward(engine.pitch_scale, target_pitch, delta * 0.3)
	engine_bed.pitch_scale = move_toward(engine_bed.pitch_scale, tone * lerpf(0.92, 1.05, road_speed_ratio), delta * 0.24)
	# Equal-power gains avoid the sudden loud middle of a dB-linear crossfade.
	# A slow filtered speed value above makes both pitch and volume continuous.
	var angle := road_speed_ratio * PI * 0.5
	var high_gain := maxf(sin(angle), 0.01)
	var idle_gain := maxf(cos(angle), 0.01)
	var master_db := lerpf(-1.0, 2.0, road_speed_ratio)
	var target_engine_db := linear_to_db(high_gain) - 3.0 + master_db + (0.5 if throttle else 0.0)
	var target_bed_db := linear_to_db(idle_gain) + master_db
	if impact_duck_time > 0.0: target_engine_db -= 7.0
	if impact_duck_time > 0.0: target_bed_db -= 5.0
	engine.volume_db = move_toward(engine.volume_db, target_engine_db, delta * 6.0)
	engine_bed.volume_db = move_toward(engine_bed.volume_db, target_bed_db, delta * 5.0)
	var scrape_now := scraping and absf(speed_mps) > 3.0
	if scrape_now and not was_scraping: sideswipe.play()
	_update_loop(scrape, scrape_now, lerpf(-14.0, -1.0, road_speed_ratio), lerpf(0.86, 1.1, road_speed_ratio), delta, 22.0, 65.0)
	was_scraping = scrape_now


func play_impact(strength: float, heavy := false) -> void:
	if impact_players.is_empty(): return
	impact_duck_time = 0.55 if heavy else 0.28
	var normalized := clampf(strength, 0.0, 1.0)
	var path := "res://assets/audio/impacts/impact_light.wav"
	var sample_gain := 0.0
	if heavy or normalized >= 0.55:
		path = "res://assets/audio/impacts/impact_heavy.wav"
		sample_gain = 5.0
	elif normalized >= 0.2:
		path = "res://assets/audio/impacts/impact_medium.wav"
		sample_gain = 4.0
	_play_impact_layer(path, lerpf(-12.0, -3.0, normalized) + sample_gain, lerpf(1.08, 0.88, normalized))


func _play_impact_layer(path: String, volume: float, pitch: float) -> void:
	var player := impact_players[impact_cursor % impact_players.size()]
	impact_cursor += 1
	player.stream = load(path)
	player.volume_db = volume
	player.pitch_scale = pitch
	player.play()


func play_powerup() -> void:
	if is_instance_valid(powerup): powerup.play()


func _update_loop(player: AudioStreamPlayer, should_play: bool, target_db: float, target_pitch: float, delta: float, attack := 38.0, release := 42.0) -> void:
	if should_play:
		if not player.playing:
			# Contact effects must be heard immediately; most wall touches last well
			# under the two seconds previously needed to climb from -50 dB.
			player.volume_db = target_db - 5.0
			player.pitch_scale = target_pitch
			player.play()
		player.volume_db = move_toward(player.volume_db, target_db, delta * attack)
		player.pitch_scale = move_toward(player.pitch_scale, target_pitch, delta * 2.2)
	else:
		player.volume_db = move_toward(player.volume_db, -50.0, delta * release)
		if player.volume_db <= -48.0: player.stop()


func _player(node_name: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.volume_db = volume
	player.bus = "SFX"
	add_child(player)
	return player


func _set_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
		if enabled:
			# Imported compressed WAVs can report forward looping while retaining a
			# zero loop end. Godot then silently stops at EOF. Use the full sample.
			wav.loop_begin = 0
			wav.loop_end = maxi(1, int(round(wav.get_length() * float(wav.mix_rate))))
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
