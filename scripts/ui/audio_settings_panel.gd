class_name AudioSettingsPanel
extends Control

signal closed

const AudioSettingsScript := preload("res://scripts/audio/audio_settings.gd")

var music_slider: HSlider
var sfx_slider: HSlider
var music_value: Label
var sfx_value: Label
var back_button: Button
var audio_settings: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	audio_settings = get_node_or_null("/root/AudioSettings")
	if audio_settings == null:
		audio_settings = AudioSettingsScript.new()
		audio_settings.name = "AudioSettings"
		get_tree().root.add_child(audio_settings)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()


func show_panel() -> void:
	music_slider.set_value_no_signal(float(audio_settings.music_percent))
	sfx_slider.set_value_no_signal(float(audio_settings.sfx_percent))
	_refresh_values()
	show()
	back_button.grab_focus()


func close_panel() -> void:
	hide()
	closed.emit()


func _build_interface() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.002, 0.04, 0.88)
	add_child(shade)
	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.position = Vector2(-285, -230)
	card.size = Vector2(570, 460)
	card.add_theme_stylebox_override("panel", _panel(Color("10062b"), Color("46e7ff"), 22))
	add_child(card)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 46)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 22)
	margin.add_child(content)
	var title := Label.new()
	title.text = "НАСТРОЙКИ ЗВУКА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("ffe45f"))
	content.add_child(title)
	var hint := Label.new()
	hint.text = "ГРОМКОСТЬ МОЖНО МЕНЯТЬ В ЛЮБОЙ МОМЕНТ"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("79eaff"))
	content.add_child(hint)
	var music_row := _volume_row("МУЗЫКА")
	music_slider = music_row.slider
	music_value = music_row.value_label
	content.add_child(music_row.root)
	var sfx_row := _volume_row("ЗВУКОВЫЕ ЭФФЕКТЫ")
	sfx_slider = sfx_row.slider
	sfx_value = sfx_row.value_label
	content.add_child(sfx_row.root)
	music_slider.value_changed.connect(func(value: float): audio_settings.set_music_percent(value); _refresh_values())
	sfx_slider.value_changed.connect(func(value: float): audio_settings.set_sfx_percent(value); _refresh_values())
	back_button = Button.new()
	back_button.text = "НАЗАД"
	back_button.custom_minimum_size = Vector2(350, 58)
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.add_theme_stylebox_override("normal", _panel(Color("b51a72"), Color("ff82d0"), 10))
	back_button.add_theme_stylebox_override("hover", _panel(Color("31b9dc"), Color("d7fbff"), 10))
	back_button.add_theme_stylebox_override("pressed", _panel(Color("276b9e"), Color("ffe45f"), 10))
	back_button.pressed.connect(close_panel)
	content.add_child(back_button)


func _volume_row(label_text: String) -> Dictionary:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 7)
	var header := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("f2eaff"))
	header.add_child(label)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 64
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 18)
	value_label.add_theme_color_override("font_color", Color("79eaff"))
	header.add_child(value_label)
	root.add_child(header)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size = Vector2(470, 36)
	root.add_child(slider)
	return {"root": root, "slider": slider, "value_label": value_label}


func _refresh_values() -> void:
	music_value.text = "%d%%" % int(round(music_slider.value))
	sfx_value.text = "%d%%" % int(round(sfx_slider.value))


func _panel(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style
