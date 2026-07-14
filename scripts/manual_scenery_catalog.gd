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


static func entries() -> Array[Dictionary]:
	return ENTRIES.duplicate(true)


static func entry(id: String) -> Dictionary:
	for value: Dictionary in ENTRIES:
		if str(value.id) == id:
			return value.duplicate(true)
	return {}


static func scene_path(value: Dictionary) -> String:
	var folder := str(value.category).to_snake_case().replace("_and_", "_")
	return "res://scenes/manual_scenery/presets/%s/%s.tscn" % [folder, str(value.id)]
