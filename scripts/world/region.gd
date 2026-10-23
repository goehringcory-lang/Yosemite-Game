class_name Region
extends Node2D
## A map the player can be in: a hub generated from real elevation and
## OpenStreetMap data, or a smaller hand-made area like the Lamon Homestead.
## World shows one region at a time and puts the player in its Entities node.
##
## Put hand-made additions (NPCs, stations) in Entities and named Marker2D
## spots in Markers. In hub regions the terrain lives in the Map child, an
## instance of scenes/regions/generated/<id>_map.tscn that tools/mapgen
## rewrites, so don't edit inside Map.

@export var region_id := ""
## The hub this region belongs to. For hubs this is their own id.
@export var hub_id := ""
@export var display_name := ""
## Where a hand-made region sits in the real park (longitude, latitude), for
## the park map. Generated hub maps know their own geography.
@export var geo_anchor := Vector2.ZERO
## Inside a building: the day and night tint doesn't apply.
@export var indoors := false

const SeasonalDressing = preload("res://scripts/world/seasonal_dressing.gd")

## The Place nodes in this region, found once and kept until a Place enters or
## leaves (see Place). place_at() runs several times a second.
var _places: Array[Place] = []
var _places_valid := false

@onready var map: RegionMap = get_node_or_null("Map")
@onready var entities: Node2D = $Entities


func _ready() -> void:
	if not indoors:
		add_child(SeasonalDressing.new())


func get_ground() -> TileMapLayer:
	return map.get_node("Ground") if map else get_node_or_null("Ground")


## A named spot: a Marker2D in Markers (checked first, so hand-placed
## markers can override generated ones), in the generated Spawns, or one a
## story overlay added to Entities (the spots outside a building's door).
func get_spawn(spawn_name: String) -> Marker2D:
	for parent_path in ["Markers", "Map/Spawns", "Spawns", "Entities"]:
		var parent := get_node_or_null(parent_path)
		if parent and parent.has_node(spawn_name) and parent.get_node(spawn_name) is Marker2D:
			return parent.get_node(spawn_name) as Marker2D
	return null


## Every Place in the region. The array is shared: don't change it.
func get_places() -> Array[Place]:
	if not _places_valid:
		_places.clear()
		for node in find_children("*", "Marker2D", true, false):
			if node is Place:
				_places.append(node)
		_places_valid = true
	return _places


## Called by a Place entering or leaving the region, so get_places() looks again.
func places_changed() -> void:
	_places_valid = false


## The most specific named place around [param pos], or null.
func place_at(pos: Vector2) -> Place:
	var best: Place = null
	for place in get_places():
		if place.show_banner and place.radius > 0.0 and place.position.distance_to(pos) <= place.radius:
			if best == null or place.radius < best.radius:
				best = place
	return best


## Real-world longitude/latitude (x/y) of a position in this region.
func to_lonlat(pos: Vector2) -> Vector2:
	return map.position_to_lonlat(pos) if map else geo_anchor


## The playable area in pixels, from the ground layer.
func get_bounds() -> Rect2:
	var ground := get_ground()
	var used := ground.get_used_rect()
	var tile := Vector2(ground.tile_set.tile_size)
	return Rect2(Vector2(used.position) * tile, Vector2(used.size) * tile)
