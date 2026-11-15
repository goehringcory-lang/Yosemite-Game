extends Node
## Screenshots of the woods past the maps' edges (SeamBackdrop): for each
## seam it stands the player at the two ends of the stretch of edge the two
## areas share, where one map stops and the forest fills the corner.
## Needs a window (not --headless). Environment:
##   SHOT_DIR     folder for the PNGs (default user://)
##   SHOT_SEAMS   comma-separated "region:Exit" pairs (default: the tour below)
##   SHOT_HOUR    game hour (default 12)
##   SHOT_SEASON  0 spring, 1 summer, 2 fall, 3 winter (default 1)
##   SHOT_DAY     day of the season (default: leave as is)
##   SHOT_WIND    1 to let the wind blow (default: still air)
## Run: SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/edge_shot.tscn

const TOUR := [
	"mirror_lake:ToTenayaCreek", "the_ahwahnee:ToStonemanBridge", "happy_isles:ToTenayaCreek",
	"yosemite_village:NorthsideWest", "curry_village:EastRoad", "leidig_meadow:ToElCapitan",
	"bridalveil_fall:ToTunnelView", "el_capitan_meadow:NorthsideDriveWest",
]


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	Wind.enabled = OS.get_environment("SHOT_WIND") == "1"
	SaveManager.save_path = "user://edge_shot_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	Settings.wayfinding = false
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.season = int(_env("SHOT_SEASON", "1"))
	if OS.get_environment("SHOT_DAY") != "":
		GameClock.day = int(OS.get_environment("SHOT_DAY"))
	var minutes := roundi(float(_env("SHOT_HOUR", "12")) * 60.0)
	GameClock.minutes = minutes
	GameClock.paused = true
	var dir := _env("SHOT_DIR", "user://")
	for pair: String in _env("SHOT_SEAMS", ",".join(TOUR)).split(",", false):
		var region_id := pair.get_slice(":", 0)
		var exit_name := pair.get_slice(":", 1)
		await world.go_to_region(region_id, "arrival")
		GameClock.minutes = minutes
		GameClock.paused = true
		world.hud.visible = false
		var exit := world.region.find_child(exit_name, true, false) as RegionExit
		if exit == null:
			push_error("no exit %s in %s" % [exit_name, region_id])
			continue
		# beside the exit, so World lays the next area out there
		var bounds: Rect2 = world.region.get_bounds()
		var at: Vector2 = world.region.to_local(exit.global_position).clamp(bounds.position + Vector2(48, 48), bounds.end - Vector2(48, 48))
		world.player.global_position = world.region.to_global(at)
		world._update_seam(true)
		var seam: Seam = world.seam
		if seam == null or seam.exit != exit:
			push_error("no seam through %s in %s" % [exit_name, region_id])
			continue
		var along := Vector2(absf(seam.side.y), absf(seam.side.x))
		var ends := [seam.span.x, seam.span.y]
		for i in ends.size():
			# the end of the shared stretch, a little way onto this map
			var spot: Vector2 = seam.point - along * seam.point.dot(along) + along * ends[i] - Vector2(seam.side) * 56.0
			world.player.global_position = world.region.to_global(spot.clamp(bounds.position + Vector2(24, 24), bounds.end - Vector2(24, 24)))
			world._camera().reset_smoothing()
			for f in 20:
				await get_tree().process_frame
			world._camera().reset_smoothing()
			for f in 6:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/edge_%s_%s_%d.png" % [dir, region_id, exit_name, i])
	get_tree().quit()
