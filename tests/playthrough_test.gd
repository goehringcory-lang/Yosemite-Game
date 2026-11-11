extends Node
## Plays the whole game's quest list from a new game, the way a player would
## meet it: walks the seasons, talks to everyone, and does whatever each
## quest's current step asks (carrying the items, pressing the plants,
## climbing the route with the gear the quests and shops have given by then).
## Every quest has to finish, in an order the requirements allow, and the
## save has to round-trip at every quest's end.
## Run: godot --headless --path . res://tests/playthrough_test.tscn
## Exit code is the number of failed checks.

const SHOP_DIR := "res://data/shops/"
## Abilities a quest step waits on that something in the world hands over
## (not another quest), with what does it, so the bot can stand in for it.
const WORLD_ABILITIES := {
	"guardian_found": "the mirror in the Guardian's cave",
	"first_rescue": "carrying the lost boy back to Jo (Rescues)",
	"slackline_gold": "a gold medal on a Camp 4 slackline",
	"night_out": "a night at the backcountry camp (Backcountry)",
	"half_dome_cables": "climbing the Half Dome cables (Backcountry)",
	"diving_board_light": "the Diving Board in the afternoon (Backcountry)",
	"muir_cloud_sea": "on top of Half Dome before ten after a night at Little Yosemite (Backcountry)",
	"first_photograph": "the first picture taken with Ansel's camera (Photos)",
}

var failures := 0
var shops: Array[ShopData] = []
## Quest ids in the order they finished.
var finished_order: Array[String] = []
var bought: Array[String] = []
## Problems already reported, so each is said once.
var _flagged: Dictionary = {}


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	_load_shops()
	_new_game()
	QuestLog.quest_completed.connect(func(q: QuestData) -> void: finished_order.append(q.id))
	_play()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _load_shops() -> void:
	for file in DirAccess.get_files_at(SHOP_DIR):
		if file.ends_with(".tres"):
			shops.append(load(SHOP_DIR + file))


func _new_game() -> void:
	for node in get_tree().get_nodes_in_group("persist"):
		if node.has_method("start_new_game"):
			node.start_new_game()
	Inventory.start_new_game()
	Gear.start_new_game()
	Granary.start_new_game()
	Recipes.start_new_game()
	QuestLog.start_new_game()
	Herbarium.start_new_game()
	Stewardship.start_new_game()
	Park.start_new_game()
	GameClock.paused = true
	GameClock.year = 1
	GameClock.season = GameClock.Season.SPRING
	GameClock.day = 3
	GameClock.minutes = 10 * 60


func _people() -> Array[String]:
	var ids: Array[String] = []
	for c: CharacterData in QuestLog.CHARACTERS + QuestLog.STAFF:
		ids.append(c.id)
	for shop in shops:
		if shop.talk_target != "" and not shop.talk_target in ids:
			ids.append(shop.talk_target)
	return ids


func _play() -> void:
	var people := _people()
	var idle_seasons := 0
	var seasons := 0
	while idle_seasons < 5 and seasons < 80:
		var before := QuestLog.completed.size()
		# a few rounds of talking in each season, at a couple of times of day
		for round in 12:
			var moved := false
			for hour in [10, 15, 21]:
				GameClock.minutes = hour * 60
				for id in people:
					moved = _work_on_steps() or moved
					var n_active := QuestLog.active.size()
					var n_done := QuestLog.completed.size()
					var steps := _step_signature()
					QuestLog.talk_to(id)
					moved = moved or n_active != QuestLog.active.size() or n_done != QuestLog.completed.size() or steps != _step_signature()
				_check_journal()
				if QuestLog.final_entry_pending():
					QuestLog.write_final_entry(0)
					moved = true
			if not moved:
				break
		if QuestLog.completed.size() == before:
			idle_seasons += 1
		else:
			idle_seasons = 0
		_check_save_round_trip()
		_next_season()
		seasons += 1
	print("Played %d seasons. Finished %d of %d quests:" % [seasons, QuestLog.completed.size(), QuestLog.QUESTS.size()])
	print("  " + ", ".join(finished_order))
	if not bought.is_empty():
		print("Gear from shops along the way: " + ", ".join(bought))
	for quest: QuestData in QuestLog.QUESTS:
		var why := ""
		if QuestLog.active.has(quest.id):
			why = "stuck on step %d: %s" % [QuestLog.active[quest.id], JSON.stringify(QuestLog.current_step(quest))]
		elif not QuestLog.is_completed(quest.id):
			var unmet := Array(quest.requires).filter(func(r: String) -> bool: return not QuestLog.is_completed(r))
			why = "never offered (waiting on %s)" % ", ".join(unmet) if not unmet.is_empty() else "never offered by %s" % quest.giver
		check(QuestLog.is_completed(quest.id), "%s (%s) finishes in a playthrough%s" % [quest.title, quest.id, "" if why == "" else ": " + why])


