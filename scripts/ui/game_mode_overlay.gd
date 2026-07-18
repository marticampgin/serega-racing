class_name GameModeOverlay
extends CanvasLayer

signal mode_confirmed(mode: String, powerups: bool)
signal back_requested

const FREE_IMAGE := "res://assets/generated/ui/mode-free-run-v1.png"
const OBSTACLE_IMAGE := "res://assets/generated/ui/mode-obstacle-course-v1.png"

var selected_mode := "free_run"
var powerups_toggle: CheckButton
var free_button: TextureButton
var obstacle_button: TextureButton
var free_panel: PanelContainer
var obstacle_panel: PanelContainer
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
	var free := _mode_card(FREE_IMAGE, "СВОБОДНАЯ ГОНКА", "Чистая трасса • Лучшее время", "free_run")
	free_panel = free.panel
	free_button = free.button
	cards.add_child(free_panel)
	var obstacle := _mode_card(OBSTACLE_IMAGE, "ПОЛОСА ПРЕПЯТСТВИЙ", "Транспорт • Техника • Дорожный хаос", "obstacle_course")
	obstacle_panel = obstacle.panel
	obstacle_button = obstacle.button
	cards.add_child(obstacle_panel)
	powerups_toggle = CheckButton.new()
	powerups_toggle.text = "ВКЛЮЧИТЬ УСИЛЕНИЯ НА ТРАССЕ"
	powerups_toggle.button_pressed = true
	powerups_toggle.custom_minimum_size = Vector2(650, 48)
	powerups_toggle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	powerups_toggle.add_theme_font_size_override("font_size", 19)
	powerups_toggle.add_theme_color_override("font_color", Color("8beeff"))
	content.add_child(powerups_toggle)
	content.add_child(_label("ТУРБО • РЕМОНТ • ЩИТ • РЕЖИМ ПРИЗРАКА", 15, Color("d7cceb"), HORIZONTAL_ALIGNMENT_CENTER))
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
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(free_panel): return
	free_panel.add_theme_stylebox_override("panel", _panel(Color("121735"), Color("ffe45f") if selected_mode == "free_run" else Color("43dff5"), 16))
	obstacle_panel.add_theme_stylebox_override("panel", _panel(Color("21102f"), Color("ffe45f") if selected_mode == "obstacle_course" else Color("ee57b4"), 16))
	free_button.modulate = Color.WHITE if selected_mode == "free_run" else Color(0.62, 0.62, 0.7)
	obstacle_button.modulate = Color.WHITE if selected_mode == "obstacle_course" else Color(0.62, 0.62, 0.7)


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
