class_name RegionMap
extends Node2D
## The generated part of a hub region: terrain, flora, signs, spawn points,
## and exits, built by tools/mapgen from real elevation and OpenStreetMap
## data. Regenerating overwrites this scene.

## Longitude of the map's west edge and latitude of its north edge.
@export var geo_west := 0.0
@export var geo_north := 0.0
@export var meters_per_tile := 40.0
## Meters per degree of longitude (x) and latitude (y) at this latitude.
@export var meters_per_degree := Vector2.ONE
@export var size_in_tiles := Vector2i.ZERO
## A 1-pixel-per-tile picture of this map, shown on the area map screen.
@export_file("*.png") var area_map_path := ""

const TILE := 16.0


func position_to_lonlat(pos: Vector2) -> Vector2:
	var meters := pos / TILE * meters_per_tile
	return Vector2(geo_west + meters.x / meters_per_degree.x, geo_north - meters.y / meters_per_degree.y)


func lonlat_to_position(lonlat: Vector2) -> Vector2:
	return Vector2((lonlat.x - geo_west) * meters_per_degree.x,
		(geo_north - lonlat.y) * meters_per_degree.y) / meters_per_tile * TILE
