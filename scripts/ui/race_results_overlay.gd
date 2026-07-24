class_name RaceResultsOverlay
extends CanvasLayer

signal restart_requested
signal main_menu_requested

var title_label: Label
var summary_label: Label
var laps_label: Label


func _ready() -> void:
	layer = 125
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	hide()


func show_results(lap_times: Array[float], lap_speeds: Array[float], hits: int, damage: float, total_time: float, completed: bool, finish_reason := "") -> void:
	title_label.text = "ФИНИШ!" if completed else (finish_reason if not finish_reason.is_empty() else "МАШИНА РАЗБИТА")
	var rows: Array[String] = []
	for index in lap_times.size():
		var speed := lap_speeds[index] if index < lap_speeds.size() else 0.0
		rows.append("КРУГ %d   %s   •   %.1f КМ/Ч" % [index + 1, _format_time(lap_times[index]), speed])
	if rows.is_empty(): rows.append("ЗАВЕРШЁННЫХ КРУГОВ НЕТ")
	laps_label.text = "\n".join(rows)
	var overall_speed := 0.0
	var completed_time := 0.0
	for index in mini(lap_speeds.size(), lap_times.size()):
		overall_speed += lap_speeds[index] * lap_times[index]
		completed_time += lap_times[index]
	if completed_time > 0.0: overall_speed /= completed_time
	summary_label.text = "ОБЩЕЕ ВРЕМЯ  %s\nСРЕДНЯЯ СКОРОСТЬ  %.1f КМ/Ч\nСТОЛКНОВЕНИЯ  %d   •   ПОЛУЧЕНО УРОНА  %.1f" % [
		_format_time(total_time), overall_speed, hits, damage,
	]
	show()
	var restart := get_node_or_null("Root/Card/Margin/Content/Actions/RestartButton") as Button
	if restart: restart.grab_focus()


func _build_interface() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.004, 0.06, 0.88)
	root.add_child(shade)
	var card := PanelContainer.new()
	card.name = "Card"
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.position = Vector2(-390, -360)
	card.size = Vector2(780, 720)
	card.add_theme_stylebox_override("panel", _panel(Color("10072b"), Color("55eaff"), 22))
	root.add_child(card)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 42)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 22)
	margin.add_child(content)
	title_label = _label("ФИНИШ!", 50, Color("ffe45f"))
	content.add_child(title_label)
	laps_label = _label("", 22, Color("e8f8ff"))
	laps_label.custom_minimum_size = Vector2(650, 220)
	content.add_child(laps_label)
	summary_label = _label("", 20, Color("75eaff"))
	content.add_child(summary_label)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	content.add_child(actions)
	var restart := _button("ЕЩЁ РАЗ")
	restart.name = "RestartButton"
	restart.pressed.connect(func(): hide(); restart_requested.emit())
	actions.add_child(restart)
	var menu := _button("В ГЛАВНОЕ МЕНЮ")
	menu.name = "MainMenuButton"
	menu.pressed.connect(func(): hide(); main_menu_requested.emit())
	actions.add_child(menu)


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(285, 58)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _panel(Color("b51a72"), Color("ff82d0"), 10))
	button.add_theme_stylebox_override("hover", _panel(Color("31b9dc"), Color.WHITE, 10))
	return button


func _panel(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style


func _format_time(value: float) -> String:
	return "%02d:%02d.%03d" % [int(value) / 60, int(value) % 60, int(fmod(value, 1.0) * 1000.0)]
