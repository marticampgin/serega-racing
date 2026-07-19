class_name VehicleAudioController
extends Node

const ENGINE_PATHS := {
	"iskra": "res://assets/audio/engine/4age_loop.mp3",
	"molniya": "res://assets/audio/engine/4age_loop.mp3",
	"prizrak": "res://assets/audio/engine/sedan_loop.mp3",
	"titan": "res://assets/audio/engine/sedan_loop.mp3",
	"strela": "res://assets/audio/engine/4age_loop.mp3",
	"lilpoc": "res://assets/audio/engine/v8_rev.mp3",
}
const ENGINE_TONES := {
	"iskra": 0.86, "molniya": 1.03, "prizrak": 0.9,
	"titan": 0.76, "strela": 0.96, "lilpoc": 0.72,
}

var engine: AudioStreamPlayer
var scrape: AudioStreamPlayer
var brake: AudioStreamPlayer
var impact_players: Array[AudioStreamPlayer] = []
var powerup: AudioStreamPlayer
var selected_profile := "iskra"
var active := false
var impact_cursor := 0
var impact_duck_time := 0.0


func _ready() -> void:
	engine = _player("Engine", -45.0)
	scrape = _player("WallScrape", -50.0)
	brake = _player("BrakeSkid", -50.0)
	powerup = _player("Powerup", -4.0)
	scrape.stream = load("res://assets/audio/vehicle/metal_scrape.mp3")
	brake.stream = load("res://assets/audio/vehicle/brake_skid.wav")
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
	_set_loop(engine.stream, true)
	if was_active: engine.play()


func set_active(value: bool) -> void:
	active = value
	if not is_instance_valid(engine): return
	if active:
		if not engine.playing: engine.play()
	else:
		engine.stop()
		scrape.stop()
		brake.stop()


func update_vehicle(speed_mps: float, max_speed_mps: float, throttle: bool, braking: bool, scraping: bool, delta: float) -> void:
	if not active or not is_instance_valid(engine): return
	impact_duck_time = maxf(0.0, impact_duck_time - delta)
	var ratio := clampf(absf(speed_mps) / maxf(max_speed_mps, 1.0), 0.0, 1.0)
	# Speed, not the throttle key, drives the engine. This gives a calm idle and a
	# progressive rise instead of an instant full-volume roar on the first frame.
	var tone := float(ENGINE_TONES.get(selected_profile, 0.9))
	var target_pitch := tone * lerpf(0.72, 1.72, pow(ratio, 0.72))
	engine.pitch_scale = move_toward(engine.pitch_scale, target_pitch, delta * 1.65)
	var target_engine_db := lerpf(-16.0, -1.0, sqrt(ratio)) + (1.0 if throttle else 0.0)
	if impact_duck_time > 0.0: target_engine_db -= 7.0
	engine.volume_db = move_toward(engine.volume_db, target_engine_db, delta * 26.0)
	_update_loop(scrape, scraping and ratio > 0.025, lerpf(-22.0, -5.0, ratio), lerpf(0.82, 1.22, ratio), delta)
	_update_loop(brake, braking and ratio > 0.07, lerpf(-25.0, -7.0, ratio), lerpf(0.75, 1.12, ratio), delta)


func play_impact(strength: float, heavy := false) -> void:
	if impact_players.is_empty(): return
	impact_duck_time = 0.55 if heavy else 0.28
	var normalized := clampf(strength, 0.0, 1.0)
	_play_impact_layer("res://assets/audio/impacts/car_crash_heavy.mp3" if heavy else "res://assets/audio/impacts/vehicle_collision.mp3", lerpf(-11.0, 0.5, normalized), lerpf(1.02, 0.8, normalized))
	# A short metal-body transient under the longer heavy crash supplies weight
	# without turning repeated wall taps into full cinematic pile-ups.
	if heavy:
		_play_impact_layer("res://assets/audio/impacts/vehicle_collision.mp3", lerpf(-9.0, -1.0, normalized), lerpf(0.96, 0.76, normalized))


func _play_impact_layer(path: String, volume: float, pitch: float) -> void:
	var player := impact_players[impact_cursor % impact_players.size()]
	impact_cursor += 1
	player.stream = load(path)
	player.volume_db = volume
	player.pitch_scale = pitch
	player.play()


func play_powerup() -> void:
	if is_instance_valid(powerup): powerup.play()


func _update_loop(player: AudioStreamPlayer, should_play: bool, target_db: float, target_pitch: float, delta: float) -> void:
	if should_play:
		if not player.playing: player.play()
		player.volume_db = move_toward(player.volume_db, target_db, delta * 38.0)
		player.pitch_scale = move_toward(player.pitch_scale, target_pitch, delta * 2.2)
	else:
		player.volume_db = move_toward(player.volume_db, -50.0, delta * 42.0)
		if player.volume_db <= -48.0: player.stop()


func _player(node_name: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.volume_db = volume
	add_child(player)
	return player


func _set_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
