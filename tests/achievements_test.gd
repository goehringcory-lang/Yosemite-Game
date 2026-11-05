extends Node
## Headless test of achievements and the collection log: every achievement
## and summit is well formed, sends, summits and fish are recorded, each kind
## of achievement unlocks (with a HUD message), the Logbook tab shows it all,
## and it all saves, loads, and catches up on a save from before the logbook.
## Run: godot --headless --path . res://tests/achievements_test.tscn
## Exit code is the number of failed checks.

const SWAN := preload("res://data/routes/swan_slab.tres")
const FIREFALL := preload("res://data/routes/firefall_slab.tres")
const NOSE := preload("res://data/routes/the_nose.tres")
const ASTROMAN := preload("res://data/routes/astroman.tres")

var failures := 0
var _signalled: Array[String] = []


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://achievements_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame
	Achievements.unlocked.connect(func(achievement: Dictionary) -> void: _signalled.append(achievement.id))

	test_definitions()
	test_fresh_game()
	test_sends()
	test_summits()
	test_fish()
	test_wildlife_and_valley_life()
	await test_toast(world)
	await test_logbook_tab(world)
	test_save_and_load()
	test_old_save_catches_up()

	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _state(route: RouteData, falls: int, minutes: int) -> ClimbState:
	var state := ClimbState.new(route, 8)
	state.falls = falls
	state.minutes = minutes
	return state


func test_definitions() -> void:
	var ids := {}
	var route_ids := {}
	for route in Guidebook.routes():
		route_ids[route.id] = true
	for achievement: Dictionary in Achievements.ACHIEVEMENTS:
		check(not ids.has(achievement.id), "%s has its own id" % achievement.id)
		ids[achievement.id] = true
		check(achievement.name != "" and achievement.how.ends_with(".") and achievement.group in Achievements.GROUPS,
			"%s has a name, a how and a group" % achievement.name)
		var unlock: Dictionary = achievement.unlock
		match str(unlock.type):
			"route":
				check(route_ids.has(unlock.id), "%s names a real route" % achievement.name)
			"summit":
				check(not Achievements.get_summit(unlock.id).is_empty(), "%s names a real summit" % achievement.name)
			"length":
				var fish := Fishing.get_fish(unlock.id)
				check(not fish.is_empty() and int(unlock.inches) <= int(fish.inches[1]), "%s asks for a fish that can be that big" % achievement.name)
		# A field log group may be empty until its animals have a group; the
		# rest all have something to count.
		if str(unlock.type) != "group":
			check(Achievements.progress(achievement)[1] > 0, "%s has something to count" % achievement.name)
	check(Achievements.total() >= 20, "at least 20 achievements (%d)" % Achievements.total())
	for summit: Dictionary in Achievements.SUMMITS:
		check(summit.has("route") and route_ids.has(summit.route) or summit.has("unlock"),
			"the %s summit is reached by a real route or an unlock" % summit.name)
		check(int(summit.feet) > 5000 and summit.note != "" and summit.how != "", "the %s summit has a height, a note and a how" % summit.name)


func test_fresh_game() -> void:
	check(Achievements.count() == 0 and Achievements.send_count() == 0 and Achievements.fish_count() == 0
		and Achievements.summit_count() == 0, "a new game starts with an empty logbook")


