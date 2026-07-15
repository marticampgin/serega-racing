extends SceneTree

const CatalogScript := preload("res://scripts/manual_scenery_catalog.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)


func _run() -> void:
	var entries := CatalogScript.entries()
	check(entries.size() == 164, "catalog exposes 57 originals, 52 small props and 55 friend-media variants")
	check(CatalogScript.SMALL_PROP_ENTRIES.size() == 52, "small-prop expansion has the complete 52-piece set")
	var required_ids := ["flowering_bush_pink", "hedge_long", "agave", "traffic_cone", "road_barricade", "white_picket_fence", "trash_bin", "fire_hydrant", "bus_stop", "side_road_straight", "side_road_corner", "crosswalk", "dock_corner", "surfboard_rack"]
	for id: String in required_ids:
		check(not CatalogScript.entry(id).is_empty(), "small standalone preset exists: %s" % id)
	for entry: Dictionary in CatalogScript.SMALL_PROP_ENTRIES:
		var packed := load(CatalogScript.scene_path(entry)) as PackedScene
		check(packed != null, "small prop scene loads: %s" % entry.id)
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		check(not instance.find_children("*", "MeshInstance3D", true, false).is_empty(), "%s has visible geometry" % entry.id)
		check(instance.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s remains visual-only" % entry.id)
		instance.free()

	var matrix := {}
	var matrix_count := 0
	for entry: Dictionary in entries:
		if not entry.has("artwork_id"):
			continue
		matrix_count += 1
		var key := "%s/%s" % [entry.artwork_id, entry.carrier_id]
		check(not matrix.has(key), "friend-media pair is unique: %s" % key)
		matrix[key] = true
		var packed := load(CatalogScript.scene_path(entry)) as PackedScene
		check(packed != null, "friend-media scene loads: %s" % key)
		if packed == null:
			continue
		var instance := packed.instantiate() as Node3D
		var expected_texture := str(entry.texture)
		var faces := instance.find_children("PosterFace*", "Sprite3D", true, false)
		check(not faces.is_empty(), "%s has visible artwork faces" % key)
		for value in faces:
			check((value as Sprite3D).texture != null and (value as Sprite3D).texture.resource_path == expected_texture, "%s uses the requested friend image" % key)
		check(instance.find_children("*", "CollisionObject3D", true, false).is_empty(), "%s remains visual-only" % key)
		instance.free()
	check(matrix_count == CatalogScript.FRIEND_ART.size() * CatalogScript.ART_CARRIERS.size(), "matrix contains every 11 friends x 5 carriers")
	for artwork: Dictionary in CatalogScript.FRIEND_ART:
		for carrier: Dictionary in CatalogScript.ART_CARRIERS:
			check(matrix.has("%s/%s" % [artwork.id, carrier.id]), "%s is available as %s" % [artwork.name, carrier.name])
	print("MANUAL SCENERY EXPANSION QA: %d presets, %d failures" % [entries.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
