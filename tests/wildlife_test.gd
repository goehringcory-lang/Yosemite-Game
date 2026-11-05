extends Node
## Headless test of the park's wider wildlife: the squirrels and the new
## birds among the Critters, the peregrine falcons over the big walls
## (Falcons, and on a long climb), the great gray owls of the high meadows
## (Owls), the rare bobcat (Bobcats), the sprites they're drawn from
## (WildlifeSheet), and the Wildlife journal tab that shows the field log
## (FieldLog) a picture at a time.
## Run: godot --headless --path . res://tests/wildlife_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://wildlife_test_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true

	test_definitions()
	test_where_they_live()
	await test_squirrels(world)
	await test_falcons(world)
	await test_owls(world)
	await test_bobcats(world)
	await test_climb_falcon()
	test_journal(world)

	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _fair_weather() -> void:
	Weather.today()
	Weather._today = {"snow": 0.0, "rain": 0.0, "clouds": 0.3}


## Runs [param body] with the current region named [param id] (the odds go
## by the region's id), then puts the name back.
func _as_region(world: Node, id: String, body: Callable) -> void:
	var real: String = world.region.region_id
	world.region.region_id = id
	body.call()
	world.region.region_id = real


func test_definitions() -> void:
	for id: String in WildlifeSheet.ROWS:
		check(not FieldLog.get_animal(id).is_empty(), "%s on the wildlife sheet is in the field log" % id)
	var sheet := WildlifeSheet.sheet()
	check(sheet != null and sheet.get_height() == int(WildlifeSheet.CELL.y) * WildlifeSheet.ROWS.size()
		and sheet.get_width() == int(WildlifeSheet.CELL.x) * WildlifeSheet.COLUMNS, "the wildlife sheet has a row for each animal")
	for kind: String in Critters.SQUIRRELS:
		check(WildlifeSheet.has(kind) and FieldLog.get_animal(kind).group == "mammal", "the %s is painted and logged as a mammal" % kind)
	for id in ["peregrine_falcon", "great_gray_owl", "bobcat"]:
		check(FieldLog.get_animal(id).how == "seen", "%s is logged by seeing one" % id)
	for animal: Dictionary in FieldLog.ANIMALS:
		check(animal.group in FieldLog.GROUPS, "%s is in a group of the Wildlife journal" % animal.id)
		check(FieldLog.icon(animal.id) != null, "%s has a picture in the Wildlife journal" % animal.id)
	var sum := 0
	for group: String in FieldLog.GROUPS:
		sum += FieldLog.total_in(group)
	check(sum == FieldLog.total(), "the groups hold every animal")


func test_where_they_live() -> void:
	check(Critters.lives_in(Critters.SQUIRRELS.western_gray_squirrel, "yosemite_village"), "gray squirrels in the Valley")
	check(not Critters.lives_in(Critters.SQUIRRELS.western_gray_squirrel, "tuolumne_meadows"), "...not up in Tuolumne")
	check(Critters.lives_in(Critters.SQUIRRELS.golden_mantled_ground_squirrel, "tuolumne_meadows")
		and not Critters.lives_in(Critters.SQUIRRELS.golden_mantled_ground_squirrel, "curry_village"), "golden-mantled ground squirrels only up high")
	check(Critters.lives_in(Critters.SQUIRRELS.douglas_squirrel, "wawona") and Critters.lives_in(Critters.SQUIRRELS.douglas_squirrel, "crane_flat")
		and not Critters.lives_in(Critters.SQUIRRELS.douglas_squirrel, "el_capitan_meadow"), "chickarees in the conifers up high and at Wawona")
	check(Critters.lives_in(Critters.SQUIRRELS.california_ground_squirrel, "glacier_point"), "ground squirrels beg at Glacier Point too")
	check(not GameClock.Season.WINTER in Critters.SQUIRRELS.california_ground_squirrel.seasons
		and not GameClock.Season.WINTER in Critters.SQUIRRELS.golden_mantled_ground_squirrel.seasons, "the ground squirrels sleep through the winter")
	check(Critters.lives_in(Critters.BIRDS.acorn_woodpecker, "ahwahnee_meadow") and not Critters.lives_in(Critters.BIRDS.acorn_woodpecker, "tuolumne_meadows"),
		"acorn woodpeckers down among the oaks")
	check(Critters.lives_in(Critters.BIRDS.clarks_nutcracker, "glacier_point") and not Critters.lives_in(Critters.BIRDS.clarks_nutcracker, "curry_village"),
		"nutcrackers up in the high country")
	check(Critters.lives_in(Critters.BIRDS.robin, "tuolumne_meadows") and Critters.lives_in(Critters.BIRDS.robin, "curry_village"), "robins anywhere")


