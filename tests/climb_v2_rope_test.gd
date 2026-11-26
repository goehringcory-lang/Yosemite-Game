extends Node
## Headless test of climbing v2's rope and clipping (thread 5,
## scripts/climb/v2/rope): pulls from geometry, slack, the clip phase, the
## scary clip, slings, drag, back-clips and the rope rolling out, fall
## lengths, the stick-clip, and a bot climbing the fixture on the real rope.
## Every other system is pinned to its stub.
## Run: godot --headless --path . res://tests/climb_v2_rope_test.tscn
## Exit code is the number of failed checks.

const Base := preload("res://tests/climb_v2_test.gd")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	ClimbSystems.pin_stubs_except([&"rope"])
	test_registry()
	test_pulls()
	test_clip_phase()
	test_scary_clip()
	test_bail()
	test_slings_and_drag()
	test_back_clip()
	test_too_high()
	test_bot_climb()
	ClimbSystems.pins.clear()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


func new_director(seed := 7, pitches := 2) -> ClimbDirector:
	var d := ClimbDirector.new()
	d.setup(Base.fixture_route(pitches), seed, V2Modifiers.new(), Base.fixture_rack())
	d.start()
	d.handle_verb(&"commit", true)
	return d


## Puts the hips at [param hip] (tests only; body owns the pose).
func stand(s: ClimbSession, hip: Vector2) -> void:
	s.pose.hip = hip


func test_registry() -> void:
	var d := new_director()
	var s := d.session
	check(ClimbSystems.is_real(&"rope") and s.sys.rope is ClimbRope, "the real rope plugs in")
	check(s.rope.clipped == PackedStringArray(["bolt_1"]) and s.rack.count("quickdraw") == 5, "story routes start with the first bolt stick-clipped")
	var free := V2Modifiers.new()
	free.story = false
	var d2 := ClimbDirector.new()
	d2.setup(Base.fixture_route(1), 7, free, Base.fixture_rack())
	d2.start()
	check(d2.session.rope.clipped.is_empty(), "other routes clip the first bolt themselves")


func test_pulls() -> void:
	var d := new_director()
	var s := d.session
	var rope: ClimbRope = s.sys.rope
	var needs := []
	for hip_y: float in [7.0, 6.6, 6.2, 5.8]:
		stand(s, Vector2(3, hip_y))
		needs.append(rope.arms_needed("bolt_2"))
	check(needs[0] == 1, "a bolt at the waist is one pull (%s)" % [needs])
	check(needs[3] == 3 and needs[1] <= needs[2] and needs[2] <= needs[3], "a bolt overhead takes more, up to three (%s)" % [needs])
	var plan := rope.pull_plan(s.piece("bolt_2"), RopeTuning.DRAW_M)
	stand(s, Vector2(3, 5.0))
	check(rope.pull_plan(s.piece("bolt_2"), RopeTuning.DRAW_M).overflow > 0.0, "rope past three pulls is extra pump, not free")
	stand(s, Vector2(3, 6.2))
	var before := rope.arms_needed("bolt_2")
	s.rope.slack_m = 1.0
	check(rope.arms_needed("bolt_2") < before, "slack already out means fewer pulls")
	s.rope.slack_m = 0.0
	check(plan.need >= 1, "pull plans are queries")


func test_clip_phase() -> void:
	var d := new_director()
	var s := d.session
	stand(s, Vector2(3, 6.4))
	var draws := s.rack.count("quickdraw")
	check(d.handle_verb(&"rope", true) and s.phase == &"clip" and s.rope.arms_pulled == 0, "R hangs a draw on the bolt")
	check(s.rope.pulling_for == "bolt_2" and s.rack.count("quickdraw") == draws - 1, "the draw comes off the harness")
	var need := s.sys.rope.arms_needed("bolt_2")
	var fall_before: float = s.sys.rope.fall_preview().drop_m
	d.handle_verb(&"rope", true)
	check(s.rope.arms_pulled == 1 and s.rope.slack_m > 0.4, "a pull brings up an arm-length of slack")
	if need > 1:
		check(s.sys.rope.fall_preview().drop_m > fall_before, "falling with rope in your hand is a longer fall")
	for i in need - 1:
		d.handle_verb(&"rope", true)
	check(s.phase == &"climb" and s.rope.top_piece() == "bolt_2", "the last pull clips it")
	check(s.rope.slack_m < 0.7 and s.piece("bolt_2").sling_m == RopeTuning.DRAW_M, "clipping takes the pulled rope in")
	check(s.bus.names([&"rope_pulled", &"clipped"]).slice(-2) == [&"rope_pulled", &"clipped"], "rope_pulled then clipped go out")
	var p := s.piece("bolt_2")
	check(not p.back_clipped, "a straight-up line never back-clips")
	# Climbing on uses the leftover slack; the belayer takes in the rest.
	s.rope.slack_m = 0.5
	s.bus.send(&"move_committed", [V2Move.new()])
	check(s.rope.slack_m <= 0.25, "the belayer takes slack in as you climb")
	var f: Dictionary = s.sys.rope.fall_preview()
	check(f.caught_by == "bolt_2", "the fall preview names the piece that catches")


