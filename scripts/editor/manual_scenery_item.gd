@tool
class_name ManualSceneryItem
extends Node3D

const CourseLayoutScript := preload("res://scripts/course_layout.gd")
const SEA_LEVEL := -1.4

enum Surface { LAND, WATER, AIR, WALL }

@export_category("Scenery Catalog")
@export var catalog_id := ""
@export var display_name := "Manual Scenery"
@export var category := "Props"
@export_enum("Land", "Water", "Air", "Wall") var surface: int = Surface.LAND
@export_range(0.25, 80.0, 0.25) var footprint_radius := 4.0
@export_range(0.25, 100.0, 0.25) var object_height := 5.0
@export var allow_on_course := false
@export var allow_manual_overlap := false

@export_category("Editable Artwork")
@export var poster_texture: Texture2D:
	set(value):
		poster_texture = value
		_apply_poster_texture()

@export_category("Optional Sky Motion")
@export var movement_enabled := false
@export var movement_axis := Vector3.RIGHT
@export_range(10.0, 2000.0, 5.0) var movement_span := 300.0
@export_range(0.5, 100.0, 0.5) var movement_speed := 10.0
@export_range(0.0, 8.0, 0.1) var movement_bob := 0.8

var _movement_origin := Vector3.ZERO
var _movement_time := 0.0


func _enter_tree() -> void:
	add_to_group("manual_scenery_preset", true)
	add_to_group("manual_scenery", true)
	match surface:
		Surface.LAND:
			add_to_group("grounded_scenery", true)
			add_to_group("manual_grounded_scenery", true)
		Surface.WATER:
			add_to_group("water_scenery", true)
			add_to_group("manual_water_scenery", true)
		Surface.AIR:
			add_to_group("manual_sky_scenery", true)
		Surface.WALL:
			add_to_group("manual_wall_scenery", true)
	set_meta("catalog_id", catalog_id)
	set_meta("scenery_radius", footprint_radius)
	set_meta("manual_surface", surface)
	set_notify_transform(true)


func _ready() -> void:
	_movement_origin = position
	_apply_poster_texture()
	update_configuration_warnings()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not movement_enabled or surface != Surface.AIR:
		return
	_movement_time += delta
	var axis := movement_axis.normalized()
	if axis.length_squared() < 0.5:
		axis = Vector3.RIGHT
	var period := movement_span * 2.0 / maxf(movement_speed, 0.1)
	# Phase 0.5 starts at the editor-authored centre instead of jumping to the
	# negative edge of the corridor on the first runtime frame.
	var phase := fposmod(_movement_time / period + 0.5, 1.0)
	position = _movement_origin + axis * lerpf(-movement_span, movement_span, phase)
	position.y += sin(phase * TAU * 2.0) * movement_bob


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and is_inside_tree():
		update_configuration_warnings.call_deferred()


func _apply_poster_texture() -> void:
	if poster_texture == null:
		return
	for value in find_children("PosterFace*", "Sprite3D", true, false):
		(value as Sprite3D).texture = poster_texture


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_parent() == null or get_parent().name != "ManualScenery":
		warnings.append("Place this preset as a direct child of Race/ManualScenery.")
	if scale.x <= 0.0 or scale.y <= 0.0 or scale.z <= 0.0:
		warnings.append("Negative or zero scale is unsupported; rotate the preset instead.")
	if absf(scale.x - scale.z) > 0.02:
		warnings.append("Non-uniform horizontal scale makes clearance validation inaccurate.")
	if surface == Surface.WATER and absf(global_position.y - SEA_LEVEL) > 2.0:
		warnings.append("Water props should normally sit near Y = %.1f." % SEA_LEVEL)
	if surface == Surface.AIR and global_position.y < 35.0:
		warnings.append("Aircraft below Y = 35 may intersect buildings or the track.")
	if not allow_on_course and surface in [Surface.LAND, Surface.WATER] and _intersects_course():
		warnings.append("This footprint intersects the generated racing surface. Move it farther from the course.")
	if not allow_manual_overlap and _overlaps_manual_sibling():
		warnings.append("This footprint overlaps another manual scenery preset.")
	return warnings


func _intersects_course() -> bool:
	var course := CourseLayoutScript.load_default()
	var offset := 0.0
	var world_scale := global_transform.basis.get_scale()
	var radius := footprint_radius * maxf(absf(world_scale.x), absf(world_scale.z))
	while offset < course.length():
		var point := course.point_at(offset)
		var horizontal := Vector2(global_position.x, global_position.z).distance_to(Vector2(point.x, point.z))
		if horizontal < course.road_half_width + radius + 1.0:
			var bottom := global_position.y
			var top := bottom + object_height * absf(world_scale.y)
			if point.y >= bottom - 2.0 and point.y <= top + 2.0:
				return true
		offset += 10.0
	return false


func _overlaps_manual_sibling() -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	var world_scale := global_transform.basis.get_scale()
	var own_radius := footprint_radius * maxf(absf(world_scale.x), absf(world_scale.z))
	for value in parent.get_children():
		if value == self or not value is Node3D or not value.is_in_group("manual_scenery"):
			continue
		var other := value as Node3D
		var other_scale := other.global_transform.basis.get_scale()
		var other_radius := float(other.get_meta("scenery_radius", 1.0)) * maxf(absf(other_scale.x), absf(other_scale.z))
		if Vector2(global_position.x, global_position.z).distance_to(Vector2(other.global_position.x, other.global_position.z)) < own_radius + other_radius:
			return true
	return false