func test_squirrels(world: Node) -> void:
	FieldLog.start_new_game()
	_fair_weather()
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 10 * 60
	var critters: Critters = world.find_children("*", "Critters", true, false)[0]
	var player: Player = world.player
	var squirrel := critters.add_squirrel("western_gray_squirrel", player.global_position + Vector2(Critters.SPOT_DISTANCE + 60.0, 0))
	await get_tree().process_frame
	check(not FieldLog.has("western_gray_squirrel"), "a squirrel far off isn't logged")
	check(squirrel.state == "sit" or squirrel.state == "run", "it sits up or scampers about while you keep away")
	squirrel.pos = player.global_position + Vector2(Critters.SPOT_DISTANCE - 20.0, 0)
	squirrel.state = "sit"
	await get_tree().process_frame
	check(FieldLog.has("western_gray_squirrel"), "walking up close logs it")
	check(world.hud.message_label.text.begins_with("Spotted: Western Gray Squirrel") and "(N)" in world.hud.message_label.text,
		"...and says it's in the Wildlife journal (%s)" % world.hud.message_label.text)
	squirrel.pos = player.global_position + Vector2(Critters.SQUIRREL_FLEE - 20.0, 0)
	squirrel.state = "sit"
	critters._process(0.016)
	check(squirrel.state == "flee" and squirrel.vel.x > 0.0, "too close, and it dashes off away from you")
	var x: float = squirrel.pos.x
	critters._process(0.1)
	check(squirrel.pos.x > x + 10.0, "...fast")
	for i in 60:
		critters._process(0.1)
	check(not squirrel in critters._squirrels, "...and is gone off the edge of the view")
	critters._squirrels.clear()


func test_falcons(world: Node) -> void:
	var falcons: Falcons = world.find_children("*", "Falcons", true, false)[0]
	_fair_weather()
	GameClock.season = GameClock.Season.SPRING
	GameClock.minutes = 11 * 60
	var spring := 0.0
	_as_region(world, "el_capitan_meadow", func() -> void:
		spring = falcons.chance()
		check(falcons.active() and spring > 0.0, "peregrines hunt over El Capitan Meadow by day")
		GameClock.season = GameClock.Season.WINTER
		check(falcons.chance() < spring, "...most in spring, when they're feeding young")
		GameClock.season = GameClock.Season.SPRING
		GameClock.minutes = 21 * 60
		check(not falcons.active(), "...and not after dark")
		GameClock.minutes = 11 * 60)
	_as_region(world, "tuolumne_meadows", func() -> void:
		check(falcons.chance() == 0.0, "none over Tuolumne's meadows, away from the big walls"))

	FieldLog.seen.erase("peregrine_falcon")
	_as_region(world, "el_capitan_meadow", func() -> void:
		var falcon := falcons.send_one()
		check(falcons.falcons().size() == 1 and falcon.state == "soar" and falcon.height > 100.0, "one comes in soaring high")
		# move it into the view and let it circle
		var view := falcons._view()
		falcon.pos = view.get_center() + Vector2(-120, 160)
		falcon.time = 0.5
		for i in 20:
			falcons._process(0.05)
		check(falcon.state == "stoop" and not falcons._prey.is_empty(), "then folds its wings and stoops on a bird below")
		check(FieldLog.has("peregrine_falcon"), "...and you've had a good look at it")
		for i in 60:
			falcons._process(0.02)
			if falcon.state != "stoop":
				break
		check(falcon.state == "climb" and falcon.height < Falcons.SOAR_HEIGHT * 0.5 and not falcons._puffs.is_empty(), "the strike leaves a puff of feathers, and it climbs away")
		for i in 400:
			falcons._process(0.05)
		check(falcons.falcons().is_empty() and falcons._cooldown > 0.0, "then it's gone, and the next waits a while"))
	falcons._cooldown = 0.0
	await get_tree().process_frame


