extends Node
## Plays search and rescue from Camp 4 (Rescues): Hodges sends you to Jo
## Tolliver at the rescue site, Jo's first call (a boy lost in Cook's
## Meadow) has you follow his prints and carry him back, and after that the
## radio calls by season, weather and the climbs you've ticked. Also the
## food-sharing and climbing calls, the lower (RescueLower), nightfall, the
## thank-you notes on the board, the rescue log, the perk and saving.
## Run: godot --headless --path . res://tests/rescue_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const JO := "jo_tolliver"

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func said(lines: Array[Dictionary], text: String) -> bool:
	return lines.any(func(l: Dictionary) -> bool: return text in l.text)


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://rescue_test_save.json"
	SaveManager.delete_save()
	var world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	test_data()
	await test_calls_on_the_map()
	await test_first_call(world)
	test_feed_call()
	test_radio()
	test_climb_call()
	test_lower()
	test_nightfall()
	test_thanks()
	test_perk_and_log(world)
	test_save()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## Talking to Jo, as an NPC does it: rescues first, then her quests.
func _talk_to_jo() -> Array[Dictionary]:
	var lines := Rescues.talk_to(JO)
	lines.append_array(QuestLog.talk_to(JO))
	return lines


func _fresh() -> void:
	Inventory.items.clear()
	QuestLog.start_new_game()
	Perks.start_new_game()
	Rescues.start_new_game()
	GameClock.minutes = 9 * 60


func test_data() -> void:
	var jo := QuestLog.get_character(JO)
	check(jo != null and jo.staff and not jo.visitor and jo in QuestLog.STAFF, "Jo Tolliver is invented staff, not in the Register")
	check(jo != null and jo.sprite_sheet != null and jo.sprite_sheet.get_height() == 192 and CharacterSheet.has_poses(jo.sprite_sheet), "she has a 32px sprite sheet with every pose")
	check(Portraits.for_speaker("Jo Tolliver") != null, "and a portrait")
	check(Friendship.LOVES.has(JO) and GuardianMirror.GATHERING.any(func(e: Array) -> bool: return e[0] == JO), "she has favorite gifts and a line in the cave")
	var join := QuestLog.get_quest(Rescues.JOIN_QUEST)
	var first := QuestLog.get_quest(Rescues.FIRST_QUEST)
	check(join != null and join.giver == "clare_hodges" and "leonard_belay" in join.requires and join.steps[0].target == JO, "Ranger Hodges sends you to Jo once you can belay")
	check(first != null and first.giver == JO and Rescues.JOIN_QUEST in first.requires and first.steps[0].ability == Rescues.FIRST_DONE, "Jo's first quest waits on your first rescue")
	check(Rescues.CALLS.size() >= 6 and Rescues.CALLS.size() <= 8, "six to eight kinds of call (%d)" % Rescues.CALLS.size())
	var stages := {}
	var bad: Array[String] = []
	for call: Dictionary in Rescues.CALLS:
		for s: String in call.stages:
			stages[s] = true
			if not s in Rescues.REMINDERS:
				bad.append("%s:%s" % [call.id, s])
		for id: String in call.gift:
			if ItemDB.get_item(id) == null:
				bad.append("%s gift %s" % [call.id, id])
		if not ResourceLoader.exists(RescueField.VISITOR_DIR % call.look):
			bad.append("%s look %s" % [call.id, call.look])
		if "feed" in call.stages and int(call.get("feed", 0)) <= 0:
			bad.append("%s feed" % call.id)
		var last: String = call.stages[-1]
		if last != "carry" and last != "report":
			bad.append("%s ends on %s" % [call.id, last])
		for key in ["title", "who", "radio", "done", "thanks", "place"]:
			if str(call.get(key, "")) == "":
				bad.append("%s %s" % [call.id, key])
	check(bad.is_empty(), "every call is complete, and ends back with Jo %s" % [bad])
	for s in ["search", "feed", "carry", "climb", "report"]:
		check(stages.has(s), "some call uses '%s'" % s)
	var seasons := {}
	for call: Dictionary in Rescues.CALLS:
		if call.id != Rescues.FIRST_CALL:
			for season: int in call.seasons:
				seasons[season] = true
	check(seasons.size() == 4, "calls come in every season")