## The journal's lines must always read as words: no ids, no empty
## objectives, no unfilled format codes.
var _bad_lines: Dictionary = {}
func _check_journal() -> void:
	var lines: Array[String] = []
	for obj: Dictionary in [QuestLog.main_objective(), QuestLog.press_objective(), QuestLog.guardian_objective()]:
		if not obj.is_empty():
			lines.append("%s: %s" % [obj.quest.id, obj.objective])
	for line in QuestLog.objectives():
		lines.append(line)
	var id_like := RegEx.create_from_string("\\b[a-z]+_[a-z_]+\\b|%[sd]|\\(\\)|: $")
	for line in lines:
		var text := line.substr(line.find(":") + 1) if line.find(":") >= 0 else line
		if id_like.search(text) != null and not _bad_lines.has(line):
			_bad_lines[line] = true
			check(false, "the journal reads as words: %s" % line)


func _step_signature() -> String:
	return JSON.stringify(QuestLog.active)


func _next_season() -> void:
	GameClock.season = (GameClock.season + 1) % 4
	if GameClock.season == GameClock.Season.SPRING:
		GameClock.year += 1


## Does what each active quest's current step asks. Returns true if anything
## changed.
func _work_on_steps() -> bool:
	var did := false
	for quest: QuestData in QuestLog.QUESTS:
		if not QuestLog.active.has(quest.id):
			continue
		var step := QuestLog.current_step(quest)
		if QuestLog.is_step_done(step):
			continue
		did = _do_step(quest, step) or did
	return did


func _do_step(quest: QuestData, step: Dictionary) -> bool:
	match step.get("type", ""):
		"have":
			var item: String = step.item
			check(ItemDB.get_item(item) != null or FoodDB.is_food(item), "%s asks for an item that exists: %s" % [quest.id, item])
			Inventory.add(item, int(step.get("count", 1)) - Inventory.count(item))
		"have_food", "pay":
			Inventory.add("black_oak_acorn", int(step.energy) / maxi(1, FoodDB.energy("black_oak_acorn")) + 4)
		"chuckah":
			while Granary.chuckahs_built < int(step.get("count", 1)):
				Granary.build_chuckah()
		"stored":
			while Granary.capacity < int(step.count):
				Granary.build_chuckah()
			Granary.acorns = int(step.count)
		"made":
			var recipe: String = step.recipe
			check(Recipes.get_recipe(recipe) != null, "%s asks for a recipe that exists: %s" % [quest.id, recipe])
			if not Recipes.knows(recipe):
				if not _flagged.has(quest.id + ":recipe"):
					_flagged[quest.id + ":recipe"] = true
					check(false, "%s asks you to make %s before you know the recipe" % [quest.id, recipe])
				return false
			Recipes.times_made[recipe] = int(step.get("count", 1))
		"climbed":
			return _climb(quest, step.route)
		"time":
			GameClock.minutes = int(step.from) * 60 + 30
		"pressed":
			for id: String in step.get("plants", []):
				check(not Herbarium.get_plant(id).is_empty(), "%s asks for a plant that exists: %s" % [quest.id, id])
				Herbarium.press(id, "playthrough")
			var hub: String = step.get("hub", "")
			for plant: Dictionary in Herbarium.PLANTS:
				if Herbarium.count(hub) >= int(step.get("count", 0)):
					break
				if hub == "" or hub in Herbarium.hubs_of(plant):
					Herbarium.press(plant.id, "playthrough")
			check(Herbarium.has_press(), "%s asks for pressed plants once you have the press" % quest.id)
		"unlocked":
			var ability: String = step.ability
			if ability in WORLD_ABILITIES:
				if ability == QuestLog.GUARDIAN_FOUND:
					QuestLog.find_guardian()
				else:
					QuestLog.unlocks.append(ability)
			else:
				# Unlocked by an earlier quest or step; if nothing gives it the
				# quest can't go on.
				var giver := _gives_ability(ability)
				if giver == "" and not _flagged.has(quest.id + ":" + ability):
					_flagged[quest.id + ":" + ability] = true
					check(false, "%s waits on ability %s, which nothing hands over" % [quest.id, ability])
				return false
		"photographed":
			# A picture for each line of Ansel's list, the asked-for ones first.
			check(Photos.has_camera(), "%s asks for photographs once you have the camera" % quest.id)
			var shots: Array = step.get("shots", [])
			for id: String in shots:
				check(not Photos.get_entry(id).is_empty(), "%s asks for a picture on the list: %s" % [quest.id, id])
				Photos.listed[id] = {"day": Friendship.today(), "title": "playthrough"}
			for entry: Dictionary in Photos.SHOT_LIST:
				if Photos.listed_count() >= int(step.get("count", 0)):
					break
				Photos.listed[entry.id] = {"day": Friendship.today(), "title": "playthrough"}
			check(Photos.listed_count() >= int(step.get("count", 0)), "%s asks for no more pictures than the list holds" % quest.id)
		"work":
			var work := Stewardship.next_work_step(quest)
			var task: String = work.get("task", step.task)
			check(not Stewardship.spots_for(task).is_empty(), "%s has work spots for %s" % [quest.id, task])
			for spot in Stewardship.spots_for(task):
				Stewardship.finish(spot.id)
		"talk", "return":
			return false
		_:
			check(false, "%s has a step type the bot knows: %s" % [quest.id, step.get("type", "")])
			return false
	return true


