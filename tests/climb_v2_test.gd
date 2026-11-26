extends Node
## Headless test of the climbing v2 foundation (scripts/climb/v2): the switch,
## the system registry and its stubs, the frozen fixture pitch, the move
## pipeline (pure previews), a scripted climber getting up the fixture
## through every stub (clips, a cam, the crux, the belay), a fall, snapshots,
## determinism, verbs on the screen, and the old climbing left alone.
## Other threads' tests pin the systems they don't own to stubs the same way
## (ClimbSystems.pin_stubs_except).
## Run: godot --headless --path . res://tests/climb_v2_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	ClimbSystems.pin_stubs_except([])
	test_flag()
	test_registry()
	test_fixture()
	test_preview_is_pure()
	test_climb_fixture()
	test_fall()
	test_snapshot()
	test_determinism()
	test_verbs()
	await test_screen()
	test_ladder_route()
	test_crux_contract()
	ClimbSystems.pins.clear()
	ClimbV2.force = null
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


static func fixture_route(pitches := 2) -> RouteData:
	var r := RouteData.new()
	r.id = "v2_fixture"
	r.display_name = "Fixture"
	r.grade = "5.8"
	r.protection = "bolts"
	var p: Array[int] = []
	for i in pitches:
		p.append(2)
	r.pitches = p
	return r


## A rack with the sizes the fixture's hand crack takes, plus draws.
static func fixture_rack() -> V2Rack:
	var r := V2Rack.new()
	r.items.assign([
		{"id": "nut_mid", "kind": "nut", "width_min": 2, "width_max": 3, "count": 1, "name": "Nut"},
		{"id": "cam_075", "kind": "cam", "width_min": 3, "width_max": 3, "count": 1, "name": "#0.75"},
		{"id": "cam_1", "kind": "cam", "width_min": 4, "width_max": 4, "count": 1, "name": "#1"},
		{"id": "cam_2", "kind": "cam", "width_min": 5, "width_max": 5, "count": 1, "name": "#2"},
		{"id": "quickdraw", "kind": "draw", "width_min": -1, "width_max": -1, "count": 6, "name": "Quickdraw"},
		{"id": "sling", "kind": "sling", "width_min": -1, "width_max": -1, "count": 2, "name": "Sling"},
	])
	return r


func new_director(seed := 7, pitches := 2) -> ClimbDirector:
	var d := ClimbDirector.new()
	d.setup(fixture_route(pitches), seed, V2Modifiers.new(), fixture_rack())
	return d


func test_flag() -> void:
	ClimbV2.force = null
	OS.set_environment("VALLEY_CLIMB_V2", "")
	check(not ClimbV2.enabled_for("swan_slab") and not ClimbV2.enabled(), "v2 is off unless switched on")
	check(not ClimbStart.uses_v2(fixture_route()), "ClimbStart keeps the old climbing by default")
	OS.set_environment("VALLEY_CLIMB_V2", "swan_slab, nutcracker")
	check(ClimbV2.enabled_for("nutcracker") and not ClimbV2.enabled_for("the_nose") and not ClimbV2.enabled(), "VALLEY_CLIMB_V2 can list routes")
	OS.set_environment("VALLEY_CLIMB_V2", "1")
	check(ClimbV2.enabled() and ClimbV2.enabled_for("the_nose"), "VALLEY_CLIMB_V2=1 turns it on everywhere")
	OS.set_environment("VALLEY_CLIMB_V2", "")
	ClimbV2.force = true
	check(ClimbStart.uses_v2(fixture_route()), "ClimbV2.force switches ClimbStart over")
	ClimbV2.force = null
	var back := ClimbV2.to_wall(ClimbV2.to_screen(Vector2(2, 5), Vector2(3, 4), Vector2(960, 540)), Vector2(3, 4), Vector2(960, 540))
	check(back.is_equal_approx(Vector2(2, 5)), "to_screen and to_wall undo each other (y up on the wall)")


