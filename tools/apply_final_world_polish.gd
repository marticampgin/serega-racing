extends SceneTree

const CourseLayoutScript := preload("res://scripts/course_layout.gd")

const WORLD_PATH := "res://scenes/world/editable_world.tscn"
const LAND_Y := 1.36
const GENERATED_FRIEND_NAMES := [
	"StartGridPortrait", "CoastRacePoster", "PartyCrewPortrait", "DanikHeroPoster",
	"CityEngineerPortrait", "ShoppingEngineerPoster", "ShoppingHedgehogBillboard",
	"NorthCoastCrewBillboard", "NorthCoastRiderBillboard", "FinishMilkBillboard",
	"PartyTownBralisBillboard", "TunnelPoster_00", "TunnelPoster_01", "TunnelPoster_02",
]
const PALM_IDS := ["palm_small", "palm_tall", "palm_wide"]

# A deliberately restrained set of small, editable clusters for sparse sectors.
# Each entry is [preset path, longitudinal shift, extra outward shift, yaw offset].
const CLUSTERS := [
	{"offset": 6040.0, "side": -1.0, "setback": 48.0, "items": [
		["landmarks/city_monument", 0.0, 0.0, 0.0], ["street_props/bench", -9.0, -7.0, 1.57],
		["vegetation/flower_bed", 9.0, -6.0, 0.0], ["street_furniture/park_lamp", 0.0, -10.0, 0.0],
	]},
	{"offset": 6210.0, "side": -1.0, "setback": 49.0, "items": [
		["buildings/bungalow", 0.0, 8.0, 0.0], ["paths_surfaces/driveway", 0.0, -5.0, 0.0],
		["vegetation/hedge_short", -9.0, -2.0, 0.0], ["vegetation/bush", 14.0, 3.0, 0.0],
	]},
	{"offset": 6550.0, "side": 1.0, "setback": 47.0, "items": [
		["street_props/island_cabana", 0.0, 5.0, 0.0], ["street_furniture/picnic_table", -9.0, -4.0, 0.0],
		["vegetation/agave", 10.0, -2.0, 0.0], ["street_furniture/trash_bin", -3.0, -9.0, 0.0],
	]},
	{"offset": 7570.0, "side": 1.0, "setback": 48.0, "items": [
		["buildings/marina_office", 0.0, 8.0, 0.0], ["street_furniture/wayfinding_sign", -10.0, -6.0, 0.0],
		["vegetation/rectangular_planter", 9.0, -4.0, 0.0], ["street_furniture/bike_rack", 1.0, -8.0, 0.0],
	]},
	{"offset": 7740.0, "side": -1.0, "setback": 47.0, "items": [
		["street_furniture/bus_stop", 0.0, -4.0, 0.0], ["street_furniture/vending_machine", 10.0, -2.0, 0.0],
		["vegetation/round_planter", -10.0, -2.0, 0.0], ["paths_surfaces/sidewalk_straight", 0.0, -10.0, 0.0],
	]},
	{"offset": 8420.0, "side": 1.0, "setback": 50.0, "items": [
		["buildings/bungalow", 0.0, 8.0, 0.0], ["paths_surfaces/stepping_stone_path", 0.0, -5.0, 0.0],
		["fences_barriers/white_picket_fence", -9.0, -2.0, 0.0], ["vegetation/flowering_bush_cyan", 14.0, 3.0, 0.0],
	]},
	{"offset": 8760.0, "side": 1.0, "setback": 49.0, "items": [
		["street_props/walking_trail", 0.0, 1.0, 0.0], ["vegetation/bird_of_paradise", -8.0, -3.0, 0.0],
		["vegetation/ornamental_grass", 8.0, -3.0, 0.0], ["street_furniture/drinking_fountain", 0.0, -8.0, 0.0],
	]},
	{"offset": 9100.0, "side": -1.0, "setback": 51.0, "items": [
		["landmarks/sunset_pavilion", 0.0, 8.0, 0.0], ["street_props/bench", -11.0, -4.0, 1.57],
		["vegetation/flowering_bush_pink", 17.0, 0.0, 0.0], ["street_furniture/park_lamp", 0.0, -10.0, 0.0],
	]},
	{"offset": 10120.0, "side": 1.0, "setback": 50.0, "items": [
		["street_props/island_cabana", 0.0, 8.0, 0.0], ["street_props/umbrella_table", -9.0, -1.0, 0.0],
		["vegetation/bush", 9.0, 0.0, 0.0], ["fences_barriers/low_pastel_wall", 0.0, -8.0, 0.0],
	]},
	{"offset": 10460.0, "side": -1.0, "setback": 50.0, "items": [
		["buildings/marina_office", 0.0, 7.0, 0.0], ["beach_marina/surfboard_rack", -9.0, -2.0, 0.0],
		["beach_marina/life_ring_stand", 9.0, -2.0, 0.0], ["vegetation/agave", 0.0, -8.0, 0.0],
	]},
	{"offset": 11310.0, "side": -1.0, "setback": 49.0, "items": [
		["street_props/island_cabana", 0.0, 7.0, 0.0], ["street_props/umbrella_table", -9.0, -2.0, 0.0],
		["street_furniture/recycling_bin", 9.0, -4.0, 0.0], ["vegetation/round_bush", 0.0, -8.0, 0.0],
	]},
	{"offset": 2980.0, "side": -1.0, "setback": 50.0, "items": [
		["street_props/island_cabana", 0.0, 7.0, 0.0], ["street_furniture/picnic_table", -9.0, -2.0, 0.0],
		["vegetation/agave", 9.0, -2.0, 0.0], ["street_furniture/wayfinding_sign", 0.0, -9.0, 0.0],
	]},
	{"offset": 5530.0, "side": -1.0, "setback": 47.0, "items": [
		["street_furniture/neon_phone_booth", 0.0, 2.0, 0.0], ["vegetation/round_planter", -9.0, -2.0, 0.0],
		["street_props/bench", 9.0, -2.0, 1.57], ["street_furniture/park_lamp", 0.0, -8.0, 0.0],
	]},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(WORLD_PATH) as PackedScene
	if packed == null:
		push_error("FINAL WORLD POLISH: editable world does not load")
		quit(1)
		return
	var world := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	root.add_child(world)
	await process_frame
	if world.get_node_or_null("EditableBlocks") != null:
		push_error("FINAL WORLD POLISH: legacy one-time tool is disabled after editable blocks are authored")
		quit(2)
		return
	var removed_friend := _remove_generated_friend_media(world)
	var removed_palms := _remove_duplicate_palms(world)
	var fixed_surfaces := _repair_floating_surfaces(world)
	var added := _add_sprinkle(world)
	var output := PackedScene.new()
	var pack_error := output.pack(world)
	if pack_error != OK:
		push_error("FINAL WORLD POLISH: pack failed: %s" % error_string(pack_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(output, WORLD_PATH)
	if save_error != OK:
		push_error("FINAL WORLD POLISH: save failed: %s" % error_string(save_error))
		quit(1)
		return
	print("FINAL WORLD POLISH: removed %d generated friend roots, %d duplicate palms; fixed %d surfaces; added %d editable sprinkle items" % [
		removed_friend, removed_palms, fixed_surfaces, added,
	])
	root.remove_child(world)
	world.free()
	quit(0)


func _remove_generated_friend_media(world: Node) -> int:
	var doomed: Array[Node] = []
	for district_name in ["StartCoast", "UnderwaterTunnel", "PartyTown", "CityCentre", "ShoppingAlley", "NorthCoast"]:
		var district := world.get_node_or_null(district_name)
		if district == null:
			continue
		for child in district.get_children():
			if child.name in GENERATED_FRIEND_NAMES:
				doomed.append(child)
	var sky_traffic := world.get_node_or_null("Sky/SkyTraffic")
	if sky_traffic != null:
		doomed.append(sky_traffic)
	# Landmark murals were generated as nested sprites rather than poster roots.
	# They are still automatic friend media and must not survive this authored-only pass.
	for value in world.find_children("*", "Node", true, false):
		var node := value as Node
		if node.is_in_group("building_mural_scenery") and not doomed.has(node):
			doomed.append(node)
	for node in doomed:
		node.get_parent().remove_child(node)
		node.free()
	return doomed.size()


func _remove_duplicate_palms(world: Node) -> int:
	var palms: Array[Node3D] = []
	for value in world.find_children("*", "Node3D", true, false):
		var node := value as Node3D
		if node.has_meta("catalog_id") and str(node.get_meta("catalog_id")) in PALM_IDS:
			palms.append(node)
	var doomed: Array[Node3D] = []
	for left_index in range(palms.size()):
		var left := palms[left_index]
		if doomed.has(left):
			continue
		for right_index in range(left_index + 1, palms.size()):
			var right := palms[right_index]
			if doomed.has(right) or str(left.get_meta("catalog_id")) != str(right.get_meta("catalog_id")):
				continue
			if left.global_position.distance_to(right.global_position) < 0.08:
				doomed.append(right)
	for node in doomed:
		node.get_parent().remove_child(node)
		node.free()
	return doomed.size()


func _repair_floating_surfaces(world: Node) -> int:
	# This authored boardwalk piece was a scaled, raised duplicate sitting across
	# the otherwise continuous promenade. Removing it restores the clean chain.
	var stray := world.get_node_or_null("BoardwalkSection11")
	if stray == null:
		return 0
	world.remove_child(stray)
	stray.free()
	return 1


func _add_sprinkle(world: Node) -> int:
	# Make the tool safe to rerun while iterating on the final pass.
	for child in world.get_children():
		if child.has_meta("final_sprinkle"):
			world.remove_child(child)
			child.free()
	var course: CourseLayout = CourseLayoutScript.load_default()
	var added := 0
	for cluster_index in range(CLUSTERS.size()):
		var cluster: Dictionary = CLUSTERS[cluster_index]
		var offset := float(cluster.offset)
		var side := float(cluster.side)
		var road := course.point_at(offset)
		var lateral := course.lateral_at(offset).normalized()
		var tangent := course.tangent_at(offset).normalized()
		var anchor := road + lateral * side * float(cluster.setback)
		anchor.y = LAND_Y
		for item_index in range((cluster.items as Array).size()):
			var spec: Array = cluster.items[item_index]
			var scene_path := "res://scenes/manual_scenery/presets/%s.tscn" % str(spec[0])
			var preset := load(scene_path) as PackedScene
			if preset == null:
				push_warning("FINAL WORLD POLISH: missing preset %s" % scene_path)
				continue
			var item := preset.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
			item.name = "FinalSprinkle_%02d_%02d_%s" % [cluster_index + 1, item_index + 1, str(spec[0]).get_file().to_pascal_case()]
			world.add_child(item, true)
			item.owner = world
			var position := anchor + tangent * float(spec[1]) + lateral * side * float(spec[2])
			position.y = LAND_Y
			item.global_position = position
			item.look_at(Vector3(road.x, position.y, road.z), Vector3.UP)
			item.rotate_y(float(spec[3]))
			item.set_meta("final_sprinkle", true)
			item.set_meta("course_offset", offset)
			added += 1
	return added
