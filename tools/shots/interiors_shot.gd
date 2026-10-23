extends Node
## Photographs every building interior (the rooms in
## tools/hubs/build_interiors.gd) as the player sees them on walking in, and
## the far end of rooms wider than the screen. Needs a window:
##   SHOT_DIR=/tmp/rooms xvfb-run -a godot --path . res://tools/shots/interiors_shot.tscn
## SHOT_ROOMS=degnans,yosemite_chapel picks rooms; SHOT_SCALE (default 1).

const Builder = preload("res://tools/hubs/build_interiors.gd")


func _ready() -> void:
	SaveManager.save_path = "user://interiors_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	GameClock.minutes = 12 * 60
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var scale := int(OS.get_environment("SHOT_SCALE")) if OS.get_environment("SHOT_SCALE") != "" else 1
	var only := OS.get_environment("SHOT_ROOMS").split(",", false)
	var builder: Node = Builder.new()
	var specs: Array = builder.rooms()
	builder.free()
	for spec: Dictionary in specs:
		if not only.is_empty() and not spec.id in only:
			continue
		var spots: Array = []
		for door: Dictionary in spec.doors:
			spots.append(door.get("spot", "door"))
		for spot: String in spots:
			await world.go_to_region(spec.id, spot)
			world.hud.visible = false
			GameClock.paused = true
			for i in 10:
				await get_tree().process_frame
			var image := get_viewport().get_texture().get_image()
			if scale > 1:
				image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
			image.save_png("%s/%s_%s.png" % [dir, spec.id, spot])
	get_tree().quit()