func test_registry() -> void:
	for name: StringName in ClimbSystems.SYSTEMS.keys() + ClimbSystems.VIEWS.keys():
		check(ClimbSystems.path_for(name).contains("/stubs/") and ResourceLoader.exists(ClimbSystems.path_for(name)), "%s falls back to its stub" % name)
	var d := new_director()
	var s := d.session
	check(s.sys.wall is WallSource and s.sys.body is BodySystem and s.sys.cruxes is CruxSystem
		and s.sys.effort is EffortSystem and s.sys.rope is RopeSystem and s.sys.gear is GearSystem
		and s.sys.falls is FallSystem, "every system has its interface's type")
	for phase: StringName in ClimbDirector.PHASES:
		check(d._phases.has(phase), "phase %s has a controller" % phase)
	check(ClimbSystems.make(&"climber") is ClimberView and ClimbSystems.make(&"look") is ClimbLook, "the views have their interfaces' types")


func test_fixture() -> void:
	var w := WallSourceStub.new().build_pitch(fixture_route(), 0, 1)
	check(w.holds.size() > 30 and w.cracks.size() == 1 and w.fixed.size() == 4, "the fixture pitch has its holds, crack and fixed pieces")
	check(w.anchor() != null and w.hold("anchor_hold").has_tag("anchor"), "the fixture has a top anchor")
	check(absf(w.crack("crack_a").width_near(Vector2(4.0, 5.2)) - 4.6) < 0.05, "a crack's width reads along it")
	check(w.zones_at(Vector2(3, 10), &"crux").size() == 1 and w.zones_at(Vector2(3, 6), &"rest").size() == 1, "rest and crux zones are found")
	var again := V2Wall.from_dict(w.to_dict())
	check(JSON.stringify(again.to_dict()) == JSON.stringify(w.to_dict()), "a wall round-trips through plain data")


func test_preview_is_pure() -> void:
	var d := new_director()
	d.start()
	d.handle_verb(&"commit", true)
	var s := d.session
	var before := JSON.stringify(s.snapshot())
	var holds: Array[V2Hold] = s.sys.body.reachable(s.pose.next_hand)
	check(not holds.is_empty(), "the start pose can reach holds")
	var a := d.preview(holds[0].id)
	var b := d.preview(holds[0].id, Vector2(0.15, 0))
	var c := d.preview(holds[0].id)
	check(JSON.stringify(s.snapshot()) == before, "previews change nothing (not even random streams)")
	check(JSON.stringify(a.to_dict()) == JSON.stringify(c.to_dict()), "the same preview twice is the same move")
	check(not a.hip.is_equal_approx(b.hip), "the hip shift moves the previewed hips")
	check(a.cost.pump > 0.0 and a.cost.minutes > 0, "effort prices the previewed move")


func test_climb_fixture() -> void:
	var d := new_director()
	d.start()
	var bot := ClimbV2TestBot.new(d)
	var ok := bot.run()
	var s := d.session
	var r := s.result
	check(ok, "a scripted climber tops out the fixture through the stubs (%d steps)" % bot.steps)
	check(r.pitches_done == 2 and r.moves > 20, "two pitches climbed, %d moves" % r.moves)
	check(s.bus.count(&"clipped") >= 8, "bolts, pin and anchors clipped (%d clips)" % s.bus.count(&"clipped"))
	check(s.bus.count(&"piece_placed") >= 1 and s.bus.count(&"piece_offered") >= 1, "a cam offered and placed")
	check(s.bus.count(&"rope_pulled") >= s.bus.count(&"clipped") - 4, "rope pulled up before clips")
	check(s.bus.count(&"piece_cleaned") == s.bus.count(&"piece_placed") and r.placements.size() == s.bus.count(&"piece_placed"), "the partner cleans and grades every placed piece")
	check(s.rack.count("cam_1") + s.rack.count("cam_075") + s.rack.count("cam_2") + s.rack.count("nut_mid") == 4, "cleaned gear is back on the rack")
	check(r.perfect_cruxes + r.slipped_cruxes == 2, "the crux is sent on each pitch")
	check(r.minutes == s.minutes and r.minutes > 0, "the clock ran (%d minutes)" % r.minutes)
	var golden := [&"climb_started", &"pitch_started", &"crux_entered", &"crux_sent", &"pitch_finished",
		&"piece_cleaned", &"pitch_started", &"crux_entered", &"crux_sent", &"pitch_finished", &"piece_cleaned", &"climb_finished"]
	var got := s.bus.names(golden)
	check(got == golden, "the climb's story events come in order: %s" % [got])


