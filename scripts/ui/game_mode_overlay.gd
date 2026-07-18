class_name GameModeOverlay
extends CanvasLayer

signal mode_confirmed(mode: String, powerups: bool)
signal back_requested

var selected_mode := "free_run"
var powerups_toggle: CheckButton
var free_button: Button
var obstacle_button: Button
var background: TextureRect


func _ready() -> void:
	layer = 105
	_build_interface()
	_refresh()
	hide()


func show_selector() -> void:
	show()
	free_button.grab_focus()


func set_background_path(path: String) -> void:
	if is_instance_valid(background) and ResourceLoader.exists(path):
		background.texture = load(path)


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
	background.modulate = Color(0.35, 0.25, 0.48, 0.42)
	root.add_child(background)
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.02, 0.005, 0.07, 0.76)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tint)
	var content := VBoxContainer.new()
	content.anchor_left = 0.12
	content.anchor_top = 0.1
	content.anchor_right = 0.88
	content.anchor_bottom = 0.9
	content.add_theme_constant_override("separation", 26)
	root.add_child(content)
	content.add_child(_label("ВЫБЕРИТЕ РЕЖИМ", 44, Color("ffe45f"), HORIZONTAL_ALIGNMENT_CENTER))
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 28)
	content.add_child(cards)
	free_button = _mode_button("СВОБОДНАЯ ГОНКА\n\nЧистая трасса и лучшее время.\nБудущие награды: бронза, серебро, золото.")
	free_button.pressed.connect(_select_mode.bind("free_run"))
	cards.add_child(free_button)
	obstacle_button = _mode_button("ПОЛОСА ПРЕПЯТСТВИЙ\n\nСлучайный дорожный хаос: транспорт,\nтехника, конусы и разбитые болиды.")
	obstacle_button.pressed.connect(_select_mode.bind("obstacle_course"))
	cards.add_child(obstacle_button)
	powerups_toggle = CheckButton.new()
	powerups_toggle.text = "ВКЛЮЧИТЬ УСИЛЕНИЯ НА ТРАССЕ"
	powerups_toggle.button_pressed = true
	powerups_toggle.custom_minimum_size = Vector2(650, 54)
	powerups_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	powerups_toggle.add_theme_font_size_override("font_size", 20)
	powerups_toggle.add_theme_color_override("font_color", Color("8beeff"))
	content.add_child(powerups_toggle)
	var hint := _label("ТУРБО • РЕМОНТ • ЩИТ • РЕЖИМ ПРИЗРАКА", 16, Color("d7cceb"), HORIZONTAL_ALIGNMENT_CENTER)
	content.add_child(hint)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	content.add_child(actions)
	var back := _button("НАЗАД", false)
	back.pressed.connect(func(): hide(); back_requested.emit())
	actions.add_child(back)
	var confirm := _button("ДАЛЕЕ — ВЫБОР МАШИНЫ", true)
	confirm.pressed.connect(func(): hide(); mode_confirmed.emit(selected_mode, powerups_toggle.button_pressed))
	actions.add_child(confirm)


func _select_mode(mode: String) -> void:
	selected_mode = mode
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(free_button): return
	free_button.add_theme_stylebox_override("normal", _panel(Color("17204b") if selected_mode == "free_run" else Color("0d1028"), Color("ffe45f") if selected_mode == "free_run" else Color("4de6ff"), 18))
	obstacle_button.add_theme_stylebox_override("normal", _panel(Color("48143e") if selected_mode == "obstacle_course" else Color("0d1028"), Color("ffe45f") if selected_mode == "obstacle_course" else Color("f058b6"), 18))


func _mode_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(650, 430)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_stylebox_override("hover", _panel(Color("1d3159"), Color("d8fbff"), 18))
	button.add_theme_stylebox_override("pressed", _panel(Color("57205a"), Color("ffe45f"), 18))
	return button


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360 if primary else 190, 60)
	button.add_theme_font_size_override("font_size", 19)
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
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style
