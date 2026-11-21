extends Node
## Plays the Happenings around the park: every one stands somewhere real
## with a visitor's look, comes up on days that fit it, a few a day spread
## over the areas, and each kind (witness, give, find, ask) plays through
## from talking to its person, with the reward, the Logbook and saving.
## Run: godot --headless --path . res://tests/happenings_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const KINDS := ["witness", "give", "find", "ask"]

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://happenings_test_save.json"
	SaveManager.delete_save()
	var world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	Settings.tips = false
	for hub in ["glacier_point", "tuolumne_meadows", "wawona", "el_portal"]:
		Park.unlock_hub(hub)
	test_data()
	await test_on_the_map()
	test_days()
	await test_play(world, "happy_isles_fly_box")
	await test_play(world, "glacier_breakfast")
	await test_play(world, "el_cap_spotting")
	await test_play(world, "mirror_lake_reflection")
	test_hours_and_rescues()
	test_save()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_data() -> void:
	var ids := {}
	var bad := []
	for h: Dictionary in Happenings.HAPPENINGS:
		if ids.has(h.id):
			bad.append("%s twice" % h.id)
		ids[h.id] = true
		for key in ["title", "kind", "region", "near", "offset", "hours", "seasons", "who", "look", "rumor", "lines", "thanks", "reward"]:
			if not h.has(key):
				bad.append("%s: no %s" % [h.id, key])
		if not h.kind in KINDS:
			bad.append("%s: kind %s" % [h.id, h.kind])
		match h.kind:
			"witness":
				if not h.has("watch"):
					bad.append("%s: nothing to watch" % h.id)
			"give":
				if Happenings.wanted(h).is_empty() or not h.has("wants_text"):
					bad.append("%s: wants nothing" % h.id)
				for id in Happenings.wanted(h):
					if ItemDB.get_item(id) == null:
						bad.append("%s: wants unknown %s" % [h.id, id])
			"find":
				if not h.has("thing") or ItemDB.get_item(h.thing.get("icon", "")) == null:
					bad.append("%s: no thing to find" % h.id)
			"ask":
				if h.get("options", []).size() < 2 or not h.has("question") or not h.has("wrong"):
					bad.append("%s: no question" % h.id)
		if not ResourceLoader.exists(Happenings.VISITOR_DIR % h.look):
			bad.append("%s: no look %s" % [h.id, h.look])
		for item_id in h.reward:
			if ItemDB.get_item(item_id) == null or int(h.reward[item_id]) > 2:
				bad.append("%s: reward %s" % [h.id, item_id])
		if float(h.hours[1]) <= float(h.hours[0]) or float(h.hours[1]) > GameClock.PASS_OUT_HOUR:
			bad.append("%s: hours" % h.id)
		for text in h.lines + [h.thanks, h.rumor, h.get("watch", ""), h.get("wrong", "")]:
			if DialogueBox.pages(text).size() > 1:
				bad.append("%s: long line" % h.id)
	check(bad.is_empty(), "every happening is filled in, with small rewards of real items (%s)" % [bad])
	check(Happenings.total() >= 15, "%d happenings" % Happenings.total())
	var regions := {}
	for h: Dictionary in Happenings.HAPPENINGS:
		regions[h.region] = true
	check(regions.size() >= 12, "spread over %d areas" % regions.size())
	var kinds := {}
	for h: Dictionary in Happenings.HAPPENINGS:
		kinds[h.kind] = int(kinds.get(h.kind, 0)) + 1
	check(KINDS.all(func(k: String) -> bool: return int(kinds.get(k, 0)) >= 3), "at least three of each kind (%s)" % [kinds])
	var native := ["tenaya", "maggie_howard", "lucy_telles", "maria_lebrado", "carrie_bethel"]
	check(Happenings.HAPPENINGS.all(func(h: Dictionary) -> bool: return not h.look in native), "nobody from the Native cast")