func test_owls(world: Node) -> void:
	var owls: Owls = world.find_children("*", "Owls", true, false)[0]
	var player: Player = world.player
	_fair_weather()
	GameClock.season = GameClock.Season.FALL
	GameClock.minutes = 18 * 60
	var dusk := 0.0
	_as_region(world, "crane_flat", func() -> void:
		dusk = owls.chance()
		check(dusk > 0.0, "great gray owls hunt Crane Flat's meadow at dusk")
		GameClock.minutes = 12 * 60
		check(owls.chance() < dusk * 0.5, "...seldom at midday")
		GameClock.minutes = 23 * 60
		check(owls.chance() == 0.0, "...and we leave them be at night")
		GameClock.minutes = 18 * 60)
	_as_region(world, "wawona", func() -> void:
		check(owls.chance() > 0.0, "and at Wawona"))
	_as_region(world, "yosemite_village", func() -> void:
		check(owls.chance() == 0.0, "not in the Valley"))

	FieldLog.seen.erase("great_gray_owl")
	var from := player.global_position + Vector2(owls.spot_distance + 60.0, 0)
	var owl := owls.add_group(from, from + Vector2(500, 0))
	check(owl is GreatGrayOwl and (owl as GreatGrayOwl).flying(), "one comes gliding in")
	owls._process(0.016)
	check(not FieldLog.has("great_gray_owl"), "far off, it's not logged yet")
	owl.global_position = player.global_position + Vector2(owls.notice_distance + 40.0, 0)
	owls._process(0.016)
	check(FieldLog.has("great_gray_owl"), "in sight, it's logged")
	owl.state = "forage"
	owl.timer = 2.0
	owls._process(0.016)
	check(not (owl as GreatGrayOwl).flying(), "it drops onto a vole and sits in the grass")
	owl.global_position = player.global_position + Vector2(owls.notice_distance - 20.0, 0)
	owls._process(0.016)
	check(owl.state == "watch" and world.hud.message_label.text == Owls.NOTICE_MESSAGE, "walk up and it turns its face to you")
	# an owl flies: a wall of trees doesn't stop it
	var before := owl.global_position
	owls._walk(owl, 1.0, Vector2.RIGHT)
	check(owl.global_position.x > before.x + owls.leave_speed * 0.5 or owl.global_position.x > before.x, "it flies over anything in its way")
	owls._last_region = null
	owls._process(0.016)
	owls._cooldown = 0.0
	await get_tree().process_frame


func test_bobcats(world: Node) -> void:
	var bobcats: Bobcats = world.find_children("*", "Bobcats", true, false)[0]
	var deer: Deer = world.find_children("*", "Deer", true, false)[0]
	var player: Player = world.player
	_fair_weather()
	GameClock.season = GameClock.Season.SUMMER
	GameClock.minutes = 7 * 60
	_as_region(world, "leidig_meadow", func() -> void:
		var meadow := bobcats.chance()
		check(meadow > 0.0, "a bobcat may cross a Valley meadow at dawn")
		check(meadow < deer.chance() * 0.5, "...but it's rare, much rarer than a deer")
		GameClock.season = GameClock.Season.WINTER
		check(bobcats.chance() > meadow, "...a little less rare in winter, hunting voles in the snow")
		GameClock.season = GameClock.Season.SUMMER
		GameClock.minutes = 13 * 60
		check(bobcats.chance() < meadow, "...and seldom at midday")
		GameClock.minutes = 7 * 60)
	_as_region(world, "curry_village", func() -> void:
		check(bobcats.chance() > 0.0, "one may slip through anywhere outdoors"))

	FieldLog.seen.erase("bobcat")
	var at := player.global_position + Vector2(bobcats.notice_distance + 40.0, 0)
	var cat := bobcats.add_group(at, at + Vector2(600, 0))
	check(cat is Bobcat, "a bobcat on its own")
	bobcats._process(0.016)
	check(FieldLog.has("bobcat"), "in sight, it's logged")
	cat.global_position = player.global_position + Vector2(bobcats.notice_distance - 30.0, 0)
	bobcats._process(0.016)
	check(cat.state == "watch" and cat.facing == -1 and world.hud.message_label.text == Bobcats.NOTICE_MESSAGE, "close up, it freezes and stares at you")
	for i in 200:
		bobcats._process(0.016)
	check(cat.state == "leave", "then slips away")
	bobcats._last_region = null
	bobcats._process(0.016)
	bobcats._cooldown = 0.0
	await get_tree().process_frame