func test_sends() -> void:
	# A top-roped send: it's a tick, but not a clean lead.
	Achievements.sent(SWAN, _state(SWAN, 0, 90))
	QuestLog.record_climb(SWAN.id)
	check(Achievements.has("first_tick") and "first_tick" in _signalled, "the first tick earns First Tick")
	check(not Achievements.has("clean_send"), "a clean top-rope send isn't a Clean Send")
	check(int(Achievements.sends[SWAN.id].count) == 1 and int(Achievements.sends[SWAN.id].falls) == 0
		and int(Achievements.sends[SWAN.id].first_day) == Friendship.today(), "the send is logged with no falls and today's date")
	# A led send with falls, then a faster one without.
	Achievements.sent(FIREFALL, _state(FIREFALL, 2, 120))
	QuestLog.record_climb(FIREFALL.id)
	check(not Achievements.has("clean_send"), "a send with falls isn't clean")
	Achievements.sent(FIREFALL, _state(FIREFALL, 0, 80))
	var entry: Dictionary = Achievements.sends[FIREFALL.id]
	check(int(entry.count) == 2 and int(entry.falls) == 0 and int(entry.minutes) == 80, "repeats count, with the fewest falls and the fastest time")
	check(Achievements.has("clean_send"), "a clean lead earns Clean Send")
	check(Achievements.send_count() == 3, "three sends in all")
	# A wall with nights on it, at 5.13; and a 5.11.
	Achievements.sent(ASTROMAN, _state(ASTROMAN, 1, 600))
	QuestLog.record_climb(ASTROMAN.id)
	check(Achievements.has("into_the_tens") and not Achievements.has("five_twelve"), "a 5.11 earns Into the Tens, not 5.12")
	Achievements.sent(NOSE, _state(NOSE, 3, 3000))
	QuestLog.record_climb(NOSE.id)
	check(Achievements.has("five_twelve") and (NOSE.nights == 0 or Achievements.has("wall_night")), "the Nose earns the 5.12 one and a night on the wall")


func test_summits() -> void:
	check(Achievements.on_summit("el_capitan") and int(Achievements.summits.el_capitan.day) == Friendship.today(),
		"ticking the Nose puts El Capitan's summit in the log, dated")
	check(Achievements.has("first_summit") and Achievements.has("el_cap_summit"), "...and earns Top of the World and On Top of El Cap")
	check(not Achievements.on_summit("half_dome"), "Half Dome isn't climbed yet")
	Backcountry.mark(Backcountry.SUMMIT)
	check(Achievements.on_summit("half_dome") and Achievements.has("half_dome"), "standing on Half Dome logs it")
	check(not Achievements.has("both_ways"), "one way up isn't both ways")
	Backcountry.mark(Backcountry.CABLES)
	QuestLog.record_climb("snake_dike")
	check(Achievements.has("both_ways"), "the cables and Snake Dike earn Both Ways Up")
	for summit: Dictionary in Achievements.SUMMITS:
		if summit.has("route"):
			QuestLog.record_climb(summit.route)
	check(Achievements.summit_count() == Achievements.SUMMITS.size() and Achievements.has("every_summit"), "every summit earns Peak Bagger")


func test_fish() -> void:
	var rod: Fishing = Fishing.new()
	add_child(rod)
	var small := Fishing.get_fish("rainbow_trout").duplicate()
	small["length"] = 9
	rod.land(small)
	check(Achievements.fish_count() == 1 and Achievements.has("first_fish"), "landing a fish logs it and earns First Rise")
	check(int(Achievements.fish.rainbow_trout.biggest) == 9 and Achievements.fish.rainbow_trout.where != "", "...with its size and where")
	var big := Fishing.hooked(Fishing.get_fish("brown_trout"), "hole", 1.0)
	rod.land(big)
	check(big.get("trophy", false) and Achievements.has("trophy"), "a trophy earns Trophy (%s in)" % big.length)
	check(int(big.length) >= 22 and Achievements.has("two_footer"), "a big brown earns Two-Footer")
	var bigger := Fishing.get_fish("rainbow_trout").duplicate()
	bigger["length"] = 15
	rod.land(bigger)
	rod.land(small)
	check(int(Achievements.fish.rainbow_trout.count) == 3 and int(Achievements.fish.rainbow_trout.biggest) == 15, "the count goes up and the biggest stays the biggest")
	check(not Achievements.has("every_fish"), "not every fish yet")
	for one: Dictionary in Fishing.FISH:
		rod.land(one)
	check(Achievements.has("every_fish"), "one of each earns Every Fish in the Park")
	rod.free()


