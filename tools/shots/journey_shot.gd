extends Node
## Screenshots of the trip map (Journey): a drive up the Tioga Road from
## Crane Flat to Tenaya Lake, the Mist and Panorama Trails from Happy Isles
## to Glacier Point, and a Valley shuttle ride, each caught partway; then the
## signposts at Tenaya Lake and Glacier Point (Wayfinding outside the Valley).
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/journey_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _save(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/journey_%s.png" % [dir, shot_name])


## Puts the player at [param spawn] in [param id] at [param minutes] on a
## summer day, without a trip.
func _place(world: Node, id: String, spawn: String, minutes: int) -> void:
	Settings.journeys = false
	await world.go_to_region(id, spawn)
	Settings.journeys = true
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 3
	GameClock.minutes = minutes
	GameClock._elapsed = 0.0
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
	for i in 20:
		await get_tree().process_frame


## Starts a trip and snaps it when the marker is [param at] of the way.
func _trip(world: Node, dir: String, shot_name: String, at: float, id: String, spawn: String, minutes: int, info: Dictionary) -> void:
	world.go_to_region(id, spawn, minutes, info)
	var journey: Journey = null
	for i in 2000:
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
	SaveManager.save_path = "user://journey_shot_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	Park.open_world = true
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := _env("SHOT_DIR", "user://")
	Engine.time_scale = 1.0

	await _place(world, "crane_flat", "south", 10 * 60)
	await _trip(world, dir, "tioga_road", 0.62, "tenaya_lake", "west", 55, {"title": "Tioga Road", "miles": 31.0})
	await _place(world, "happy_isles", "arrival", 8 * 60)
	await _trip(world, dir, "mist_trail", 0.45, "glacier_point", "arrival", 300, {"title": "Mist Trail and Panorama Trail", "on_foot": true})
	await _place(world, "yosemite_village", "arrival", 14 * 60)
	await _trip(world, dir, "shuttle", 0.5, "curry_village", "arrival", 15, {"title": "Valley shuttle"})

	Settings.wayfinding = true
	await _place(world, "tenaya_lake", "west", 12 * 60)
	for i in 300:
		await get_tree().process_frame
	await _save(dir, "signs_tenaya")
	await _place(world, "glacier_point", "arrival", 12 * 60)
	for i in 300:
		await get_tree().process_frame
	await _save(dir, "signs_glacier_point")
	SaveManager.delete_save()
	get_tree().quit()
