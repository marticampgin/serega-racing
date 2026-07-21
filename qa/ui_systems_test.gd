extends SceneTree

const CourseLayoutScript := preload("res://scripts/course_layout.gd")
const MENU_SCENE := preload("res://scenes/ui/main_menu_overlay.tscn")
const MAP_SCENE := preload("res://scenes/ui/track_minimap.tscn")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := MENU_SCENE.instantiate()
	menu.exit_quits_tree = false
	menu.hide_on_start = false
	get_root().add_child(menu)
	await process_frame
	_expect(menu.get_node("Root/Card/Margin/Content/StartButton").text == "НАЧАТЬ ГОНКУ", "Start button must be Russian")
	_expect(menu.get_node("Root/Card/Margin/Content/ExitButton").text == "ВЫХОД", "Exit button must be Russian")
	_expect(menu.get_node("Root/Card/Margin/Content/Title").text == "Серёга Speedster", "main menu uses the new game title")
	_expect(menu.get_node("Root/Card/Margin/Content/Subtitle").text.is_empty(), "obsolete island-speed-party subtitle is removed")
	var signal_counts := {"start": 0}
	menu.start_requested.connect(func() -> void: signal_counts["start"] += 1)
	menu.get_node("Root/Card/Margin/Content/StartButton").pressed.emit()
	_expect(signal_counts["start"] == 1, "Start button must emit start_requested exactly once")
	menu.queue_free()

	var minimap := MAP_SCENE.instantiate()
	get_root().add_child(minimap)
	await process_frame
	var course := CourseLayoutScript.load_default()
	minimap.set_course(course, 240)
	minimap.set_player_distance(course.length() * 0.25, course.length())
	await process_frame
	_expect(minimap.track_point_count() == 241, "Minimap must cache requested samples plus closed endpoint")
	var marker: Vector2 = minimap.player_marker_position()
	_expect(marker.x >= 0.0 and marker.x <= minimap.size.x, "Player marker X must stay inside minimap")
	_expect(marker.y >= 0.0 and marker.y <= minimap.size.y, "Player marker Y must stay inside minimap")
	_expect(minimap.position.x > 0.0 or minimap.anchor_left == 1.0, "Minimap must be top-right anchored")
	minimap.queue_free()
	await process_frame

	if _failures.is_empty():
		print("UI SYSTEMS TEST PASS")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
