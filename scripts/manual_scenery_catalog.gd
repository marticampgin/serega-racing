class_name ManualSceneryCatalog
extends RefCounted

## Canonical drag-and-drop library. Infrastructure is intentionally absent:
## terrain, ocean, road, bridge, flyover and tunnel shells remain procedural.

const LAND := 0
const WATER := 1
const AIR := 2
const WALL := 3

const ENTRIES: Array[Dictionary] = [
	# Buildings
	{"id": "villa", "name": "Beach Villa", "category": "Buildings", "archetype": "villa", "variant": 0, "surface": LAND, "radius": 11.0, "height": 9.0},
	{"id": "grand_villa", "name": "Grand Beach Villa", "category": "Buildings", "archetype": "villa", "variant": 1, "surface": LAND, "radius": 15.0, "height": 18.0},
	{"id": "nightclub", "name": "Neon Nightclub", "category": "Buildings", "archetype": "nightclub", "variant": 0, "surface": LAND, "radius": 13.0, "height": 12.0},
	{"id": "art_deco_tower", "name": "Art Deco Tower", "category": "Buildings", "archetype": "tower", "variant": 0, "surface": LAND, "radius": 11.0, "height": 38.0},
	{"id": "storefront_row", "name": "Storefront Row", "category": "Buildings", "archetype": "storefront_row", "variant": 0, "surface": LAND, "radius": 18.0, "height": 11.0},
	{"id": "city_block", "name": "Mixed Use City Block", "category": "Buildings", "archetype": "city_block", "variant": 0, "surface": LAND, "radius": 19.0, "height": 30.0},
	{"id": "beach_bar", "name": "Beach Bar", "category": "Buildings", "archetype": "beach_bar", "variant": 0, "surface": LAND, "radius": 14.0, "height": 8.0},
	{"id": "grand_hotel", "name": "Grand Hotel", "category": "Buildings", "archetype": "grand_hotel", "variant": 0, "surface": LAND, "radius": 22.0, "height": 34.0},
	{"id": "neon_theatre", "name": "Neon Theatre", "category": "Buildings", "archetype": "theatre", "variant": 0, "surface": LAND, "radius": 22.0, "height": 31.0},
	{"id": "twin_towers", "name": "Civic Twin Towers", "category": "Buildings", "archetype": "twin_towers", "variant": 0, "surface": LAND, "radius": 25.0, "height": 64.0},
	{"id": "market_hall", "name": "Market Hall", "category": "Buildings", "archetype": "market_hall", "variant": 0, "surface": LAND, "radius": 22.0, "height": 14.0},
	{"id": "neon_arena", "name": "Neon Arena", "category": "Buildings", "archetype": "arena", "variant": 0, "surface": LAND, "radius": 25.0, "height": 18.0},
	{"id": "marina_hotel", "name": "Marina Hotel", "category": "Buildings", "archetype": "marina_hotel", "variant": 0, "surface": LAND, "radius": 21.0, "height": 32.0},
	{"id": "neon_diner", "name": "Neon Diner", "category": "Buildings", "archetype": "diner", "variant": 0, "surface": LAND, "radius": 14.0, "height": 10.0},
	{"id": "beach_motel", "name": "Beach Motel", "category": "Buildings", "archetype": "motel", "variant": 0, "surface": LAND, "radius": 17.0, "height": 13.0},
	{"id": "motor_inn", "name": "Pastel Motor Inn", "category": "Buildings", "archetype": "motel", "variant": 1, "surface": LAND, "radius": 20.0, "height": 13.0},
	{"id": "marina_office", "name": "Marina Office", "category": "Buildings", "archetype": "marina_office", "variant": 0, "surface": LAND, "radius": 15.0, "height": 11.0},
	{"id": "bungalow", "name": "Coastal Bungalow", "category": "Buildings", "archetype": "bungalow", "variant": 0, "surface": LAND, "radius": 11.0, "height": 8.0},
	{"id": "midrise", "name": "Art Deco Midrise", "category": "Buildings", "archetype": "midrise", "variant": 0, "surface": LAND, "radius": 13.0, "height": 25.0},
	{"id": "coastal_apartment", "name": "Coastal Apartment", "category": "Buildings", "archetype": "apartment", "variant": 0, "surface": LAND, "radius": 14.0, "height": 23.0},
	{"id": "party_hotel", "name": "Party Hotel", "category": "Buildings", "archetype": "party_hotel", "variant": 0, "surface": LAND, "radius": 17.0, "height": 28.0},
	{"id": "city_complex", "name": "City Complex", "category": "Buildings", "archetype": "city_complex", "variant": 0, "surface": LAND, "radius": 20.0, "height": 40.0},
	{"id": "market_arcade", "name": "Market Arcade", "category": "Buildings", "archetype": "market_arcade", "variant": 0, "surface": LAND, "radius": 17.0, "height": 13.0},
	{"id": "sport_hall", "name": "Sport Hall", "category": "Buildings", "archetype": "sport_hall", "variant": 0, "surface": LAND, "radius": 21.0, "height": 18.0},

	# Landmarks and leisure
	{"id": "lighthouse", "name": "Coastal Lighthouse", "category": "Landmarks", "archetype": "lighthouse", "variant": 0, "surface": LAND, "radius": 8.0, "height": 31.0},
	{"id": "city_monument", "name": "City Monument", "category": "Landmarks", "archetype": "monument", "variant": 0, "surface": LAND, "radius": 10.0, "height": 17.0},
	{"id": "sport_complex", "name": "Sport Complex", "category": "Landmarks", "archetype": "sport_complex", "variant": 0, "surface": LAND, "radius": 38.0, "height": 18.0},
	{"id": "sport_facility", "name": "Courts and Bleachers", "category": "Landmarks", "archetype": "sport_facility", "variant": 0, "surface": LAND, "radius": 21.0, "height": 8.0},
	{"id": "drive_in", "name": "Drive In Cinema", "category": "Landmarks", "archetype": "drive_in", "variant": 0, "surface": LAND, "radius": 18.0, "height": 14.0},
	{"id": "sunset_pavilion", "name": "Sunset Pavilion", "category": "Landmarks", "archetype": "pavilion", "variant": 0, "surface": LAND, "radius": 14.0, "height": 13.0},
	{"id": "skate_park", "name": "Neon Skate Park", "category": "Landmarks", "archetype": "skate_park", "variant": 0, "surface": LAND, "radius": 20.0, "height": 9.0},
	{"id": "party_island_club", "name": "Party Island Club", "category": "Landmarks", "archetype": "party_club", "variant": 0, "surface": LAND, "radius": 20.0, "height": 44.0},
	{"id": "coastal_promenade", "name": "Coastal Promenade", "category": "Landmarks", "archetype": "promenade", "variant": 0, "surface": LAND, "radius": 17.0, "height": 5.0},
	{"id": "party_patio", "name": "Party Patio", "category": "Landmarks", "archetype": "party_patio", "variant": 0, "surface": LAND, "radius": 15.0, "height": 7.0},
	{"id": "marina_docks", "name": "Marina Docks", "category": "Landmarks", "archetype": "marina_docks", "variant": 0, "surface": WATER, "radius": 20.0, "height": 5.0},

	# Vegetation and small street props
	{"id": "palm_small", "name": "Small Palm", "category": "Vegetation", "archetype": "palm", "variant": 0, "surface": LAND, "radius": 4.5, "height": 7.0},
	{"id": "palm_tall", "name": "Tall Palm", "category": "Vegetation", "archetype": "palm", "variant": 1, "surface": LAND, "radius": 5.0, "height": 11.0},
	{"id": "palm_wide", "name": "Wide Palm", "category": "Vegetation", "archetype": "palm", "variant": 2, "surface": LAND, "radius": 6.0, "height": 9.0},
	{"id": "bush", "name": "Tropical Bush", "category": "Vegetation", "archetype": "bush", "variant": 0, "surface": LAND, "radius": 2.0, "height": 1.8},
	{"id": "roadside_lamp", "name": "Roadside Lamp", "category": "Street Props", "archetype": "lamp", "variant": 0, "surface": LAND, "radius": 2.5, "height": 7.0},
	{"id": "floodlight", "name": "Floodlight", "category": "Street Props", "archetype": "floodlight", "variant": 0, "surface": LAND, "radius": 3.0, "height": 16.0},
	{"id": "fence_section", "name": "Fence Section", "category": "Street Props", "archetype": "fence", "variant": 0, "surface": LAND, "radius": 6.5, "height": 2.0},
	{"id": "walking_trail", "name": "Walking Trail", "category": "Street Props", "archetype": "trail", "variant": 0, "surface": LAND, "radius": 7.0, "height": 0.2},
	{"id": "bench", "name": "Promenade Bench", "category": "Street Props", "archetype": "bench", "variant": 0, "surface": LAND, "radius": 2.5, "height": 1.5},
	{"id": "umbrella_table", "name": "Cafe Umbrella Table", "category": "Street Props", "archetype": "umbrella", "variant": 0, "surface": LAND, "radius": 3.0, "height": 3.2},
	{"id": "island_cabana", "name": "Island Cabana", "category": "Street Props", "archetype": "cabana", "variant": 0, "surface": LAND, "radius": 7.0, "height": 5.0},

	# Signs. The texture remains editable on the root Inspector.
	{"id": "roadside_billboard", "name": "Roadside Billboard", "category": "Signs and Posters", "archetype": "billboard", "variant": 0, "surface": LAND, "radius": 7.0, "height": 9.0, "texture": "res://assets/generated/friends/481d5ab6-7c3f-47be-a2bd-e02bdfb2c1d5.jpg"},
	{"id": "wall_poster", "name": "Wall Poster", "category": "Signs and Posters", "archetype": "wall_poster", "variant": 0, "surface": WALL, "radius": 5.0, "height": 6.0, "texture": "res://assets/generated/friends/5213d1b1-6e99-448d-ad81-26f61e859010.jpg"},

	# Maritime scenery
	{"id": "motorboat", "name": "Small Motorboat", "category": "Boats and Waterfront", "archetype": "motorboat", "variant": 0, "surface": WATER, "radius": 6.0, "height": 3.0},
	{"id": "sailboat", "name": "Sailboat", "category": "Boats and Waterfront", "archetype": "sailboat", "variant": 0, "surface": WATER, "radius": 8.0, "height": 17.0},
	{"id": "yacht", "name": "Yacht", "category": "Boats and Waterfront", "archetype": "yacht", "variant": 0, "surface": WATER, "radius": 12.0, "height": 6.0},
	{"id": "party_yacht", "name": "Party Yacht", "category": "Boats and Waterfront", "archetype": "yacht", "variant": 1, "surface": WATER, "radius": 13.0, "height": 9.0},
	{"id": "ferry", "name": "Island Ferry", "category": "Boats and Waterfront", "archetype": "ferry", "variant": 0, "surface": WATER, "radius": 19.0, "height": 13.0},
	{"id": "fishing_boat", "name": "Fishing Boat", "category": "Boats and Waterfront", "archetype": "fishing_boat", "variant": 0, "surface": WATER, "radius": 9.0, "height": 8.0},

	# Static by default; optional motion is exposed on the root Inspector.
	{"id": "zeppelin", "name": "Banner Zeppelin", "category": "Sky", "archetype": "zeppelin", "variant": 0, "surface": AIR, "radius": 26.0, "height": 18.0, "texture": "res://assets/generated/friends/5213d1b1-6e99-448d-ad81-26f61e859010.jpg"},
	{"id": "banner_plane", "name": "Banner Plane", "category": "Sky", "archetype": "banner_plane", "variant": 0, "surface": AIR, "radius": 28.0, "height": 13.0, "texture": "res://assets/generated/friends/882a2791-af8b-4378-b3b7-a05b4cf0dd08.jpg"},
	{"id": "air_banner", "name": "Air Banner", "category": "Sky", "archetype": "air_banner", "variant": 0, "surface": AIR, "radius": 12.0, "height": 11.0, "texture": "res://assets/generated/friends/8608460d-bd44-4e25-b2dc-ccf8a5003e87.jpg"},
]

