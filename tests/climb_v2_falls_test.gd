extends Node
## Headless test of climbing v2 falls and the partner (thread 7,
## scripts/climb/v2/falls): move risk (solid moves never fail, pump
## multiplies, named causes), the hidden meter, which pieces hold or pop,
## zippers capped on story routes, back-clipped draws, swings, ledges, no
## decking on story routes, cams walking and nuts welding, the partner's
## warnings and lines, the fall phase (back on, shake out, lower off), the
## belay (cleaning, grades, minutes), snapshots, determinism, the overlay,
## and the scripted climber topping out with real falls.
## Everything except falls is pinned to its stub.
## Run: godot --headless --path . res://tests/climb_v2_falls_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	ClimbSystems.pin_stubs_except([&"falls"])
	test_registry()
	test_risk()
	test_meter()
	test_hold_chance()
	test_pop_and_catch()
	test_zipper_cap()
	test_back_clip()
	test_no_deck()
	test_ledge_and_swing()
	test_wear_and_cleaning()
	test_partner_warnings()
	test_fall_phase()
	test_snapshot()
	test_determinism()
	await test_overlay()
	test_bot_climbs()
	ClimbSystems.pins.clear()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


static func fixture_route(pitches := 1) -> RouteData:
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


static func fixture_rack() -> V2Rack:
	var r := V2Rack.new()
	r.items.assign([
		{"id": "nut_mid", "kind": "nut", "width_min": 2, "width_max": 3, "count": 2, "name": "Nut"},
		{"id": "cam_075", "kind": "cam", "width_min": 3, "width_max": 3, "count": 1, "name": "#0.75"},
		{"id": "cam_1", "kind": "cam", "width_min": 4, "width_max": 4, "count": 2, "name": "#1"},
		{"id": "cam_2", "kind": "cam", "width_min": 5, "width_max": 5, "count": 2, "name": "#2"},
		{"id": "quickdraw", "kind": "draw", "width_min": -1, "width_max": -1, "count": 8, "name": "Quickdraw"},
		{"id": "sling", "kind": "sling", "width_min": -1, "width_max": -1, "count": 2, "name": "Sling"},
	])
	return r


func new_director(seed := 7, pitches := 1, story := true, device := true) -> ClimbDirector:
	var m := V2Modifiers.new()
	m.story = story
	m.has_device = device
	var d := ClimbDirector.new()
	d.setup(fixture_route(pitches), seed, m, fixture_rack())
	d.start()
	d.handle_verb(&"commit", true)
	return d


## A placed piece at [param pos], clipped, of [param quality].
func add_piece(s: ClimbSession, id: String, pos: Vector2, quality: float, kind := &"cam", gear_id := "cam_1") -> V2Piece:
	var p := V2Piece.new()
	p.id = id
	p.kind = kind
	p.pos = pos
	p.quality = quality
	p.gear_id = gear_id
	s.rack.take(gear_id)
	p.clipped = true
	s.pieces[id] = p
	s.rope.clipped.append(id)
	return p


## Puts the climber's hips at [param hip] (a test shortcut past the body).
func place_climber(s: ClimbSession, hip: Vector2) -> void:
	s.pose.hip = hip


func move_of(s: ClimbSession, hold_id: String, security: float, strain: float, pump := 0.0) -> V2Move:
	var m := V2Move.new()
	m.hold_id = hold_id
	m.valid = true
	m.security = security
	m.strain = strain
	m.reach = 0.6
	m.cost = V2Cost.make(pump)
	return m


func falls(d: ClimbDirector) -> ClimbFalls:
	return d.session.sys.falls as ClimbFalls


func test_registry() -> void:
	check(ClimbSystems.is_real(&"falls") and ClimbSystems.path_for(&"falls").ends_with("falls/falls.gd"), "the registry runs the real falls system")
	var d := new_director()
	check(d.session.sys.falls is ClimbFalls and d.session.sys.falls is FallSystem, "falls extends the FallSystem interface")
	check(d._phases[&"fall"] is ClimbFalls.FallPhase and d._phases[&"belay"] is ClimbFalls.BelayPhase, "falls supplies the fall and belay phases")