func test_scary_clip() -> void:
	var d := new_director()
	var s := d.session
	stand(s, Vector2(3, 5.9))
	d.handle_verb(&"rope", true)
	check(s.sys.rope.arms_needed("bolt_2") >= 2, "an overhead clip takes several pulls")
	check(s.sys.rope.pump_forecast()[1] > s.effort.pump, "the card forecasts the pump")
	s.effort.pump = 0.995
	d.handle_verb(&"rope", true)
	check(s.phase == &"fall", "pumping out mid-pull is a fall")
	var fall: V2Fall = d.current.get("fall")
	check(fall.slack_m > 0.4 and fall.caught_by == "bolt_1", "you fall holding the slack, onto the bolt below")
	check(s.rope.pulling_for == "" and s.rack.count("quickdraw") == 5, "the draw goes back on the harness")
	check(s.rope.slack_m == 0.0, "the belayer takes it all in once you hang")


func test_bail() -> void:
	var d := new_director()
	var s := d.session
	stand(s, Vector2(3, 6.2))
	d.handle_verb(&"rope", true)
	d.handle_verb(&"rope", true)
	d.handle_verb(&"cancel", true)
	check(s.phase == &"climb" and s.rope.slack_m == 0.0 and s.rack.count("quickdraw") == 5, "Esc drops the rope and the belayer takes it back")
	check(s.rope.clipped == PackedStringArray(["bolt_1"]), "nothing got clipped")


func test_slings_and_drag() -> void:
	var d := new_director()
	var s := d.session
	var rope: ClimbRope = s.sys.rope
	var straight := s.rope.drag
	# A zig-zag: pieces left and right of the line.
	var zig := [Vector2(1.8, 4.6), Vector2(4.2, 5.6), Vector2(1.8, 6.6)]
	var ids := []
	for i in zig.size():
		var p := V2Piece.new()
		p.id = "z%d" % i
		p.kind = &"cam"
		p.pos = zig[i]
		p.sling_m = RopeTuning.OWN_SLING_M
		p.clipped = true
		s.pieces[p.id] = p
		s.rope.clipped.append(p.id)
		ids.append(p.id)
	stand(s, Vector2(3, 7.4))
	var zag := rope.drag_for()
	check(zag > straight + 0.2, "a zig-zag drags (%.2f vs %.2f straight)" % [zag, straight])
	var fetch_straight := ClimbV2.ARM_PULL_M * (1.0 - RopeTuning.DRAG_FETCH_LOSS * straight)
	s.rope.drag = zag
	check(rope.fetch_m() < fetch_straight, "drag means less rope each pull")
	for id: String in ids:
		s.piece(id).sling_m = RopeTuning.LONG_M
	check(rope.drag_for() < zag, "long slings let the rope run straighter (%.2f)" % rope.drag_for())
	var short_fall := 0.0
	s.piece("z2").sling_m = RopeTuning.OWN_SLING_M
	short_fall = rope.drop_to(Vector2(3, 8.5), "z2")
	s.piece("z2").sling_m = RopeTuning.LONG_M
	check(rope.drop_to(Vector2(3, 8.5), "z2") > short_fall, "a long sling makes a longer fall")
	check(rope.bend_at("z1") > 1.0, "the rope bends sharply through the middle piece")
	# Choosing a sling in the clip phase swaps a draw for a sling.
	var d2 := new_director()
	var s2 := d2.session
	stand(s2, Vector2(3, 6.4))
	d2.handle_verb(&"rope", true)
	d2.handle_verb(&"aim_up", true)
	check(s2.rack.count("sling") == 1 and s2.rack.count("quickdraw") == 5, "Up hangs a long sling instead of the draw")
	for i in 4:
		if s2.phase == &"clip":
			d2.handle_verb(&"rope", true)
	check(s2.piece("bolt_2").clipped and s2.piece("bolt_2").sling_m == RopeTuning.LONG_M, "clipped on the long sling")


