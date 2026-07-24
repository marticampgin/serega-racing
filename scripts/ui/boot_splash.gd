extends CanvasLayer

const MAIN_SCENE := "res://scenes/main.tscn"
const FIRST_SPLASH := preload("res://assets/generated/ui/loading-vladikus-clean.png")
const SECOND_SPLASH := preload("res://assets/generated/ui/loading-bralis-games.png")
const FADE_SECONDS := 0.65
const HOLD_SECONDS := 3.0

@onready var splash: TextureRect = $Root/Splash


func _ready() -> void:
	# Begin loading the main scene while the two branded cards are visible.
	ResourceLoader.load_threaded_request(MAIN_SCENE)
	get_node("/root/MusicController").call("play_menu")
	await _show_card(FIRST_SPLASH, TextureRect.STRETCH_KEEP_ASPECT_COVERED, true)
	await _show_card(SECOND_SPLASH, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, false)
	while ResourceLoader.load_threaded_get_status(MAIN_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene
	if packed == null:
		push_error("Could not load the main game scene after the splash sequence.")
		get_tree().quit(1)
		return
	# Keep splash 2 on the top canvas while the heavy world _ready() work runs.
	# Once the complete menu is ready underneath, cross-fade directly into it.
	var main := packed.instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var final_fade := create_tween()
	final_fade.tween_property(splash, "modulate:a", 0.0, FADE_SECONDS)
	await final_fade.finished
	queue_free()


func _show_card(texture: Texture2D, stretch: TextureRect.StretchMode, fade_out: bool) -> void:
	splash.texture = texture
	splash.stretch_mode = stretch
	splash.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(splash, "modulate:a", 1.0, FADE_SECONDS)
	await fade_in.finished
	await get_tree().create_timer(HOLD_SECONDS).timeout
	if not fade_out:
		return
	var fade_out_tween := create_tween()
	fade_out_tween.tween_property(splash, "modulate:a", 0.0, FADE_SECONDS)
	await fade_out_tween.finished
