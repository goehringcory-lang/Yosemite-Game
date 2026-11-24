extends Node
## Headless test of your cabin (Camp.CABIN, Cabin, CabinRoom, CabinPiece):
## Lamon's old cabin stands at the homestead from the first day with a door
## that's always open, keepers' quests add to it (and say so), the room
## inside fills up and opens into the kitchen, the bed sleeps you through
## the night at home, and it all comes back with a saved game.
## Run: godot --headless --path . res://tests/cabin_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	Park.open_world = false
	SaveManager.save_path = "user://cabin_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame

	test_definitions()
	await test_outside(world)
	await test_inside(world)
	await test_sleep(world)
	test_save_and_load()

	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func new_game() -> void:
	NewGame.reset()
	GameClock.season = GameClock.Season.SPRING
	GameClock.day = 3
	GameClock.minutes = 9 * 60


func finish(ids: Array) -> void:
	for id: String in ids:
		QuestLog.active.erase(id)
		if not QuestLog.is_completed(id):
			QuestLog.completed.append(id)
	QuestLog.changed.emit()


func test_definitions() -> void:
	var ids := {}
	for piece: Dictionary in Camp.PIECES:
		ids[piece.id] = true
	var givers := {}
	for part: Dictionary in Camp.CABIN:
		check(not ids.has(part.id), "cabin addition %s has a name of its own" % part.id)
		ids[part.id] = true
		check(QuestLog.get_quest(part.quest) != null, "%s comes from a real quest (%s)" % [part.id, part.quest])
		var giver := QuestLog.get_character(part.from)
		check(giver != null and not giver.needs_tribal_review, "%s comes from someone who can give it (%s)" % [part.id, part.from])
		givers[part.from] = true
		check(part.where in ["inside", "outside", "both"], "%s shows inside, outside or both" % part.id)
		check(part.text != "" and part.got != "" and not part.got.contains("%"), "%s has a reward line and something to read" % part.id)
		if part.where != "outside" and part.has("pos"):
			check((CabinRoom.MAIN.has_point(part.pos) or CabinRoom.KITCHEN.has_point(part.pos)
				or (part.pos.y <= CabinRoom.MAIN.position.y + 32 and part.pos.x > 32 and part.pos.x < 736)),
				"%s stands in the room (%s)" % [part.id, part.get("pos")])
	check(Camp.CABIN.size() >= 12 and givers.size() >= 10, "a dozen or more additions, from ten or more keepers (%d, %d)" % [Camp.CABIN.size(), givers.size()])
	for part: Dictionary in Camp.CABIN:
		check(Camp.reward_line(part.quest).contains("For your cabin: "), "finishing %s says what it brings the cabin" % part.quest)


func test_outside(world: Node) -> void:
	new_game()
	world._enter_region("lamon_homestead", "home")
	await get_tree().process_frame
	var cabin: Cabin = world.region.entities.get_node_or_null("Cabin")
	check(cabin != null and cabin.position == Cabin.POS, "Lamon's old cabin stands at the homestead on the first day")
	var area := Rect2(Cabin.POS + Cabin.CLEAR.position, Cabin.CLEAR.size)
	var in_the_way: Array = world.region.entities.get_children().filter(func(n: Node) -> bool:
		return n is Node2D and str(n.name).begins_with("Dec_") and area.has_point((n as Node2D).position))
	check(in_the_way.is_empty(), "nothing on the map grows through it (%s)" % [in_the_way])
	var doors: Array = world.region.find_children("*", "BuildingDoor", true, false).filter(func(d: Node) -> bool:
		return d.target_region == Cabin.ROOM_REGION)
	check(doors.size() == 1 and doors[0].is_unlocked() and doors[0].is_open_now(), "its door is always open")
	check(world.region.get_spawn("guardian_cabin_door") != null, "with a spot outside it to come back out to")
	var tent: Node = world.region.entities.get_node_or_null("Tent")
	check(tent != null and tent.get_node("Sprite").visible, "your tent is still pitched beside it, for the first nights")
	var chair: CabinPiece = world.region.entities.get_node_or_null(CabinPiece.NAME_PREFIX + "porch_chair")
	check(chair != null and not chair.visible, "no porch chair yet")
	finish(["leonard_belay", "clark_big_trees"])
	await get_tree().process_frame
	check(chair != null and chair.visible, "Galen Clark's chair turns up after the Big Trees")


