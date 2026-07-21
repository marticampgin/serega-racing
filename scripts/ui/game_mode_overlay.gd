class_name GameModeOverlay
extends CanvasLayer

signal mode_confirmed(mode: String, powerups: bool, laps: int, realistic_fueling: bool)
signal back_requested

const FREE_IMAGE := "res://assets/generated/ui/mode-free-run-v1.png"
const OBSTACLE_IMAGE := "res://assets/generated/ui/mode-obstacle-course-v1.png"

var selected_mode := "free_run"
var free_button: TextureButton
var obstacle_button: TextureButton
var free_panel: PanelContainer
var obstacle_panel: PanelContainer
var background: TextureRect
var ui_move: AudioStreamPlayer
var ui_select: AudioStreamPlayer
var lap_count := 2
var lap_value_label: Label
var realistic_fueling_toggle: CheckButton


func _ready() -> void:
	layer = 105
	ui_move = AudioStreamPlayer.new()
	ui_move.stream = load("res://assets/audio/ui/menu_move.wav")
	ui_move.volume_db = -8.0
	ui_move.bus = "SFX"
	add_child(ui_move)
	ui_select = AudioStreamPlayer.new()
	ui_select.stream = load("res://assets/audio/ui/menu_select.wav")
	ui_select.volume_db = -8.0
	ui_select.bus = "SFX"
	add_child(ui_select)
	_build_interface()
	_refresh()
	hide()


func show_selector() -> void:
	show()
	free_button.grab_focus()


func set_background_path(path: String) -> void:
	if is_instance_valid(background) and ResourceLoader.exists(path): background.texture = load(path)


func _build_interface() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var fallback := ColorRect.new()
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.color = Color("07021a")
	root.add_child(fallback)
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.25, 0.18, 0.36, 0.28)
	root.add_child(background)
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.02, 0.005, 0.07, 0.78)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tint)
	var content := VBoxContainer.new()
	content.anchor_left = 0.16
	content.anchor_top = 0.06
	content.anchor_right = 0.84
	content.anchor_bottom = 0.94
	content.add_theme_constant_override("separation", 18)
	root.add_child(content)
	content.add_child(_label("ВЫБЕРИТЕ РЕЖИМ", 42, Color("ffe45f"), HORIZONTAL_ALIGNMENT_CENTER))
	var cards := HBoxContainer.new()
	cards.custom_minimum_size = Vector2(0, 440)
	cards.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 28)
	content.add_child(cards)
	var free := _mode_card(FREE_IMAGE, "СВОБОДНАЯ ГОНКА", "Чистая трасса • Только прочность • Лучшее время", "free_run")
	free_panel = free.panel
	free_button = free.button
	cards.add_child(free_panel)
	var obstacle := _mode_card(OBSTACLE_IMAGE, "ПОЛОСА ПРЕПЯТСТВИЙ", "Транспорт • Техника • Усиления включены", "obstacle_course")
	obstacle_panel = obstacle.panel
	obstacle_button = obstacle.button
	cards.add_child(obstacle_panel)
	var options := HBoxContainer.new()
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	options.add_theme_constant_override("separation", 14)
	content.add_child(options)
	options.add_child(_label("КРУГИ", 18, Color("dfe8ff"), HORIZONTAL_ALIGNMENT_CENTER))
	var fewer_laps := _button("‹", false)
	fewer_laps.custom_minimum_size = Vector2(54, 44)
	fewer_laps.pressed.connect(_change_laps.bind(-1))
	options.add_child(fewer_laps)
	lap_value_label = _label(str(lap_count), 25, Color("ffe45f"), HORIZONTAL_ALIGNMENT_CENTER)
	lap_value_label.custom_minimum_size = Vector2(54, 44)
	lap_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	options.add_child(lap_value_label)
	var more_laps := _button("›", false)
	more_laps.custom_minimum_size = Vector2(54, 44)
	more_laps.pressed.connect(_change_laps.bind(1))
	options.add_child(more_laps)
	realistic_fueling_toggle = CheckButton.new()
	realistic_fueling_toggle.text = "РЕАЛИСТИЧНАЯ ЗАПРАВКА ЧЕРЕЗ КАМЕРУ"
	realistic_fueling_toggle.add_theme_font_size_override("font_size", 17)
	realistic_fueling_toggle.tooltip_text = "F — записать 5-секундное видео; Gemini подтвердит жест питья"
	options.add_child(realistic_fueling_toggle)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	content.add_child(actions)
	var back := _button("НАЗАД", false)
	back.pressed.connect(func(): hide(); back_requested.emit())
	actions.add_child(back)
	var confirm := _button("ДАЛЕЕ — ВЫБОР МАШИНЫ", true)
	confirm.pressed.connect(_confirm_mode)
	actions.add_child(confirm)


func _mode_card(image_path: String, title: String, subtitle: String, mode: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(590, 405)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var image_button := TextureButton.new()
	image_button.custom_minimum_size = Vector2(550, 305)
	image_button.ignore_texture_size = true
	image_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	image_button.texture_normal = load(image_path)
	image_button.tooltip_text = title
	image_button.pressed.connect(_select_mode.bind(mode))
	column.add_child(image_button)
	column.add_child(_label(title, 23, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(_label(subtitle, 15, Color("bfc9e5"), HORIZONTAL_ALIGNMENT_CENTER))
	return {"panel": panel, "button": image_button}


func _select_mode(mode: String) -> void:
	selected_mode = mode
	if is_instance_valid(ui_move): ui_move.play()
	_refresh()


func _confirm_mode() -> void:
	if is_instance_valid(ui_select): ui_select.play()
	hide()
	mode_confirmed.emit(selected_mode, selected_mode == "obstacle_course", lap_count, realistic_fueling_toggle.button_pressed and selected_mode == "obstacle_course")


func _change_laps(delta: int) -> void:
	lap_count = clampi(lap_count + delta, 2, 5)
	lap_value_label.text = str(lap_count)
	if is_instance_valid(ui_move): ui_move.play()


func _refresh() -> void:
	if not is_instance_valid(free_panel): return
	free_panel.add_theme_stylebox_override("panel", _panel(Color("121735"), Color("ffe45f") if selected_mode == "free_run" else Color("43dff5"), 16))
	obstacle_panel.add_theme_stylebox_override("panel", _panel(Color("21102f"), Color("ffe45f") if selected_mode == "obstacle_course" else Color("ee57b4"), 16))
	free_button.modulate = Color.WHITE if selected_mode == "free_run" else Color(0.62, 0.62, 0.7)
	obstacle_button.modulate = Color.WHITE if selected_mode == "obstacle_course" else Color(0.62, 0.62, 0.7)
	if is_instance_valid(realistic_fueling_toggle):
		realistic_fueling_toggle.visible = selected_mode == "obstacle_course"


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360 if primary else 190, 56)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _panel(Color("b51a72") if primary else Color("17204b"), Color("6be8ff"), 11))
	button.add_theme_stylebox_override("hover", _panel(Color("31b9dc"), Color.WHITE, 11))
	return button


func _label(text: String, size: int, color: Color, alignment: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _panel(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style
