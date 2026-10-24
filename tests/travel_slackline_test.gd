extends Node
## Headless test of Wren's slackline: the side story that asks for gold at
## Camp 4 (wren_slackline), the line she gives you for it, and rigging it
## between two trees anywhere in the park (TravelSlackline, SlacklineAnchor)
## to walk on the slackline screen.
## Run: godot --headless --path . res://tests/travel_slackline_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const DT := 1.0 / 60.0
const QUEST := "wren_slackline"

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://travel_slackline_test_save.json"
	SaveManager.delete_save()
	new_game()
	test_lines()
	await test_quest()
	await test_old_gold()
	await test_rigging()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func new_game() -> void:
	Inventory.start_new_game()
	Inventory.items.clear()
	Gear.start_new_game()
	QuestLog.start_new_game()
	Perks.start_new_game()
	GameClock.paused = true


## A rig's line is sized to the gap between its trees: longer is harder,
## the wind finds the longest, and gold takes tricks with flow.
func test_lines() -> void:
	var short := SlacklineState.travel_line(8)
	var mid := SlacklineState.travel_line(18, "Mirror Lake")
	var long := SlacklineState.travel_line(28)
	check(short.id == SlacklineState.TRAVEL and mid.meters == 18 and "Mirror Lake" in mid.blurb, "a rig is your own line, named for where it's strung")
	check(short.walk_time < mid.walk_time and mid.walk_time < long.walk_time and short.sag < long.sag, "a longer rig takes longer to walk and sags more")
	check(short.young and not long.young and short.height == "knee-high" and long.height == "head-high", "a short rig is low between slim trees, a long one high")
	check(not mid.gusts and long.gusts, "the wind only finds a long rig")
	check(long.gold > short.gold and long.silver < long.gold, "gold asks more on a long rig")
	for l: Dictionary in [short, mid, long]:
		var plain := 0
		var trick := 0
		for seed in 8:
			var a := SlacklineState.new(seed, "", l)
			_run(a, false)
			plain = maxi(plain, a.medal())
			var b := SlacklineState.new(seed, "", l)
			_run(b, true)
			trick = maxi(trick, b.medal())
		check(plain >= 1 and plain < 3 and trick == 3, "a %d m rig: steady walking crosses but isn't gold, tricks with flow are (%d, %d)" % [l.meters, plain, trick])


func _run(state: SlacklineState, tricks: bool) -> void:
	for i in int(200.0 / DT):
		if tricks and state.can_trick():
			state.start_trick()
		state.step(DT, _balance(state))
		if state.status != SlacklineState.Status.WALKING:
			break


static func _balance(state: SlacklineState) -> float:
	return clampf(-(state.lean * 2.5 + state.lean_speed * 0.8), -1.0, 1.0)


## Wren offers the line after the rest of the Apron, and hands it over for a
## gold medal on a Camp 4 line.
func test_quest() -> void:
	new_game()
	var quest := QuestLog.get_quest(QUEST)
	check(quest != null and not quest.main_line and quest.giver == "wren_alvarez", "Gold on the Line is Wren's side story")
	check(ItemDB.get_item("travel_slackline") != null and ItemDB.get_item("travel_slackline").icon != null, "her slackline is an item with an icon")
	QuestLog.completed.append_array(["clark_register", "shop_guidebook", "shop_outfit", "partner_apron", "leonard_belay"])
	QuestLog.talk_to("wren_alvarez")
	check(QuestLog.active.has("wren_apron") and not QuestLog.active.has(QUEST), "the Apron comes first")
	QuestLog.active.erase("wren_apron")
	QuestLog.completed.append("wren_apron")
	var lines := QuestLog.talk_to("wren_alvarez")
	check(QuestLog.active.has(QUEST) and lines.any(func(l: Dictionary) -> bool: return "Camp 4" in l.text), "then Wren offers her slackline for a Camp 4 gold")
	lines = QuestLog.talk_to("wren_alvarez")
	check(QuestLog.active.has(QUEST) and lines.any(func(l: Dictionary) -> bool: return "flow" in l.text), "until there's a gold, she reminds you how")
	# A crossing that isn't gold doesn't count.
	var screen := await _screen()
	screen.begin("short")
	screen.go()
	await _walk(screen, false)
	check(screen.last_medal in [1, 2] and not QuestLog.is_unlocked(SlacklineMinigame.GOLD), "a bronze or silver isn't enough (%d)" % screen.last_medal)
	screen.begin("short")
	screen.go()
	await _walk(screen, true)
	check(screen.last_medal == 3 and QuestLog.is_unlocked(SlacklineMinigame.GOLD), "a gold on the short line counts")
	check("Wren" in str(screen._result.note), "and the results card sends you to Wren")
	check(QuestLog.marker_for("wren_alvarez") == "?", "Wren shows a ? to hand it in")
	screen.leave()
	await get_tree().process_frame
	lines = QuestLog.talk_to("wren_alvarez")
	check(QuestLog.is_completed(QUEST), "telling Wren finishes the quest")
	check(Inventory.count("travel_slackline") == 1 and QuestLog.is_unlocked(TravelSlackline.ABILITY), "and her slackline is yours")
	check(lines[-1].text.contains("Wren's Slackline"), "the quest-complete line names it (%s)" % lines[-1].text)
	check(not Friendship.giftable_items("wren_alvarez").has("travel_slackline"), "it can't be given away as a gift")


## A gold won before the quest still counts.
func test_old_gold() -> void:
	new_game()
	Perks.record("slackline_medal_long", 3)
	var screen := await _screen()
	check(QuestLog.is_unlocked(SlacklineMinigame.GOLD), "a gold from an older save counts for Wren")
	screen.leave()
	await get_tree().process_frame


