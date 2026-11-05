extends Node
## Photographs rooms at several hours, to see their windows follow the clock
## (RoomWindows). Needs a window:
##   SHOT_DIR=/tmp/windows xvfb-run -a godot --path . res://tools/shots/room_windows_shot.tscn
## SHOT_ROOMS=curry_store,ahwahnee_great_lounge picks rooms (default: every
## room in data/park/room_windows.json); SHOT_HOURS=7,12,18.6,23 the hours;
## SHOT_DAY the day of the season (14 is full moon); SHOT_PLAIN=1 hides
## RoomWindows, for "before" shots. Files are <room>_<hour>.png.


func _ready() -> void:
	SaveManager.save_path = "user://room_windows_shot_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	GameClock.season = 1
	if OS.get_environment("SHOT_DAY") != "":
		GameClock.day = int(OS.get_environment("SHOT_DAY"))
	GameClock.paused = true
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var rooms := OS.get_environment("SHOT_ROOMS").split(",", false)
	if rooms.is_empty():
		rooms = PackedStringArray(RoomWindows.data().keys())
	var hours := OS.get_environment("SHOT_HOURS").split(",", false)
	if hours.is_empty():
		hours = PackedStringArray(["7", "12", "18.6", "23"])
	var plain := OS.get_environment("SHOT_PLAIN") == "1"
	for room in rooms:
		await world.go_to_region(room, "door")
		world.hud.visible = false
		var windows := world.region.get_node_or_null("RoomWindows") as Node2D
		if windows and plain:
			windows.visible = false
		for h in hours:
			GameClock.minutes = int(round(float(h) * 60.0))
			GameClock.paused = true
			for i in 10:
				await get_tree().process_frame
			var image := get_viewport().get_texture().get_image()
			image.save_png("%s/%s_%s.png" % [dir, room, h])
	get_tree().quit()
