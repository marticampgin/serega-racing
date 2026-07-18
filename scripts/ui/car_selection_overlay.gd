class_name CarSelectionOverlay
extends CanvasLayer

signal car_confirmed(profile_id: String, color: Color)
signal back_requested

const CarFactory := preload("res://scripts/cars/car_visual_factory.gd")

var selected_car := 0
var selected_color := 0
var preview_root: Node3D
var viewport: SubViewport
var name_label: Label
var subtitle_label: Label
var description_label: Label
var stat_bars: Array[ProgressBar] = []
var stat_labels: Array[Label] = []
var color_buttons: Array[Button] = []
var background: TextureRect
var position_label: Label
var lock_label: Label
var code_edit: LineEdit
var code_status: Label
var confirm_button: Button
var unlocked_cars := {}


func _ready() -> void:
	layer = 110
	_build_interface()
	_refresh_selection()
	hide()
	_set_preview_active(false)


func _process(delta: float) -> void:
	if visible and is_instance_valid(preview_root):
		preview_root.rotate_y(delta * 0.42)
		preview_root.position.y = 0.15 + sin(Time.get_ticks_msec() * 0.0014) * 0.08


func show_selector() -> void:
	show()
	_set_preview_active(true)
	_refresh_selection()


func set_background_path(path: String) -> void:
	if is_instance_valid(background) and ResourceLoader.exists(path):
		background.texture = load(path)


func _build_interface() -> void:
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)

	var fallback := ColorRect.new()
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.color = Color("08031b")
	root_control.add_child(fallback)
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.38, 0.28, 0.5, 0.42)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(background)
	var tint := ColorRect.new()
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(0.025, 0.008, 0.09, 0.72)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(tint)

	var title := _label("ВЫБЕРИТЕ БОЛИД", 42, Color("ffe35a"), HORIZONTAL_ALIGNMENT_CENTER)
	title.anchor_right = 1.0
	title.offset_top = 34.0
	title.offset_bottom = 94.0
	root_control.add_child(title)

	var card := PanelContainer.new()
	card.anchor_left = 0.04
	card.anchor_top = 0.12
	card.anchor_right = 0.96
	card.anchor_bottom = 0.9
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.015, 0.11, 0.9), Color("43d9f5"), 20))
	root_control.add_child(card)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	card.add_child(layout)

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(430, 0)
	info.add_theme_constant_override("separation", 7)
	layout.add_child(info)
	name_label = _label("", 38, Color.WHITE)
	info.add_child(name_label)
	subtitle_label = _label("", 20, Color("5de6ff"))
	info.add_child(subtitle_label)
	description_label = _label("", 17, Color("d9d3ec"))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size = Vector2(400, 56)
	info.add_child(description_label)
	for stat in ["УПРАВЛЕНИЕ", "МАКС. СКОРОСТЬ", "РАЗГОН", "ЭКОНОМИЧНОСТЬ", "ПРОЧНОСТЬ"]:
		var stat_label := _label(stat, 13, Color("b9c8e8"))
		info.add_child(stat_label)
		stat_labels.append(stat_label)
		var bar := ProgressBar.new()
		bar.max_value = 5.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(390, 12)
		bar.add_theme_stylebox_override("background", _panel_style(Color(0.12, 0.08, 0.2, 0.9), Color(0,0,0,0), 6))
		bar.add_theme_stylebox_override("fill", _panel_style(Color("d72f91"), Color("ff88cf"), 6))
		info.add_child(bar)
		stat_bars.append(bar)
	info.add_child(_label("ЦВЕТ КУЗОВА", 13, Color("b9c8e8")))
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 10)
	info.add_child(colors)
	for index in CarFactory.COLORS.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(42, 42)
		button.add_theme_stylebox_override("normal", _swatch_style(CarFactory.COLORS[index], false))
		button.add_theme_stylebox_override("hover", _swatch_style(CarFactory.COLORS[index].lightened(0.15), true))
		button.add_theme_stylebox_override("pressed", _swatch_style(CarFactory.COLORS[index], true))
		button.pressed.connect(_select_color.bind(index))
		colors.add_child(button)
		color_buttons.append(button)
	var unlock_row := HBoxContainer.new()
	unlock_row.add_theme_constant_override("separation", 8)
	info.add_child(unlock_row)
	code_edit = LineEdit.new()
	code_edit.placeholder_text = "СЕКРЕТНЫЙ КОД"
	code_edit.custom_minimum_size = Vector2(245, 42)
	code_edit.add_theme_font_size_override("font_size", 16)
	code_edit.secret = true
	code_edit.text_submitted.connect(func(_value: String): _try_unlock())
	unlock_row.add_child(code_edit)
	var unlock := _button("ОТКРЫТЬ", 15)
	unlock.custom_minimum_size = Vector2(135, 42)
	unlock.pressed.connect(_try_unlock)
	unlock_row.add_child(unlock)
	code_status = _label("", 13, Color("7deaff"))
	info.add_child(code_status)

	var preview_column := VBoxContainer.new()
	preview_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_column.add_theme_constant_override("separation", 12)
	layout.add_child(preview_column)
	var preview_row := HBoxContainer.new()
	preview_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_column.add_child(preview_row)
	var left := _button("‹", 32)
	left.custom_minimum_size = Vector2(58, 58)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.pressed.connect(_change_car.bind(-1))
	preview_row.add_child(left)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(760, 560)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_row.add_child(container)
	_build_preview(container)
	var right := _button("›", 32)
	right.custom_minimum_size = Vector2(58, 58)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.pressed.connect(_change_car.bind(1))
	preview_row.add_child(right)
	position_label = _label("", 18, Color("8eefff"), HORIZONTAL_ALIGNMENT_CENTER)
	preview_column.add_child(position_label)
	lock_label = _label("", 22, Color("ffe35a"), HORIZONTAL_ALIGNMENT_CENTER)
	preview_column.add_child(lock_label)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 18)
	preview_column.add_child(actions)
	var back := _button("НАЗАД", 20)
	back.custom_minimum_size = Vector2(190, 58)
	back.pressed.connect(_on_back)
	actions.add_child(back)
	confirm_button = _button("ВЫБРАТЬ И НАЧАТЬ", 21, true)
	confirm_button.custom_minimum_size = Vector2(330, 58)
	confirm_button.pressed.connect(_on_confirm)
	actions.add_child(confirm_button)