func test_risk() -> void:
	var d := new_director()
	var s := d.session
	var f := falls(d)
	var jug := move_of(s, "h0", 0.95, 0.1)
	check(f.risk_of(jug) == 0.0, "a fresh, secure move never fails (risk 0)")
	var hard := move_of(s, "h1", 0.25, 0.7)
	var fresh := f.risk_of(hard)
	s.effort.pump = 0.85
	var pumped := f.risk_of(hard)
	s.effort.pump = 0.0
	check(fresh > 0.0 and pumped > fresh * 2.0, "pump multiplies risk (fresh %.2f, pumped %.2f)" % [fresh, pumped])
	check(pumped <= FallsTuning.RISK_CAP, "risk short of pumped out is capped")
	s.effort.pump = 1.0
	check(f.risk_of(jug) == 1.0 and f.top_cause(jug) == "pump", "pumped out, any move fails, and pump is the cause")
	s.effort.pump = 0.0
	var snap := JSON.stringify(s.snapshot())
	for i in 5:
		d.preview("h1")
		f.risk_of(hard)
		f.causes(hard)
		f.danger_here()
	check(JSON.stringify(s.snapshot()) == snap, "risk, causes and the danger check are pure")
	var crux := move_of(s, "h1", 0.6, 0.3)
	var base := f.risk_of(crux)
	crux.crux_id = "crux_top"
	crux.in_sequence = false
	check(f.risk_of(crux) > base and f.top_cause(crux) == "sequence", "out of sequence on a crux adds risk and is named")
	var dyno := move_of(s, "h1", 0.6, 0.3)
	dyno.tags.append("dyno")
	dyno.reach = 1.0
	check(f.top_cause(dyno) == "dyno" and f.risk_of(dyno) >= FallsTuning.DYNO + FallsTuning.DYNO_OVERSHOOT - 0.01, "a full-stretch dyno is risky")
	s.mods.wet = 0.8
	check(f.risk_of(crux) > base, "wet rock adds risk")
	s.mods.wet = 0.0
	s.mods.assists.append("relaxed")
	check(f.risk_of(hard) < fresh, "the relaxed assist lowers risk")
	s.mods.assists.clear()
	var feet := move_of(s, "h1", 0.05, 0.1)
	check(f.top_cause(feet) == "feet", "no feet is named as the cause")
	var rest := move_of(s, "h1", 0.0, 1.0)
	rest.tags.append("rest")
	check(f.risk_of(rest) == 0.0, "a rest never fails")
	var m := d.preview("h1")
	check(m.risk == f.risk_of(m), "the director's preview fills move.risk")


func test_meter() -> void:
	var d := new_director()
	var s := d.session
	var f := falls(d)
	var m := move_of(s, "h1", 0.3, 0.6)
	m.risk = 0.2
	var pattern := []
	for i in 60:
		pattern.append(f.falls_now(m))
	var twice := false
	var longest := 0
	var run := 0
	for i in pattern.size():
		if pattern[i] and i > 0 and pattern[i - 1]:
			twice = true
		run = 0 if pattern[i] else run + 1
		longest = maxi(longest, run)
	check(not pattern[0] and not twice, "a 20% move never fails first go or twice running")
	check(pattern.count(true) >= 4 and longest <= 9, "...and can't be passed forever (%d falls in 60, longest run %d)" % [pattern.count(true), longest])
	var solid := move_of(s, "h0", 1.0, 0.0)
	solid.risk = 0.0
	var fell := false
	for i in 50:
		fell = f.falls_now(solid) or fell
	check(not fell, "solid moves never fall")
	var out := move_of(s, "h0", 1.0, 0.0)
	out.risk = 1.0
	check(f.falls_now(out) and str(s.note(&"falls").cause) != "", "risk 1 always falls and keeps a cause")


