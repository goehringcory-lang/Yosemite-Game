extends Node
## Checks the people who walk between the Valley's areas (Travelers): every
## walk of every plan is measured in data/park/walks.json, each day reads
## right (in time order, across the areas between, there before they go in,
## a rest day in the rain), and in the world they turn up where the clock
## says, walk the road out of an area and over the seam into the next with
## no fade, say where they're going when you talk to them, stand where they
## should at a stop, and go in for the night.
## Run: godot --headless --path . res://tests/travelers_test.tscn
## Exit code is the number of failed checks.

const LEAD := "traveler_climber_lead"
const SECOND := "traveler_climber_second"

var failures := 0
## What the dialogue box has shown, as it tells whoever is speaking (on_line).
var shown: Array[String] = []


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


## The dialogue box tells "talkers" each line it shows.
func on_line(_speaker: String, text: String, _mood: String) -> void:
	shown.append(text)


func _ready() -> void:
	add_to_group("talkers")
	SaveManager.save_path = "user://travelers_test_save.json"
	SaveManager.delete_save()
	test_data()
	test_days()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true
	Engine.time_scale = 4.0
	await test_world(world)
	Engine.time_scale = 1.0
	world.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()
	print("OK: %d failure(s)" % failures if failures == 0 else "FAILED: %d failure(s)" % failures)
	get_tree().quit(failures)


## Everyone has a look, a face and things to say, and every stop and every
## walk of every plan was measured on the maps.
func test_data() -> void:
	var links: Dictionary = Travelers.walks().get("links", {})
	check(Travelers.PLANS.size() >= 5, "there are people who travel (%d)" % Travelers.PLANS.size())
	var missing := []
	var long_lines := []
	for id: String in Travelers.PLANS:
		var character: CharacterData = load(Travelers.CHARACTER_DIR % id)
		check(character != null and character.visitor and character.sprite_sheet != null and character.idle_lines.size() >= 2
				and ResourceLoader.exists("res://assets/sprites/portraits/%s.png" % id),
				"%s is a visitor with art, a face and things to say" % id)
		check(QuestLog.get_character(id) == null, "%s isn't in the Register's cast" % id)
		var plan: Dictionary = Travelers.PLANS[id]
		var stops: Array = plan.stops
		for i in stops.size():
			var stop: Dictionary = stops[i]
			if Travelers.spot_point(stop.region, Travelers.point_of(id, stop)) == Vector2.INF:
				missing.append("%s stop %s" % [id, Travelers.point_of(id, stop)])
			for text: String in stop.get("lines", []) + stop.get("going", []):
				if DialogueBox.pages(text).size() > 1:
					long_lines.append(text)
			if i == 0:
				continue
			for walk: Dictionary in Travelers.walk_segments(id, stops[i - 1], stop):
				var way := Travelers.route(walk.region, walk.a, walk.b)
				if way.size() < 2:
					missing.append("%s %s -> %s" % [walk.region, walk.a, walk.b])
		for text: String in plan.get("rest_lines", []):
			if DialogueBox.pages(text).size() > 1:
				long_lines.append(text)
	check(missing.is_empty(), "every stop and walk is measured (run tools/travelers/measure_walks.tscn) %s" % [missing])
	check(long_lines.is_empty(), "every line fits on one page %s" % [long_lines])
	check(Travelers.region_path("yosemite_village", "el_capitan_meadow") == PackedStringArray(["yosemite_village", "leidig_meadow", "el_capitan_meadow"]),
			"from the Village to El Capitan Meadow is by Northside Drive, through Leidig Meadow")