func _build_preview(container: SubViewportContainer) -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(760, 560)
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("100820")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a99bd8")
	env.ambient_light_energy = 1.15
	environment.environment = env
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -28, 0)
	light.light_color = Color("ffd0ee")
	light.light_energy = 1.8
	world.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3, 2, 3)
	fill.light_color = Color("35dfff")
	fill.omni_range = 12.0
	fill.light_energy = 5.0
	world.add_child(fill)
	var platform := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 3.8
	cylinder.bottom_radius = 4.1
	cylinder.height = 0.22
	cylinder.radial_segments = 32
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color("19102d")
	platform_material.emission_enabled = true
	platform_material.emission = Color("641e77")
	platform_material.emission_energy_multiplier = 0.5
	cylinder.material = platform_material
	platform.mesh = cylinder
	platform.position.y = -0.48
	world.add_child(platform)
	preview_root = Node3D.new()
	preview_root.rotation_degrees = Vector3(-4, 145, 0)
	preview_root.scale = Vector3.ONE * 1.35
	world.add_child(preview_root)
	var camera := Camera3D.new()
	camera.position = Vector3(5.4, 3.15, 7.4)
	camera.fov = 42.0
	camera.look_at_from_position(camera.position, Vector3(0, 0.25, 0), Vector3.UP)
	world.add_child(camera)


func _change_car(direction: int) -> void:
	selected_car = posmod(selected_car + direction, CarFactory.PROFILES.size())
	_refresh_selection()


func _select_color(index: int) -> void:
	selected_color = index
	_refresh_selection()


func _refresh_selection() -> void:
	if not is_instance_valid(preview_root):
		return
	var profile: Dictionary = CarFactory.PROFILES[selected_car]
	name_label.text = str(profile.name)
	subtitle_label.text = str(profile.subtitle)
	description_label.text = str(profile.description)
	stat_bars[0].value = float(profile.control)
	stat_bars[1].value = float(profile.speed)
	stat_bars[2].value = float(profile.acceleration)
	stat_bars[3].value = float(profile.efficiency)
	stat_bars[4].value = float(profile.tolerance)
	stat_labels[1].text = "МАКС. СКОРОСТЬ — %d КМ/Ч" % int(profile.max_speed_kmh)
	position_label.text = "%d / %d" % [selected_car + 1, CarFactory.PROFILES.size()]
	var locked := bool(profile.get("locked", false)) and not unlocked_cars.has(str(profile.id))
	lock_label.text = "ЗАБЛОКИРОВАНО — НУЖЕН КОД" if locked else ""
	confirm_button.disabled = locked
	confirm_button.text = "ЗАБЛОКИРОВАНО" if locked else "ВЫБРАТЬ И НАЧАТЬ"
	for index in color_buttons.size():
		color_buttons[index].add_theme_stylebox_override("normal", _swatch_style(CarFactory.COLORS[index], index == selected_color))
	for child in preview_root.get_children():
		child.queue_free()
	CarFactory.build(preview_root, str(profile.id), CarFactory.COLORS[selected_color])


func _on_confirm() -> void:
	var profile: Dictionary = CarFactory.PROFILES[selected_car]
	if bool(profile.get("locked", false)) and not unlocked_cars.has(str(profile.id)):
		return
	car_confirmed.emit(str(profile.id), CarFactory.COLORS[selected_color])
	_set_preview_active(false)
	hide()


func _try_unlock() -> void:
	if code_edit.text == "LILPOC_":
		unlocked_cars["lilpoc"] = true
		code_status.text = "LILPOC РАЗБЛОКИРОВАН"
		code_status.add_theme_color_override("font_color", Color("70ef88"))
		code_edit.clear()
		_refresh_selection()
	else:
		code_status.text = "НЕВЕРНЫЙ КОД"
		code_status.add_theme_color_override("font_color", Color("ff6a86"))


func _on_back() -> void:
	_set_preview_active(false)
	hide()
	back_requested.emit()


func _set_preview_active(active: bool) -> void:
	if is_instance_valid(viewport):
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


func _label(value: String, size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _button(value: String, size: int, primary := false) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_stylebox_override("normal", _panel_style(Color("b51a72") if primary else Color("17204b"), Color("71e8ff"), 12))
	button.add_theme_stylebox_override("hover", _panel_style(Color("32b9dd"), Color("d2fbff"), 12))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("276b9e"), Color("ffe35a"), 12))
	return button


func _panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2 if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 22.0
	style.content_margin_bottom = 22.0
	return style


func _swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("fff16a") if selected else Color(1, 1, 1, 0.45)
	style.set_border_width_all(4 if selected else 2)
	style.set_corner_radius_all(24)
	return style