func test_wildlife_and_valley_life() -> void:
	for animal: Dictionary in FieldLog.ANIMALS:
		FieldLog.spot(animal.id, true)
	check(Achievements.has("animals_5") and Achievements.has("every_animal"), "the whole field log earns Field Notes and Naturalist")
	var birds := Achievements.progress(Achievements.get_achievement("every_bird"))
	check(Achievements.has("every_bird") == (birds[1] > 0), "Birder is earned once the field log has birds in it (%d)" % birds[1])
	Backcountry.mark(Backcountry.NIGHT_OUT)
	check(Achievements.has("night_out"), "a night out earns Under the Stars")
	Perks.record("slackline_medal_test", 3)
	Perks.changed.emit()
	check(Achievements.has("slackline_gold"), "a gold slackline medal earns Gold on the Line")
	Perks.note("rescues", 10)
	check(Achievements.has("rescues_10"), "10 rescues earn Yellow Shirt")


func test_toast(world: Node) -> void:
	var toasts := Achievements.pending_toasts()
	check(not toasts.is_empty() and toasts[0].begins_with("Achievement: ") and toasts[0].contains("logbook (L)"),
		"each new achievement queues a HUD message (%s)" % (toasts[0] if not toasts.is_empty() else "none"))
	var hud = world.get_node_or_null("HUD")
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud")
	Perks.pending_toasts().clear()
	var before := toasts.size()
	for i in 60:
		await get_tree().process_frame
		if Achievements.pending_toasts().size() < before:
			break
	check(Achievements.pending_toasts().size() < before, "the messages show one at a time on the HUD")
	Achievements.pending_toasts().clear()


func test_logbook_tab(world: Node) -> void:
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	check(InputMap.has_action("logbook") and InputMap.action_get_events("logbook").any(func(e: InputEvent) -> bool: return e is InputEventKey),
		"the Logbook has a key")
	var press := InputEventAction.new()
	press.action = "logbook"
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	var release := InputEventAction.new()
	release.action = "logbook"
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await get_tree().process_frame
	check(journal.is_open() and journal.tab() == Journal.Tab.LOGBOOK, "L opens the book on the Logbook")
	var texts := PackedStringArray()
	for child in journal._body.get_children():
		if child is Label:
			texts.append(child.text)
	var page := "\n".join(texts)
	check(page.contains("Achievements: %d of %d" % [Achievements.count(), Achievements.total()]), "the Logbook counts the achievements")
	check(page.contains("Summits: %d of %d" % [Achievements.summit_count(), Achievements.SUMMITS.size()]) and page.contains("El Capitan, 7,573 ft"),
		"...lists the summits with their heights")
	check(page.contains("Firefall Slab") and page.contains("sent 2 times") and page.contains("No falls, fastest: 1 h 20 min"),
		"...the climbs sent, with repeats and the best send")
	check(page.contains("Fish caught: %d" % Achievements.fish_count()) and page.contains("biggest 15 in"), "...and the fish caught")
	check(journal._footer.text.contains("[L/Esc] Close"), "its footer names its key (%s)" % journal._footer.text)
	journal.close()
	await get_tree().process_frame


func test_save_and_load() -> void:
	var saved := Achievements.save_data()
	var json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var earned := Achievements.count()
	var sends := Achievements.send_count()
	var fish := Achievements.fish_count()
	Achievements.start_new_game()
	check(Achievements.count() == 0, "a new game clears the logbook")
	Achievements.load_data(json)
	check(Achievements.count() == earned and Achievements.send_count() == sends and Achievements.fish_count() == fish
		and Achievements.summit_count() == Achievements.SUMMITS.size(), "the logbook saves and loads")
	Achievements.settle()
	check(Achievements.count() == earned and Achievements.pending_toasts().is_empty(), "settling a loaded game changes nothing and says nothing")


func test_old_save_catches_up() -> void:
	# A save from before the logbook: World loads it without calling
	# load_data, then settles.
	Achievements.settle()
	check(Achievements.sends.has(NOSE.id) and int(Achievements.sends[NOSE.id].first_day) == -1, "old ticks become sends of unknown date")
	check(Achievements.fish.has("brook_trout") and Achievements.on_summit("half_dome"), "the field log's fish and Half Dome come back")
	check(Achievements.has("every_summit") and Achievements.pending_toasts().is_empty(), "achievements already met are earned quietly")
	check(Achievements.day_text(-1) == "" and Achievements.day_text(1) == "Spring 1, year 1" and Achievements.day_text(113) == "Spring 1, year 2",
		"dates read as season and day")
