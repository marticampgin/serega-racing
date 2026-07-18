class_name MainMenuOverlay
extends CanvasLayer

## Self-contained Russian main menu. The background can be replaced at runtime
## without changing the scene, which keeps the generated artwork optional.

signal start_requested
signal exit_requested

@export var background_texture: Texture2D
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var background_texture_path := ""
@export var hide_on_start := true
@export var exit_quits_tree := true
@export_range(0.0, 24.0, 0.1) var background_drift_pixels := 9.0
@export_range(0.0, 2.0, 0.01) var background_drift_speed := 0.18

@onready var _backdrop: TextureRect = %Backdrop
@onready var _start_button: Button = %StartButton
@onready var _exit_button: Button = %ExitButton

var _elapsed := 0.0


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)
	_apply_background()


func _process(delta: float) -> void:
	_elapsed += delta
	if not is_instance_valid(_backdrop):
		return
	var drift := Vector2(
		sin(_elapsed * background_drift_speed) * background_drift_pixels,
		cos(_elapsed * background_drift_speed * 0.73) * background_drift_pixels * 0.45
	)
	_backdrop.position = Vector2(-background_drift_pixels, -background_drift_pixels) + drift


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
	start_requested.emit()
	if hide_on_start:
		hide()


func _on_exit_pressed() -> void:
	exit_requested.emit()
	if exit_quits_tree:
		get_tree().quit()