## Each happening's person, and its lost thing, stand on open ground near
## their marker, and you can walk from one to the other.
func test_on_the_map() -> void:
	var missing := []
	var far := []
	for h: Dictionary in Happenings.HAPPENINGS:
		var path := "res://scenes/regions/%s.tscn" % h.region
		if not ResourceLoader.exists(path):
			missing.append(h.id)
			continue
		var holder := SubViewport.new()
		holder.world_2d = World2D.new()
		add_child(holder)
		var region: Region = (load(path) as PackedScene).instantiate()
		holder.add_child(region)
		StoryContent.attach(region)
		for i in 3:
			await get_tree().physics_frame
		var marker := region.get_spawn(h.near)
		var at := HappeningField.spot_in(region, h.near, h.offset)
		if marker == null or at == Vector2.INF:
			missing.append(h.id)
		elif at.distance_to(marker.global_position + h.offset) > 96.0:
			far.append("%s (%d px off)" % [h.id, at.distance_to(marker.global_position + h.offset)])
		if h.kind == "find" and at != Vector2.INF:
			var lost := HappeningField.spot_in(region, h.thing.near, h.thing.offset)
			var way := WalkGrid.of(region).route(at, lost) if lost != Vector2.INF else PackedVector2Array()
			if lost == Vector2.INF or (way.is_empty() and at.distance_to(lost) > 32.0) or at.distance_to(lost) < 120.0:
				far.append("%s: thing %d px off, way %d" % [h.id, at.distance_to(lost) if lost != Vector2.INF else -1, way.size()])
		holder.free()
	check(missing.is_empty(), "every happening's area and marker are real (%s)" % [missing])
	check(far.is_empty(), "everyone stands on open ground where they're meant to (%s)" % [far])


## Over two years, every happening comes up; a day has a few, one an area,
## and often two at the same hours; none on the first morning.
func test_days() -> void:
	var came := {}
	var counts := []
	var overlap_days := 0
	var bad := []
	for year in [1, 2]:
		for season in 4:
			for day in range(1, GameClock.DAYS_PER_SEASON + 1):
				var out := Happenings.roll(year, season, day)
				if out != Happenings.roll(year, season, day):
					bad.append("reroll %d:%d:%d" % [year, season, day])
				counts.append(out.size())
				var regions := {}
				var hs := []
				for id in out:
					var h := Happenings.get_happening(id)
					came[id] = true
					if regions.has(h.region):
						bad.append("two in %s" % h.region)
					regions[h.region] = true
					if not Happenings.fits_day(h, year, season, day):
						bad.append("%s on a day that doesn't fit" % id)
					hs.append(h)
				var overlaps := false
				for i in hs.size():
					for j in range(i + 1, hs.size()):
						if float(hs[i].hours[0]) < float(hs[j].hours[1]) and float(hs[j].hours[0]) < float(hs[i].hours[1]):
							overlaps = true
				if overlaps:
					overlap_days += 1
	check(bad.is_empty(), "the day's happenings are the same each roll, fit the day, one an area (%s)" % [bad.slice(0, 5)])
	var never := Happenings.HAPPENINGS.filter(func(h: Dictionary) -> bool: return not came.has(h.id)).map(func(h: Dictionary) -> String: return h.id)
	check(never.is_empty(), "every happening comes up in two years (never: %s)" % [never])
	check(Happenings.roll(1, 0, 1).is_empty(), "nothing on the very first morning")
	check(counts.max() <= Happenings.PER_DAY and counts.count(0) < counts.size() / 10, "up to %d a day, and hardly a day without (%d empty)" % [Happenings.PER_DAY, counts.count(0)])
	check(overlap_days > counts.size() / 2, "most days two go on at the same time, so you choose (%d of %d)" % [overlap_days, counts.size()])
	# a summer's Firefall night: the crowd at Curry Village is out
	var firefall := Happenings.roll(1, GameClock.Season.SUMMER, 10)
	check("firefall_crowd" in firefall, "the Firefall crowd is out on summer nights")


## A day [param id] fits, in year 1 after the first morning.
func _day_for(id: String) -> Vector2i:
	var h := Happenings.get_happening(id)
	for season in h.seasons:
		for day in range(2, GameClock.DAYS_PER_SEASON + 1):
			if Happenings.fits_day(h, 1, season, day):
				return Vector2i(season, day)
	return Vector2i(-1, -1)


func _figure(world: Node, id: String) -> HappeningFigure:
	for node in world.region.entities.get_children():
		if node is HappeningFigure and node.happening.id == id and not node.is_queued_for_deletion():
			return node
	return null


func _thing(world: Node, id: String) -> HappeningThing:
	for node in world.region.entities.get_children():
		if node is HappeningThing and node.happening.id == id and not node.is_queued_for_deletion():
			return node
	return null


func _find_box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


## Talks to [param node] until the box closes, picking the option whose
## text starts with [param pick] when asked (or the first).
func _talk(node: Node, player: Player, pick := "") -> void:
	node.interact(player)
	for i in 400:
		await get_tree().process_frame
		var box := _find_box()
		if box == null:
			if not is_instance_valid(node) or not ("_busy" in node and node._busy):
				break
			continue
		if not box._options.is_empty():
			box._cursor = 0
			for k in box._options.size():
				if pick != "" and box._options[k].begins_with(pick):
					box._cursor = k
		box.press()
	for i in 3:
		await get_tree().process_frame