func test_hold_chance() -> void:
	check(ClimbFalls.hold_chance(0.85, 1.0) == 1.0, "a bomber piece (0.8+) never pops")
	check(ClimbFalls.hold_chance(0.75, 0.5) == 1.0 and ClimbFalls.hold_chance(0.2, 0.6) == 0.0, "clear margins hold or pop for sure")
	var mid := ClimbFalls.hold_chance(0.55, 0.55)
	check(absf(mid - 0.5) < 0.01 and ClimbFalls.hold_chance(0.6, 0.55) > mid, "near the line it's a coin weighted by the margin")
	var d := new_director()
	var s := d.session
	var f := falls(d)
	add_piece(s, "c", Vector2(3, 3), 0.55)
	var low := f.severity(Vector2(3, 3.6), "c")
	var high := f.severity(Vector2(3, 6.5), "c")
	check(high > low, "a longer fall loads the piece harder (%.2f vs %.2f)" % [low, high])
	s.mods.has_device = false
	check(f.severity(Vector2(3, 6.5), "c") > high, "no belay device: a harder catch")
	s.mods.has_device = true
	check(f.severity(Vector2(5, 6.5), "c") > high, "a sideways fall loads it harder")
	check(f.holds("bolt_1", Vector2(3, 9)) == 1.0, "bolts always hold")


func test_pop_and_catch() -> void:
	var d := new_director()
	var s := d.session
	var bolt := s.piece("bolt_2")
	bolt.clipped = true
	s.rope.clipped.append("bolt_2")
	add_piece(s, "bad", Vector2(3.2, 9.0), 0.1)
	place_climber(s, Vector2(3.2, 10.0))
	var fall := d.take_fall()
	check(fall.popped == PackedStringArray(["bad"]) and s.piece("bad").popped and fall.caught_by == "bolt_2", "a bad cam pops and the bolt below catches")
	check(not s.rope.clipped.has("bad"), "the popped piece comes off the rope")
	var expect := s.sys.rope.drop_to(fall.from_pos, "bolt_2")
	check(absf(fall.drop_m - expect) < 0.01, "the drop is to the catching piece (%.1f m)" % fall.drop_m)
	check(fall.partner_line.contains("#1"), "the partner names the piece that popped: %s" % fall.partner_line)
	check(s.phase == &"fall" and s.result.falls == 1 and bolt.loaded == 1, "you hang on the rope and the bolt took the load")
	check(fall.cost.pump > 0.0 and fall.cost.minutes > 0, "the fall costs pump and time")
	var good := new_director()
	var gs := good.session
	add_piece(gs, "sweet", Vector2(3, 4.0), 0.9)
	place_climber(gs, Vector2(3, 5.0))
	var gf := good.take_fall()
	check(gf.popped.is_empty() and gf.caught_by == "sweet", "a sweet cam holds")


func test_zipper_cap() -> void:
	var d := new_director()
	var s := d.session
	add_piece(s, "a", Vector2(3, 2.5), 0.05)
	add_piece(s, "b", Vector2(3, 4.0), 0.05)
	add_piece(s, "c", Vector2(3, 5.5), 0.05)
	place_climber(s, Vector2(3, 7.0))
	var fall := d.take_fall()
	check(fall.popped == PackedStringArray(["c", "b"]) and fall.caught_by == "a", "story route: two pieces zip, the third always holds")
	check(fall.partner_line != "", "the partner says something about the zipper: %s" % fall.partner_line)
	var d2 := new_director(7, 1, false)
	var s2 := d2.session
	add_piece(s2, "a", Vector2(3, 2.5), 0.05)
	add_piece(s2, "b", Vector2(3, 4.0), 0.05)
	add_piece(s2, "c", Vector2(3, 5.5), 0.05)
	place_climber(s2, Vector2(3, 7.0))
	var f2 := d2.take_fall()
	check(f2.popped.size() == 3 and f2.caught_by == "", "other routes can zip three")


