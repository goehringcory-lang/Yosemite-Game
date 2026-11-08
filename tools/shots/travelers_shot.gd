extends Node
## Screenshots of the people who walk between the Valley's areas
## (Travelers): the climbers walking out of Camp 4 at dawn, the pair crossing
## Leidig Meadow, the two of them at the foot of the Nose, the camp kid and
## the ranger passing on Southside Drive, and a word with the ranger.
## Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/travelers_shot.tscn

const CLIMBERS := ["traveler_climber_lead", "traveler_climber_second"]


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


## Saves the screen after [param frames], with the clock running through
## the last few when [param walking] so whoever's on the move is mid-stride.
func _snap(dir: String, shot_name: String, frames := 20, walking := false) -> void:
	Engine.time_scale = 1.0
	for i in frames:
		GameClock.paused = not (walking and i >= frames - 4)
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/travelers_%s.png" % [dir, shot_name])
	GameClock.paused = true
	Engine.time_scale = 4.0


func _walker(world: Node, id: String) -> Traveler:
	for node in world.get_children():
		if node is Travelers:
			for walker: Traveler in node.walkers():
				if is_instance_valid(walker) and walker.plan_id == id:
					return walker
	return null


## Goes to [param id] at [param spawn] at [param minutes] on a dry summer day,
## with the clock stopped there (and showing it), and everyone out and about
## put where it has them.
func _go(world: Node, id: String, spawn: String, minutes: float) -> void:
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 3
	GameClock.minutes = floori(minutes)
	await world.go_to_region(id, spawn)
	GameClock.paused = true
	GameClock.minutes = floori(minutes)
	GameClock._elapsed = 0.0
	GameClock.time_changed.emit(GameClock.hour, GameClock.minute)
	Travelers.forget()
	for i in 30:
		await get_tree().physics_frame


## Lets the clock run until [param a] and [param b] are both out and within
## [param reach] of each other, or until [param latest] (minutes); true if
## they met.
func _until_near(world: Node, a: String, b: String, reach: float, latest: float) -> bool:
	GameClock.paused = false
	var met := false
	while GameClock.smooth_minutes() < latest and not met:
		await get_tree().physics_frame
		var one := _walker(world, a)
		var two := _walker(world, b)
		met = one != null and two != null and one.global_position.distance_to(two.global_position) < reach
	GameClock.paused = true
	return met


## Puts you [param from] the middle of the walkers [param ids], looking on,
## so the camera has them all.
func _frame(world: Node, ids: Array, from := Vector2(0, 80)) -> void:
	var middle := Vector2.ZERO
	var count := 0
	for id: String in ids:
		var walker := _walker(world, id)
		if walker:
			middle += walker.global_position
			count += 1
			print("  %s at %s, %s %s" % [id, walker.global_position.round(), walker.segment.kind, walker.segment.get("b", walker.segment.get("point"))])
		else:
			print("  %s not here" % id)
	if count == 0:
		push_warning("nobody to frame: %s" % [ids])
		return
	var player: Player = world.player
	player.global_position = middle / count + from
	player.facing = Vector2i.UP
	world._camera().reset_smoothing()


func _ready() -> void:
	SaveManager.save_path = "user://travelers_shot_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := _env("SHOT_DIR", "user://")
	Engine.time_scale = 4.0

	# Dawn: the climbers out of Camp 4 and off down Northside Drive.
	await _go(world, "yosemite_village", "camp_4", 6 * 60 + 27)
	_frame(world, CLIMBERS, Vector2(0, 120))
	await _snap(dir, "dawn", 20, true)

	# Across Leidig Meadow, an hour of road before the rock.
	await _go(world, "leidig_meadow", "east", 7 * 60 + 10)
	_frame(world, CLIMBERS, Vector2(0, 80))
	await _snap(dir, "leidig", 20, true)

	# At the foot of the Nose, either side of the start.
	await _go(world, "el_capitan_meadow", "arrival", 10 * 60)
	_frame(world, CLIMBERS, Vector2(0, 110))
	await _snap(dir, "nose")

	# Southside Drive: the kid on the way in, the ranger on the way out.
	await _go(world, "yosemite_village", "southside_east", 8 * 60 + 12)
	if await _until_near(world, "traveler_camp_kid", "traveler_ranger", 110.0, 10 * 60):
		print("kid and ranger pass at %d:%02d" % [GameClock.hour, GameClock.minute])
	_frame(world, ["traveler_camp_kid", "traveler_ranger"], Vector2(-70, 60))
	await _snap(dir, "southside", 20, true)

	# A word with the ranger.
	var ranger := _walker(world, "traveler_ranger")
	if ranger:
		_frame(world, ["traveler_ranger"], Vector2(0, 40))
		await get_tree().process_frame
		ranger.interact(world.player)
		for i in 30:
			await get_tree().process_frame
			for child in get_tree().root.get_children():
				if child is DialogueBox:
					child.reveal_all()
		await _snap(dir, "talk", 4)
	SaveManager.delete_save()
	get_tree().quit()
