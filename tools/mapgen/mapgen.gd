extends Node
## Builds Yosemite's maps from real-world data: elevation from the USGS 3D
## Elevation Program (via the AWS Terrain Tiles) and OpenStreetMap. Run it
## from the project folder:
##
##   godot --headless --path . res://tools/mapgen/mapgen.tscn -- [steps] [hub ids]
##
## Steps: fetch, art, park, regions. With no steps it runs all of them. Add
## hub ids to rebuild only those regions. Downloads are cached in
## tools/mapgen/cache/ (delete a file there to download it again).

const Osm = preload("res://tools/mapgen/osm.gd")
const Dem = preload("res://tools/mapgen/dem.gd")
const Art = preload("res://tools/mapgen/art.gd")
const ParkBuilder = preload("res://tools/mapgen/park_builder.gd")
const RegionBuilder = preload("res://tools/mapgen/region_builder.gd")
const HubContent = preload("res://tools/mapgen/hub_content.gd")

const CACHE := "res://tools/mapgen/cache"
const STEPS := ["fetch", "art", "park", "regions"]
## Elevation tile zoom levels: about 120 m per pixel for the park map and
## 15 m per pixel for the hub maps.
const PARK_ZOOM := 10
const REGION_ZOOM := 13


func _ready() -> void:
	var steps := PackedStringArray()
	var hubs := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg in STEPS:
			steps.append(arg)
		else:
			hubs.append(arg)
	if steps.is_empty():
		steps = PackedStringArray(STEPS)
	var started := Time.get_ticks_msec()
	for step in steps:
		print("== %s" % step)
		match step:
			"fetch":
				fetch_all()
			"art":
				build_art()
			"park":
				build_park()
			"regions":
				build_regions(hubs)
	print("Done in %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	get_tree().quit()


func cache_path(relative: String) -> String:
	return ProjectSettings.globalize_path(CACHE.path_join(relative))


func fetch_all() -> void:
	Osm.fetch(Osm.park_query(ParkAtlas.MAP_SOUTH, ParkAtlas.MAP_WEST, ParkAtlas.MAP_NORTH, ParkAtlas.MAP_EAST),
		cache_path("osm/park.json"))
	Osm.fetch(Osm.boundary_query(), cache_path("osm/boundary.json"))
	for hub: HubData in ParkAtlas.HUBS:
		_hub_osm(hub)


func _hub_osm(hub: HubData) -> Dictionary:
	var m := 0.004
	return Osm.fetch(Osm.region_query(hub.south - m, hub.west - m, hub.north + m, hub.east + m),
		cache_path("osm/%s.json" % hub.id))


func build_art() -> void:
	var art := Art.new()
	art.save_images()
	_import()
	art.build_tileset()
	_object_scene("InfoSign", "res://scripts/objects/info_sign.gd", "res://assets/sprites/info_sign.png",
		Vector2(16, 16), Vector2(12, 4), Vector2(16, 14), "res://scenes/objects/info_sign.tscn")
	_object_scene("TravelPoint", "res://scripts/objects/travel_point.gd", "res://assets/sprites/map_kiosk.png",
		Vector2(16, 24), Vector2(14, 4), Vector2(16, 20), "res://scenes/objects/travel_point.tscn")
	_object_scene("RegionDoor", "res://scripts/objects/region_door.gd", "res://assets/sprites/trailhead.png",
		Vector2(16, 24), Vector2(6, 4), Vector2(16, 20), "res://scenes/objects/region_door.tscn")


func build_park() -> void:
	var osm := Osm.fetch("", cache_path("osm/park.json"))
	osm.elements.append_array(Osm.fetch(Osm.boundary_query(), cache_path("osm/boundary.json")).get("elements", []))
	var builder := ParkBuilder.new(osm, Dem.new(PARK_ZOOM, cache_path("dem")))
	builder.build_map()
	builder.build_routes()
	_import()


func build_regions(only: PackedStringArray) -> void:
	var dem := Dem.new(REGION_ZOOM, cache_path("dem"))
	for hub: HubData in ParkAtlas.HUBS:
		if not only.is_empty() and not hub.id in only:
			continue
		if not HubContent.CONTENT.has(hub.id):
			push_warning("No content for %s in hub_content.gd" % hub.id)
			continue
		var builder := RegionBuilder.new(hub, HubContent.CONTENT[hub.id], dem, _hub_osm(hub))
		var report := builder.build()
		print("    walkable %d tiles, %d reachable from the arrival point" % [report.walkable, report.reachable])
		for line: String in report.warnings:
			print("    " + line)
	_import()


## Imports new or changed PNGs so scenes can reference them.
func _import() -> void:
	print("  importing assets")
	var output := []
	OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"], output, true)


## A small interactable object: sprite, collision at its base, and a hitbox
## on the "interactable" layer that the player's interaction area detects.
func _object_scene(node_name: String, script: String, texture: String, tex_size: Vector2,
		body_size: Vector2, hitbox_size: Vector2, path: String) -> void:
	var body := StaticBody2D.new()
	body.name = node_name
	body.set_script(load(script))
	body.collision_layer = 1
	body.collision_mask = 0
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = ResourceLoader.load(texture, "", ResourceLoader.CACHE_MODE_REPLACE)
	sprite.offset = Vector2(0, -tex_size.y / 2.0)
	body.add_child(sprite)
	var shape := CollisionShape2D.new()
	shape.name = "Collision"
	var rect := RectangleShape2D.new()
	rect.size = body_size
	shape.shape = rect
	shape.position = Vector2(0, -body_size.y / 2.0)
	body.add_child(shape)
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var hit_shape := CollisionShape2D.new()
	hit_shape.name = "Shape"
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = hitbox_size
	hit_shape.shape = hit_rect
	hit_shape.position = Vector2(0, -hitbox_size.y / 2.0)
	hitbox.add_child(hit_shape)
	body.add_child(hitbox)
	for child in body.get_children():
		child.owner = body
	hit_shape.owner = body
	var packed := PackedScene.new()
	assert(packed.pack(body) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	body.free()