func test_back_clip() -> void:
	var outs := 0
	var straight := 0
	for seed in 40:
		var d := new_director(seed)
		var s := d.session
		var bolt := s.piece("bolt_2")
		bolt.clipped = true
		bolt.back_clipped = true
		s.rope.clipped.append("bolt_2")
		place_climber(s, Vector2(4.2, 8.5))
		var fall := d.take_fall()
		if fall.popped.has("bolt_2"):
			outs += 1
			if seed == 0 or outs == 1:
				check(not bolt.popped and not bolt.clipped and fall.caught_by == "", "a back-clipped draw lets the rope out (the bolt stays in the rock)")
		var d2 := new_director(seed)
		var s2 := d2.session
		var b2 := s2.piece("bolt_2")
		b2.clipped = true
		b2.back_clipped = true
		s2.rope.clipped.append("bolt_2")
		place_climber(s2, Vector2(3.0, 8.5))
		if d2.take_fall().popped.has("bolt_2"):
			straight += 1
	check(outs > 4 and outs < 30, "across the gate it unclips some of the time (%d/40)" % outs)
	check(straight < outs, "a straight fall unclips it less often (%d/40)" % straight)


func test_no_deck() -> void:
	var d := new_director()
	var s := d.session
	place_climber(s, Vector2(3, 3.0))
	var fall := d.take_fall()
	check(fall.lands_on == &"" and fall.settle_pos.y >= s.wall.start.y + FallsTuning.FLOOR_M - 0.01, "story route: no ground fall, the partner takes in")
	check(bool(s.note(&"falls").hard) and fall.partner_line != "", "a hard catch, and the partner says so: %s" % fall.partner_line)
	var d2 := new_director(7, 1, false)
	var s2 := d2.session
	place_climber(s2, Vector2(3, 3.0))
	var f2 := d2.take_fall()
	check(f2.lands_on == &"ground", "other routes can hit the ground")
	check(not d2.done and s2.phase == &"fall", "...and even then the climb goes on")


func test_ledge_and_swing() -> void:
	var d := new_director()
	var s := d.session
	var z := V2Zone.new()
	z.id = "ledge_a"
	z.kind = &"ledge"
	z.rect = Rect2(2.0, 4.0, 2.5, 0.4)
	s.wall.zones.append(z)
	var bolt := s.piece("bolt_1")
	bolt.clipped = true
	s.rope.clipped.append("bolt_1")
	place_climber(s, Vector2(3, 6.5))
	check(falls(d).danger_here() == &"ledge", "the partner can see a ledge in the fall line")
	var fall := d.take_fall()
	check(fall.lands_on == &"ledge" and fall.settle_pos.y > z.rect.end.y, "a fall onto a ledge stops on it")
	var d2 := new_director()
	var s2 := d2.session
	add_piece(s2, "side", Vector2(1.5, 5.0), 0.9)
	place_climber(s2, Vector2(4.5, 5.5))
	var f2 := d2.take_fall()
	check(f2.swing_m > 2.5 and absf(f2.settle_pos.x - 1.5) < 0.6, "a fall off to the side swings you under the piece (%.1f m)" % f2.swing_m)