## Plays [param id] through on a day it fits, from talking to its person.
func test_play(world: Node, id: String) -> void:
	var h := Happenings.get_happening(id)
	var date := _day_for(id)
	check(date.x >= 0, "%s: there's a day for it" % id)
	if date.x < 0:
		return
	Happenings.start_new_game()
	Inventory.items.clear()
	GameClock.year = 1
	GameClock.season = date.x
	GameClock.day = date.y
	GameClock.minutes = int(float(h.hours[0]) * 60.0) + 30
	Happenings.day_of = Friendship.today()
	Happenings.out_today = PackedStringArray([id])
	await world.go_to_region(h.region, "arrival")
	GameClock.paused = true
	GameClock.minutes = int(float(h.hours[0]) * 60.0) + 30
	for i in 4:
		await get_tree().process_frame
	var figure := _figure(world, id)
	check(figure != null, "%s: %s is standing in %s" % [id, h.who, h.region])
	if figure == null:
		return
	var player: Player = world.player
	player.global_position = figure.global_position + Vector2(0, 24)
	check(figure.get_prompt().contains(h.who), "%s: \"%s\"" % [id, figure.get_prompt()])
	var reward_id: String = h.reward.keys()[0]
	match h.kind:
		"witness":
			var before := GameClock.minutes
			await _talk(figure, player, "Stay")
			check(GameClock.minutes >= before + int(h.minutes), "%s: staying a while takes time" % id)
		"give":
			await _talk(figure, player)
			check(not Happenings.is_done(id), "%s: with nothing to give, nothing happens" % id)
			var food: String = Happenings.wanted(h)[0]
			Inventory.add(food, 1)
			await _talk(figure, player, "Give")
			check(Inventory.count(food) == 0, "%s: you hand over the %s" % [id, food])
		"find":
			await _talk(figure, player)
			check(Happenings.has_asked(id) and not Happenings.is_done(id), "%s: they tell you what's lost" % id)
			for i in 3:
				await get_tree().process_frame
			var thing := _thing(world, id)
			check(thing != null, "%s: %s is lying nearby" % [id, h.thing.name])
			if thing == null:
				return
			player.global_position = thing.global_position + Vector2(0, 20)
			await _talk(thing, player)
			check(Happenings.has_found(id) and _thing(world, id) == null, "%s: you pick it up" % id)
			player.global_position = figure.global_position + Vector2(0, 24)
			await _talk(figure, player)
		"ask":
			await _talk(figure, player, "On the far end")
			check(not Happenings.is_done(id), "%s: a wrong answer isn't the end" % id)
			await _talk(figure, player, str(h.options[0]).left(12))
	check(Happenings.is_done(id) and Happenings.has_seen(id), "%s: done, and in the Logbook" % id)
	check(Inventory.count(reward_id) >= int(h.reward[reward_id]), "%s: you're given %s" % [id, reward_id])
	var count := Inventory.count(reward_id)
	await _talk(figure, player)
	check(Inventory.count(reward_id) == count, "%s: talking again gives nothing more" % id)


func test_hours_and_rescues() -> void:
	var h := Happenings.get_happening("happy_isles_fly_box")
	Happenings.day_of = Friendship.today()
	Happenings.out_today = PackedStringArray([h.id])
	GameClock.minutes = int(float(h.hours[1]) * 60.0) + 10
	check(Happenings.here_now(h.region).is_empty(), "after its hours it's over")
	GameClock.minutes = int(float(h.hours[0]) * 60.0) + 10
	check(not Happenings.here_now(h.region).is_empty(), "in its hours it's on")
	Rescues.current = "happy_isles_cold"
	check(Happenings.here_now(h.region).is_empty(), "not while a rescue is on in the same area")
	Rescues.current = ""
	# after midnight is still tonight
	var moon := Happenings.get_happening("moonbow")
	check(Happenings.in_hours(moon, 24 * 60 + 30) and not Happenings.in_hours(moon, 20 * 60), "the moonbow is out past midnight, not before dark")
	check(Happenings.hours_text(moon) == "9 PM to 1:30 AM", "its hours read %s" % Happenings.hours_text(moon))


func test_save() -> void:
	var data := Happenings.save_data()
	Happenings.start_new_game()
	check(Happenings.count() == 0, "a new game has seen nothing")
	Happenings.load_data(JSON.parse_string(JSON.stringify(data)))
	check(Happenings.count() == 1 and Happenings.has_seen("mirror_lake_reflection") and Happenings.is_done("mirror_lake_reflection"), "what you've seen and done today is saved")
	Happenings.load_data({"seen": {"no_such": 1}, "day": Friendship.today(), "out": ["no_such"]})
	check(Happenings.count() == 0 and Happenings.out_today.is_empty(), "an old or odd save loads cleanly")
	Happenings.load_data({})
	check(Happenings.count() == 0, "and an empty one")