const SMALL_PROP_ENTRIES: Array[Dictionary] = [
	# Fine-grained vegetation
	{"id":"round_bush","name":"Round Tropical Bush","category":"Vegetation","archetype":"bush","variant":1,"surface":LAND,"radius":1.8,"height":1.7},
	{"id":"flowering_bush_pink","name":"Pink Flowering Bush","category":"Vegetation","archetype":"flowering_bush","variant":0,"surface":LAND,"radius":2.2,"height":2.0},
	{"id":"flowering_bush_cyan","name":"Cyan Flowering Bush","category":"Vegetation","archetype":"flowering_bush","variant":1,"surface":LAND,"radius":2.2,"height":2.0},
	{"id":"hedge_short","name":"Short Hedge","category":"Vegetation","archetype":"hedge","variant":0,"surface":LAND,"radius":3.5,"height":1.7,"allow_overlap":true},
	{"id":"hedge_long","name":"Long Hedge","category":"Vegetation","archetype":"hedge","variant":1,"surface":LAND,"radius":6.5,"height":1.9,"allow_overlap":true},
	{"id":"rectangular_planter","name":"Rectangular Planter","category":"Vegetation","archetype":"planter","variant":0,"surface":LAND,"radius":2.8,"height":1.8},
	{"id":"round_planter","name":"Round Planter","category":"Vegetation","archetype":"planter","variant":1,"surface":LAND,"radius":2.2,"height":2.0},
	{"id":"agave","name":"Agave Plant","category":"Vegetation","archetype":"agave","variant":0,"surface":LAND,"radius":1.8,"height":2.2},
	{"id":"bird_of_paradise","name":"Bird of Paradise Cluster","category":"Vegetation","archetype":"tropical_plant","variant":0,"surface":LAND,"radius":2.3,"height":3.2},
	{"id":"ornamental_grass","name":"Ornamental Grass","category":"Vegetation","archetype":"tropical_plant","variant":1,"surface":LAND,"radius":1.7,"height":1.9},
	{"id":"flower_bed","name":"Tropical Flower Bed","category":"Vegetation","archetype":"flower_bed","variant":0,"surface":LAND,"radius":3.8,"height":0.9,"allow_overlap":true},
	{"id":"bougainvillea_trellis","name":"Bougainvillea Trellis","category":"Vegetation","archetype":"trellis","variant":0,"surface":LAND,"radius":4.5,"height":4.0,"allow_overlap":true},

	# Fences and traffic-control pieces
	{"id":"white_picket_fence","name":"White Picket Fence","category":"Fences and Barriers","archetype":"fence_variant","variant":0,"surface":LAND,"radius":5.5,"height":1.8,"allow_overlap":true},
	{"id":"neon_rail_fence","name":"Neon Rail Fence","category":"Fences and Barriers","archetype":"fence_variant","variant":1,"surface":LAND,"radius":5.5,"height":1.6,"allow_overlap":true},
	{"id":"chain_link_fence","name":"Chain Link Fence","category":"Fences and Barriers","archetype":"fence_variant","variant":2,"surface":LAND,"radius":5.5,"height":2.5,"allow_overlap":true},
	{"id":"low_pastel_wall","name":"Low Pastel Wall","category":"Fences and Barriers","archetype":"fence_variant","variant":3,"surface":LAND,"radius":5.5,"height":1.3,"allow_overlap":true},
	{"id":"traffic_cone","name":"Traffic Cone","category":"Fences and Barriers","archetype":"traffic_cone","variant":0,"surface":LAND,"radius":0.8,"height":1.1,"allow_on_course":true,"allow_overlap":true},
	{"id":"road_barricade","name":"Road Barricade","category":"Fences and Barriers","archetype":"barricade","variant":0,"surface":LAND,"radius":2.8,"height":1.7,"allow_on_course":true,"allow_overlap":true},
	{"id":"short_bollard","name":"Short Bollard","category":"Fences and Barriers","archetype":"bollard","variant":0,"surface":LAND,"radius":0.8,"height":1.2,"allow_overlap":true},

	# Individual street furniture
	{"id":"double_streetlamp","name":"Double Streetlamp","category":"Street Furniture","archetype":"lamp_variant","variant":0,"surface":LAND,"radius":2.6,"height":7.0},
	{"id":"park_lamp","name":"Park Lamp","category":"Street Furniture","archetype":"lamp_variant","variant":1,"surface":LAND,"radius":1.6,"height":4.2},
	{"id":"trash_bin","name":"Trash Bin","category":"Street Furniture","archetype":"bin","variant":0,"surface":LAND,"radius":1.0,"height":1.3},
	{"id":"recycling_bin","name":"Recycling Bin","category":"Street Furniture","archetype":"bin","variant":1,"surface":LAND,"radius":1.0,"height":1.3},
	{"id":"fire_hydrant","name":"Fire Hydrant","category":"Street Furniture","archetype":"hydrant","variant":0,"surface":LAND,"radius":0.8,"height":1.2},
	{"id":"bike_rack","name":"Bike Rack","category":"Street Furniture","archetype":"bike_rack","variant":0,"surface":LAND,"radius":2.2,"height":1.3},
	{"id":"bus_stop","name":"Bus Stop","category":"Street Furniture","archetype":"bus_stop","variant":0,"surface":LAND,"radius":4.5,"height":3.6},
	{"id":"neon_phone_booth","name":"Neon Phone Booth","category":"Street Furniture","archetype":"phone_booth","variant":0,"surface":LAND,"radius":1.6,"height":3.0},
	{"id":"vending_machine","name":"Vending Machine","category":"Street Furniture","archetype":"vending","variant":0,"surface":LAND,"radius":1.3,"height":2.3},
	{"id":"newspaper_box","name":"Newspaper Box","category":"Street Furniture","archetype":"newspaper","variant":0,"surface":LAND,"radius":0.9,"height":1.3},
	{"id":"picnic_table","name":"Picnic Table","category":"Street Furniture","archetype":"picnic","variant":0,"surface":LAND,"radius":2.7,"height":1.4},
	{"id":"drinking_fountain","name":"Drinking Fountain","category":"Street Furniture","archetype":"fountain","variant":0,"surface":LAND,"radius":1.0,"height":1.3},
	{"id":"wayfinding_sign","name":"Wayfinding Sign","category":"Street Furniture","archetype":"wayfinding","variant":0,"surface":LAND,"radius":1.5,"height":3.4},

	# Thin connectable ground pieces
	{"id":"side_road_straight","name":"Side Road Straight","category":"Paths and Surfaces","archetype":"surface_piece","variant":0,"surface":LAND,"radius":8.0,"height":0.12,"allow_overlap":true},
	{"id":"side_road_corner","name":"Side Road Corner","category":"Paths and Surfaces","archetype":"surface_piece","variant":1,"surface":LAND,"radius":8.0,"height":0.12,"allow_overlap":true},
	{"id":"sidewalk_straight","name":"Sidewalk Straight","category":"Paths and Surfaces","archetype":"surface_piece","variant":2,"surface":LAND,"radius":6.0,"height":0.16,"allow_overlap":true},
	{"id":"sidewalk_corner","name":"Sidewalk Corner","category":"Paths and Surfaces","archetype":"surface_piece","variant":3,"surface":LAND,"radius":5.0,"height":0.16,"allow_overlap":true},
	{"id":"driveway","name":"Driveway","category":"Paths and Surfaces","archetype":"surface_piece","variant":4,"surface":LAND,"radius":5.0,"height":0.14,"allow_overlap":true},
	{"id":"marked_parking_pad","name":"Marked Parking Pad","category":"Paths and Surfaces","archetype":"surface_piece","variant":5,"surface":LAND,"radius":7.0,"height":0.14,"allow_overlap":true},
	{"id":"crosswalk","name":"Crosswalk","category":"Paths and Surfaces","archetype":"surface_piece","variant":6,"surface":LAND,"radius":5.0,"height":0.08,"allow_on_course":true,"allow_overlap":true},
	{"id":"boardwalk_section","name":"Boardwalk Section","category":"Paths and Surfaces","archetype":"surface_piece","variant":7,"surface":LAND,"radius":6.0,"height":0.18,"allow_overlap":true},
	{"id":"plaza_tile","name":"Plaza Tile","category":"Paths and Surfaces","archetype":"surface_piece","variant":8,"surface":LAND,"radius":5.0,"height":0.12,"allow_overlap":true},
	{"id":"stepping_stone_path","name":"Stepping Stone Path","category":"Paths and Surfaces","archetype":"surface_piece","variant":9,"surface":LAND,"radius":5.5,"height":0.16,"allow_overlap":true},

	# Beach and marina details
	{"id":"dock_straight","name":"Dock Straight","category":"Beach and Marina","archetype":"waterfront_prop","variant":0,"surface":WATER,"radius":6.0,"height":0.5,"allow_overlap":true},
	{"id":"dock_corner","name":"Dock Corner","category":"Beach and Marina","archetype":"waterfront_prop","variant":1,"surface":WATER,"radius":6.0,"height":0.5,"allow_overlap":true},
	{"id":"mooring_bollard","name":"Mooring Bollard","category":"Beach and Marina","archetype":"waterfront_prop","variant":2,"surface":LAND,"radius":1.0,"height":1.0},
	{"id":"red_buoy","name":"Red Buoy","category":"Beach and Marina","archetype":"waterfront_prop","variant":3,"surface":WATER,"radius":1.5,"height":2.0,"allow_overlap":true},
	{"id":"cyan_buoy","name":"Cyan Buoy","category":"Beach and Marina","archetype":"waterfront_prop","variant":4,"surface":WATER,"radius":1.5,"height":2.0,"allow_overlap":true},
	{"id":"life_ring_stand","name":"Life Ring Stand","category":"Beach and Marina","archetype":"waterfront_prop","variant":5,"surface":LAND,"radius":1.5,"height":2.4},
	{"id":"beach_shower","name":"Beach Shower","category":"Beach and Marina","archetype":"waterfront_prop","variant":6,"surface":LAND,"radius":1.5,"height":2.8},
	{"id":"surfboard_rack","name":"Surfboard Rack","category":"Beach and Marina","archetype":"waterfront_prop","variant":7,"surface":LAND,"radius":2.6,"height":2.2},
	{"id":"lounge_chair","name":"Lounge Chair","category":"Beach and Marina","archetype":"waterfront_prop","variant":8,"surface":LAND,"radius":2.0,"height":1.0},
	{"id":"lifeguard_chair","name":"Lifeguard Chair","category":"Beach and Marina","archetype":"waterfront_prop","variant":9,"surface":LAND,"radius":2.2,"height":4.2},
]