func _gives_ability(ability: String) -> String:
	for quest: QuestData in QuestLog.QUESTS:
		if ability in quest.reward_unlocks or ability in quest.start_unlocks:
			return quest.id
		for step: Dictionary in quest.steps:
			if step.get("unlock", "") == ability:
				return quest.id
	return ""


## Climbs [param route_id] if the player could: they have the guidebook, a
## partner if the route needs one, and the gear (buying what shops sell).
func _climb(quest: QuestData, route_id: String) -> bool:
	var route: RouteData = null
	for r in Guidebook.routes():
		if r.id == route_id:
			route = r
	if route == null:
		check(false, "%s sends you up a route in the guidebook: %s" % [quest.id, route_id])
		return false
	if not Guidebook.has_book():
		return false
	if route.partner_quest != "" and not (QuestLog.active.has(route.partner_quest) or QuestLog.is_completed(route.partner_quest)):
		return false
	for id: String in _missing_ids(route.required_gear):
		_buy(id, int(route.required_gear[id]))
	if not Gear.has_all(route.required_gear):
		return false
	QuestLog.record_climb(route.id)
	if route.destination_hub != "":
		Park.unlock_hub(route.destination_hub)
	return true


func _missing_ids(required: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in required:
		if Gear.count(id) < int(required[id]):
			out.append(id)
	return out


## Trades for [param id] at any shop whose offer the player can see now.
func _buy(id: String, need: int) -> void:
	for shop in shops:
		for offer in shop.offers:
			if offer.kind != "gear" or offer.id != id or not Gear.has_all(offer.requires):
				continue
			while Gear.count(id) < need and (offer.max_owned == 0 or Gear.count(id) < offer.max_owned):
				Gear.add(id, offer.amount)
				bought.append(id)


## Saves everything and loads it back; the quest log must come back the same.
func _check_save_round_trip() -> void:
	var before := JSON.stringify(QuestLog.save_data())
	var data := QuestLog.save_data()
	var copy: Dictionary = JSON.parse_string(JSON.stringify(data))
	QuestLog.load_data(copy)
	var after := JSON.stringify(QuestLog.save_data())
	if before != after:
		check(false, "the quest log round-trips through a save in %s year %d" % [GameClock.SEASON_NAMES[GameClock.season], GameClock.year])
