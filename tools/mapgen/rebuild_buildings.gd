extends Node
## Redoes the buildings of the generated hub maps in place, without
## regenerating anything else (the terrain, collision and spawns stay as they
## are, and no download is needed):
##   godot --headless --path . res://tools/mapgen/rebuild_buildings.tscn -- paint
##   godot --headless --path . --import
##   godot --headless --path . res://tools/mapgen/rebuild_buildings.tscn -- place [hub ids]
## "paint" draws the lodge and hotel sprites (hub_building_art.gd) and the
## atlas's lit windows into assets/sprites/. "place" reads each map's Flora
## layer, takes out the one-cabin-per-cell tiles, and adds a Buildings node
## with one building per footprint (hub_buildings.gd, the same code the map
## generator uses). A map that already has a Buildings node is skipped:
## regenerate it with mapgen to start over.

const Buildings = preload("res://tools/mapgen/hub_buildings.gd")
const BuildingArt = preload("res://tools/mapgen/hub_building_art.gd")
const Art = preload("res://tools/mapgen/art.gd")
const Terrain = preload("res://tools/mapgen/terrain.gd")
const HUBS := ["el_portal", "wawona", "glacier_point", "tuolumne_meadows", "yosemite_valley"]
## The spawn marker the hotel is built around, per hub.
const HOTEL_MARKERS := {"wawona": "wawona_hotel"}


func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	if "paint" in args:
		BuildingArt.new().save_all()
		var art := Art.new()
		art._save_png(art.paint_flora(), Art.FLORA_PNG)
		art._save_png(art.paint_flora_glow(), Art.FLORA_GLOW_PNG)
		print("lodge and hotel sprites painted; now run --import, then 'place'")
	else:
		var hubs := args.filter(func(a: String) -> bool: return a != "place")
		for hub_id: String in (HUBS if hubs.is_empty() else hubs):
			print("%s: %s" % [hub_id, _place(hub_id)])
	get_tree().quit()


func _place(hub_id: String) -> String:
	var path := "res://scenes/regions/generated/%s_map.tscn" % hub_id
	var map: Node2D = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if map.has_node("Buildings"):
		map.free()
		return "already has Buildings (regenerate the map to redo it)"
	var layer := map.get_node("Flora") as TileMapLayer
	var cells := {}
	for c: Vector2i in layer.get_used_cells():
		var at := layer.get_cell_atlas_coords(c)
		var flora_type := at.y * Terrain.FLORA_COLUMNS + at.x
		if Buildings.is_building(flora_type):
			cells[c] = flora_type
	for c: Vector2i in cells:
		layer.erase_cell(c)
	var hotel_at := Vector2(-1, -1)
	if HOTEL_MARKERS.has(hub_id):
		var marker := map.get_node_or_null("Spawns/" + HOTEL_MARKERS[hub_id]) as Node2D
		if marker != null:
			hotel_at = marker.position
	var count := Buildings.add_to(map, cells, hotel_at)
	var blocked := _blocked_spots(map)
	var packed := PackedScene.new()
	packed.pack(map)
	var err := ResourceSaver.save(packed, path)
	map.free()
	return "%d footprint cells -> %d buildings%s%s" % [cells.size(), count, "" if err == OK else " (SAVE FAILED)",
		"" if blocked.is_empty() else "\n  INSIDE A BUILDING: " + ", ".join(blocked)]


## Spawn points and objects that a building's collision would now cover.
func _blocked_spots(map: Node2D) -> Array[String]:
	var found: Array[String] = []
	var shapes: Array[CollisionShape2D] = []
	shapes.assign(map.get_node("Buildings/Footprints").get_children())
	for group in ["Spawns", "Objects"]:
		for spot: Node2D in map.get_node(group).get_children():
			for cs in shapes:
				if Rect2(cs.position - cs.shape.size / 2.0, cs.shape.size).grow(2.0).has_point(spot.position):
					found.append("%s/%s" % [group, spot.name])
					break
	return found
