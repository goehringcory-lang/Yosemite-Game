extends Node
## Films the v2 climber (scripts/climb/v2/art) climbing the fixture pitch
## through the stub systems: moves, a clip, a cam, a rest, a meal and a fall,
## one action every so often so each animation plays out. Saves a crop round
## the climber every frame as numbered PNGs (make a GIF or video from them).
## Run with a fixed frame rate and a window:
##   CLIP_OUT=/tmp/clip godot --path . --fixed-fps 30 res://tools/shots/climber_v2_clip.tscn
## Environment: CLIP_OUT (folder, default user://climber_clip), CLIP_FRAMES
## (default 420), CLIP_EVERY (frames between actions, default 14), CLIP_FALL
## (frame to fall at, default 300; -1 for none), CLIP_SIZE (crop, window
## pixels, default 520x600).

var screen: ClimbScreenV2
var bot: ClimbV2TestBot


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	ClimbSystems.pin_stubs_except([&"climber"])
	var route := RouteData.new()
	route.id = "v2_fixture"
	route.display_name = "Fixture"
	route.protection = "bolts"
	route.pitches.assign([2, 2])
	var rack := ClimberPoses.session_for(["rest on jugs"]).rack
	rack.items.append({"id": "cam_1", "kind": "cam", "width_min": 4, "width_max": 4, "count": 1, "name": "#1"})
	screen = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(route, 7, V2Modifiers.new(), rack)
	add_child(screen)
	await get_tree().process_frame
	bot = ClimbV2TestBot.new(screen.director)
	var out := _env("CLIP_OUT", ProjectSettings.globalize_path("user://climber_clip"))
	DirAccess.make_dir_recursive_absolute(out)
	var frames := int(_env("CLIP_FRAMES", "420"))
	var every := int(_env("CLIP_EVERY", "14"))
	var fall_at := int(_env("CLIP_FALL", "300"))
	var size := Vector2(float(_env("CLIP_SIZE", "520x600").split("x")[0]), float(_env("CLIP_SIZE", "520x600").split("x")[1]))
	screen.director.handle_verb(&"commit", true)
	for f in frames:
		if f == fall_at and screen.session.phase == &"climb":
			screen.director.take_fall()
		elif f % every == 0 and f < fall_at - 10 or f > fall_at + 110 and f % every == 0:
			if not screen.director.done:
				bot.step()
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var art := screen.climber as ClimberArt
		var at := art.get_global_transform_with_canvas() * ClimberView.px(art.rig.hip)
		at *= Vector2(img.get_size()) / get_viewport().get_visible_rect().size
		var rect := Rect2i(Vector2i(at - size * Vector2(0.5, 0.45)), Vector2i(size))
		rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		img.get_region(rect).save_png("%s/f%04d.png" % [out, f])
	print("saved ", frames, " frames to ", out)
	ClimbSystems.pins.clear()
	get_tree().quit()
