extends Node

const SAVE_PATH := "user://audio_settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const SETTINGS_VERSION := 2

var music_percent := 30.0
var sfx_percent := 40.0


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_load_settings()
	_apply()


func set_music_percent(value: float) -> void:
	music_percent = clampf(value, 0.0, 100.0)
	_apply_bus(MUSIC_BUS, music_percent)
	_save_settings()


func set_sfx_percent(value: float) -> void:
	sfx_percent = clampf(value, 0.0, 100.0)
	_apply_bus(SFX_BUS, sfx_percent)
	_save_settings()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply() -> void:
	_apply_bus(MUSIC_BUS, music_percent)
	_apply_bus(SFX_BUS, sfx_percent)


func _apply_bus(bus_name: String, percent: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var linear := percent / 100.0
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	# Version 2 establishes the intended launch mix (30% music / 40% SFX).
	# Migrate the old 70/85 defaults once, then preserve all later user choices.
	if int(config.get_value("audio", "version", 0)) < SETTINGS_VERSION:
		_save_settings()
		return
	music_percent = clampf(float(config.get_value("audio", "music", music_percent)), 0.0, 100.0)
	sfx_percent = clampf(float(config.get_value("audio", "sfx", sfx_percent)), 0.0, 100.0)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "version", SETTINGS_VERSION)
	config.set_value("audio", "music", music_percent)
	config.set_value("audio", "sfx", sfx_percent)
	config.save(SAVE_PATH)
