class_name FirstDay
extends Node
## The guided first day: a new game teaches itself one small step at a time,
## with no text walls. A little card under the clock names the next thing to
## try, with its button ("[WASD] Walk", "[E] Talk to Galen Clark"), and a
## gold arrow points the way to whatever it's about: bobbing over a campfire
## or a fishing hole when it's on screen, at the screen's edge when it isn't.
## When you do it, the line turns green with a soft chime, and the next one
## slides in.
##
## Each lesson waits for its moment rather than a schedule: gathering comes
## after Clark's opening, the map once you reach Curry Village, cooking and
## the tent once evening comes, the climb once Wren is waiting at Firefall
## Slab, and the cast once Greg's rod is in your pack. A lesson you've
## already done by yourself is marked off without being shown. The climbing
## and fishing screens teach their own buttons (ClimbMinigame._hint,
## FishingMinigame), so these only get you to the start of them.
##
## The Tips setting (pause menu) turns the card off. Saves made before this
## existed load with every lesson done. World adds one before the save
## loads, and starts it on a new game.

## Lesson ids, in the order they're offered. The first one that isn't done
## and whose moment has come is the one on the card.
const LESSONS := ["walk", "talk", "gather", "backpack", "quests", "run", "head_out", "map",
	"cook", "sleep", "climb", "fish"]
## Pixels walked to finish "walk", seconds run to finish "run", and things
## gathered to finish "gather".
const WALK_PIXELS := 96.0
const RUN_SECONDS := 1.2
const GATHER_COUNT := 3
## The hour cooking supper, and then sleeping, come up.
const SUPPER_HOUR := 17
const BED_HOUR := 20
## Seconds a finished line stays (green) before the next one comes.
const DONE_HOLD := 1.1
## Seconds between looks for the thing a lesson points at.
const LOOK_EVERY := 0.4
## The arrow keeps this far (UI pixels) inside the screen's edge.
const EDGE := 14.0

const INK := Color("2a1b14")
const GOLD := Color("f7a64a")
const HEADING := Color(1, 0.831, 0.541)
const DONE_COLOR := Color("9fd77a")

## Lessons done (ids). All of them when the guide is over.
var done: PackedStringArray = PackedStringArray(LESSONS)

var _current := ""
## The lesson whose green "done" line is still showing, and for how long.
var _finishing := ""
var _finish_left := 0.0
var _walked := 0.0
var _ran := 0.0
var _last_pos := Vector2.INF
var _target: Node2D
var _look := 0.0
var _time := 0.0
## What each lesson's target was when last looked for: [_time then, region,
## node or null]. Each look searches the whole region, and the evening's
## cook lesson (until you've cooked) and the bed card asked every frame.
var _found: Dictionary = {}

var _card: PanelContainer
var _line: ButtonHints
var _arrow: Control


func _ready() -> void:
	name = "FirstDay"
	add_to_group("persist")
	add_to_group("first_day")
	GameClock.day_started.connect(_on_day_started.unbind(3))
	Cooking.cooked.connect(func(_meal: String) -> void: mark("cook"))
	_build.call_deferred()


## A new game: every lesson to learn.
func start_new_game() -> void:
	done = PackedStringArray()
	_current = ""
	_finishing = ""
	_walked = 0.0
	_ran = 0.0


## True once every lesson is done.
func is_over() -> bool:
	return LESSONS.all(func(id: String) -> bool: return id in done)


## The lesson on the card now ("" when none is).
func current() -> String:
	return _finishing if _finishing != "" else _current


## Marks [param id] done. If it's the one on the card, the card shows it
## done for a moment first.
func mark(id: String) -> void:
	if id in done:
		return
	done.append(id)
	if id == _current and _shown():
		_finishing = id
		_finish_left = DONE_HOLD
		Sound.play("ui_select", -4.0, 0.0)
	if id == _current:
		_current = ""


func _on_day_started() -> void:
	mark("sleep")


