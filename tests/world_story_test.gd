extends Node
## Headless test of the story wired into the real World: new-game setup,
## story overlays in each region, the first quest, and the journal.
## Run: godot --headless --path . res://tests/world_story_test.tscn
## Uses its own save file, so it never touches a real save.
var failures := 0
func check(c: bool, what: String) -> void:
	print(("PASS  " if c else "FAIL  ") + what)
	if not c: failures += 1

func find_named(root: Node, n: String) -> Node:
	return root.find_child(n, true, false)

func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://world_story_test_save.json"
	SaveManager.delete_save()
	var world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	check(world.region.region_id == "lamon_homestead", "starts at the homestead")
	check(Gear.count("approach_shoes") == 1, "new game gives starting gear")
	check(Recipes.knows("yerba_buena_tea"), "new game gives starting recipes")
	check(find_named(world.region, "Chuckah") != null, "homestead has the chuckah")
	check(find_named(world.region, "Campfire") != null, "homestead has a campfire")
	check(get_tree().get_first_node_in_group("journal") != null, "journal exists")
	world._enter_region("yosemite_valley", "apron_base")
	await get_tree().process_frame
	check(find_named(world.region, "GlacierPointApron") != null, "Apron climb start is placed")
	world._enter_region("yosemite_village", "camp_4")
	await get_tree().process_frame
	var leonard = find_named(world.region, "DickLeonard")
	check(leonard != null and leonard.get_parent() == world.region.entities, "Dick Leonard is in Camp 4's Entities (Yosemite Village)")
	# talk to Leonard: quest starts
	var lines = QuestLog.talk_to("dick_leonard")
	check(QuestLog.active.has("leonard_belay"), "talking to Leonard starts his quest")
	QuestLog.record_climb("swan_slab")
	Inventory.add("acorn_cake", 1)
	lines = QuestLog.talk_to("dick_leonard")
	check(Gear.count("cam") == 2, "Leonard gives 2 cams")
	check(Gear.has_all(load("res://data/routes/glacier_point_apron.tres").required_gear), "player can now start the Apron")
	# leave and come back: no duplicate overlay
	world._enter_region("lamon_homestead", "home")
	world._enter_region("yosemite_village", "camp_4")
	var count := 0
	for n in world.region.entities.get_children():
		if n.name.begins_with("DickLeonard"): count += 1
	check(count == 1, "overlay isn't added twice on revisit")
	# journal renders
	var j = get_tree().get_first_node_in_group("journal")
	j.open()
	check(j.is_open() and GameClock.paused, "journal opens and pauses the clock")
	j.close()
	check(not GameClock.paused, "journal closes and unpauses")
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)
