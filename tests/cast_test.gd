extends Node
## Checks the cast and the storyline: every person has art and sources,
## every quest points at people, items, gear, and routes that exist, the gear
## curve lets every climb happen in order, and everyone placed in a story
## overlay stands on open ground.
## Run: godot --headless --path . res://tests/cast_test.tscn
## Exit code is the number of failed checks.

const CONTENT_DIR := "res://scenes/story/content/"
const ROUTE_DIR := "res://data/routes/"
const VISITOR_DIR := "res://data/characters/visitors/"
const NATIVE_IDS := ["tenaya", "maggie_howard", "lucy_telles", "maria_lebrado", "carrie_bethel"]

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	_check_characters()
	_check_visitors()
	_check_quest_references()
	_check_gear_curve()
	_check_placements()
	_play_first_chapter()
	_play_the_nose()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _check_characters() -> void:
	var missing_art: Array[String] = []
	var missing_sources: Array[String] = []
	for character: CharacterData in QuestLog.CHARACTERS:
		var sheet := character.sprite_sheet
		if sheet == null or sheet.get_size() != Vector2(48, 96):
			missing_art.append(character.id)
		if character.sources.strip_edges() == "":
			missing_sources.append(character.id)
		check(not character.visitor, "%s is a historical person, not a visitor" % character.id)
	check(missing_art.is_empty(), "every character has a 48×96 sprite sheet %s" % [missing_art])
	check(missing_sources.is_empty(), "every character lists sources %s" % [missing_sources])
	for id: String in NATIVE_IDS:
		var character := QuestLog.get_character(id)
		check(character != null and character.needs_tribal_review, "%s is flagged for tribal review" % id)


func _check_visitors() -> void:
	var visitors := _load_dir(VISITOR_DIR)
	check(visitors.size() >= 8, "there are visitors from several eras (%d)" % visitors.size())
	for visitor: CharacterData in visitors:
		check(visitor.visitor and visitor.idle_lines.size() >= 2 and visitor.sprite_sheet != null,
			"%s is a visitor with art and things to say" % visitor.id)
		check(QuestLog.get_character(visitor.id) == null, "%s isn't in the Register's cast" % visitor.id)
	for quest: QuestData in QuestLog.QUESTS:
		check(not quest.giver.begins_with("visitor_"), "%s isn't given by a visitor" % quest.id)


func _check_quest_references() -> void:
	var routes := {}
	for route: RouteData in _load_dir(ROUTE_DIR):
		routes[route.id] = route
	var obtainable := _obtainable_items()
	var ids := {}
	for quest: QuestData in QuestLog.QUESTS:
		check(not ids.has(quest.id), "quest id %s is unique" % quest.id)
		ids[quest.id] = true
	for quest: QuestData in QuestLog.QUESTS:
		var problems: Array[String] = []
		if QuestLog.get_character(quest.giver) == null:
			problems.append("giver " + quest.giver)
		for req in quest.requires:
			if not ids.has(req):
				problems.append("requires " + req)
		for s: Dictionary in quest.steps:
			match s.type:
				"talk":
					if QuestLog.get_character(s.target) == null:
						problems.append("talk " + s.target)
				"have":
					if ItemDB.get_item(s.item) == null or not obtainable.has(s.item):
						problems.append("item " + s.item)
				"climbed":
					if not routes.has(s.route):
						problems.append("route " + s.route)
				"made":
					if Recipes.get_recipe(s.recipe) == null:
						problems.append("recipe " + s.recipe)
			for key in ["objective", "reminder"]:
				if str(s.get(key, "")) == "":
					problems.append("%s step has no %s" % [s.type, key])
		for id in quest.reward_gear:
			if Gear.get_gear(id) == null:
				problems.append("gear " + id)
		for id in quest.reward_items:
			if ItemDB.get_item(id) == null:
				problems.append("reward item " + id)
		for id in quest.reward_recipes:
			if Recipes.get_recipe(id) == null:
				problems.append("recipe " + id)
		for ability in quest.reward_unlocks:
			if ability.begins_with("hub:") and Park.get_hub(ability.trim_prefix("hub:")) == null:
				problems.append(ability)
		check(problems.is_empty(), "%s: everything it refers to exists %s" % [quest.id, problems])


## Items the player can actually get: forage, cooking, quest rewards, and
## one-off pickups in the story overlays.
func _obtainable_items() -> Dictionary:
	var result := {}
	for item in ItemDB.forage_items():
		result[item.id] = true
	for recipe: RecipeData in Recipes.RECIPES:
		result[recipe.output_id] = true
	for quest: QuestData in QuestLog.QUESTS:
		for id in quest.reward_items:
			result[id] = true
	for overlay in _overlays():
		for pickup in overlay.find_children("*", "StoryPickup", true, false):
			result[pickup.item_id] = true
		overlay.free()
	return result


## Walks the quests in order, the way a player could, and checks that each
## climb's gear is in hand by the time a quest asks for it. Side quests count
## as soon as their own requirements are met.
func _check_gear_curve() -> void:
	var routes := {}
	for route: RouteData in _load_dir(ROUTE_DIR):
		routes[route.id] = route
	var done := {}
	var gear := {"approach_shoes": 1, "chalk_bag": 1}
	var progressed := true
	while progressed:
		progressed = false
		for quest: QuestData in QuestLog.QUESTS:
			if done.has(quest.id) or not Array(quest.requires).all(func(r): return done.has(r)):
				continue
			var climbs_ok := true
			for s: Dictionary in quest.steps:
				if s.type == "climbed" and not _has_gear(gear, routes[s.route].required_gear):
					climbs_ok = false
			if not climbs_ok:
				continue
			done[quest.id] = true
			for id in quest.reward_gear:
				gear[id] = gear.get(id, 0) + int(quest.reward_gear[id])
			progressed = true
	var stuck := QuestLog.QUESTS.filter(func(q: QuestData) -> bool: return not done.has(q.id)).map(func(q): return q.id)
	check(stuck.is_empty(), "every quest can be finished in some order %s" % [stuck])
	for id in routes:
		check(_has_gear(gear, routes[id].required_gear), "the story hands out enough gear for %s" % id)
	check(done.has("clark_last_page"), "the story reaches The Last Page")


