extends Node
## Screenshots of earned fast travel (Trailheads): a trailhead sign just
## found at Upper Pines, the trip planner open at it, the trip to Tuolumne
## on the trip map, and the new Evergreen Road drive from Crane Flat to
## Hetch Hetchy. Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/trailheads_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _save(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/trailheads_%s.png" % [dir, shot_name])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _trip_shot(world: Node, dir: String, shot_name: String, at: float) -> void:
	var journey: Journey = null
	for i in 3000:
		await get_tree().process_frame
		if journey == null:
			for child in world.get_children():
				if child is Journey:
					journey = child
		if journey and journey._running and journey._progress >= at:
			break
	await _save(dir, shot_name)
	while world._busy:
		await get_tree().process_frame


func _ready() -> void:
	SaveManager.save_path = "user://trailheads_shot_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	Park.open_world = true
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await _frames(2)
	world.journeys_headless = true
	var dir := _env("SHOT_DIR", "user://")
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 3
	GameClock.minutes = 10 * 60

	# Walk up to the Upper Pines sign: found.
	Settings.journeys = false
	await world.go_to_region("upper_pines", "campground")
	Settings.journeys = true
	await _frames(40)
	var point := Trailheads.get_point("upper_pines")
	world.player.global_position = world.region.to_global(point.pos + Vector2(-24, 36))
	world.player.facing = Vector2i.UP
	await _frames(30)
	await _save(dir, "found")

	# Plenty found: the planner, with Tuolumne under the cursor.
	for id in ["village_parking", "curry_parking", "happy_isles", "glacier_point", "taft_point", "tuolumne_vc", "hetch_hetchy", "wawona_store", "tenaya_beach"]:
		Trailheads.register(id, false)
	await _frames(120)
	Trailheads.plan_trip(world.player, "upper_pines")
	await _frames(30)
	var box: DialogueBox = null
	for child in get_tree().root.get_children():
		if child is DialogueBox:
			box = child
	if box:
		box.reveal_all()
		for i in 7:
			box._cursor = i
			box._refresh_options()
			box._refresh_detail()
			await _frames(2)
			if "Tuolumne" in str(box._details[i].get("title", "")):
				break
		await _frames(20)
		await _save(dir, "planner")
		box.press(true)
	await _trip_shot(world, dir, "trip", 0.55)
	await _frames(30)
	await _save(dir, "arrived")

	# The drive to Hetch Hetchy from Crane Flat's west end.
	Settings.journeys = false
	await world.go_to_region("crane_flat", "west")
	Settings.journeys = true
	GameClock.minutes = 15 * 60
	await _frames(30)
	world.use_exit(world.region.find_child("BigOakFlatRoadWest", true, false))
	await _trip_shot(world, dir, "evergreen_road", 0.6)
	SaveManager.delete_save()
	get_tree().quit()