## Every search's markers are in its region, with a walkable way between
## them, and every climb's route starts in its region's story overlay.
func test_calls_on_the_map() -> void:
	for call: Dictionary in Rescues.CALLS:
		var path := "res://scenes/regions/%s.tscn" % call.region
		check(ResourceLoader.exists(path), "%s: region %s exists" % [call.id, call.region])
		if not ResourceLoader.exists(path):
			continue
		# in a world of its own, apart from the region World has open
		var holder := SubViewport.new()
		holder.world_2d = World2D.new()
		add_child(holder)
		var region: Region = (load(path) as PackedScene).instantiate()
		holder.add_child(region)
		StoryContent.attach(region)
		if call.has("route"):
			var starts := region.entities.get_children().filter(func(n: Node) -> bool: return n is ClimbStart and n.route.id == call.route)
			check(starts.size() == 1, "%s: %s starts in %s" % [call.id, call.route, call.region])
		else:
			var start := region.get_spawn(call.start)
			var near := region.get_spawn(call.near)
			check(start != null and near != null, "%s: its prints start and end at real spots" % call.id)
			if start and near:
				for i in 3:
					await get_tree().physics_frame
				var grid := WalkGrid.of(region)
				var at := grid.nearest_open(near.global_position + Vector2(call.offset))
				var from := grid.nearest_open(start.global_position)
				var way := grid.route(from, at)
				var length := 0.0
				var here := from
				for p in way:
					length += here.distance_to(p)
					here = p
				check(not way.is_empty() and length > 200.0 and length < 1400.0, "%s: you can walk the trail of prints (%d px)" % [call.id, length])
		holder.free()


