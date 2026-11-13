extends Node
## Checks the open world (Park.open_world): on a fresh game, in any season,
## every hub, road, trail and door is open, every region can be reached from
## the homestead, and the Valley shuttle still runs to every stop.
## Run: godot --headless --path . res://tests/open_world_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://open_world_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0
	check(Park.open_world, "the park is an open world by default")

	_check_hubs_and_roads()
	_check_doors_and_reach()
	_check_cables()
	await _check_place_list()
	await _check_shuttle()

	SaveManager.delete_save()
	print("%d failure(s)" % failures)
	get_tree().quit(failures)


## Every hub is open on day one, and no road or trail closes for the winter.
func _check_hubs_and_roads() -> void:
	Park.start_new_game()
	var locked := PackedStringArray()
	for hub in ParkAtlas.HUBS:
		if not Park.is_hub_unlocked(hub.id):
			locked.append(hub.id)
	check(locked.is_empty(), "every hub is open on a new game (locked: %s)" % ", ".join(locked))
	var was := [GameClock.season, GameClock.day]
	for season in [GameClock.Season.SPRING, GameClock.Season.WINTER]:
		GameClock.season = season
		GameClock.day = 1
		var shut := PackedStringArray()
		for closure: String in Park.SEASONAL:
			if not Park.is_open(closure):
				shut.append(closure)
		for hub in ParkAtlas.HUBS:
			for leg in Park.legs_from(hub.id):
				if not leg.open:
					shut.append("%s->%s" % [hub.id, leg.to])
		check(shut.is_empty(), "season %d: every road, trail and the cables are open (shut: %s)" % [season, ", ".join(shut)])
	GameClock.season = was[0]
	GameClock.day = was[1]
	check(Park.nights_until_open("tioga_road") == 0 and not QuestLog.snowed_in(), "the story is never snowed in")


## Every door in every region (and its story overlay) opens, and walking,
## driving and the shuttle reach every region from the homestead.
func _check_doors_and_reach() -> void:
	var links := {}
	var shut := PackedStringArray()
	var ids := PackedStringArray()
	for file in DirAccess.get_files_at("res://scenes/regions/"):
		if file.ends_with(".tscn"):
			ids.append(file.get_basename())
	for id in ids:
		var to: Dictionary = links.get_or_add(id, {})
		for path in ["res://scenes/regions/%s.tscn" % id, StoryContent.DIR % id, StoryContent.DOORS_DIR % id]:
			if not ResourceLoader.exists(path):
				continue
			var root: Node = (load(path) as PackedScene).instantiate()
			for door in root.find_children("*", "RegionDoor", true, false):
				if not door.is_unlocked():
					shut.append("%s/%s" % [id, door.name])
				if door.target_region != "":
					to[door.target_region] = true
			for exit in root.find_children("*", "RegionExit", true, false):
				if exit.target_region != "":
					to[exit.target_region] = true
				for hub_id in [exit.drive_to, exit.travel_to]:
					if hub_id != "":
						to[_arrival(hub_id)] = true
			if root.find_children("*", "ShuttleStop", true, false).size() > 0:
				for stop: Dictionary in ShuttleStop.STOPS:
					to[stop.region] = true
			# Any outdoor region of a hub can open the travel map.
			if root is Region and root.hub_id != "":
				for leg in Park.legs_from(root.hub_id):
					to[_arrival(leg.to)] = true
			root.free()
	check(shut.is_empty(), "every door and trail opens (shut: %s)" % ", ".join(shut))

	var seen := {Park.HOME_REGION: true}
	var queue: Array = [Park.HOME_REGION]
	while not queue.is_empty():
		for next: String in links.get(queue.pop_front(), {}):
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	var missed := PackedStringArray()
	for id in ids:
		if not seen.has(id):
			missed.append(id)
	check(missed.is_empty(), "all %d regions can be reached from the homestead (missed: %s)" % [ids.size(), ", ".join(missed)])


func _arrival(hub_id: String) -> String:
	var hub := Park.get_hub(hub_id)
	return hub.arrival_region if hub and hub.arrival_region != "" else hub_id


## The Half Dome cables don't ask for a permit (rain still keeps you off).
func _check_cables() -> void:
	check(not Backcountry.has_permit(), "a new game has no wilderness permit")
	check(not HalfDomeCables.closed_reason().contains("permit"), "the cables are open without a permit (%s)" % HalfDomeCables.closed_reason())