## Each day: in time order with no gaps, across the areas between stops,
## every stop reached before they go in; a rest day in the rain; staying in
## out of season.
func test_days() -> void:
	for id: String in Travelers.PLANS:
		var plan: Dictionary = Travelers.PLANS[id]
		var day := Travelers.day_of(id, GameClock.Season.SUMMER, false)
		var gaps := []
		for i in range(1, day.size()):
			if absf(day[i].from - day[i - 1].to) > 0.01 or day[i].to < day[i].from or day[i].n != i:
				gaps.append(i)
		check(not day.is_empty() and gaps.is_empty(), "%s's summer day runs on with no gaps %s" % [id, gaps])
		var stops_reached := day.filter(func(s: Dictionary) -> bool: return s.kind == "stop")
		check(stops_reached.size() == plan.stops.size(), "%s reaches every stop" % id)
		var home_at := float(Travelers._clock(plan.home_at))
		check(day[-1].to == home_at and day[-1].from < home_at, "%s is at their last stop before going in at %s" % [id, plan.home_at])
		# the walks go area by area along the way
		var crossings := true
		for i in range(1, plan.stops.size()):
			var walks := day.filter(func(s: Dictionary) -> bool: return s.kind == "walk" and s.stop == i)
			var path := Travelers.region_path(plan.stops[i - 1].region, plan.stops[i].region)
			if walks.size() != path.size():
				crossings = false
			for j in walks.size():
				if j < path.size() and walks[j].region != path[j]:
					crossings = false
		check(crossings, "%s walks through each area on the way, in order" % id)
		check(Travelers.segment_at(day, day[0].from - 1.0).is_empty() and Travelers.segment_at(day, home_at + 1.0).is_empty(),
				"%s is in before %s and after %s" % [id, _hm(day[0].from), plan.home_at])
	var wet := Travelers.day_of(LEAD, GameClock.Season.SPRING, true)
	check(wet.size() == 1 and wet[0].get("rest", false) and wet[0].spot == "camp_4",
			"in the rain the climbers rest at Camp 4 all day")
	check(Travelers.day_of("traveler_day_hiker", GameClock.Season.WINTER, false).is_empty(), "the hiker isn't here in winter")
	check(not Travelers.day_of("traveler_ranger", GameClock.Season.WINTER, true).is_empty(), "the ranger walks the rounds in the snow too")
	var walk: Dictionary = Travelers.day_of(LEAD, GameClock.Season.SUMMER, false)[1]
	check(is_equal_approx(Travelers.progress(walk, (walk.from + walk.to) / 2.0), 0.5), "half way through a walk's time is half way along it")