func test_back_clip() -> void:
	var d := new_director()
	var s := d.session
	var rope: ClimbRope = s.sys.rope
	# The line above bolt_2 now heads right, to the pin.
	s.piece("pin_1").pos = Vector2(4.6, 10.0)
	check(rope.line_dir(s.piece("bolt_2")) == 1 and rope.line_dir(s.piece("bolt_1")) == 0, "the line above a bolt reads left, right or straight")
	stand(s, Vector2(3, 6.6))
	d.handle_verb(&"rope", true)
	var natural := int(rope.hang().gate)
	d.handle_verb(&"aim_right", true)
	check(rope.warns_back_clip(), "a gate facing the line warns before you clip")
	check(rope.cross_body() == (natural != 1), "turning the gate from its natural side is a cross-body clip")
	for i in 4:
		if s.phase == &"clip":
			d.handle_verb(&"rope", true)
	var p := s.piece("bolt_2")
	check(p.clipped and p.back_clipped and s.bus.trace.has([&"clipped", ["bolt_2", true]]), "clipped back-to-front")
	# Climb up and right past it: a fall rolls the rope out of it.
	stand(s, Vector2(3.6, 7.6))
	var rolls: PackedStringArray = rope.fall_preview().rolls
	check(rolls == PackedStringArray(["bolt_2"]), "falling from the gate side rolls the rope out of it")
	stand(s, Vector2(2.6, 7.6))
	check((rope.fall_preview().rolls as PackedStringArray).is_empty(), "on the other side it holds")
	# Re-clip it the right way.
	stand(s, Vector2(3.2, 7.0))
	var fixes := rope.clippable()
	check(not fixes.is_empty() and fixes[fixes.size() - 1].id == "bolt_2", "a back-clipped piece in reach can be re-clipped")
	var snap := s.snapshot()
	check(rope.start_clip("bolt_2") and rope.arms_needed("bolt_2") == 1, "re-clipping is one pull")
	check(int(rope.hang().gate) == -1, "re-clipping turns the gate round")
	rope.pull()
	check(rope.clip() and not p.back_clipped, "re-clipped the right way")
	s.restore(snap)
	check(s.piece("bolt_2").back_clipped and rope.gate_of("bolt_2") == 1, "snapshots keep gates")
	# The fall itself: the rope comes out of bolt_2 and bolt_1 catches.
	stand(s, Vector2(3.6, 7.6))
	var fall := d.take_fall()
	check(fall.caught_by == "bolt_1" and not s.rope.clipped.has("bolt_2"), "the rope rolled out; the bolt below caught it")
	check(s.bus.count(&"unclipped") == 1, "unclipped goes out for it")
	# Story routes never roll the rope out of the last piece on it.
	var d2 := new_director()
	var s2 := d2.session
	(s2.notes[&"rope"].gates as Dictionary)["bolt_1"] = 1
	stand(s2, Vector2(3.8, 4.0))
	check((s2.sys.rope.fall_preview().rolls as PackedStringArray).is_empty(), "never the last piece on a story route")


func test_too_high() -> void:
	var d := new_director()
	var s := d.session
	var rope: ClimbRope = s.sys.rope
	stand(s, Vector2(3, 5.6))
	check(rope.clippable().any(func(p: V2Piece) -> bool: return p.id == "bolt_2"), "a high bolt is clippable with a sling on the rack")
	d.handle_verb(&"rope", true)
	check(s.phase == &"clip" and rope.hang().long, "out of reach on a draw, it takes the long sling")
	d.handle_verb(&"aim_down", true)
	check(rope.too_high(), "back to the short draw it's too high")
	d.handle_verb(&"rope", true)
	check(s.rope.arms_pulled == 0, "no pulling a draw you can't reach")
	d.handle_verb(&"cancel", true)
	check(s.rack.count("quickdraw") == 5 and s.rack.count("sling") == 2, "letting go puts it all back")


func test_bot_climb() -> void:
	var runs := []
	for i in 2:
		var d := ClimbDirector.new()
		d.setup(Base.fixture_route(2), 42, V2Modifiers.new(), Base.fixture_rack())
		d.start()
		var ok := ClimbV2TestBot.new(d).run(900)
		var s := d.session
		check(ok, "a bot climbs the two-pitch fixture on the real rope")
		check(s.bus.count(&"clipped") >= 6 and s.bus.count(&"rope_pulled") >= 4, "it clipped its way up (%d clips)" % s.bus.count(&"clipped"))
		runs.append([s.minutes, s.bus.names(), JSON.stringify(s.result.to_dict())])
	check(runs[0] == runs[1], "the same seed climbs the same way")
	var d := new_director()
	var s := d.session
	var bot := ClimbV2TestBot.new(d)
	for i in 14:
		bot.step()
	var snap := s.snapshot()
	var text := JSON.stringify(snap)
	for i in 10:
		bot.step()
	s.restore(snap)
	check(JSON.stringify(s.snapshot()) == text, "rope state round-trips a snapshot")
	var card: Node = s.sys.rope.make_overlay()
	check(card is RopeCard, "rope mounts its HUD card")
	card.free()
