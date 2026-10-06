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
	_check_main_line()
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
	for character: CharacterData in QuestLog.STAFF:
		var sheet := character.sprite_sheet
		check(character.staff and not character.visitor and sheet != null and sheet.get_size() == Vector2(48, 96),
			"%s is invented Mountain Shop staff, with art" % character.id)
		check(not QuestLog.CHARACTERS.has(character), "%s isn't in the Register's cast" % character.id)
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
					if QuestLog.get_character(s.target) == null and not _shop_targets().has(s.target):
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
	var gear := Gear.STARTING_GEAR.duplicate()
	var progressed := true
	while progressed:
		progressed = false
		for quest: QuestData in QuestLog.QUESTS:
			if done.has(quest.id) or not Array(quest.requires).all(func(r): return done.has(r)):
				continue
			var climbs_ok := true
			var gifts := {}
			var have := gear.duplicate()
			for s: Dictionary in quest.steps:
				# Gear a step hands over counts for the steps after it.
				for id in s.get("gear", {}):
					have[id] = have.get(id, 0) + int(s.gear[id])
				if s.type == "climbed" and not _has_gear(have, routes[s.route].required_gear):
					climbs_ok = false
			if not climbs_ok:
				continue
			for s: Dictionary in quest.steps:
				for id in s.get("gear", {}):
					gear[id] = gear.get(id, 0) + int(s.gear[id])
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
		# A shopkeeper's quests are given across the counter (ShopData.talk_target).
		if not placed.has(quest.giver) and not _shop_targets().has(quest.giver):
			unplaced.append(quest.giver)
		for s: Dictionary in quest.steps:
			if s.type == "talk" and not placed.has(s.target) and not _shop_targets().has(s.target):
				unplaced.append(s.target)
	check(unplaced.is_empty(), "every quest giver and talk target is placed in the park %s" % [unplaced])


## The main storyline: every route in the guidebook is reachable, and every
## main-line quest (but the ending) finishes on a climb.
func _check_main_line() -> void:
	var main: Array[QuestData] = QuestLog.QUESTS.filter(func(q: QuestData) -> bool: return q.main_line)
	check(main.size() >= 10, "the main line has its quests (%d)" % main.size())
	for quest in main:
		if quest.id in ["clark_register", "shop_guidebook", "shop_outfit", "clark_last_page"]:
			continue # the errands for the guidebook and the first kit, and the ending
		check(quest.steps.back().type == "climbed", "%s finishes on a tick in the guidebook" % quest.id)
	for route in Guidebook.routes():
		check(Guidebook.main_quest_for(route.id) != null or route.id == "swan_slab" or route.id == "glacier_point_apron",
			"%s is on the main line" % route.id)
		check(route.guide_chapter != "" and route.guide_tip != "", "%s has a guidebook chapter and tip" % route.id)
	var first := QuestLog.get_quest("clark_register")
	check(first.giver == "galen_clark" and first.steps[0].target == "mountain_shop",
		"the first quest sends you to the Mountain Shop")
	var book := QuestLog.get_quest("shop_guidebook")
	check(book.giver == "mountain_shop" and book.steps.any(func(st): return st.get("unlock") == "guidebook" and st.type == "pay"),
		"the guidebook is traded for at the Mountain Shop")
	# The chain runs in one line from the guidebook to the glacier.
	var order := ["clark_register", "shop_guidebook", "shop_outfit", "partner_apron", "leonard_belay", "eichorn_apron", "eichorn_spires", "robbins_clean",
		"salathe_steel", "harding_summit", "muir_cathedral", "muir_glacier"]
	for i in range(1, order.size()):
		var quest := QuestLog.get_quest(order[i])
		check(quest != null and quest.main_line and not quest.requires.is_empty(), "%s follows %s" % [order[i], order[i - 1]])


func _shop_targets() -> Dictionary:
	var result := {}
	for shop: ShopData in _load_dir("res://data/shops/"):
		if shop.talk_target != "":
			result[shop.talk_target] = true
	return result