func test_climb_falcon() -> void:
	FieldLog.seen.erase("peregrine_falcon")
	var nose: RouteData = load("res://data/routes/the_nose.tres")
	var climb := ClimbMinigame.new()
	climb.setup(nose, 3)
	add_child(climb)
	await get_tree().process_frame
	climb._pal = {"night": false}
	climb.send_falcon()
	check(climb._falcon_t >= 0.0, "a peregrine stoops past the Nose")
	for i in 40:
		climb._update_falcon(0.05)
	check(FieldLog.has("peregrine_falcon") and "peregrine" in climb._toast_text, "seeing it from the wall logs it (%s)" % climb._toast_text)
	check(climb._falcon_t < 0.0, "...and it's gone below")
	climb.queue_free()
	var swan: RouteData = load("res://data/routes/swan_slab.tres")
	var low := ClimbMinigame.new()
	low.setup(swan, 3)
	add_child(low)
	await get_tree().process_frame
	low._pal = {"night": false}
	low.send_falcon()
	check(low._falcon_t < 0.0, "none on a short slab")
	low.queue_free()
	await get_tree().process_frame


func test_journal(world: Node) -> void:
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	check(InputMap.has_action("wildlife"), "the Wildlife journal has a key")
	FieldLog.start_new_game()
	FieldLog.spot("bobcat", true)
	journal.open(Journal.Tab.WILDLIFE)
	check(journal.tab() == Journal.Tab.WILDLIFE and journal._slots.size() == FieldLog.total() and journal._detail.visible,
		"Wildlife shows every animal as a slot, with the detail lines")
	var labels: Array[String] = []
	for node in journal._body.find_children("*", "Label", true, false):
		labels.append((node as Label).text)
	check(labels.has("Birds (0 of %d)" % FieldLog.total_in("bird")) and labels.has("Mammals (1 of %d)" % FieldLog.total_in("mammal")),
		"each group counts what you've found (%s)" % ", ".join(labels.slice(0, 4)))
	var cat_slot := -1
	for i in journal._slot_items.size():
		if journal._slot_items[i].name == "Bobcat":
			cat_slot = i
	check(cat_slot >= 0 and not journal._slot_items[cat_slot].get("dim", false), "the bobcat you saw is filled in")
	check(journal._slot_items.filter(func(item: Dictionary) -> bool: return item.get("dim", false)).size() == FieldLog.total() - 1,
		"the rest are shadows, waiting")
	var owl: Dictionary = journal._slot_items.filter(func(item: Dictionary) -> bool: return item.name.begins_with("Great Gray Owl"))[0]
	check(owl.description.begins_with("Look: ") and "Crane Flat" in owl.description, "a shadow says where to look")
	journal.close()
	journal.open(Journal.Tab.JOURNAL)
	var lines: Array[String] = []
	for node in journal._body.find_children("*", "Label", true, false):
		lines.append((node as Label).text)
	check(lines.has("Field log: 1 of %d animals" % FieldLog.total()) and lines.any(func(l: String) -> bool: return "Wildlife tab (N)" in l),
		"the Journal keeps the field log's count and points to the Wildlife tab")
	journal.close()