func test_wear_and_cleaning() -> void:
	var d := new_director()
	var s := d.session
	var f := falls(d)
	var cam := add_piece(s, "cam", Vector2(3, 4.0), 0.9)
	var nut := add_piece(s, "nut", Vector2(3, 2.0), 0.7, &"nut", "nut_mid")
	add_piece(s, "junk", Vector2(3, 3.0), 0.12, &"cam", "cam_2")
	var over := add_piece(s, "over", Vector2(3, 1.5), 0.85, &"cam", "cam_075")
	over.tags.append("overcammed")
	place_climber(s, Vector2(3, 4.8))
	d.take_fall()
	check(cam.loaded == 1 and f.seen_quality(cam) < cam.quality, "a cam that held a fall walks a little")
	var cams := s.rack.count("cam_1") + s.rack.count("cam_2") + s.rack.count("cam_075") + s.rack.count("nut_mid")
	var report := f.clean_pitch()
	check(report.size() == 4 and report[0].piece_id == "over" and report[3].piece_id == "cam", "the partner cleans from the bottom up")
	check(s.rack.count("cam_1") + s.rack.count("cam_2") + s.rack.count("cam_075") + s.rack.count("nut_mid") == cams + 4, "every piece goes back on the rack")
	var grades := {}
	for r in report:
		grades[r.piece_id] = r.grade
	check(grades.cam == "held" and grades.junk == "prayer" and grades.over == "stuck", "grades: held a fall, a prayer, stuck (%s)" % [grades])
	check(int(report[0].minutes) > FallsTuning.CLEAN_MINUTES, "a stuck cam takes longer to clean")
	var lit := report.filter(func(r: Dictionary) -> bool: return r.highlight)
	check(lit.size() >= 2 and lit.size() <= 4 and report.filter(func(r: Dictionary) -> bool: return r.piece_id == "junk")[0].highlight, "full lines for the worst, the best and the one that held")
	for r in report:
		check(not str(r.line).contains("{") and str(r.line) != "", "grade line reads: %s" % r.line)
		check(not str(r.line).replace(str(r.name), "").contains("0.") and not str(r.line).contains("%"), "no numbers in the partner's verdict on %s" % r.name)
	var n2 := new_director()
	var s2 := n2.session
	var welded := add_piece(s2, "w", Vector2(3, 4.0), 0.75, &"nut", "nut_mid")
	place_climber(s2, Vector2(3, 5.0))
	n2.take_fall()
	check(welded.loaded == 1 and falls(n2).grade_of(welded) == &"stuck", "a nut that held a fall gets welded in")


func test_partner_warnings() -> void:
	var d := new_director()
	var s := d.session
	var f := falls(d)
	var bolt := s.piece("bolt_1")
	bolt.clipped = true
	bolt.back_clipped = true
	s.rope.clipped.append("bolt_1")
	place_climber(s, Vector2(3, 4.5))
	var m := move_of(s, "h1", 1.0, 0.0)
	m.risk = 0.0
	var said := s.bus.count(&"partner_said")
	f.falls_now(m)
	check(s.bus.count(&"partner_said") == said + 1 and str(s.bus.trace[-1][1][0]).to_lower().contains("clip"), "the partner calls out a back-clip")
	f.falls_now(m)
	check(s.bus.count(&"partner_said") == said + 1, "...once")
	bolt.back_clipped = false
	var bolt2 := s.piece("bolt_2")
	bolt2.clipped = true
	s.rope.clipped.append("bolt_2")
	place_climber(s, Vector2(3, 11.5))
	f.falls_now(m)
	check(str(s.bus.trace[-1][1][0]) in PartnerLines.LINES[&"runout"], "a runout gets a warning")
	var n := s.bus.count(&"partner_said")
	for i in 3:
		f.falls_now(m)
	check(s.bus.count(&"partner_said") == n, "the partner doesn't nag")
	var d2 := new_director()
	var s2 := d2.session
	place_climber(s2, Vector2(3, 3.0))
	check(falls(d2).danger_here() == &"deck", "with nothing clipped up high, the partner sees the deck")
	add_piece(s2, "junky", Vector2(3, 2.5), 0.05)
	var m2 := move_of(s2, "h1", 1.0, 0.0)
	m2.risk = 0.0
	falls(d2).falls_now(m2)
	falls(d2).falls_now(m2)
	var junk_lines := 0
	for e: Array in s2.bus.trace:
		if e[0] == &"partner_said" and str(e[1][0]) in PartnerLines.LINES[&"junk"]:
			junk_lines += 1
	check(junk_lines == 1, "junk gear gets one ambiguous \"you sure?\"")


