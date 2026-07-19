class_name VehicleAudioController
extends Node

const ENGINE_PATHS := {
	"iskra": "res://assets/audio/engine/engine_2.wav",
	"molniya": "res://assets/audio/engine/engine_5.wav",
	"prizrak": "res://assets/audio/engine/engine_1.wav",
	"titan": "res://assets/audio/engine/engine_3.wav",
	"strela": "res://assets/audio/engine/engine_4.wav",
	"lilpoc": "res://assets/audio/engine/engine_0.wav",
}
const ENGINE_TONES := {
	"iskra": 0.92, "molniya": 1.08, "prizrak": 0.82,
	"titan": 0.88, "strela": 1.0, "lilpoc": 0.68,
}

var engine: AudioStreamPlayer
var scrape: AudioStreamPlayer
var brake: AudioStreamPlayer
var impact_players: Array[AudioStreamPlayer] = []
var powerup: AudioStreamPlayer
var selected_profile := "iskra"
var active := false
var impact_cursor := 0


func _ready() -> void:
	engine = _player("Engine", -45.0)
	scrape = _player("WallScrape", -50.0)
	brake = _player("BrakeSkid", -50.0)
	powerup = _player("Powerup", -7.0)
	scrape.stream = load("res://assets/audio/vehicle/wall_scrape.ogg")
	brake.stream = load("res://assets/audio/vehicle/brake_skid.wav")
	powerup.stream = load("res://assets/audio/ui/powerup.wav")
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
	var ratio := clampf(absf(speed_mps) / maxf(max_speed_mps, 1.0), 0.0, 1.0)
	# Speed, not the throttle key, drives the engine. This gives a calm idle and a
	# progressive rise instead of an instant full-volume roar on the first frame.
	var tone := float(ENGINE_TONES.get(selected_profile, 0.9))
	var target_pitch := tone * lerpf(0.72, 1.72, pow(ratio, 0.72))
	engine.pitch_scale = move_toward(engine.pitch_scale, target_pitch, delta * 1.65)
	var target_engine_db := lerpf(-20.0, -3.0, sqrt(ratio)) + (1.5 if throttle else 0.0)
	engine.volume_db = move_toward(engine.volume_db, target_engine_db, delta * 26.0)
	_update_loop(scrape, scraping and ratio > 0.025, lerpf(-22.0, -5.0, ratio), lerpf(0.82, 1.22, ratio), delta)
	_update_loop(brake, braking and ratio > 0.07, lerpf(-25.0, -7.0, ratio), lerpf(0.75, 1.12, ratio), delta)


func play_impact(strength: float, heavy := false) -> void:
	if impact_players.is_empty(): return
	var player := impact_players[impact_cursor % impact_players.size()]
	impact_cursor += 1
	player.stream = load("res://assets/audio/impacts/crash.ogg" if heavy else ("res://assets/audio/impacts/metal_thud_heavy.wav" if strength > 0.45 else "res://assets/audio/impacts/metal_thud_light.wav"))
	player.volume_db = lerpf(-15.0, -2.0, clampf(strength, 0.0, 1.0))
	player.pitch_scale = lerpf(1.08, 0.82, clampf(strength, 0.0, 1.0))
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