func test_first_call(world: Node) -> void:
	_fresh()
	QuestLog.completed.append_array(["clark_register", "shop_guidebook", "shop_outfit", "partner_apron", "leonard_belay"])
	check(Rescues.talk_to(JO).is_empty() and not Rescues.on_team(), "Jo has nothing for you until Hodges sends you")
	var lines := QuestLog.talk_to("clare_hodges")
	check(QuestLog.active.has(Rescues.JOIN_QUEST) and said(lines, "Jo Tolliver"), "Hodges sends you to Jo")
	lines = _talk_to_jo()
	check(QuestLog.is_completed(Rescues.JOIN_QUEST) and QuestLog.active.has(Rescues.FIRST_QUEST), "Jo takes you on, and sets you a first call")
	check(Rescues.current == Rescues.FIRST_CALL and Rescues.current_stage() == "search", "the radio calls about a lost boy")
	check(said(lines, "Cook's Meadow"), "she tells you where he was last seen")
	check(Rescues.objective().contains("prints"), "the Quests tab says to follow his prints")
	lines = _talk_to_jo()
	check(Rescues.current_stage() == "search" and said(lines, "prints"), "talk to her again and she reminds you")

	await world.go_to_region("yosemite_village", "camp_4")
	for i in 3:
		await get_tree().process_frame
	var field: RescueField = null
	for child in world.get_children():
		if child is RescueField:
			field = child
	check(field != null, "World keeps a rescue field")
	if field == null:
		return
	var subject := field.subject
	check(subject != null and is_instance_valid(subject) and subject.is_inside_tree(), "the boy is out there somewhere")
	if subject == null:
		return
	var call := Rescues.active_call()
	var start: Vector2 = world.region.get_spawn(call.start).global_position
	check(field.prints.size() >= 8, "he left a trail of prints (%d)" % field.prints.size())
	check((field.prints[0][0] as Vector2).distance_to(start) < 80.0, "starting where he was last seen")
	check((field.prints[-1][0] as Vector2).distance_to(subject.global_position) < 40.0, "and ending where he is")
	check(WalkGrid.of(world.region).is_open(subject.global_position), "he's on open ground you can walk to")
	check(subject.global_position.distance_to(start) > 200.0, "some way off the boardwalk")
	check(subject.get_prompt() == "Help Toby Lindqvist", "walk up and you can help him")
	# the prints show close to you, not across the map
	world.player.global_position = start
	var near_seen := RescueField.READ_FADE - start.distance_to(field.prints[0][0]) > 0.0
	var far_seen := RescueField.READ_FADE - start.distance_to(subject.global_position) > 0.0
	check(near_seen and not far_seen, "you read the prints near you, not the whole trail at once")

	lines = Rescues.reach()
	check(said(lines, "following the deer") and Rescues.current_stage() == "carry", "you find him, and he needs carrying")
	for i in 2:
		await get_tree().process_frame
	check(not is_instance_valid(subject) or subject.is_queued_for_deletion(), "he's off the ground")
	check(field.prints.is_empty(), "and the trail's done with")
	check(is_equal_approx(Rescues.speed_factor(), Rescues.CARRY_SPEED), "carrying him slows you down")
	check(world.player.has_node("RescueRider"), "he rides on your back")
	lines = _talk_to_jo()
	check(Rescues.current == "" and Rescues.count() == 1, "bring him to Jo and the rescue's done")
	check(QuestLog.is_completed(Rescues.FIRST_QUEST) and QuestLog.is_unlocked(Rescues.FIRST_DONE), "and so is her first quest")
	check(said(lines, "Rescue logged") and said(lines, "Your first one"), "she logs it and says so")
	check(is_equal_approx(Rescues.speed_factor(), 1.0), "you walk at your own pace again")
	await get_tree().process_frame
	check(not world.player.has_node("RescueRider") or world.player.get_node("RescueRider").is_queued_for_deletion(), "with nobody on your back")
	check(int(Friendship.points.get(JO, 0)) > 0, "Jo warms to you")


func test_feed_call() -> void:
	_fresh()
	Rescues.begin("four_mile_overdue")
	var lines := Rescues.reach()
	check(said(lines, "legs just quit") and Rescues.current_stage() == "feed", "you find the overdue hiker, out of food")
	check(said(lines, "8 energy"), "he needs food worth 8 energy")
	lines = Rescues.reach()
	check(Rescues.current_stage() == "feed", "with nothing to share, you can't help him yet")
	Inventory.add("trail_mix", 3)
	var before := FoodDB.carried_energy()
	lines = Rescues.reach()
	check(Rescues.current_stage() == "report" and FoodDB.carried_energy() <= before - 8, "share your food and he can walk out")
	check(said(lines, "You share"), "you're told what you shared")
	lines = Rescues.talk_to(JO)
	check(Rescues.current == "" and Rescues.count() == 1 and said(lines, "Dale got his legs back"), "then tell Jo")


