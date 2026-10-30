extends Node
## Screenshots of a tour of the park for comparing renderers: each region at
## a morning hour, at sunset and at night. The same tour run under two
## renderers (see tools/shots/renderer_compare.sh) should look the same.
## Needs a window (not --headless). Environment:
##   SHOT_DIR       folder for the PNGs (default user://)
##   SHOT_REGIONS   comma-separated region ids (default: the tour below)
##   SHOT_HOURS     comma-separated game hours (default 10,19.5,22)
##   SHOT_SEASON    0 spring, 1 summer, 2 fall, 3 winter (default 1)
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
	for region_id in regions:
		await world.go_to_region(region_id)
		world.hud.visible = false
		for hour in hours:
			GameClock.minutes = roundi(float(hour) * 60.0)
			GameClock.paused = true
			for i in 12:
				await get_tree().process_frame
			var image := get_viewport().get_texture().get_image()
			image.save_png("%s/%s_%s.png" % [dir, region_id, hour.replace(".", "_")])
	get_tree().quit()
