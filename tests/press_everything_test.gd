extends Node
## Walks up to everything you can interact with in every region and presses
## the button on it, the way a curious player would: people, signs, doors,
## stoves, route signs. Dialogue is read to the end and every choice is
## turned down, so nothing is bought and no minigame starts. Any script error
## an interaction throws shows up in the log.
## Environment:
##   SWEEP_REGIONS  comma-separated region ids (default: every region scene)
##   SWEEP_LATE     1 to play with the story finished (every quest done)
## Also checks that everyone you talk to answers, and that nothing leaves a
## box open or the game busy.
## Run: godot --headless --path . res://tests/press_everything_test.tscn
## Exit code is the number of failed checks (tests/run_all.sh also fails it
## on any SCRIPT ERROR in the log).

## Kinds of thing that always answer in a dialogue box when pressed.
const ALWAYS_SAY := ["npc", "vendor", "climb_start", "station", "chongo", "crow"]

const REGION_DIR := "res://scenes/regions/"

var failures := 0
var world: Node
var root_children: Array[Node] = []
## Interactions that opened a dialogue box.
var talked := 0
## Script name -> [interactions, said something].
var kinds := {}


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://press_everything_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 4.0
	var regions: Array = []
	for file in DirAccess.get_files_at(REGION_DIR):
		if file.ends_with(".tscn"):
			regions.append(file.get_basename())
	if OS.get_environment("SWEEP_REGIONS") != "":
		regions = Array(OS.get_environment("SWEEP_REGIONS").split(","))
	world = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	if OS.get_environment("SWEEP_LATE") == "1":
		for quest: QuestData in QuestLog.QUESTS:
			QuestLog.completed.append(quest.id)
		QuestLog.final_entry = 0
		Gear.add("harness", 1)
	root_children = get_tree().root.get_children()
	var total := 0
	for id: String in regions:
		world._enter_region(id, "")
		await get_tree().physics_frame
		var things: Array[Node] = []
		for node in world.region.find_children("*", "", true, false):
			if node.has_method("interact") and node != world.player and node is Node2D:
				things.append(node)
		for i in things.size():
			# a door may have taken us elsewhere: come back
			if world.region == null or world.region.region_id != id:
				world._enter_region(id, "")
				await get_tree().physics_frame
			if not is_instance_valid(things[i]) or not things[i].is_inside_tree():
				continue
			var thing: Node2D = things[i]
			world.player.global_position = thing.global_position + Vector2(0, 14)
			world.player.can_act = true
			GameClock.paused = true
			var kind: String = thing.get_script().resource_path.get_file().get_basename() if thing.get_script() else thing.get_class()
			thing.interact(world.player)
			var said := await _finish_up()
			if not _settled:
				check(false, "%s %s in %s finishes and hands back control" % [kind, thing.name, id])
			var tally: Array = kinds.get(kind, [0, 0])
			kinds[kind] = [tally[0] + 1, tally[1] + int(said)]
			total += 1
		print("swept %s: %d things" % [id, things.size()])
	print("SWEEP DONE: %d interactions, %d said something" % [total, talked])
	for kind: String in kinds:
		print("  %-24s %4d pressed, %4d said something" % [kind, kinds[kind][0], kinds[kind][1]])
		if kind in ALWAYS_SAY:
			check(kinds[kind][0] == kinds[kind][1], "every %s answers when pressed (%d of %d)" % [kind, kinds[kind][1], kinds[kind][0]])
	check(kinds.get("npc", [0])[0] >= 40, "the sweep met the cast (%d people)" % kinds.get("npc", [0])[0])
	check(total >= 1000, "the sweep pressed on everything (%d)" % total)
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## Reads every box to the end, turns down every choice, and closes anything
## the interaction opened.
var _settled := true
func _finish_up() -> bool:
	var opened := false
	_settled = false
	for frame in 900:
		await get_tree().process_frame
		var boxes := get_tree().get_nodes_in_group("dialogue_box")
		if not boxes.is_empty() and not opened:
			opened = true
			talked += 1
		for box in boxes:
			if not box._options.is_empty():
				box._answer = -1
			else:
				box.reveal_all()
				box._answer = 1
		if boxes.is_empty() and not world._busy and frame > 3:
			_settled = true
			break
	for child in get_tree().root.get_children():
		if not child in root_children and not child.is_in_group("dialogue_box"):
			child.queue_free()
	world.player.can_act = true
	return opened
