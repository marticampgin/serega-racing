class_name MainMenuOverlay
extends CanvasLayer

const SettingsPanelScript := preload("res://scripts/ui/audio_settings_panel.gd")

## Self-contained Russian main menu. The background can be replaced at runtime
## without changing the scene, which keeps the generated artwork optional.

signal start_requested
signal exit_requested

@export var background_texture: Texture2D
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var background_texture_path := ""
@export var hide_on_start := true
@export var exit_quits_tree := true
@onready var _backdrop: TextureRect = %Backdrop
@onready var _sun_glow: ColorRect = %SunGlow
@onready var _start_button: Button = %StartButton
@onready var _settings_button: Button = %SettingsButton
@onready var _exit_button: Button = %ExitButton

var _elapsed := 0.0
var _ui_select: AudioStreamPlayer
var _settings_panel: AudioSettingsPanel


func _ready() -> void:
	_ui_select = AudioStreamPlayer.new()
	_ui_select.stream = load("res://assets/audio/ui/menu_select.wav")
	_ui_select.volume_db = -8.0
	_ui_select.bus = "SFX"
	add_child(_ui_select)
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_settings_panel = SettingsPanelScript.new()
	add_child(_settings_panel)
	_settings_panel.closed.connect(func(): _settings_button.grab_focus())
	_apply_background()


func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(_sun_glow) and _sun_glow.material is ShaderMaterial:
		var pulse := 0.5 + 0.5 * sin(_elapsed * 1.15)
		(_sun_glow.material as ShaderMaterial).set_shader_parameter("strength", lerpf(0.10, 0.24, pulse))


func set_background_texture(texture: Texture2D) -> void:
	background_texture = texture
	if is_node_ready():
		_apply_background()


func set_background_path(path: String) -> void:
	background_texture_path = path
	if is_node_ready():
		_apply_background()


func focus_start_button() -> void:
	if is_instance_valid(_start_button):
		_start_button.grab_focus()


func _apply_background() -> void:
	var texture := background_texture
	if texture == null and not background_texture_path.is_empty() and ResourceLoader.exists(background_texture_path):
		texture = load(background_texture_path) as Texture2D
	_backdrop.texture = texture
	_backdrop.visible = texture != null


func _on_start_pressed() -> void:
	if is_instance_valid(_ui_select): _ui_select.play()
	start_requested.emit()
	if hide_on_start:
		hide()


func _on_exit_pressed() -> void:
	if is_instance_valid(_ui_select): _ui_select.play()
	exit_requested.emit()
	if exit_quits_tree:
		get_tree().quit()


func _on_settings_pressed() -> void:
	if is_instance_valid(_ui_select): _ui_select.play()
	_settings_panel.show_panel()
