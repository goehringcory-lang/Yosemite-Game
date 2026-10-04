class_name ParkAtlas
extends RefCounted
## Park geography shared by the game and the map generator (tools/mapgen).
## Keep this free of autoload references so the generator can load it.

## The park map covers this box (decimal degrees). tools/mapgen renders
## res://assets/map/park_map.png for exactly this area.
const MAP_WEST := -119.92
const MAP_EAST := -119.17
const MAP_SOUTH := 37.46
const MAP_NORTH := 38.22

const HUBS: Array[HubData] = [
	preload("res://data/park/hubs/yosemite_valley.tres"),
	preload("res://data/park/hubs/el_portal.tres"),
	preload("res://data/park/hubs/glacier_point.tres"),
	preload("res://data/park/hubs/wawona.tres"),
	preload("res://data/park/hubs/tuolumne_meadows.tres"),
]


## Converts longitude/latitude (x/y) to a pixel position on a park map image.
static func geo_to_map(lon_lat: Vector2, map_size: Vector2) -> Vector2:
	return Vector2(
		(lon_lat.x - MAP_WEST) / (MAP_EAST - MAP_WEST) * map_size.x,
		(MAP_NORTH - lon_lat.y) / (MAP_NORTH - MAP_SOUTH) * map_size.y)


## Meters per degree of longitude and latitude near [param lat].
static func meters_per_degree(lat: float) -> Vector2:
	var phi := deg_to_rad(lat)
	return Vector2(
		111412.84 * cos(phi) - 93.5 * cos(3.0 * phi),
		111132.92 - 559.82 * cos(2.0 * phi) + 1.175 * cos(4.0 * phi))