func test_radio() -> void:
	_fresh()
	check(Rescues.call_waiting() == false, "no calls before you've joined")
	QuestLog.completed.append_array([Rescues.JOIN_QUEST, Rescues.FIRST_QUEST])
	GameClock.season = GameClock.Season.SUMMER
	var ids := Rescues.eligible().map(func(c: Dictionary) -> String: return c.id)
	check(not Rescues.FIRST_CALL in ids, "the first call doesn't come again")
	check(not "swan_slab_stuck" in ids and not "royal_arches_benighted" in ids, "no climbing calls on routes you haven't climbed")
	check(not "el_cap_meadow_snow" in ids and "four_mile_overdue" in ids, "calls follow the season")
	QuestLog.climbed.append("swan_slab")
	ids = Rescues.eligible().map(func(c: Dictionary) -> String: return c.id)
	check("swan_slab_stuck" in ids, "tick Swan Slab and its call can come in")
	var days := 0
	var calls := 0
	for d in range(1, 29):
		GameClock.day = d
		Rescues.offered_day = -1
		Rescues.refresh()
		days += 1
		if Rescues.offered != "":
			calls += 1
	check(calls >= 6 and calls <= 22, "some mornings the radio calls (%d of %d)" % [calls, days])
	# find a day with a call, and take it from Jo
	for d in range(1, 29):
		GameClock.day = d
		Rescues.offered_day = -1
		Rescues.refresh()
		if Rescues.offered != "":
			break
	var offered := Rescues.offered
	GameClock.minutes = 17 * 60
	check(not Rescues.call_waiting(), "too late in the day to send you out")
	GameClock.minutes = 8 * 60
	var lines := Rescues.talk_to(JO)
	check(Rescues.current == offered and said(lines, "radio's going") and said(lines, "Rescue call"), "in the morning Jo hands you the call")
	Rescues.start_new_game()
	GameClock.day = 1
	Rescues.offered_day = -1
	for d in range(1, 29):
		GameClock.day = d
		Rescues.offered_day = -1
		Rescues.refresh()
		if Rescues.offered == "":
			break
	lines = Rescues.talk_to(JO)
	check(Rescues.current == "" and said(lines, "radio"), "on a quiet morning she says so")
	check(Rescues.talk_to(JO).is_empty(), "once a day")


func test_climb_call() -> void:
	_fresh()
	Rescues.begin("royal_arches_benighted")
	check(Rescues.wants_climb("royal_arches") and not Rescues.wants_climb("swan_slab"), "a climbing call waits at its own route")
	check(Rescues.objective().contains("Royal Arches") and Rescues.objective().contains("lower"), "climb to them, then lower them")
	Rescues.start_new_game()
	check(not Rescues.wants_climb("royal_arches"), "no call, a route is just a climb")


func _lower(policy: Callable) -> RescueLower:
	var lower := RescueLower.new()
	add_child(lower)
	lower.set_process(false)
	lower.start()
	for i in 3000:
		if lower.done:
			break
		lower.step(1.0 / 60.0, policy.call(lower))
	return lower


func test_lower() -> void:
	var reckless := _lower(func(_l: RescueLower) -> bool: return true)
	check(reckless.done and reckless.depth >= 1.0, "they always reach the ground")
	check(reckless.bumps == RescueLower.SNAGS.size(), "but letting the rope run bumps them at every flake (%d)" % reckless.bumps)
	check(reckless.outcome_text().contains("bumps"), "and you hear about it")
	var careful := _lower(func(l: RescueLower) -> bool:
		var ahead := RescueLower.snag_at(l.depth + 0.08)
		var over := RescueLower.snag_at(l.depth)
		if over >= 0 or ahead >= 0:
			return l.speed < RescueLower.SAFE_SPEED * 0.6
		return l.speed < RescueLower.HOT_SPEED * 0.95)
	check(careful.done and careful.bumps == 0, "ease them past each flake and it's a clean lower (%d bumps)" % careful.bumps)
	check(careful.outcome_text().contains("perfect"), "a perfect lower")
	var hot := RescueLower.new()
	add_child(hot)
	hot.set_process(false)
	hot.start()
	hot.depth = 0.0
	var locked := false
	for i in 600:
		hot.step(1.0 / 60.0, true)
		hot.depth = 0.05 # hold them above the flakes, rope running
		if hot.heat >= 1.0 or hot._locked > 0.0:
			locked = true
			break
	check(locked, "run the rope fast too long and the brake heats up and locks")
	hot.hand_off()
	check(hot.done and hot.handed_off and hot.outcome_text().contains("team"), "cancel and the team finishes the lower")
	for node in [reckless, careful, hot]:
		node.queue_free()