func test_world(world: Node) -> void:
	var travelers: Travelers = world.get_children().filter(func(n: Node) -> bool: return n is Travelers)[0]
	_set_date(GameClock.Season.SUMMER, 3)
	var day := Travelers.today(LEAD)
	var out: Dictionary = day[1]
	check(out.kind == "walk" and out.region == "yosemite_village" and out.b == "exit:NorthsideWest",
			"on a dry summer morning the climbers walk out of Camp 4 toward Northside Drive")

	# Met on the way: they're where the clock says, walking.
	await _go(world, "yosemite_village", "camp_4", lerpf(out.from, out.to, 0.5))
	await _frames(20)
	var lead := _walker(travelers, LEAD)
	check(lead != null and lead.region_id() == "yosemite_village" and lead.visible, "half way to the road, the lead climber is out in the Village")
	if lead == null:
		return
	var way := Travelers.route(out.region, out.a, out.b)
	var expect: Vector2 = Travelers.point_along(way, 0.5 * Travelers.length_of(way))[0]
	check(world.region.to_local(lead.global_position).distance_to(expect) < 24.0,
			"and stands half way along the measured way (%s, %s)" % [world.region.to_local(lead.global_position), expect])
	var before := lead.global_position
	_set_time(lerpf(out.from, out.to, 0.6))
	await _frames(30)
	check(lead.global_position.distance_to(before) > 40.0, "as the clock goes on, they walk on")

	# Talking: where they're going.
	shown.clear()
	await _talk(lead, world.player)
	check(shown.size() == 1 and shown[0] in Travelers.PLANS[LEAD].stops[1].going, "talked to on the way, they say where they're going (%s)" % [shown])

	# Over the seam into Leidig Meadow, the same people, no fade.
	await _go(world, "yosemite_village", "west_road", out.to - 1.0)
	await _frames(10)
	check(world.seam != null and world.seam.neighbor.region_id == "leidig_meadow", "by Northside Drive, Leidig Meadow is laid beside the Village")
	_set_time(out.to - 1.0)
	await _frames(60)
	lead = _walker(travelers, LEAD)
	check(lead != null and lead.region_id() == "yosemite_village", "a minute from the edge, the lead climber is still in the Village")
	if lead == null:
		return
	_set_time(out.to + 2.0)
	await _until(func() -> bool: return lead.region_id() == "leidig_meadow", 6.0)
	check(is_instance_valid(lead) and lead.region_id() == "leidig_meadow" and travelers.walkers().has(lead),
			"they walk off the Village's edge and on into Leidig Meadow, the same walker")
	check(is_instance_valid(lead) and lead.modulate.a > 0.99, "with no fade")
	if is_instance_valid(lead):
		var leidig: Region = world.seam.neighbor
		var landing := Travelers.route("leidig_meadow", "east", "exit:ToElCapitan")[0]
		check(leidig.to_local(lead.global_position).distance_to(landing) < 160.0, "coming in at Leidig Meadow's east end")

	# Not shown: nobody walks where you can't see.
	await _go(world, "yosemite_village", "arrival", day[2].from + 10.0)
	await _frames(10)
	check(_walker(travelers, LEAD) == null, "while they cross Leidig Meadow, they're not in the Village")

	# At their stop: at El Cap, at the foot of the Nose, looking up.
	var nose: Dictionary = day.filter(func(s: Dictionary) -> bool: return s.kind == "stop" and s.spot == "the_nose")[0]
	await _go(world, "el_capitan_meadow", "arrival", nose.from + 60.0)
	await _frames(30)
	lead = _walker(travelers, LEAD)
	var second := _walker(travelers, SECOND)
	check(lead != null and second != null, "mid-morning, both climbers are at El Capitan")
	if lead and second:
		var stand := Travelers.spot_point("el_capitan_meadow", Travelers.point_of(LEAD, Travelers.PLANS[LEAD].stops[1]))
		check(world.region.to_local(lead.global_position).distance_to(stand) < 4.0, "standing by the foot of the Nose")
		check(lead.global_position.distance_to(second.global_position) > 48.0, "apart from each other")
		var start: Node2D = world.region.find_child("TheNose", true, false)
		check(start and lead.global_position.distance_to(start.global_position) > 48.0, "and out of the way of the climb's start")
		check(lead.facing == Vector2i.UP, "looking up at the wall")
		shown.clear()
		await _talk(lead, world.player)
		check(shown.size() == 1 and shown[0] in Travelers.PLANS[LEAD].stops[1].lines, "and talk about the climb (%s)" % [shown])

	# A rest day in the rain: at Camp 4 all day.
	var wet_day := _wet_day()
	check(wet_day > 0, "there's a rainy spring day to try")
	_set_date(GameClock.Season.SPRING, wet_day)
	await _go(world, "yosemite_village", "camp_4", 12 * 60)
	await _frames(30)
	lead = _walker(travelers, LEAD)
	check(lead != null and not lead.segment.is_empty() and lead.segment.get("rest", false), "in the rain the lead climber is resting at Camp 4")
	if lead:
		shown.clear()
		await _talk(lead, world.player)
		check(shown.size() == 1 and shown[0] in Travelers.PLANS[LEAD].rest_lines, "and says so (%s)" % [shown])
		# Night: they go in.
		_set_time(22 * 60)
		await _frames(90)
		check(not is_instance_valid(lead) or lead.is_queued_for_deletion() or _walker(travelers, LEAD) == null,
				"at night they go in")

	# Indoors there are no travelers.
	_set_date(GameClock.Season.SUMMER, 3)
	await _go(world, "welcome_center", "door", 10 * 60)
	await _frames(10)
	check(travelers.walkers().is_empty(), "indoors there's nobody on the road")


## Goes to [param id] at [param spawn], with the clock stopped at
## [param minutes] (going through a door starts it again).
func _go(world: Node, id: String, spawn: String, minutes: float) -> void:
	_set_time(minutes)
	await world.go_to_region(id, spawn)
	GameClock.paused = true
	_set_time(minutes)


func _set_date(season: int, day: int) -> void:
	GameClock.season = season
	GameClock.day = day
	Travelers.forget()


func _set_time(minutes: float) -> void:
	GameClock.minutes = floori(minutes)
	GameClock._elapsed = (minutes - floorf(minutes)) / GameClock.MINUTES_PER_TICK * GameClock.seconds_per_tick


## A spring day of this year with rain, or 0.
func _wet_day() -> int:
	for d in range(1, GameClock.DAYS_PER_SEASON + 1):
		if Weather.on_day(GameClock.year, GameClock.Season.SPRING, d).rain > 0.0:
			return d
	return 0


func _walker(travelers: Travelers, id: String) -> Traveler:
	for node: Traveler in travelers.walkers():
		if is_instance_valid(node) and node.plan_id == id and not node.is_queued_for_deletion():
			return node
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _until(cond: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end and not cond.call():
		await get_tree().physics_frame


func _find_box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


func _talk(npc: NPC, player: Player) -> void:
	npc.interact(player)
	for i in 400:
		await get_tree().process_frame
		var box := _find_box()
		if box == null:
			if not npc._talking:
				return
			continue
		box.press()


static func _hm(minutes: float) -> String:
	return "%d:%02d" % [int(minutes) / 60, int(minutes) % 60]