## The whole opening: Clark sends you to the Mountain Shop, the guidebook is
## the first thing in your pack, and only a tick finishes each quest after it.
func _play_first_chapter() -> void:
	QuestLog.start_new_game()
	Gear.start_new_game()
	check(not Guidebook.has_book(), "you start without a guidebook")
	var lines := QuestLog.talk_to("galen_clark")
	check(QuestLog.active.has("clark_register") and QuestLog.main_objective().objective.contains("Mountain Shop"), "Galen Clark sends you to the Mountain Shop")
	check(QuestLog.talk_to("dick_leonard").size() > 0 and not QuestLog.active.has("leonard_belay"), "no lessons before the guidebook")
	var firefall: RouteData = load("res://data/routes/firefall_slab.tres")
	lines = QuestLog.talk_to("mountain_shop", "Marty Kessler")
	check(QuestLog.is_completed("clark_register") and QuestLog.active.has("shop_guidebook"), "the clerk sets you an errand for the guidebook")
	check(lines[0].speaker == "Marty Kessler", "the clerk is the one speaking")
	check(not Guidebook.has_book(), "no guidebook yet: it's a trade")
	QuestLog.talk_to("jennie_curry")
	check(QuestLog.current_step(QuestLog.get_quest("shop_guidebook")).type == "return", "Jennie Curry hands over the box of guidebooks")
	QuestLog.talk_to("mountain_shop", "Marty Kessler")
	check(not Guidebook.has_book(), "no guidebook without food to trade")
	Inventory.add("wild_strawberry", 3)
	lines = QuestLog.talk_to("mountain_shop", "Marty Kessler")
	check(Guidebook.has_book() and QuestLog.is_completed("shop_guidebook"), "food buys the guidebook")
	check(Inventory.count("wild_strawberry") == 1, "the trade takes 20 energy of food (2 strawberries)")
	check("guidebook" in lines.filter(func(l): return l.text.begins_with("Received"))[0].text, "the pickup is announced")
	check(QuestLog.main_objective().objective.contains("Marty Kessler"), "the journal points you back to the clerk")
	QuestLog.talk_to("mountain_shop", "Marty Kessler")
	check(QuestLog.active.has("shop_outfit"), "the clerk offers to fit you out")
	check(QuestLog.talk_to("wren_alvarez").size() > 0 and not QuestLog.active.has("partner_apron"), "Wren isn't looking for you until you have a kit")
	Inventory.add("trail_mix", 2)
	QuestLog.talk_to("mountain_shop", "Marty Kessler")
	check(not QuestLog.is_completed("shop_outfit") and Gear.count("harness") == 0, "the kit waits on the rental shoes")
	Inventory.add("rental_shoes")
	lines = QuestLog.talk_to("mountain_shop", "Marty Kessler")
	check(QuestLog.is_completed("shop_outfit") and Inventory.count("rental_shoes") == 0, "returning the shoes and trading food finishes the fitting")
	check(Gear.has_all(firefall.required_gear), "the kit is exactly what Firefall Slab takes (%s)" % [Gear.missing(firefall.required_gear)])
	check(not Gear.has_all(load("res://data/routes/glacier_point_apron.tres").required_gear), "the shop kit doesn't open the cam routes")
	check(lines.any(func(l): return "Wren" in l.text), "the clerk points you to Wren")
	QuestLog.talk_to("wren_alvarez")
	check(QuestLog.active.has("partner_apron"), "Wren asks you to be their partner")
	QuestLog.talk_to("wren_alvarez")
	check(QuestLog.current_step(QuestLog.get_quest("partner_apron")).type == "climbed", "with food in your pack, only the climb is left")
	QuestLog.talk_to("wren_alvarez")
	check(not QuestLog.is_completed("partner_apron"), "talking isn't climbing")
	QuestLog.record_climb("firefall_slab")
	check(QuestLog.tick_report("firefall_slab").size() == 2, "the tick report says Wren is waiting")
	QuestLog.talk_to("wren_alvarez")
	check(QuestLog.is_completed("partner_apron") and QuestLog.has_climbed("firefall_slab"), "the tick finishes Wren's quest")
	check(QuestLog.main_objective().objective.contains("Dick Leonard"), "the journal points you to Dick Leonard next")
	QuestLog.talk_to("dick_leonard")
	Inventory.add("lamon_apple", 3)
	QuestLog.talk_to("dick_leonard")
	check(not QuestLog.is_completed("leonard_belay"), "food alone doesn't finish the quest")
	QuestLog.talk_to("dick_leonard")
	check(not QuestLog.is_completed("leonard_belay"), "you have to climb Swan Slab first")
	QuestLog.record_climb("swan_slab")
	QuestLog.talk_to("dick_leonard")
	check(QuestLog.is_completed("leonard_belay") and Gear.count("rope") == 1 and Gear.count("cam") == 2, "the tick finishes Leonard's quest and pays out the rack")
	check(Gear.has_all(load("res://data/routes/glacier_point_apron.tres").required_gear), "the shop's harness and Leonard's rope and cams open the Apron")
	QuestLog.talk_to("jules_eichorn")
	check(QuestLog.active.has("eichorn_apron"), "Jules Eichorn sets the Apron")
	check(Guidebook.entries().filter(func(e): return e.ticked).size() == 2, "two routes are ticked")
	# Side stories still work: Degnan's delivery round.
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
	QuestLog.start_new_game()
	Inventory.items.clear()
	Gear.start_new_game()
	Gear.add("rope")
	Gear.add("harness")
	Gear.add("cam", 8)
	Gear.add("quickdraw", 6)
	QuestLog.completed.append_array(["salathe_steel", "tabuce_chuckah"])
	var nose: RouteData = load("res://data/routes/the_nose.tres")
	check(not Park.is_hub_unlocked("tuolumne_meadows"), "Tuolumne starts locked")
	QuestLog.talk_to("warren_harding")
	check(QuestLog.active.has("harding_summit"), "Harding starts The Nose")
	check(not Gear.has_all(nose.required_gear), "the Nose needs the big-wall kit")
	Recipes.times_made["acorn_cake"] = 4
	QuestLog.talk_to("warren_harding")
	check(Gear.count("aiders") == 2, "four batches of acorn cakes earn the aiders")
	Inventory.add("acorn_cake", 4)
	Granary.acorns = 30
	QuestLog.talk_to("warren_harding")
	check(Gear.count("haul_bag") == 1, "enough food earns the haul bag")
	check(QuestLog.current_step(QuestLog.get_quest("harding_summit")).type == "talk", "then Beverly Johnson is next")
	QuestLog.talk_to("beverly_johnson")
	check(Gear.count("ascenders") == 2 and Gear.count("portaledge") == 1, "Beverly Johnson hands over the ascenders and portaledge")
	check(Gear.has_all(nose.required_gear), "the rack is complete for the Nose")
	check(not QuestLog.is_completed("harding_summit") and QuestLog.current_step(QuestLog.get_quest("harding_summit")).type == "climbed",
		"only the climb is left")
	QuestLog.talk_to("warren_harding")
	check(not Park.is_hub_unlocked("tuolumne_meadows"), "talking isn't enough to open Tuolumne")
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
