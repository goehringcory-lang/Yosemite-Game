extends Node
## Saves screenshots of the open-world map: the Park map's fog after a few
## areas, zoomed in, the stamp picker, the tracked pointer in the world, and
## a region's title card on arrival.
## Needs a window (not --headless). Environment:
##   SHOT_DIR    folder for the PNGs (default user://)
##   SHOT_SCALE  integer upscale (default 2)
## Run: SHOT_DIR=/tmp/shots godot --path . res://tools/shots/map_world_shot.tscn


func _snap(dir: String, scale: int, shot_name: String) -> void:
	for i in 10:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	if scale > 1:
		image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/map_%s.png" % [dir, shot_name])


func _ready() -> void:
	SaveManager.save_path = "user://map_world_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 11 * 60
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 2
	MapFog.start_new_game()
	# a few days' wandering: the Valley floor, up to Glacier Point, Tenaya Lake
	for id: String in ["el_capitan_meadow", "yosemite_village", "the_ahwahnee", "mirror_lake", "tenaya_lake", "tuolumne_meadows", "glacier_point", "curry_village"]:
		await world.go_to_region(id, "arrival")
		for i in 4:
			await get_tree().process_frame
		MapFog.walk(world.region, world.region.to_local(world.player.global_position))
	await get_tree().create_timer(0.2).timeout
	var title: Control = world.hud.arrival_title
	world.hud.arrival_title.show_title("Hetch Hetchy", "Yosemite Valley")
	await get_tree().create_timer(1.0).timeout
	await _snap(dir, scale, "arrival_title")
	title.visible = false
	MapFog.add_stamp("fish", Vector2(-119.555, 37.733))
	MapFog.add_stamp("flower", Vector2(-119.50, 37.80))
	MapFog.add_stamp("tent", Vector2(-119.36, 37.875))
	MapFog.add_stamp("star", Vector2(-119.575, 37.742))
	MapFog.track({"kind": "stamp", "id": "3", "label": "Star", "lonlat": Vector2(-119.575, 37.742), "region": ""})
	world.open_map()
	var map: ParkMap = world.park_map
	map._tab = ParkMap.Tab.PARK
	map._hover_nearest()
	map._refresh()
	await _snap(dir, scale, "park")
	map._select("tuolumne_meadows")
	await _snap(dir, scale, "park_hub")
	map._cursor_at = ParkAtlas.geo_to_map(Vector2(-119.555, 37.733), ParkMap.PARK_MAP.get_size())
	map._set_zoom(2)
	await _snap(dir, scale, "park_zoom")
	map._cursor_at += Vector2(6, -3)
	map._hover_nearest()
	map._picking = true
	map._pick = 2
	map._refresh()
	await _snap(dir, scale, "park_picker")
	map.close()
	# the tracked star, from Curry Village
	for i in 20:
		await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	await _snap(dir, scale, "tracker")
	MapFog.track({"kind": "area", "id": "tenaya_lake", "label": "Tenaya Lake", "lonlat": MapFog.region_lonlat("tenaya_lake"), "region": "tenaya_lake"})
	await get_tree().create_timer(0.6).timeout
	await _snap(dir, scale, "tracker_other_area")
	get_tree().quit()