func test_nightfall() -> void:
	_fresh()
	Rescues.begin("mirror_lake_ankle")
	GameClock.time_changed.emit(20, 0)
	check(Rescues.current == "mirror_lake_ankle", "you have until dark")
	GameClock.time_changed.emit(Rescues.NIGHTFALL, 0)
	check(Rescues.current == "" and Rescues.count() == 0, "at nightfall the team finishes it, without you")
	QuestLog.active[Rescues.FIRST_QUEST] = 0
	Rescues.begin(Rescues.FIRST_CALL)
	GameClock.time_changed.emit(Rescues.NIGHTFALL, 0)
	check(Rescues.current == Rescues.FIRST_CALL, "but Jo's first call waits for you")


func test_thanks() -> void:
	_fresh()
	Rescues.begin("swan_slab_stuck")
	Rescues.stage = 1
	Rescues.talk_to(JO)
	check(Rescues.thanks_waiting.has("swan_slab_stuck") and Rescues.read_thanks() == "", "a thank-you note is on its way")
	GameClock.day_started.emit(GameClock.day, GameClock.season, GameClock.year)
	check(Rescues.thanks_posted.has("swan_slab_stuck"), "next morning it's on the Camp 4 board")
	var before := Inventory.count("trail_mix")
	var text := Rescues.read_thanks()
	check(text.contains("Mountain Shop") and Inventory.count("trail_mix") == before + 2, "from Andy, with trail mix tucked behind it")
	check(Rescues.read_thanks() == "", "and you take it down")


func test_perk_and_log(world: Node) -> void:
	_fresh()
	QuestLog.completed.append_array([Rescues.JOIN_QUEST, Rescues.FIRST_QUEST])
	for id in ["four_mile_overdue", "mirror_lake_ankle", "swan_slab_stuck", "apron_stuck"]:
		Rescues.begin(id)
		Rescues.stage = Rescues.active_call().stages.size() - 1
		Rescues.talk_to(JO)
	check(not Perks.has("long_carry"), "no perk after four rescues")
	Rescues.begin("happy_isles_cold")
	Rescues.stage = 2
	check(is_equal_approx(Rescues.speed_factor(), Rescues.CARRY_SPEED), "carrying is slow")
	Rescues.talk_to(JO)
	check(Perks.has("long_carry"), "five rescues and you learn the Long Carry")
	Rescues.begin("mirror_lake_ankle")
	Rescues.stage = 1
	check(Rescues.speed_factor() > Rescues.CARRY_SPEED + 0.1, "which carries faster")
	Rescues.start_new_game()
	Rescues.history.append({"id": "four_mile_overdue", "day": 1})
	Rescues.begin("apron_stuck")
	var journal := get_tree().get_first_node_in_group("journal")
	journal.open()
	var text := _journal_text(journal)
	check(text.contains("Rescue log: 1 person helped") and text.contains("Overdue on the Four Mile Trail"), "the Journal keeps a rescue log")
	journal.show_tab(Journal.Tab.QUESTS)
	text = _journal_text(journal)
	check(text.contains("Off route on the Apron") and text.contains("Glacier Point Apron"), "and the Quests tab shows the call underway")
	journal.close()
	var sign: RescueSiteSign = world.region.find_child("RescueSiteSign", true, false) if world.region.region_id == "yosemite_village" else null
	check(sign != null and sign.current_text().contains("Off route on the Apron"), "the rescue site's sign shows the call too")


func _journal_text(journal: Node) -> String:
	var parts := PackedStringArray()
	for node in journal._body.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return "\n".join(parts)


func test_save() -> void:
	_fresh()
	Rescues.history.append({"id": "apron_stuck", "day": 3})
	Rescues.begin("happy_isles_cold")
	Rescues.stage = 1
	Rescues.thanks_waiting.append("apron_stuck")
	var saved := Rescues.save_data()
	Rescues.start_new_game()
	Rescues.load_data(JSON.parse_string(JSON.stringify(saved)))
	check(Rescues.current == "happy_isles_cold" and Rescues.stage == 1 and Rescues.count() == 1 and Rescues.thanks_waiting.has("apron_stuck"), "a call underway and the rescue log are saved")