func _build() -> void:
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud == null:
		return
	_arrow = Control.new()
	_arrow.name = "FirstDayArrow"
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiScale.fit(_arrow)
	_arrow.draw.connect(_draw_arrow)
	hud.add_overlay(_arrow)
	_card = PanelContainer.new()
	_card.name = "FirstDayCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.165, 0.106, 0.078, 0.78)
	style.border_color = Color(0.573, 0.412, 0.239, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 2
	style.content_margin_bottom = 3
	_card.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	_card.add_child(rows)
	var title := Label.new()
	title.text = "First day"
	title.add_theme_font_size_override("font_size", 8)
	title.add_theme_color_override("font_color", HEADING)
	rows.add_child(title)
	_line = ButtonHints.new()
	rows.add_child(_line)
	_card.modulate.a = 0.0
	hud.add_overlay(_card)


func _process(delta: float) -> void:
	_time += delta
	var world := get_parent()
	var player: Player = world.player if world and "player" in world else null
	if player == null or is_over() and _finishing == "":
		_hide()
		return
	_watch(player, delta)
	if _finishing != "":
		_finish_left -= delta
		if _finish_left <= 0.0:
			_finishing = ""
	if _finishing == "":
		var next := _next()
		if next != _current:
			_current = next
			_target = null
			_look = 0.0
	_look -= delta
	if _look <= 0.0:
		_look = LOOK_EVERY
		_target = _target_for(current())
	_show(player)


## Counts the steps walked and the seconds run, tick by tick (the tests run
## the clock fast, so a frame can hold many ticks).
func _physics_process(delta: float) -> void:
	var world := get_parent()
	var player: Player = world.player if world and "player" in world else null
	if player == null or is_over():
		return
	if player.can_act and _last_pos != Vector2.INF:
		var step := player.global_position.distance_to(_last_pos)
		if step < 40.0: # not a trip or a door
			_walked += step
			if Input.is_action_pressed("run") and step > 0.0:
				_ran += delta
	_last_pos = player.global_position


## Watches for the lessons done by doing (walking, running, the menus), and
## marks off any whose result is already there.
func _watch(_player: Player, _delta: float) -> void:
	if _walked >= WALK_PIXELS:
		mark("walk")
	if _ran >= RUN_SECONDS:
		mark("run")
	if _started("clark_register"):
		mark("talk")
	if Perks.stat("forage") >= GATHER_COUNT:
		mark("gather")
	var journal := get_tree().get_first_node_in_group("journal")
	if journal and journal.is_open():
		if journal.tab() == Journal.Tab.BACKPACK:
			mark("backpack")
		elif journal.tab() == Journal.Tab.QUESTS:
			mark("quests")
	var map := get_tree().get_first_node_in_group("park_map")
	if map and map.is_open():
		mark("map")
	var region_id := _region_id()
	if region_id == "curry_village" or _started("shop_guidebook"):
		mark("head_out")
	if QuestLog.has_climbed("firefall_slab"):
		mark("climb")
	if Perks.stat("casts") > 0:
		mark("fish")


## The first lesson not done whose moment has come, or "".
func _next() -> String:
	for id: String in LESSONS:
		if id not in done and _ready_for(id):
			return id
	return ""


func _ready_for(id: String) -> bool:
	match id:
		"walk":
			return true
		"talk", "gather", "backpack", "quests":
			return _all_done(LESSONS.slice(0, LESSONS.find(id)))
		"run":
			return _all_done(["walk", "talk"])
		"head_out":
			return _region_id() == Park.HOME_REGION and _all_done(["talk", "gather"])
		"map":
			return _region_id() == "curry_village"
		"cook":
			return GameClock.hour >= SUPPER_HOUR and _has_raw_food() and _target_for("cook") != null
		"sleep":
			return GameClock.hour >= BED_HOUR or GameClock.hour < 4
		"climb":
			return QuestLog.active.has("partner_apron")
		"fish":
			return Gear.count(Fishing.ROD) > 0
	return false


## The card's line for [param id], with the buttons for the device in use.
func text_for(id: String) -> String:
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	var pad := func(keyboard: String, gamepad: String) -> String:
		return hud.prompt(keyboard, gamepad) if hud else keyboard
	var use: String = pad.call("E", "A")
	match id:
		"walk":
			return "[%s] Walk around camp" % pad.call("WASD", "Stick")
		"talk":
			return "[%s] Talk to Galen Clark" % use
		"gather":
			return "[%s] Gather something to eat  %d/%d" % [use, mini(Perks.stat("forage"), GATHER_COUNT), GATHER_COUNT]
		"backpack":
			return "[B] Look in your backpack" if pad.call("k", "g") == "k" else "[Y] then [RB] Backpack"
		"quests":
			return "[Q] See what to do next" if pad.call("k", "g") == "k" else "[Y] then [RB] Quests"
		"run":
			return "Hold [%s] to run" % pad.call("Shift", "B")
		"head_out":
			return "Out the south gate to Curry Village"
		"map":
			return "[%s] Look at the map" % pad.call("M", "Back")
		"cook":
			return "[%s] Cook supper at the campfire" % use
		"sleep":
			return "[%s] Sleep in your tent" % use if _target_for("sleep") != null else "Head back to your tent at Lamon's camp"
		"climb":
			return "[%s] Climb Firefall Slab with Wren" % use
		"fish":
			return "Face the water, [%s] Cast" % use
	return ""


## [method _find_target], looked up again only after LOOK_EVERY or in
## another region.
func _target_for(id: String) -> Node2D:
	var world := get_parent()
	var region: Region = world.region if world and "region" in world else null
	var seen: Array = _found.get(id, [])
	if seen.is_empty() or _time - float(seen[0]) >= LOOK_EVERY or seen[1] != region:
		seen = [_time, region, _find_target(id)]
		_found[id] = seen
	return seen[2] if is_instance_valid(seen[2]) else null


## What lesson [param id] points at in this region, or null.
func _find_target(id: String) -> Node2D:
	var world := get_parent()
	var region: Region = world.region if world and "region" in world else null
	if region == null or id == "":
		return null
	var player: Player = world.player
	var best: Node2D = null
	var best_d := INF
	for node in _candidates(region, id):
		var d := (node as Node2D).global_position.distance_squared_to(player.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _candidates(region: Region, id: String) -> Array:
	match id:
		"talk":
			return region.find_children("*", "NPC", true, false).filter(func(n: NPC) -> bool:
				return n.visible and n.character and n.character.id == "galen_clark")
		"gather":
			return region.find_children("*", "Forageable", true, false)
		"head_out":
			return region.find_children("*", "RegionExit", true, false).filter(func(n: RegionExit) -> bool:
				return n.target_region == "curry_village")
		"cook":
			return region.find_children("*", "Station", true, false).filter(func(n: Station) -> bool:
				return n.station == "campfire")
		"sleep":
			return region.find_children("Tent", "", true, false).filter(func(n: Node) -> bool:
				return n is Node2D and n.has_signal("sleep_requested"))
		"climb":
			return region.find_children("*", "ClimbStart", true, false).filter(func(n: ClimbStart) -> bool:
				return n.route and n.route.id == "firefall_slab")
		"fish":
			return region.find_children("*", "FishingWater", true, false)
	return []


## True when the card should be up: tips on, nothing covering the screen.
func _shown() -> bool:
	var world := get_parent()
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if not Settings.tips or hud == null or hud.is_covered() or get_tree().paused:
		return false
	if world and world.get("_busy"):
		return false
	return world.player.can_act


func _show(_player: Player) -> void:
	if _card == null:
		return
	var id := current()
	var up := id != "" and _shown()
	if up:
		_line.text = text_for(id)
		_line.add_theme_color_override("font_color", DONE_COLOR if id == _finishing else Color.WHITE)
		_card.size = Vector2.ZERO
		var hud := get_tree().get_first_node_in_group("hud") as HUD
		var below := hud.clock_panel.get_rect().end.y + 3.0 if hud else 40.0
		var width := _card.get_combined_minimum_size().x
		_card.position = Vector2(UiScale.SCREEN.x - 4.0 - width, below).round()
	var goal := 1.0 if up else 0.0
	if id == _finishing and _finish_left < 0.25:
		goal = 0.0 # fades out as the next comes
	_card.modulate.a = move_toward(_card.modulate.a, goal, get_process_delta_time() * 6.0)
	_arrow.visible = up and id != _finishing and is_instance_valid(_target)
	_arrow.queue_redraw()


func _hide() -> void:
	if _card:
		_card.modulate.a = 0.0
		_arrow.visible = false


## The gold arrow: over the thing when it's on screen (unless a person's
## quest bubble already marks them), at the edge pointing to it when not.
func _draw_arrow() -> void:
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		return
	var at := UiScale.from_view(_target.get_global_transform_with_canvas().origin)
	var bob := sin(_time * 4.0) * 2.0
	var inside := Rect2(Vector2(EDGE, EDGE), UiScale.SCREEN - Vector2(EDGE, EDGE) * 2.0)
	if inside.has_point(at):
		if _target is NPC:
			return
		_chevron(Vector2(at.x, UiScale.from_view(_top_of(_target)).y - 3.0 + bob).round(), Vector2.DOWN)
		return
	var middle := UiScale.SCREEN / 2.0
	var dir := (at - middle).normalized()
	# where the line from the middle to it leaves the inside rectangle
	var t := INF
	if dir.x != 0.0:
		t = minf(t, ((inside.end.x if dir.x > 0.0 else inside.position.x) - middle.x) / dir.x)
	if dir.y != 0.0:
		t = minf(t, ((inside.end.y if dir.y > 0.0 else inside.position.y) - middle.y) / dir.y)
	_chevron((middle + dir * t + dir * bob).round(), dir)


## The top middle of [param node]'s picture, in the view's pixels: the
## highest of its sprites, or a little over its feet if it draws itself.
func _top_of(node: Node2D) -> Vector2:
	var origin := node.get_global_transform_with_canvas().origin
	var top := origin + Vector2(0, -12)
	for child in node.get_children():
		if child is Sprite2D and child.visible and child.texture:
			var rect: Rect2 = child.get_rect()
			var point: Vector2 = child.get_global_transform_with_canvas() * Vector2(rect.get_center().x, rect.position.y)
			if point.y < top.y:
				top = Vector2(origin.x, point.y)
	return top


## A small pixel arrow pointing [param dir], its tip at [param tip].
func _chevron(tip: Vector2, dir: Vector2) -> void:
	var side := Vector2(-dir.y, dir.x)
	var back := tip - dir * 7.0
	var points := PackedVector2Array([tip, back + side * 5.0, back - side * 5.0])
	var rim := PackedVector2Array([tip + dir * 1.5, back + side * 6.5 - dir, back - side * 6.5 - dir])
	_arrow.draw_colored_polygon(rim, INK)
	_arrow.draw_colored_polygon(points, GOLD)
	_arrow.draw_line(back - dir * 4.0, back, INK, 4.0)
	_arrow.draw_line(back - dir * 3.0, back, GOLD, 2.0)


func _started(quest_id: String) -> bool:
	return QuestLog.active.has(quest_id) or QuestLog.is_completed(quest_id)


func _all_done(ids: Array) -> bool:
	return ids.all(func(id: String) -> bool: return id in done)


func _region_id() -> String:
	var world := get_parent()
	var region: Region = world.region if world and "region" in world else null
	return region.region_id if region else ""


## True if there's raw forage in the pack for the pot.
func _has_raw_food() -> bool:
	for id: String in Inventory.items:
		var item := ItemDB.get_item(id)
		if item and item.forage_per_day > 0 and Inventory.count(id) > 0:
			return true
	return false


func save_data() -> Dictionary:
	return {"done": Array(done)}


func load_data(data: Dictionary) -> void:
	done = PackedStringArray(data.get("done", LESSONS))
	_current = ""
	_finishing = ""