const FRIEND_ART: Array[Dictionary] = [
	{"id":"friend_glasses","name":"Friend Glasses","texture":"res://assets/generated/friends/friend-glasses-racing.png"},
	{"id":"friend_dark_hair","name":"Friend Dark Hair","texture":"res://assets/generated/friends/friend-dark-hair-racing.png"},
	{"id":"friend_beard","name":"Friend Beard","texture":"res://assets/generated/friends/friend-beard-racing.png"},
	{"id":"race_car_art","name":"Race Car Art","texture":"res://assets/generated/friends/1844112d-4cdc-4fd7-af55-4c29c7179983.jpg"},
	{"id":"crew_collage","name":"Crew Collage","texture":"res://assets/generated/friends/1daf0fdc-2536-4e54-b476-fc61c770b23d.jpg"},
	{"id":"bralis","name":"Bralis","texture":"res://assets/generated/friends/481d5ab6-7c3f-47be-a2bd-e02bdfb2c1d5.jpg"},
	{"id":"punk_hedgehog","name":"Punk Hedgehog","texture":"res://assets/generated/friends/5213d1b1-6e99-448d-ad81-26f61e859010.jpg"},
	{"id":"race_engineer","name":"Race Engineer","texture":"res://assets/generated/friends/61b5ddf7-ae71-4d13-b677-660bd070a785.jpg"},
	{"id":"danik","name":"Danik","texture":"res://assets/generated/friends/71b38443-851b-401f-a174-0b72d699a284.jpg"},
	{"id":"motorcycle_rider","name":"Motorcycle Rider","texture":"res://assets/generated/friends/8608460d-bd44-4e25-b2dc-ccf8a5003e87.jpg"},
	{"id":"milk_racer","name":"Milk Racer","texture":"res://assets/generated/friends/882a2791-af8b-4378-b3b7-a05b4cf0dd08.jpg"},
]

