extends Node
## Hidden finds off the paths (Finds, data/park/finds.json): the list is sound
## (ids, areas, rewards, seasons), every find lies where the player can walk
## to it from the area's arrival and off the roads and trails, taking one
## hands over its reward once, it only shows in its season and hours, the
## Logbook's rumors only come from areas you've been to, it saves, and the
## two achievements count it.
## Run: godot --headless --path . res://tests/finds_test.tscn
## Exit code is the number of failed checks.

const WalkCheck := preload("res://scripts/story/find_walk.gd")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	NewGame.reset()
	_check_list()
	await _check_spots()
	await _check_taking()
	_check_gates()
	_check_rumors_and_saves()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _check_list() -> void:
	check(Finds.total() >= 20, "there are %d finds (20 or more)" % Finds.total())
	var ids := {}
	var regions := {}
	for find: Dictionary in Finds.all():
		var id := str(find.get("id", ""))
		check(id != "" and not ids.has(id), "%s: has an id of its own" % id)
		ids[id] = true
		regions[find.region] = int(regions.get(find.region, 0)) + 1
		check(ResourceLoader.exists("res://scenes/regions/%s.tscn" % find.region), "%s: lies in a region that exists (%s)" % [id, find.region])
		check(find.has("pos") and (find.pos as Array).size() == 2, "%s: has a spot" % id)
		for key in ["title", "text", "rumor"]:
			check(str(find.get(key, "")) != "", "%s: has a %s" % [id, key])
		var reward: Dictionary = find.get("reward", {})
		check(not reward.is_empty(), "%s: gives something" % id)
		for reward_id: String in reward:
			check(Gear.get_gear(reward_id) != null or ItemDB.get_item(reward_id) != null, "%s: its reward %s is an item or gear" % [id, reward_id])
			check(int(reward[reward_id]) >= 1, "%s: gives at least one %s" % [id, reward_id])
		for season: String in find.get("seasons", []):
			check(Finds.SEASONS.has(season), "%s: season %s is a season" % [id, season])
		check(Finds.icon_of(find) != null, "%s: has an icon to lie on the ground" % id)
	# Spread over the park, not piled into a few areas.
	check(regions.size() >= 15, "finds lie in %d areas (15 or more)" % regions.size())
	for region_id: String in regions:
		check(int(regions[region_id]) <= (6 if region_id == "hetch_hetchy" else 2), "%s: holds no more than two finds (six in the big Hetch Hetchy)" % region_id)
	# Gear is the rare, valuable kind: a few cams at most.
	var cams := 0
	for find: Dictionary in Finds.all():
		cams += int(find.reward.get("cam", 0))
	check(cams >= 1 and cams <= 3, "the finds hold %d cams (1 to 3)" % cams)
	var cobras := 0
	for find: Dictionary in Finds.all():
		cobras += int(find.reward.get("king_cobra", 0))
	check(cobras >= 1, "some King Cobra is hidden for climbers to find (%d cans)" % cobras)


## Every find can be walked up to from the area's arrival, and lies off the
## roads, trails and paths, with its spot in the area.
func _check_spots() -> void:
	var walker := WalkCheck.new()
	var by_region := {}
	for find: Dictionary in Finds.all():
		(by_region.get_or_add(find.region, []) as Array).append(find)
	for region_id: String in by_region:
		var region: Region = (load("res://scenes/regions/%s.tscn" % region_id) as PackedScene).instantiate()
		add_child(region)
		StoryContent.attach(region)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var start := WalkCheck.start_of(region)
		var walked := walker.walk(region, start.global_position)
		var ground := region.get_ground()
		var off := WalkCheck.path_distance(ground)
		for find: Dictionary in by_region[region_id]:
			var pos := Vector2(find.pos[0], find.pos[1])
			check(region.get_bounds().has_point(pos), "%s: lies inside %s" % [find.id, region_id])
			check(WalkCheck.reaches(walked, pos), "%s: can be walked to from %s's arrival, at %s" % [find.id, region_id, pos])
			var cell := ground.local_to_map(ground.to_local(pos))
			check(int(off.get(cell, 99)) >= 1, "%s: lies off the road and trail tiles" % find.id)
			var spot := region.entities.get_node_or_null("Find_" + str(find.id))
			check(spot is FindSpot and spot.position == pos, "%s: is laid out in the area" % find.id)
		remove_child(region)
		region.free()


