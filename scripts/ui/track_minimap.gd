class_name TrackMinimap
extends Control

## Lightweight vector minimap. It draws one cached track polyline and updates
## only the player marker, so it does not require a SubViewport or second camera.

@export_range(1.0, 12.0, 0.5) var track_width := 4.0
@export_range(0.0, 1.0, 0.01) var panel_opacity := 0.58
@export var track_color := Color("88e8ff")
@export var player_color := Color("ff3f8e")
@export var start_finish_color := Color("fff27a")

var _track_points := PackedVector2Array()
var _display_points := PackedVector2Array()
var _progress_normalized := 0.0
var _bounds := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_rebuild_display_points)
	queue_redraw()


func set_track_points(points: PackedVector2Array) -> void:
	_track_points = points
	_calculate_bounds()
	_rebuild_display_points()


func set_course(layout: Object, sample_count := 360) -> void:
	var points := PackedVector2Array()
	if layout == null or not layout.has_method("length") or not layout.has_method("point_at"):
		set_track_points(points)
		return
	var course_length := float(layout.call("length"))
	var count := maxi(12, sample_count)
	for index in count:
		var position: Vector3 = layout.call("point_at", course_length * float(index) / float(count))
		points.append(Vector2(position.x, position.z))
	if not points.is_empty():
		points.append(points[0])
	set_track_points(points)


func set_player_progress_normalized(value: float) -> void:
	_progress_normalized = fposmod(value, 1.0)
	queue_redraw()


func set_player_distance(distance: float, course_length: float) -> void:
	set_player_progress_normalized(distance / maxf(course_length, 0.001))


func track_point_count() -> int:
	return _track_points.size()


func player_marker_position() -> Vector2:
	if _display_points.size() < 2:
		return size * 0.5
	var segment_count := _display_points.size() - 1
	var cursor := _progress_normalized * float(segment_count)
	var segment := mini(floori(cursor), segment_count - 1)
	return _display_points[segment].lerp(_display_points[segment + 1], cursor - float(segment))


func _draw() -> void:
	var panel_rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_panel_style(), panel_rect)
	if _display_points.size() < 2:
		return

	draw_polyline(_display_points, Color(0.02, 0.02, 0.09, 0.88), track_width + 4.0, true)
	draw_polyline(_display_points, track_color, track_width, true)

	var start := _display_points[0]
	var forward := (_display_points[1] - start).normalized()
	var across := Vector2(-forward.y, forward.x) * 7.0
	draw_line(start - across, start + across, start_finish_color, 3.0, true)
	draw_circle(start, 3.5, Color("25123d"))
	draw_circle(player_marker_position(), 6.0, Color(0.02, 0.02, 0.09, 0.9))
	draw_circle(player_marker_position(), 4.0, player_color)


func _calculate_bounds() -> void:
	if _track_points.is_empty():
		_bounds = Rect2()
		return
	var minimum := _track_points[0]
	var maximum := _track_points[0]
	for point in _track_points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	_bounds = Rect2(minimum, maximum - minimum)


func _rebuild_display_points() -> void:
	_display_points = PackedVector2Array()
	if _track_points.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		queue_redraw()
		return
	var content := Rect2(Vector2(18.0, 24.0), size - Vector2(36.0, 42.0))
	var safe_bounds_size := Vector2(maxf(_bounds.size.x, 0.001), maxf(_bounds.size.y, 0.001))
	var scale_factor := minf(content.size.x / safe_bounds_size.x, content.size.y / safe_bounds_size.y)
	var drawn_size := safe_bounds_size * scale_factor
	var origin := content.position + (content.size - drawn_size) * 0.5
	for point in _track_points:
		var relative := point - _bounds.position
		_display_points.append(origin + Vector2(relative.x, relative.y) * scale_factor)
	queue_redraw()


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.02, 0.11, panel_opacity)
	style.border_color = Color(0.35, 0.85, 1.0, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 8
	return style
