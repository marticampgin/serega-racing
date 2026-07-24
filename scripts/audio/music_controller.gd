extends Node

const MENU_TRACK := "res://assets/audio/music/menu_slow.mp3"
const CADILLAC_TRACK := "res://assets/audio/music/cadillac.mp3"
const RACE_TRACKS := [
	"res://assets/audio/music/race_01.mp3",
	"res://assets/audio/music/race_02.mp3",
	"res://assets/audio/music/race_03.mp3",
	"res://assets/audio/music/race_04.mp3",
	"res://assets/audio/music/race_05.mp3",
	"res://assets/audio/music/race_06.mp3",
	"res://assets/audio/music/race_07.mp3",
	"res://assets/audio/music/race_08.mp3",
	"res://assets/audio/music/race_09.mp3",
	"res://assets/audio/music/race_10.mp3",
	"res://assets/audio/music/race_11.mp3",
	"res://assets/audio/music/race_12.mp3",
	"res://assets/audio/music/race_13.mp3",
	"res://assets/audio/music/race_14.mp3",
	"res://assets/audio/music/race_15.mp3",
	"res://assets/audio/music/race_16.mp3",
	"res://assets/audio/music/race_17.mp3",
	"res://assets/audio/music/race_18.mp3",
	"res://assets/audio/music/race_19.mp3",
	"res://assets/audio/music/race_20.mp3",
]

var player: AudioStreamPlayer
var race_sequence: Array[String] = []
var race_index := 0
var cadillac_race := false
var menu_active := false


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "SoundtrackPlayer"
	player.bus = "Music"
	player.finished.connect(_on_track_finished)
	add_child(player)
	play_menu()


func play_menu() -> void:
	menu_active = true
	cadillac_race = false
	race_sequence.clear()
	race_index = 0
	_play_path(MENU_TRACK, true, -5.0)


func prepare_race(car_id: String) -> void:
	menu_active = false
	cadillac_race = car_id == "lilpoc"
	race_sequence.clear()
	race_index = 0
	if cadillac_race:
		if ResourceLoader.exists(CADILLAC_TRACK):
			race_sequence.append(CADILLAC_TRACK)
		return
	for path in RACE_TRACKS:
		if ResourceLoader.exists(path):
			race_sequence.append(path)
	race_sequence.shuffle()


func start_prepared_race() -> void:
	if race_sequence.is_empty():
		player.stop()
		player.stream = null
		return
	race_index = clampi(race_index, 0, race_sequence.size() - 1)
	_play_path(race_sequence[race_index], cadillac_race, 0.0)


func stop() -> void:
	if is_instance_valid(player):
		player.stop()


func next_track() -> void:
	if menu_active or cadillac_race or race_sequence.size() < 2:
		return
	race_index = wrapi(race_index + 1, 0, race_sequence.size())
	_play_path(race_sequence[race_index], false, 0.0)


func previous_track() -> void:
	if menu_active or cadillac_race or race_sequence.size() < 2:
		return
	race_index = wrapi(race_index - 1, 0, race_sequence.size())
	_play_path(race_sequence[race_index], false, 0.0)


func track_count() -> int:
	return race_sequence.size()


func _on_track_finished() -> void:
	if menu_active:
		_play_path(MENU_TRACK, true, -5.0)
	elif cadillac_race:
		_play_path(CADILLAC_TRACK, true, 0.0)
	elif not race_sequence.is_empty():
		next_track()


func _play_path(path: String, looped: bool, volume_db: float) -> void:
	if not ResourceLoader.exists(path):
		player.stop()
		player.stream = null
		return
	var stream := load(path)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = looped
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.play()