func _has_gear(have: Dictionary, need: Dictionary) -> bool:
	for id in need:
		if have.get(id, 0) < int(need[id]):
			return false
	return true


## Every person and climb in an overlay is placed on open ground, and every
## quest giver and talk target is placed somewhere.
func _check_placements() -> void:
	var placed := {}
	for file in DirAccess.get_files_at(CONTENT_DIR):
		if not file.ends_with(".tscn"):
			continue
		var region_id := file.get_basename()
		var hub := Park.get_hub(region_id)
		var path := hub.scene_path() if hub else "res://scenes/regions/%s.tscn" % region_id
		check(ResourceLoader.exists(path), "%s's overlay has a region" % region_id)
		if not ResourceLoader.exists(path):
			continue
		var region: Region = (load(path) as PackedScene).instantiate()
		add_child(region)
		StoryContent.attach(region)
		# Generated hubs keep collision in Map/Blocker, hand-made hubs in Blocker.
		# The homestead has neither (its tiles collide themselves).
		var blocker: TileMapLayer = region.get_node_or_null("Map/Blocker")
		if blocker == null:
			blocker = region.get_node_or_null("Blocker")
		var blocked: Array[String] = []
		for node in region.entities.get_children():
			if not (node is NPC or node is ClimbStart or node is StoryPickup):
				continue
			if node is NPC and node.character:
				placed[node.character.id] = true
			if node is NPC and node.spot != "" and region.get_spawn(node.spot) == null:
				blocked.append("%s (no spot %s)" % [node.name, node.spot])
			elif blocker and blocker.get_cell_source_id(blocker.local_to_map(blocker.to_local(node.global_position))) != -1:
				blocked.append(node.name)
		check(blocked.is_empty(), "%s: everyone stands on open ground %s" % [region_id, blocked])
		region.free()
	var unplaced: Array[String] = []
	for quest: QuestData in QuestLog.QUESTS:
		if not placed.has(quest.giver):
			unplaced.append(quest.giver)
		for s: Dictionary in quest.steps:
			if s.type == "talk" and not placed.has(s.target):
				unplaced.append(s.target)
	check(unplaced.is_empty(), "every quest giver and talk target is placed in the park %s" % [unplaced])


## Clark's first quest, then Degnan's delivery round, which ends with a
## "return" step and a material (the starter) for Jennie Curry's quest.
func _play_first_chapter() -> void:
	QuestLog.start_new_game()
	QuestLog.talk_to("galen_clark")
	check(QuestLog.active.has("clark_register"), "Galen Clark hands over the Register")
	QuestLog.talk_to("james_lamon")
	Inventory.add("lamon_apple", 1)
	QuestLog.talk_to("galen_clark")
	check(QuestLog.is_completed("clark_register") and QuestLog.is_unlocked("register"), "The Guardian's Register is done after meeting Lamon and packing food")
	QuestLog.talk_to("bridget_degnan")
	QuestLog.talk_to("dick_leonard")
	QuestLog.talk_to("jennie_curry")
	check(QuestLog.current_step(QuestLog.get_quest("degnan_bread")).get("type") == "return", "after both deliveries, Degnan's quest waits for you to come back")
	QuestLog.talk_to("bridget_degnan")
	check(QuestLog.is_completed("degnan_bread") and Inventory.count("sourdough_starter") == 1 and Inventory.count("degnan_loaf") >= 3,
		"coming back to Bridget pays out bread and her starter")
	QuestLog.talk_to("jennie_curry")
	QuestLog.talk_to("jennie_curry")
	check(QuestLog.is_completed("curry_starter") and Inventory.count("sourdough_starter") == 0 and Inventory.count("lamon_apple") >= 6,
		"Jennie Curry trades Lamon apples for the starter")


## Topping out on the Nose finishes Harding's quest and opens the road to Tuolumne.
func _play_the_nose() -> void:
	QuestLog.completed.append_array(["harding_nose", "johnson_solo"])
	check(not Park.is_hub_unlocked("tuolumne_meadows"), "Tuolumne starts locked")
	QuestLog.talk_to("warren_harding")
	check(QuestLog.active.has("harding_summit"), "Harding sends you up the Nose")
	QuestLog.record_climb("the_nose")
	var lines := QuestLog.talk_to("warren_harding")
	check(QuestLog.is_completed("harding_summit") and Park.is_hub_unlocked("tuolumne_meadows"), "climbing the Nose opens Tuolumne Meadows")
	check(lines.back().text.contains("Tuolumne"), "the reward line names the new area (%s)" % lines.back().text)


func _overlays() -> Array[Node]:
	var result: Array[Node] = []
	for file in DirAccess.get_files_at(CONTENT_DIR):
		if file.ends_with(".tscn"):
			result.append(load(CONTENT_DIR + file).instantiate())
	return result


func _load_dir(dir: String) -> Array:
	var result := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			result.append(load(dir + file))
	return result
