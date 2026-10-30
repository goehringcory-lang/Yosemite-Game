extends Node
## Screenshots of a tour of the park for comparing renderers: each region at
## a morning hour, at sunset and at night. The same tour run under two
## renderers (see tools/shots/renderer_compare.sh) should look the same.
## Needs a window (not --headless). Environment:
##   SHOT_DIR       folder for the PNGs (default user://)
##   SHOT_REGIONS   comma-separated region ids (default: the tour below)
##   SHOT_HOURS     comma-separated game hours (default 10,19.5,22)
##   SHOT_SEASON    0 spring, 1 summer, 2 fall, 3 winter (default 1)
##   SHOT_SPAWNS    comma-separated spawns to shoot from in each region
##                  (default: the region's arrival); names get the spawn
##   SHOT_UNLIT     1 to leave the sprites unlit (LitSprites off), as on
##                  the Compatibility renderer
##   SHOT_PREFIX    put before every file name (default none)
##   SHOT_RENDERER  if set, quit with an error unless this renderer is the
##                  one running (forward_plus, mobile or gl_compatibility)
## Run: SHOT_DIR=/tmp/shots xvfb-run -a godot --path . --rendering-method forward_plus res://tools/shots/renderer_tour.tscn

const TOUR := [
	"curry_village", "yosemite_village", "lamon_homestead", "el_capitan_meadow",
	"mirror_lake", "bridalveil_fall", "tunnel_view", "glacier_point", "wawona",
	"tuolumne_meadows", "el_portal", "little_yosemite_valley", "the_ahwahnee",
	"ahwahnee_great_lounge",
]


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	var running := RenderingServer.get_current_rendering_method()
	print("Renderer: %s on %s (%s)" % [running, RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name()])
	var expected := OS.get_environment("SHOT_RENDERER")
	if expected != "" and expected != running:
		push_error("Expected the %s renderer but %s is running" % [expected, running])
		get_tree().quit(1)
		return
	LitSprites.enabled = OS.get_environment("SHOT_UNLIT") != "1"
	SaveManager.save_path = "user://renderer_tour_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.season = int(_env("SHOT_SEASON", "1"))
	GameClock.paused = true
	var dir := _env("SHOT_DIR", "user://")
	var regions: PackedStringArray = _env("SHOT_REGIONS", ",".join(TOUR)).split(",", false)
	var hours: PackedStringArray = _env("SHOT_HOURS", "10,19.5,22").split(",", false)
	var spawns: PackedStringArray = OS.get_environment("SHOT_SPAWNS").split(",", false)
	var prefix := OS.get_environment("SHOT_PREFIX")
	for region_id in regions:
		for spawn in (spawns if not spawns.is_empty() else PackedStringArray(["arrival"])):
			await world.go_to_region(region_id, spawn)
			if world.region.get_spawn(spawn) == null:
				# a room or an area without one: where the first spawn puts you
				var first: Marker2D = null
				for parent_path in ["Markers", "Map/Spawns", "Spawns"]:
					var parent: Node = world.region.get_node_or_null(parent_path)
					if first == null and parent and parent.get_child_count() > 0 and parent.get_child(0) is Marker2D:
						first = parent.get_child(0)
				if first:
					world.player.global_position = first.global_position
					world._camera().reset_smoothing()
			world.hud.visible = false
			var place := region_id if spawns.is_empty() else "%s_%s" % [region_id, spawn]
			for hour in hours:
				GameClock.minutes = roundi(float(hour) * 60.0)
				GameClock.paused = true
				for i in 12:
					await get_tree().process_frame
				var image := get_viewport().get_texture().get_image()
				image.save_png("%s/%s%s_%s.png" % [dir, prefix, place, hour.replace(".", "_")])
	get_tree().quit()