## In the real game, ride the shuttle round the whole loop, stop to stop,
## from each stop's own sign.
func _check_shuttle() -> void:
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.minutes = 7 * 60
	Discoveries.start_new_game()
	var map: ParkMap = world.park_map
	var unseen := {"tier": "place", "name": "Tunnel View"}
	check(not map._point_known(unseen), "the area map hides a place you haven't found")
	check(map._point_known({"tier": "landmark", "name": "Half Dome"}), "but the peaks and falls are always on it")
	var first: Dictionary = ShuttleStop.STOPS[0]
	await world.go_to_region(first.region, first.spawn)
	await _settle(world)
	for i in ShuttleStop.STOPS.size():
		var from: Dictionary = ShuttleStop.STOPS[i]
		var dest: Dictionary = ShuttleStop.STOPS[(i + 1) % ShuttleStop.STOPS.size()]
		var sign := _stop_named(world.region, from.name)
		check(sign != null, "%s has its shuttle stop" % from.name)
		if sign == null:
			continue
		check(sign.destinations().size() == ShuttleStop.STOPS.size() - 1, "%s rides to every other stop" % from.name)
		var before := GameClock.minutes
		sign.ride(dest)
		await get_tree().create_timer(2.5).timeout
		await _settle(world)
		check(world.region.region_id == dest.region and world.player.position == world.region.get_spawn(dest.spawn).position,
			"the shuttle from %s drops you at %s (in %s)" % [from.name, dest.name, world.region.region_id])
		# (the clock can tick on once while the screen wipes)
		var took := GameClock.minutes - before
		check(took >= ShuttleStop.RIDE_MINUTES and took < ShuttleStop.RIDE_MINUTES + 15, "the ride to %s takes %d minutes (%d)" % [dest.name, ShuttleStop.RIDE_MINUTES, took])

	# Riding the loop discovers every stop's area, each with a card.
	for _i in 3:
		await get_tree().process_frame
	var missing := PackedStringArray()
	for stop: Dictionary in ShuttleStop.STOPS:
		var region: Region = world._get_region(stop.region)
		if not Discoveries.is_found(Discoveries.key_for(stop.region, region.display_name)):
			missing.append(stop.region)
	check(missing.is_empty(), "riding the loop discovers every stop's area (missing: %s)" % ", ".join(missing))
	check(Discoveries.count() >= 8 and Discoveries.count() < Discoveries.total(), "%d of %d places found so far" % [Discoveries.count(), Discoveries.total()])
	check(map._point_known({"tier": "place", "name": "Curry Village"}) and not map._point_known(unseen), "the map names the places you've been")
	check(not Discoveries.valley_seen, "the Valley floor isn't a lookout")
	var progress := Achievements.progress(Achievements.ACHIEVEMENTS.filter(func(a: Dictionary) -> bool: return a.id == "wanderer")[0])
	check(progress[0] == Discoveries.count() and progress[1] == 25, "Wanderer counts the places found (%s)" % str(progress))

	# And from the loop, the once-locked places: the rim and the cave.
	await world.go_to_region("glacier_point", "arrival")
	await _settle(world)
	for _i in 3:
		await get_tree().process_frame
	check(world.region.region_id == "glacier_point", "you can go straight to Glacier Point")
	check(Discoveries.valley_seen and map._point_known(unseen), "from Glacier Point every place in the Valley shows on the map")
	check(Discoveries.is_found("glacier_point/Glacier Point"), "and Glacier Point itself is discovered")
	var saved := Discoveries.save_data()
	var had := Discoveries.count()
	Discoveries.start_new_game()
	check(Discoveries.count() == 0 and not Discoveries.valley_seen, "a new game starts with nothing discovered")
	Discoveries.load_data(saved)
	check(Discoveries.count() == had and Discoveries.valley_seen, "discoveries are saved and loaded")
	Discoveries.load_data({})
	check(Discoveries.count() == 0, "a save from before discoveries loads with none")
	Discoveries.load_data(saved)
	await world.go_to_region("guardian_cave", "door")
	await _settle(world)
	check(world.region.region_id == "guardian_cave", "and into the Guardian's cave")
	world.queue_free()
	await get_tree().process_frame


## data/park/places.json matches the regions (run
## tools/discovery/list_places.tscn after adding or renaming a Place).
func _check_place_list() -> void:
	var lister := preload("res://tools/discovery/list_places.gd")
	var now: Array = await lister.collect(self)
	var keys := now.map(func(p: Dictionary) -> String: return p.key)
	var listed := Discoveries.places().map(func(p: Dictionary) -> String: return p.key)
	check(keys == listed, "the list of places to discover is up to date (%d listed, %d in the regions)" % [listed.size(), keys.size()])
	for key in ["ahwahnee_meadow/Yosemite Medical Clinic", "ahwahnee_meadow/Yosemite Valley School", "yosemite_village/Lower Yosemite Fall"]:
		check(key in listed, "%s is a place to discover" % key)


func _stop_named(region: Node, stop_name: String) -> ShuttleStop:
	for stop in region.find_children("*", "ShuttleStop", true, false):
		if stop.stop_name == stop_name:
			return stop
	return null


func _settle(world: Node) -> void:
	await get_tree().process_frame
	while world._busy:
		await get_tree().process_frame