func test_fall_phase() -> void:
	var d := new_director()
	var s := d.session
	place_climber(s, Vector2(3, 4.0))
	s.effort.pump = 0.7
	d.take_fall()
	check(s.bus.names([&"fall_started", &"fall_caught", &"partner_said"]).slice(-3) == [&"fall_started", &"fall_caught", &"partner_said"], "a fall plays: started, caught, the partner speaks")
	var pump := s.effort.pump
	var mins := s.minutes
	check(d.handle_verb(&"rest", true) and s.effort.pump < pump and s.minutes > mins, "hang and shake out on the rope (costs minutes)")
	check(s.phase == &"fall", "...and you're still hanging")
	d.handle_verb(&"cancel", true)
	check(not d.done, "one Esc doesn't lower you off")
	d.handle_verb(&"commit", true)
	check(s.phase == &"climb", "Space gets back on the rock")
	var d2 := new_director()
	place_climber(d2.session, Vector2(3, 4.0))
	d2.take_fall()
	d2.handle_verb(&"cancel", true)
	d2.handle_verb(&"cancel", true)
	check(d2.done and not d2.session.result.success, "two Esc lower off")


func test_snapshot() -> void:
	var d := new_director()
	var s := d.session
	add_piece(s, "c", Vector2(3, 4.0), 0.5)
	place_climber(s, Vector2(3, 5.5))
	var snap := s.snapshot()
	var text := JSON.stringify(snap)
	d.take_fall()
	check(JSON.stringify(s.snapshot()) != text, "a fall changes the snapshot")
	s.restore(snap)
	check(JSON.stringify(s.snapshot()) == text, "restore puts falls' notes back exactly")
	check(JSON.parse_string(JSON.stringify(s.note(&"falls"))) != null, "falls keeps plain data in its notes")


func test_determinism() -> void:
	var runs := []
	for i in 2:
		var d := new_director(42, 2)
		ClimbV2TestBot.new(d).run(3000)
		runs.append([d.session.minutes, d.session.bus.names(), JSON.stringify(d.session.result.to_dict())])
	check(runs[0] == runs[1], "the same seed falls the same way")


func test_overlay() -> void:
	var d := new_director()
	var s := d.session
	var o: FallsOverlay = s.sys.falls.make_overlay()
	add_child(o)
	await get_tree().process_frame
	add_piece(s, "bad", Vector2(3, 4.0), 0.05)
	place_climber(s, Vector2(3, 5.5))
	d.take_fall()
	check(not o.queue.is_empty() and o.partner_label() == "Partner", "the partner's line shows on the pill")
	check(o._tag_label.text.begins_with("Fell ") and o._tag_label.text.contains("#1 popped"), "the fall tag says how far and what popped: %s" % o._tag_label.text)
	var text := FallsOverlay.fall_text({"drop_m": 3.24, "popped": [], "lands_on": "", "caught_kind": "bolt"})
	check(text == "Fell 3.2 m  ·  caught by the bolt", "fall text reads plainly: %s" % text)
	d.handle_verb(&"commit", true)
	d.go(&"belay")
	await get_tree().process_frame
	check(o._card.visible and o._card_rows.get_child_count() >= 1, "the belay card lists what was cleaned")
	d.go(&"climb")
	check(not o._card.visible, "the card closes when you climb on")
	o.queue_free()


func test_bot_climbs() -> void:
	var ok_runs := 0
	var falls_seen := 0
	for seed in [1, 2, 3, 4]:
		var d := new_director(seed, 2)
		var ok := ClimbV2TestBot.new(d).run(3000)
		if ok:
			ok_runs += 1
		falls_seen += d.session.result.falls
		if seed == 1:
			check(d.session.bus.count(&"piece_cleaned") == d.session.bus.count(&"piece_placed"), "the partner cleans every placed piece")
	check(ok_runs == 4, "the scripted climber tops out the fixture with real falls (%d/4, %d falls)" % [ok_runs, falls_seen])
