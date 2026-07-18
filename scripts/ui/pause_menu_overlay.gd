class_name PauseMenuOverlay
extends CanvasLayer

signal resume_requested
signal main_menu_requested
signal exit_requested


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func show_pause() -> void:
	show()
	var resume := get_node_or_null("Root/Card/Margin/Content/ResumeButton") as Button
	if resume:
		resume.grab_focus()


func _build_interface() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.004, 0.06, 0.78)
	root.add_child(shade)
	var card := PanelContainer.new()
	card.name = "Card"
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.position = Vector2(-235, -220)
	card.size = Vector2(470, 440)
	card.add_theme_stylebox_override("panel", _panel(Color("11072b"), Color("4fe7ff"), 20))
	root.add_child(card)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 42)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 20)
	margin.add_child(content)
	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("ffe45f"))
	content.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "ГОНКА ОСТАНОВЛЕНА"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("79eaff"))
	content.add_child(subtitle)
	var resume := _button("ПРОДОЛЖИТЬ")
	resume.name = "ResumeButton"
	resume.pressed.connect(func(): resume_requested.emit())
	content.add_child(resume)
	var main_menu := _button("В ГЛАВНОЕ МЕНЮ")
	main_menu.name = "MainMenuButton"
	main_menu.pressed.connect(func(): main_menu_requested.emit())
	content.add_child(main_menu)
	var exit := _button("ВЫЙТИ ИЗ ИГРЫ")
	exit.name = "ExitButton"
	exit.pressed.connect(func(): exit_requested.emit())
	content.add_child(exit)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(350, 58)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", _panel(Color("b51a72"), Color("ff82d0"), 10))
	button.add_theme_stylebox_override("hover", _panel(Color("31b9dc"), Color("d7fbff"), 10))
	button.add_theme_stylebox_override("pressed", _panel(Color("276b9e"), Color("ffe45f"), 10))
	return button


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