func test_inside(world: Node) -> void:
	new_game()
	world._enter_region(Cabin.ROOM_REGION, "door")
	await get_tree().process_frame
	var region: Region = world.region
	check(region.region_id == Cabin.ROOM_REGION and region.indoors, "the door leads into the cabin")
	var room: CabinRoom = region.entities.get_node_or_null("CabinRoom")
	check(room != null, "the room is drawn")
	var shown: Array = region.entities.get_children().filter(func(n: Node) -> bool: return n is CabinPiece and n.visible)
	check(shown.is_empty(), "and it's empty on the first day (%s)" % [shown])
	var bed := room.bed() if room else null
	check(bed != null and bed.has_signal("sleep_requested"), "there's a place for a bed")
	check(bed != null and not bed.get_node("Hitbox").monitorable, "but nothing to sleep on yet")
	var wall: StaticBody2D = room.get_node("KitchenWall") if room else null
	check(wall != null and not (wall.get_child(0) as CollisionShape2D).disabled, "the east wall is shut")
	finish(["clark_register", "lamon_orchard"])
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bed_piece: CabinPiece = region.entities.get_node_or_null(CabinPiece.NAME_PREFIX + "rope_bed")
	check(bed_piece != null and bed_piece.visible, "Lamon's rope bed is in once his orchard is done")
	check(bed != null and bed.get_node("Hitbox").monitorable, "and you can sleep in it")
	check(Player.prompt_for(bed) == "Sleep", "it says Sleep")
	finish(["degnan_bread", "enid_leave_some", "degnan_snowbound"])
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(wall != null and (wall.get_child(0) as CollisionShape2D).disabled, "Bridget Degnan's kitchen opens through the east wall")
	var stove: CabinPiece = region.entities.get_node_or_null(CabinPiece.NAME_PREFIX + "kitchen")
	check(stove != null and stove.visible and CabinRoom.KITCHEN.has_point(stove.position), "with her cookstove in it")
	check(Camp.describe("kitchen").contains("From Bridget Degnan"), "looking at it says who it's from")


func test_sleep(world: Node) -> void:
	new_game()
	finish(["clark_register", "lamon_orchard"])
	world._enter_region(Cabin.ROOM_REGION, "door")
	await get_tree().process_frame
	var day := GameClock.day
	await world.sleep()
	check(GameClock.day == day + 1, "sleeping in the bed starts the next day")
	check(world.region.region_id == Cabin.ROOM_REGION, "and you wake up in your cabin, not out by the tent")
	var spot: Marker2D = world.region.get_spawn(CabinRoom.BED_SPOT)
	check(spot != null and world.player.global_position.distance_to(spot.global_position) < 40.0, "beside the bed")
	world._enter_region("lamon_homestead", "home")
	await get_tree().process_frame


func test_save_and_load() -> void:
	new_game()
	finish(["clark_register", "lamon_orchard", "leonard_belay", "anderson_half_dome", "eichorn_apron", "mccauley_firefall"])
	check(Camp.has("porch") and Camp.has("hearth") and Camp.cabin_parts("inside").size() == 2, "a porch, a hearth and a bed (%d inside)" % Camp.cabin_parts("inside").size())
	check(SaveManager.save_game(), "the game saves")
	new_game()
	check(not Camp.has("porch"), "a new game has a bare cabin")
	check(SaveManager.load_game(), "the game loads")
	check(Camp.has("porch") and Camp.has("hearth") and Camp.has("rope_bed"), "and the cabin comes back as it was")
