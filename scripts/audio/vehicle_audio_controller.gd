class_name VehicleAudioController
extends Node

const ENGINE_PATHS := {
	"iskra": "res://assets/audio/engine/sports_high.wav",
	"molniya": "res://assets/audio/engine/sports_high.wav",
	"prizrak": "res://assets/audio/engine/sports_high.wav",
	"titan": "res://assets/audio/engine/sports_high.wav",
	"strela": "res://assets/audio/engine/sports_high.wav",
	"lilpoc": "res://assets/audio/engine/suv_high.wav",
}
const ENGINE_BED_PATHS := {
	"iskra": "res://assets/audio/engine/sports_idle.wav",
	"molniya": "res://assets/audio/engine/sports_idle.wav",
	"prizrak": "res://assets/audio/engine/sports_idle.wav",
	"titan": "res://assets/audio/engine/sports_idle.wav",
	"strela": "res://assets/audio/engine/sports_idle.wav",
	"lilpoc": "res://assets/audio/engine/suv_idle.wav",
}
const ENGINE_TONES := {
	"iskra": 0.95, "molniya": 1.08, "prizrak": 0.88,
	"titan": 0.8, "strela": 1.01, "lilpoc": 0.86,
}

var engine: AudioStreamPlayer
var engine_bed: AudioStreamPlayer
var scrape: AudioStreamPlayer
var brake: AudioStreamPlayer
var sideswipe: AudioStreamPlayer
var brake_chirp: AudioStreamPlayer
var impact_players: Array[AudioStreamPlayer] = []
var powerup: AudioStreamPlayer
var selected_profile := "iskra"
var active := false
var impact_cursor := 0
var impact_duck_time := 0.0
var was_scraping := false
var was_braking := false


func _ready() -> void:
	engine = _player("Engine", -45.0)
	engine_bed = _player("EngineBed", -45.0)
	scrape = _player("WallScrape", -50.0)
	brake = _player("BrakeSkid", -50.0)
	sideswipe = _player("Sideswipe", -12.0)
	brake_chirp = _player("BrakeChirp", -14.0)
	powerup = _player("Powerup", -4.0)
	scrape.stream = load("res://assets/audio/vehicle/wall_scrape_generated.wav")
	brake.stream = load("res://assets/audio/vehicle/tire_skid.wav")
	sideswipe.stream = load("res://assets/audio/vehicle/sideswipe.wav")
	brake_chirp.stream = load("res://assets/audio/vehicle/brake_chirp.wav")
	powerup.stream = load("res://assets/audio/ui/powerup_short.wav")
	_set_loop(scrape.stream, true)
	_set_loop(brake.stream, true)
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
		if not engine.playing: engine.play()
		if not engine_bed.playing: engine_bed.play()
	else:
		engine.stop()
		engine_bed.stop()
		scrape.stop()
		brake.stop()
		sideswipe.stop()
		brake_chirp.stop()
	was_scraping = false
	was_braking = false


func update_vehicle(speed_mps: float, max_speed_mps: float, throttle: bool, braking: bool, scraping: bool, delta: float) -> void:
	if not active or not is_instance_valid(engine): return
	impact_duck_time = maxf(0.0, impact_duck_time - delta)
	var ratio := clampf(absf(speed_mps) / maxf(max_speed_mps, 1.0), 0.0, 1.0)
	# Speed, not the throttle key, drives the engine. This gives a calm idle and a
	# progressive rise instead of an instant full-volume roar on the first frame.
	var tone := float(ENGINE_TONES.get(selected_profile, 0.9))
	var target_pitch := tone * lerpf(0.56, 1.18, pow(ratio, 0.68))
	engine.pitch_scale = move_toward(engine.pitch_scale, target_pitch, delta * 1.65)
	engine_bed.pitch_scale = move_toward(engine_bed.pitch_scale, tone * lerpf(0.92, 1.08, minf(ratio / 0.45, 1.0)), delta * 1.45)
	# Crossfade the matching idle and high-RPM recordings. The high recording is
	# pitched down at low speed, then rises smoothly instead of switching engines.
	var high_mix := smoothstep(0.035, 0.72, ratio)
	var target_engine_db := lerpf(-42.0, -1.5, high_mix) + (0.8 if throttle else 0.0)
	var target_bed_db := lerpf(-4.5, -24.0, smoothstep(0.0, 0.58, ratio))
	if impact_duck_time > 0.0: target_engine_db -= 7.0
	if impact_duck_time > 0.0: target_bed_db -= 5.0
	engine.volume_db = move_toward(engine.volume_db, target_engine_db, delta * 26.0)
	engine_bed.volume_db = move_toward(engine_bed.volume_db, target_bed_db, delta * 22.0)
	var scrape_now := scraping and ratio > 0.025
	var brake_now := braking and ratio > 0.07
	if scrape_now and not was_scraping: sideswipe.play()
	if brake_now and not was_braking: brake_chirp.play()
	_update_loop(scrape, scrape_now, lerpf(-25.0, -8.0, ratio), lerpf(0.86, 1.1, ratio), delta, 15.0, 18.0)
	_update_loop(brake, braking and ratio > 0.07, lerpf(-25.0, -7.0, ratio), lerpf(0.75, 1.12, ratio), delta)
	was_scraping = scrape_now
	was_braking = brake_now


func play_impact(strength: float, heavy := false) -> void:
	if impact_players.is_empty(): return
	impact_duck_time = 0.55 if heavy else 0.28
	var normalized := clampf(strength, 0.0, 1.0)
	var path := "res://assets/audio/impacts/impact_light.wav"
	if heavy or normalized > 0.72:
		path = "res://assets/audio/impacts/impact_heavy.wav"
	elif normalized > 0.32:
		path = "res://assets/audio/impacts/impact_medium.wav"
	_play_impact_layer(path, lerpf(-13.0, -2.0, normalized), lerpf(1.04, 0.9, normalized))


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
		if not player.playing: player.play()
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
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