## Taking a find hands over its reward once, and the spot goes.
func _check_taking() -> void:
	NewGame.reset()
	var cam := Finds.get_find("el_cap_booty_cam")
	check(not cam.is_empty(), "the El Capitan booty cam is a find")
	var cams := Gear.count("cam")
	check(Finds.take("el_cap_booty_cam"), "taking the booty cam works")
	check(Gear.count("cam") == cams + 1, "it adds a cam to your gear")
	check(not Finds.take("el_cap_booty_cam"), "and can't be taken twice")
	check(Gear.count("cam") == cams + 1, "so it's still one cam")
	var cobras := Inventory.count("king_cobra")
	GameClock.season = GameClock.Season.SUMMER
	check(Finds.take("camp4_buried_cobra"), "taking the Camp 4 six-pack works")
	check(Inventory.count("king_cobra") == cobras + 3, "it adds three King Cobras to the backpack")
	check(Finds.reward_text(Finds.get_find("lyv_stuff_sack")) == "2 Trail Mix, 1 Chocolate Bar", "a find says what it gives: %s" % Finds.reward_text(Finds.get_find("lyv_stuff_sack")))
	check(Achievements.has("finders_keepers"), "the first find earns Finders Keepers")
	check(not Achievements.has("every_find"), "but not Off the Beaten Path yet")
	# A spot laid out for a find already taken doesn't come back.
	var region: Region = (load("res://scenes/regions/el_capitan_meadow.tscn") as PackedScene).instantiate()
	add_child(region)
	StoryContent.attach(region)
	check(region.entities.get_node_or_null("Find_el_cap_booty_cam") == null, "a find taken isn't laid out again")
	remove_child(region)
	region.free()
	# One laid out and then taken in front of you goes at once.
	NewGame.reset()
	region = (load("res://scenes/regions/el_capitan_meadow.tscn") as PackedScene).instantiate()
	add_child(region)
	StoryContent.attach(region)
	var spot := region.entities.get_node_or_null("Find_el_cap_booty_cam") as FindSpot
	check(spot != null and spot.get_prompt() == "Look: Booty Cam", "the spot's prompt names it")
	Finds.take("el_cap_booty_cam")
	await get_tree().create_timer(1.2).timeout
	check(not is_instance_valid(spot) or spot.is_queued_for_deletion(), "the spot goes once its find is taken")
	remove_child(region)
	region.free()
	for find: Dictionary in Finds.all():
		Finds.take(find.id)
	check(Finds.count() == Finds.total(), "every find can be taken")
	check(Achievements.has("every_find"), "all of them earns Off the Beaten Path")


## A find only lies there in its seasons and hours.
func _check_gates() -> void:
	var cobra := Finds.get_find("camp4_buried_cobra")
	GameClock.season = GameClock.Season.WINTER
	check(not Finds.is_out(cobra), "the Camp 4 six-pack isn't there in winter")
	GameClock.season = GameClock.Season.FALL
	check(Finds.is_out(cobra), "but is in fall")
	var lamp := Finds.get_find("mirror_lake_headlamp")
	GameClock.minutes = 12 * 60
	check(not Finds.is_out(lamp), "the lost headlamp doesn't show at noon")
	GameClock.minutes = 22 * 60
	check(Finds.is_out(lamp), "it shines at 10 at night")
	GameClock.minutes = 26 * 60
	check(Finds.is_out(lamp), "and at 2 in the morning")
	GameClock.minutes = 8 * 60
	var cam := Finds.get_find("el_cap_booty_cam")
	for season in 4:
		GameClock.season = season
		check(Finds.is_out(cam), "an ungated find is there in season %d" % season)
	# Every gated find can be had every year: some season, some hour.
	for find: Dictionary in Finds.all():
		var seasons: Array = find.get("seasons", [])
		check(seasons.is_empty() or seasons.size() < 4, "%s: its seasons gate something, or it has none" % find.id)
		var hours: Array = find.get("hours", [])
		check(hours.is_empty() or hours.size() == 2, "%s: its hours are a from and a to" % find.id)


## Rumors come only from areas you've walked into, and finds save.
func _check_rumors_and_saves() -> void:
	NewGame.reset()
	check(Finds.rumors().is_empty(), "no rumors before you've been anywhere")
	Discoveries.found[Discoveries.key_for("el_capitan_meadow", "El Capitan Meadow")] = true
	var rumors := Finds.rumors()
	check(rumors.size() == 1 and rumors[0].id == "el_cap_booty_cam", "walking into El Capitan Meadow brings its find's rumor")
	Finds.take("el_cap_booty_cam")
	check(Finds.rumors().is_empty(), "a find's rumor stops once it's found")
	for find: Dictionary in Finds.all():
		Discoveries.found[Discoveries.key_for(find.region, Finds._region_name(find.region))] = true
	check(Finds.rumors().size() == Finds.RUMORS, "only %d rumors at a time" % Finds.RUMORS)
	var saved := Finds.save_data()
	Finds.start_new_game()
	check(Finds.count() == 0, "a new game has no finds")
	Finds.load_data(JSON.parse_string(JSON.stringify(saved)))
	check(Finds.is_found("el_cap_booty_cam") and Finds.count() == 1, "finds come back from a save")
