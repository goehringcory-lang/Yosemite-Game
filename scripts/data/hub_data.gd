class_name HubData
extends Resource
## One of the park's main areas. Each hub is its own map scene, generated
## from real elevation and OpenStreetMap data by tools/mapgen.
##
## The scene lives at res://scenes/regions/<id>.tscn.

@export var id: String
@export var display_name: String
@export var elevation_ft := 4000
## One line shown under the name on the park map.
@export var tagline: String
@export_multiline var description: String
## What the player comes here for. Shown as a list on the park map.
@export var activities: PackedStringArray
## Where the hub's marker sits on the park map (decimal degrees).
@export var latitude: float
@export var longitude: float

@export_group("Access")
## Hubs with road access get driving routes to the other road hubs. Hubs
## without it (a summit, a big wall) are reached some other way, such as a climb.
@export var road_access := true
## A locked hub can't be traveled to until something calls
## Park.unlock_hub(id), for example finishing the climb that leads there.
@export var starts_locked := false
## Shown on the park map while the hub is locked.
@export_multiline var locked_hint := ""
## The region drivers arrive in, if not the hub map itself (for example the
## Yosemite Village central hub). Its "arrival" spot is where they park.
@export var arrival_region := ""

@export_group("Map generation")
## Area covered by the generated map, in decimal degrees.
@export var west: float
@export var east: float
@export var south: float
@export var north: float
## Real-world meters covered by one 16 px tile.
@export var meters_per_tile := 40.0
## Ground outside this elevation band (meters) is scenery the player can't
## walk on. Roads are always walkable, so they can lead off the map.
@export var walk_min_elevation := 0.0
@export var walk_max_elevation := 5000.0


func scene_path() -> String:
	return "res://scenes/regions/%s.tscn" % id


func get_elevation_text() -> String:
	return "%s ft (%d m)" % [_thousands(elevation_ft), roundi(elevation_ft * 0.3048)]


static func _thousands(value: int) -> String:
	var text := str(value)
	return text if text.length() <= 3 else text.substr(0, text.length() - 3) + "," + text.substr(text.length() - 3)