func test_fall() -> void:
	var d := new_director(7, 1)
	d.start()
	var bot := ClimbV2TestBot.new(d)
	var s := d.session
	while not d.done and bot.steps < 400 and not (s.rope.clipped.size() >= 2 and s.phase == &"climb" and s.pose.hip.y > 8.0):
		bot.step()
	var top := s.piece(s.rope.top_piece())
	var height := s.pose.tie_in().y
	var fall := d.take_fall()
	check(fall.caught_by == top.id and fall.popped.is_empty(), "a good bolt catches the fall")
	check(absf(fall.length_m - (2.0 * (height - top.pos.y) + fall.slack_m)) < 0.01, "fall length = twice the height above the piece plus slack")
	check(s.phase == &"fall" and s.pose.tags.has("hang") and s.result.falls == 1, "the climber hangs on the rope")
	check(s.bus.names([&"fall_started", &"fall_caught"]) == [&"fall_started", &"fall_caught"], "fall events go out")
	# A bad piece pops, and a fall can never reach the ground on a story route.
	var d2 := new_director(7, 1)
	d2.start()
	var s2 := d2.session
	var bad := V2Piece.new()
	bad.id = "bad"
	bad.kind = &"cam"
	bad.pos = Vector2(3, 2.0)
	bad.quality = 0.1
	bad.clipped = true
	s2.pieces["bad"] = bad
	s2.rope.clipped.append("bad")
	d2.handle_verb(&"commit", true)
	var fall2 := d2.take_fall()
	check(fall2.popped == PackedStringArray(["bad"]) and not s2.rope.clipped.has("bad"), "a poor piece pops and comes off the rope")
	check(fall2.settle_pos.y > s2.wall.start.y and fall2.lands_on == &"", "story routes never deck")
	ClimbV2TestBot.new(d).run()
	check(d.done and s.result.success, "back on the rock and up after the fall")


func test_snapshot() -> void:
	var d := new_director()
	d.start()
	var bot := ClimbV2TestBot.new(d)
	for i in 12:
		bot.step()
	var s := d.session
	var snap := s.snapshot()
	var text := JSON.stringify(snap)
	for i in 15:
		bot.step()
	check(JSON.stringify(s.snapshot()) != text, "climbing changes the snapshot")
	s.restore(snap)
	check(JSON.stringify(s.snapshot()) == text, "restore puts a snapshot back exactly")


func test_determinism() -> void:
	var runs := []
	for i in 2:
		var d := new_director(42)
		d.start()
		ClimbV2TestBot.new(d).run()
		runs.append([d.session.minutes, d.session.bus.names(), JSON.stringify(d.session.result.to_dict())])
	check(runs[0] == runs[1], "the same seed climbs the same way")


func test_verbs() -> void:
	var d := new_director()
	d.start()
	var s := d.session
	check(s.phase == &"read", "a pitch starts with a look up")
	d.handle_verb(&"commit", true)
	check(s.phase == &"climb", "commit starts climbing")
	var y := s.pose.high_point()
	var hand := s.pose.next_hand
	d.handle_verb(&"aim_up", true)
	d.handle_verb(&"commit", true)
	check(s.pose.high_point() > y and s.pose.next_hand != hand, "aim + commit moves a hand up and the other goes next")
	d.handle_verb(&"swap", true)
	check(s.pose.next_hand == hand, "swap changes the next hand")
	var hip := s.pose.hip
	d.handle_verb(&"body", true)
	d.handle_verb(&"aim_left", true)
	d.handle_verb(&"body", false)
	d.handle_verb(&"commit", true)
	check(s.pose.hip.x < hip.x + 0.5, "the body button shifts the hips")
	d.handle_verb(&"cancel", true)
	check(not d.done, "one cancel doesn't retreat")
	d.handle_verb(&"cancel", true)
	check(d.done and not s.result.success, "a second cancel retreats")