## Rigging the line between two trees in an outdoor region, walking it, and
## taking it down.
func test_rigging() -> void:
	new_game()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true
	world._enter_region("curry_village", "")
	await get_tree().process_frame
	var region: Region = world.region
	var rig := region.get_node_or_null("TravelSlackline") as TravelSlackline
	check(rig != null, "an outdoor region can take the line")
	check(rig != null and rig.trees.is_empty() and region.find_children("SlacklineAnchor", "", true, false).is_empty(), "but not before it's yours")
	if rig == null:
		world.queue_free()
		return
	QuestLog.unlocks.append(TravelSlackline.ABILITY)
	QuestLog.changed.emit()
	check(rig.trees.size() >= 4, "once it's yours, the trees here can hold it (%d)" % rig.trees.size())
	check(rig.trees.all(func(t: Node) -> bool: return t.has_node("SlacklineAnchor")), "each with an anchor to interact with")
	var snags := region.entities.get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("TreeSnag") or String(n.name).begins_with("TreeDogwood"))
	check(snags.all(func(n: Node) -> bool: return not n.has_node("SlacklineAnchor")), "dead snags and dogwoods won't hold a line (%d)" % snags.size())
	check(TravelSlackline.kind_of(rig.trees[0]) != "", "each tree knows what it is (%s)" % TravelSlackline.kind_of(rig.trees[0]))
	check(not TravelSlackline.can_span(Vector2.ZERO, Vector2(60, 0)) and not TravelSlackline.can_span(Vector2.ZERO, Vector2(600, 0))
		and not TravelSlackline.can_span(Vector2.ZERO, Vector2(150, 150)) and TravelSlackline.can_span(Vector2.ZERO, Vector2(240, 40)),
		"a line wants trees a few strides apart, side by side")
	var a: StaticBody2D = null
	var b: StaticBody2D = null
	for t in rig.trees:
		b = rig.partner_for(t)
		if b:
			a = t
			break
	check(a != null, "two trees here are the right distance apart")
	if a == null:
		world.queue_free()
		return
	var anchor: SlacklineAnchor = a.get_node("SlacklineAnchor")
	check(anchor.get_prompt() == "Rig your slackline", "the anchor offers to rig it")
	rig.rig(a, b)
	check(rig.is_rigged_on(a) and rig.is_rigged_on(b) and region.entities.has_node("RiggedSlackline"), "rigged, the webbing runs between the two trunks")
	check(anchor.get_prompt() == "Walk your slackline", "then offers to walk it")
	var line := rig.line()
	check(line.id == SlacklineState.TRAVEL and line.meters == TravelSlackline.meters_between(a, b) and region.display_name in line.blurb, "the line is sized to the gap (%d m)" % line.meters)
	# Walking it: no line picker, no crowd, straight onto your own line.
	var screen: SlacklineMinigame = load("res://scripts/slackline/slackline_minigame.gd").new()
	screen.setup(3, line)
	get_tree().root.add_child(screen)
	await get_tree().process_frame
	check(screen.is_travel() and screen._phase == SlacklineMinigame.Phase.READY and screen.state.line.id == SlacklineState.TRAVEL, "the screen steps you straight onto your line")
	screen.go()
	var crossings := Perks.stat("slackline_crossings")
	await _walk(screen, true)
	check(screen.state.status == SlacklineState.Status.WALKED and screen._phase == SlacklineMinigame.Phase.RESULT, "you can walk it end to end")
	check(Perks.stat("slackline_crossings") == crossings + 1, "and it counts toward Slackliner's Feet")
	check(Inventory.count("king_cobra") == 0, "there's no six-pack out here")
	check(screen._speech.text == "", "and nobody's watching to call out")
	var left := [false]
	screen.finished.connect(func(_walked: bool) -> void: left[0] = true)
	screen._phase_age = 99.0
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	screen._input(esc)
	check(left[0], "Esc on the results card puts you back by the trees")
	await get_tree().process_frame
	# Rigging somewhere else takes it down here first; you own one line.
	var c: StaticBody2D = null
	var d: StaticBody2D = null
	for t in rig.trees:
		var p := rig.partner_for(t)
		if p and t != a and t != b and p != a and p != b:
			c = t
			d = p
			break
	if c:
		rig.rig(c, d)
		check(not rig.is_rigged_on(a) and rig.is_rigged_on(c) and region.entities.find_children("RiggedSlackline", "", false, false).size() <= 1, "rigging it elsewhere moves your one line")
	rig.take_down()
	await get_tree().process_frame
	check(rig.rigged.is_empty() and not region.entities.has_node("RiggedSlackline"), "taking it down leaves the trees as they were")
	world.queue_free()
	await get_tree().process_frame


func _screen() -> SlacklineMinigame:
	var screen: SlacklineMinigame = load("res://scripts/slackline/slackline_minigame.gd").new()
	screen.setup(11)
	get_tree().root.add_child(screen)
	await get_tree().process_frame
	return screen


## Walks the screen's line with a steady hand (and every trick it can, if
## [param tricks]) the way the screen does each frame.
func _walk(screen: SlacklineMinigame, tricks: bool) -> void:
	var s := screen.state
	for i in int(200.0 / DT):
		if tricks and s.can_trick():
			s.start_trick()
		s.step(DT, _balance(s))
		for e in s.take_events():
			screen._on_event(e)
		if s.status != SlacklineState.Status.WALKING:
			break
	await get_tree().process_frame
