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
var max_rev_phase := 0.0


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
		max_rev_phase = 0.0
		engine.volume_db = -43.0
		engine_bed.volume_db = -1.0
		if not engine.playing: engine.play()
		if not engine_bed.playing: engine_bed.play()
	else:
		max_rev_phase = 0.0
		engine.stop()
		engine_bed.stop()
		scrape.stop()
		sideswipe.stop()
	was_scraping = false


func update_vehicle(speed_mps: float, max_speed_mps: float, throttle: bool, _braking: bool, scraping: bool, delta: float) -> void:
	if not active or not is_instance_valid(engine): return
	impact_duck_time = maxf(0.0, impact_duck_time - delta)
	# Speed itself already accelerates and decelerates continuously. Map it directly
	# and symmetrically so sound never waits, catches up, or uses staged thresholds.
	var speed_ratio := clampf(absf(speed_mps) / maxf(max_speed_mps, 1.0), 0.0, 1.0)
	var tone := float(ENGINE_TONES.get(selected_profile, 0.9))
	var limiter_blend := smoothstep(0.94, 1.0, speed_ratio) if throttle else 0.0
	if limiter_blend > 0.0:
		max_rev_phase = fmod(max_rev_phase + delta * TAU / 1.65, TAU)
	var limiter_wave := sin(max_rev_phase) * limiter_blend
	var target_pitch := tone * lerpf(0.7, 1.16, speed_ratio) * (1.0 + 0.022 * limiter_wave)
	var idle_pitch := tone * lerpf(0.92, 1.05, speed_ratio)
	var follow := 1.0 - exp(-delta * 10.0)
	engine.pitch_scale = lerpf(engine.pitch_scale, target_pitch, follow)
	engine_bed.pitch_scale = lerpf(engine_bed.pitch_scale, idle_pitch, follow)
	# Amplitudes—not decibels—move linearly with speed. The high recording is
	# naturally about 6 dB louder, hence its 0.5 ceiling. This keeps total power
	# continuous while acceleration and deceleration remain exact mirror images.
	var high_gain := lerpf(0.02, 0.5, speed_ratio)
	var idle_gain := lerpf(1.0, 0.15, speed_ratio)
	var target_engine_db := linear_to_db(high_gain) + (0.25 if throttle else 0.0) + 0.55 * limiter_wave
	var target_bed_db := linear_to_db(idle_gain)
	if impact_duck_time > 0.0: target_engine_db -= 7.0
	if impact_duck_time > 0.0: target_bed_db -= 5.0
	engine.volume_db = lerpf(engine.volume_db, target_engine_db, follow)
	engine_bed.volume_db = lerpf(engine_bed.volume_db, target_bed_db, follow)
	var scrape_now := scraping and absf(speed_mps) > 3.0
	if scrape_now and not was_scraping: sideswipe.play()
	_update_loop(scrape, scrape_now, lerpf(-14.0, -1.0, speed_ratio), lerpf(0.86, 1.1, speed_ratio), delta, 22.0, 65.0)
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