func test_screen() -> void:
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(fixture_route(1), 7, V2Modifiers.new(), fixture_rack())
	add_child(screen)
	await get_tree().process_frame
	check(screen.look is ClimbLookStub and screen.climber is ClimberViewStub, "the screen mounts the look and the climber")
	var s := screen.session
	_press(screen, &"use_tool")
	check(s.phase == &"climb", "Space on the screen starts climbing")
	var y := s.pose.high_point()
	_press(screen, &"move_up")
	_press(screen, &"use_tool")
	check(s.pose.high_point() > y, "arrow + Space on the screen moves")
	await get_tree().process_frame
	var got := []
	screen.finished.connect(func(ok: bool, minutes: int) -> void: got.append([ok, minutes]))
	ClimbV2TestBot.new(screen.director).run()
	await get_tree().process_frame
	check(got.size() == 1 and got[0][0] == true and got[0][1] > 0, "the screen says when it's done, like the old one")
	check(not is_instance_valid(screen) or screen.is_queued_for_deletion(), "the screen closes itself")


func _press(screen: ClimbScreenV2, action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	screen._unhandled_input(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	screen._unhandled_input(up)


func test_ladder_route() -> void:
	var route: RouteData = load("res://data/routes/swan_slab_aid.tres") if ResourceLoader.exists("res://data/routes/swan_slab_aid.tres") else null
	if route == null:
		for path in DirAccess.get_files_at("res://data/routes"):
			if path.ends_with(".tres"):
				route = load("res://data/routes/" + path)
				if not route.boulder:
					break
	var d := ClimbDirector.new()
	d.setup(route, 3, V2Modifiers.new(), fixture_rack())
	d.start()
	var ok := ClimbV2TestBot.new(d).run(4000)
	check(ok, "a real route (%s) climbs end to end on the stub ladder wall" % route.id)


## Cruxes that haul at every belay (CONTRACT_VERSION 2's belay special).
class HaulCruxes extends CruxStub:
	func belay_special() -> StringName:
		return &"haul"


func test_crux_contract() -> void:
	var d := new_director()
	d.start()
	d.handle_verb(&"commit", true)
	var s := d.session
	var hold: V2Hold = s.sys.body.reachable(s.pose.next_hand)[0]
	var m := d.preview(hold.id)
	var base := m.cost.pump
	m.crux_cost = 2.0
	s.sys.effort.price(m)
	check(absf(m.cost.pump - base * 2.0) < 0.0001, "effort multiplies a move's pump by its crux cost")
	m.crux_risk = 0.4
	s.sys.falls.risk(m)
	check(absf(m.risk - 0.4) < 0.0001, "falls adds a move's crux risk")
	check(s.sys.gear.can_rack() == not s.sys.gear.placeable().is_empty() and s.sys.gear.grade_for(V2Piece.new()).is_empty(), "gear's can_rack and grade_for default sensibly")
	d.hang_at(Vector2(4, 5), PackedStringArray(["aiders"]))
	check(s.pose.hip == Vector2(4, 5) and s.pose.tags.has("hang") and s.pose.tags.has("aiders"), "hang_at hangs the climber with tags")
	d.count_aid(2)
	check(s.result.aid_moves == 2, "count_aid counts aid moves")
	var h := ClimbDirector.new()
	h.setup(fixture_route(1), 7, V2Modifiers.new(), fixture_rack())
	h.session.sys.cruxes = HaulCruxes.new()
	h.session.sys.cruxes.attach(h.session)
	h.start()
	var ok := ClimbV2TestBot.new(h).run()
	var names := h.session.bus.names([&"pitch_finished", &"special_started", &"special_step", &"special_finished", &"piece_cleaned"])
	check(ok and names.slice(0, 4) == [&"pitch_finished", &"special_started", &"special_step", &"special_finished"] and names.has(&"piece_cleaned"),
		"a belay special (the haul) runs before the belay: %s" % [names])