const ART_CARRIERS: Array[Dictionary] = [
	{"id":"billboard","name":"Billboard","archetype":"billboard","surface":LAND,"radius":7.0,"height":9.0},
	{"id":"wall_poster","name":"Wall Poster","archetype":"wall_poster","surface":WALL,"radius":5.0,"height":6.0},
	{"id":"zeppelin","name":"Zeppelin","archetype":"zeppelin","surface":AIR,"radius":26.0,"height":18.0},
	{"id":"banner_plane","name":"Banner Plane","archetype":"banner_plane","surface":AIR,"radius":28.0,"height":13.0},
	{"id":"air_banner","name":"Air Banner","archetype":"air_banner","surface":AIR,"radius":12.0,"height":11.0},
]


static func entries() -> Array[Dictionary]:
	var result := ENTRIES.duplicate(true)
	result.append_array(SMALL_PROP_ENTRIES.duplicate(true))
	for artwork: Dictionary in FRIEND_ART:
		for carrier: Dictionary in ART_CARRIERS:
			result.append({
				"id": "art_%s__%s" % [artwork.id, carrier.id],
				"name": "%s %s" % [artwork.name, carrier.name],
				"category": "Friend Media",
				"folder": "friend_media/%s" % artwork.id,
				"filename": "%s.tscn" % carrier.id,
				"archetype": carrier.archetype,
				"variant": 0,
				"surface": carrier.surface,
				"radius": carrier.radius,
				"height": carrier.height,
				"texture": artwork.texture,
				"artwork_id": artwork.id,
				"carrier_id": carrier.id,
			})
	return result


static func entry(id: String) -> Dictionary:
	for value: Dictionary in entries():
		if str(value.id) == id:
			return value.duplicate(true)
	return {}


static func scene_path(value: Dictionary) -> String:
	if value.has("folder"):
		return "res://scenes/manual_scenery/presets/%s/%s" % [str(value.folder), str(value.filename)]
	var folder := str(value.category).to_snake_case().replace("_and_", "_")
	return "res://scenes/manual_scenery/presets/%s/%s.tscn" % [folder, str(value.id)]
