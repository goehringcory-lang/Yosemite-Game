extends Node
## Headless test of climbing v2 trad gear (thread 6, scripts/climb/v2/gear):
## cam lobes from real Camalot ranges, nuts sliding to a pinch, flare and
## offsets, the fiddle cost, pumping off while fiddling, hidden quality,
## the auto_gear cursor, tug-testing pins, booty, the partner's words, a
## bot up the fixture with real gear, determinism and the overlay.
## Everything but gear is pinned to its stub.
## Run: godot --headless --path . res://tests/climb_v2_gear_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	ClimbSystems.pin_stubs_except([&"gear"])
	test_registry()
	test_cam_math()
	test_cam_readings()
	test_nuts()
	test_flare_and_offsets()
	test_offer_is_pure()
	test_fiddle_cost()
	test_place_flow()
	test_pumped_off()
	test_auto_gear()
	test_pins()
	test_booty()
	test_partner_words()
	test_bot_climbs()
	test_determinism()
	await test_overlay()
	ClimbSystems.pins.clear()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


func rack() -> V2Rack:
	var r := V2Rack.new()
	r.items.assign([
		{"id": "nut_small", "kind": "nut", "width_min": 0, "width_max": 1, "count": 1, "name": "Small nuts", "color": Color("7aa0c0")},
		{"id": "nut_mid", "kind": "nut", "width_min": 2, "width_max": 3, "count": 1, "name": "Mid nuts", "color": Color("d08a3a")},
		{"id": "offset_mid", "kind": "offset", "width_min": 2, "width_max": 3, "count": 1, "name": "Offset nut"},
		{"id": "cam_075", "kind": "cam", "width_min": 3, "width_max": 3, "count": 1, "name": "Cam #0.75", "color": Color("5a9e4a")},
		{"id": "cam_1", "kind": "cam", "width_min": 4, "width_max": 4, "count": 2, "name": "Cam #1", "color": Color("c8382e")},
		{"id": "cam_2", "kind": "cam", "width_min": 5, "width_max": 5, "count": 1, "name": "Cam #2", "color": Color("e0b534")},
		{"id": "quickdraw", "kind": "draw", "width_min": -1, "width_max": -1, "count": 6, "name": "Quickdraw"},
	])
	return r


func new_director(seed := 7, mods: V2Modifiers = null) -> ClimbDirector:
	var d := ClimbDirector.new()
	d.setup(_route(), seed, mods if mods else V2Modifiers.new(), rack())
	d.start()
	return d


func _route() -> RouteData:
	var r := RouteData.new()
	r.id = "v2_fixture"
	r.display_name = "Fixture"
	r.grade = "5.8"
	r.protection = "bolts"
	var p: Array[int] = [2, 2]
	r.pitches = p
	return r


## A straight crack up the middle at [param x] from y 1 to 6 with
## [param widths] at 1, 2.25, 3.5, 4.75, 6 m.
func add_crack(d: ClimbDirector, crack_id: String, widths: Array, flare := 0.0, kind := &"hand", x := 3.4) -> V2Crack:
	var c := V2Crack.new()
	c.id = crack_id
	c.kind = kind
	c.flare = flare
	for i in widths.size():
		c.points.append(Vector2(x, 1.0 + 5.0 * i / (widths.size() - 1)))
	c.widths = PackedFloat32Array(widths)
	d.session.wall.cracks.insert(0, c)
	return c


## Puts the climber so the shoulder is right beside the crack at [param y].
func stand_at(d: ClimbDirector, y: float, x := 3.0) -> void:
	d.session.pose.hip = Vector2(x, y - ClimbV2.TORSO_M)


func test_registry() -> void:
	check(ClimbSystems.is_real(&"gear") and not ClimbSystems.is_real(&"rope"), "the real gear system plugs in by path; the rest stay stubs")
	var d := new_director()
	check(d.session.sys.gear is TradGear, "the session's gear is TradGear")
	check(d.session.sys.gear.make_overlay() is TradGearOverlay, "gear mounts its overlay")


func test_cam_math() -> void:
	check(absf(TradGear.expansion(4, 4.0) - 0.5) < 0.02 and absf(TradGear.expansion(0, 0.0) - 0.5) < 0.02 and absf(TradGear.expansion(7, 7.0) - 0.5) < 0.02,
		"each cam sits half open in a crack of its own number")
	check(TradGear.expansion(3, 4.0) > 0.9 and TradGear.expansion(5, 4.0) < 0.2, "a #0.75 is near its tips and a #2 nearly shut in a #1 crack (real overlaps)")
	var gaps := 0
	var w := 0.0
	while w <= 7.0:
		var best := 0.0
		for size in 8:
			best = maxf(best, TradGear.cam_hold(TradGear.expansion(size, w)))
		if best < 0.85:
			gaps += 1
		w += 0.05
	check(gaps == 0, "a full rack has a good cam for every width from #0.3 to #4 (%d gaps)" % gaps)
	check(TradGear.cam_hold(0.45) > TradGear.cam_hold(0.9) and TradGear.cam_hold(0.9) > 0.0 and TradGear.cam_hold(1.2) == 0.0, "tipped holds less, past the tips nothing")


func test_cam_readings() -> void:
	var d := new_director()
	var g := d.session.sys.gear as TradGear
	add_crack(d, "hands", [3.9, 3.9, 3.9, 3.9, 3.9])
	stand_at(d, 3.0)
	var at := Vector2(3.4, 3.0)
	var sweet := g.offer("cam_1", "hands", at)
	var tip := g.offer("cam_075", "hands", at)
	var shut := g.offer("cam_2", "hands", at)
	check(sweet.fits and sweet.lobes == "sweet" and sweet.state == "sweet", "a #1 in a #1 crack reads sweet")
	check(tip.fits and tip.lobes == "tipped", "a #0.75 there is tipped out (%s)" % tip.state)
	check(shut.fits and shut.lobes == "sweet" and float(shut.e) < 0.2, "a #2 there is snug but goes")
	add_crack(d, "fingers", [1.0, 1.0, 1.0, 1.0, 1.0], 0.0, &"finger", 3.5)
	check(g.offer("cam_2", "fingers", Vector2(3.5, 3.0)).state == "tight" and not g.offer("cam_2", "fingers", Vector2(3.5, 3.0)).fits, "a #2 won't go in a finger crack")
	add_crack(d, "fist", [6.5, 6.5, 6.5, 6.5, 6.5], 0.0, &"fist", 3.3)
	check(g.offer("cam_075", "fist", Vector2(3.3, 3.0)).state == "out", "a #0.75 rattles out of a fist crack")
	check(g.quality_of(sweet) > 0.85 and g.quality_of(tip) < 0.6, "hidden quality follows the lobes")
	for r: Dictionary in [sweet, tip, shut]:
		check(not r.has("quality") and not str(r.note).contains("%") and not _has_digit(str(r.note)), "the reading never shows a number: \"%s\"" % r.note)
	var m := V2Modifiers.new()
	m.knowledge = PackedStringArray(["lobes"])
	var d2 := new_director(7, m)
	add_crack(d2, "hands", [3.9, 3.9, 3.9, 3.9, 3.9])
	stand_at(d2, 3.0)
	var taught := (d2.session.sys.gear as TradGear).offer("cam_075", "hands", at)
	check(str(taught.note) != str(tip.note) and str(taught.note).contains("walk"), "a mentor's 'lobes' lesson makes the reading say more")


func _has_digit(text: String) -> bool:
	for ch in text:
		if ch >= "0" and ch <= "9":
			return true
	return false


func test_nuts() -> void:
	var d := new_director()
	var g := d.session.sys.gear as TradGear
	# Wider above, pinching down to a #0.5 at the bottom.
	add_crack(d, "taper", [2.0, 2.8, 3.6, 3.6, 3.6])
	stand_at(d, 3.0)
	var r := g.offer("nut_mid", "taper", Vector2(3.4, 3.2))
	var stop := V2Data.vec(r.stop)
	check(r.fits and r.seated and r.state == "seated", "a mid nut slid down a tapering crack seats in the pinch (%s)" % r.state)
	check(stop.y < 3.2 and stop.y > 1.5, "it stopped lower down where the crack narrowed (%.2f m)" % stop.y)
	add_crack(d, "parallel", [3.6, 3.6, 3.6, 3.6, 3.6])
	var through := g.offer("nut_mid", "parallel", Vector2(3.4, 3.2))
	check(not through.fits and through.state == "through", "it slides through a parallel crack wider than it")
	add_crack(d, "snug", [3.0, 3.0, 3.0, 3.0, 3.0])
	var shallow := g.offer("nut_mid", "snug", Vector2(3.4, 3.2))
	check(shallow.fits and shallow.state == "shallow" and g.quality_of(shallow) < g.quality_of(r), "in a parallel crack its size it only just catches, and holds less")
	check(g.offer("nut_mid", "fingersmall", Vector2(3.4, 3.2)).fits == false, "no crack, no nut")
	add_crack(d, "thin", [0.5, 0.5, 0.5, 0.5, 0.5], 0.0, &"finger")
	check(g.offer("nut_mid", "thin", Vector2(3.4, 3.2)).state == "tight", "a mid nut is too fat for a thin seam")
	var p := g.place("nut_mid", "taper", Vector2(3.4, 3.2))
	check(p != null and p.kind == &"nut" and absf(p.pos.y - stop.y) < 0.01 and d.session.rack.count("nut_mid") == 0, "placing it sets it where it stopped and takes it off the harness")


func test_flare_and_offsets() -> void:
	var d := new_director()
	var g := d.session.sys.gear as TradGear
	add_crack(d, "flared", [2.0, 2.8, 3.6, 3.6, 3.6], 0.6, &"pinscar")
	stand_at(d, 3.0)
	var nut := g.offer("nut_mid", "flared", Vector2(3.4, 3.2))
	var off := g.offer("offset_mid", "flared", Vector2(3.4, 3.2))
	check(not nut.fits and nut.state == "flare", "a plain nut skates in a flared pin scar")
	check(off.fits and off.seated, "an offset seats in the same scar")
	add_crack(d, "flared_hands", [4.0, 4.0, 4.0, 4.0, 4.0], 0.5)
	var cam := g.offer("cam_1", "flared_hands", Vector2(3.4, 3.0))
	add_crack(d, "clean_hands", [4.0, 4.0, 4.0, 4.0, 4.0], 0.0)
	var clean := g.offer("cam_1", "clean_hands", Vector2(3.4, 3.0))
	check(cam.walks and g.quality_of(cam) < g.quality_of(clean) - 0.15, "a cam in a flare walks and holds less than the same cam in a clean crack")


func test_offer_is_pure() -> void:
	var d := new_director()
	var g := d.session.sys.gear as TradGear
	add_crack(d, "hands", [4.0, 4.0, 4.0, 4.0, 4.0])
	stand_at(d, 3.0)
	var before := d.session.snapshot()
	for id in ["cam_1", "cam_2", "nut_mid", "offset_mid"]:
		g.offer(id, "hands", Vector2(3.4, 3.0))
	g.offer_cost(Vector2(3.4, 3.0))
	g.best_item("hands", Vector2(3.4, 3.0))
	g.tug_reading("pin_1")
	check(str(d.session.snapshot()) == str(before), "offers, costs and best_item change nothing")


func test_fiddle_cost() -> void:
	var d := new_director()
	var g := d.session.sys.gear as TradGear
	add_crack(d, "hands", [4.0, 4.0, 4.0, 4.0, 4.0])
	stand_at(d, 3.0)
	var at := Vector2(3.4, 3.0)
	var first := g.offer_cost(at).pump
	g.note_try()
	var second := g.offer_cost(at).pump
	g.note_try()
	var third := g.offer_cost(at).pump
	check(first > 0.0 and second > first and third > second, "each offer from one stance costs more (%.3f %.3f %.3f)" % [first, second, third])
	stand_at(d, 3.3)
	check(absf(g.offer_cost(at).pump - first) < 0.0001 or g.stretched(at), "a new stance starts cheap again")
	stand_at(d, 3.0)
	check(g.offer_cost(Vector2(3.4, 3.0)).pump < g.offer_cost(Vector2(3.4, 3.0) + Vector2(0, 0.95)).pump, "offering at a stretch costs more")
	check(g.stretched(Vector2(3.4, 3.95)) and g.offer("cam_1", "hands", Vector2(3.4, 3.95)).murky, "...and you can't see in properly")


func test_place_flow() -> void:
	var d := new_director()
	var s := d.session
	d.handle_verb(&"commit", true)
	add_crack(d, "hands", [4.0, 4.0, 4.0, 4.0, 4.0])
	stand_at(d, 3.0)
	check(d.handle_verb(&"rack", true) and s.phase == &"place", "the rack verb at a crack opens the place phase")
	var ph := d.current as TradGear.PlacePhase
	check(ph != null and ph.entries.size() >= 6, "the harness is laid out in rack order")
	check(ph.entries[0].id == "nut_small", "the first piece is the first on the harness")
	while ph.current_item() != "cam_1":
		d.handle_verb(&"aim_right", true)
	var pump := s.effort.pump
	d.handle_verb(&"commit", true)
	check(s.effort.pump > pump and s.bus.count(&"piece_offered") == 1 and ph.reading.lobes == "sweet", "Space offers it (pump spent) and the lobes read")
	check(s.rack.count("cam_1") == 2, "an offer doesn't take it off the harness")
	check(ph.hint().contains("placed") or ph.hint().contains("Space"), "the hint says what Space does now")
	d.handle_verb(&"commit", true)
	check(s.phase == &"clip" and s.pieces.size() == 1 and s.rack.count("cam_1") == 1, "Space again places it and opens the clip")
	var p: V2Piece = s.pieces.values()[0]
	check(p.kind == &"cam" and p.crack_id == "hands" and p.quality > 0.8 and p.tags.is_empty(), "a sweet #1 is a good, untagged piece")
	check(s.bus.names([&"piece_offered", &"piece_placed", &"phase_changed"]).slice(-3) == [&"piece_offered", &"piece_placed", &"phase_changed"], "offered, placed, then the phase changes")
	d.handle_verb(&"cancel", true)
	d.handle_verb(&"rack", true)
	ph = d.current as TradGear.PlacePhase
	check(ph.current_item() == "cam_1", "the cursor comes back to the last piece you used")
	d.handle_verb(&"aim_right", true)
	d.handle_verb(&"commit", true)
	d.handle_verb(&"aim_right", true)
	check(ph.reading.is_empty(), "picking another piece clears the reading")
	d.handle_verb(&"cancel", true)
	check(s.phase == &"climb" and s.bus.count(&"piece_cancelled") == 1, "Esc puts it back and climbs on")


func test_pumped_off() -> void:
	var d := new_director()
	var s := d.session
	d.handle_verb(&"commit", true)
	add_crack(d, "hands", [4.0, 4.0, 4.0, 4.0, 4.0])
	stand_at(d, 3.0)
	d.handle_verb(&"rack", true)
	s.effort.pump = 0.99
	var ph := d.current as TradGear.PlacePhase
	check(ph.hint().contains("off"), "when one more try would pump you off, the hint warns first")
	var counts := str(s.rack.to_dict())
	d.handle_verb(&"commit", true)
	check(s.phase == &"fall" and s.result.falls == 1, "fiddling while pumped out: you come off")
	check(str(s.rack.to_dict()) == counts, "nothing is lost off the harness in the fall")


func test_auto_gear() -> void:
	var m := V2Modifiers.new()
	m.assists = PackedStringArray(["auto_gear"])
	var d := new_director(7, m)
	d.handle_verb(&"commit", true)
	add_crack(d, "hands", [4.0, 4.0, 4.0, 4.0, 4.0])
	stand_at(d, 3.0)
	d.handle_verb(&"rack", true)
	check((d.current as TradGear.PlacePhase).current_item() == "cam_1", "the auto_gear assist starts the cursor on the size that fits")


func test_pins() -> void:
	var d := new_director()
	var s := d.session
	var g := s.sys.gear as TradGear
	d.handle_verb(&"commit", true)
	add_crack(d, "high", [4.0, 4.0, 4.0, 4.0, 4.0], 0.0, &"hand", 3.4)
	s.wall.cracks[0].points = PackedVector2Array([Vector2(3.4, 8.0), Vector2(3.4, 9.0), Vector2(3.4, 10.0), Vector2(3.4, 11.0), Vector2(3.4, 12.0)])
	stand_at(d, 10.0)
	check(g.pins_in_reach().size() == 1, "the fixture's old pin is in reach")
	d.handle_verb(&"rack", true)
	var ph := d.current as TradGear.PlacePhase
	for i in ph.entries.size():
		if ph.current().type == "pin":
			break
		d.handle_verb(&"aim_right", true)
	d.handle_verb(&"commit", true)
	check(str(ph.reading.note).contains("Solid") and str(ph.reading.note).contains("Rust"), "a tug on the rusty pin tells you it's solid, but old")
	var weak := s.piece("pin_1")
	weak.quality = 0.2
	check(g.tug_reading("pin_1").note.contains("wouldn't"), "a bad pin feels bad")
	check((s.note(&"gear").tested as Dictionary).has("pin_1"), "what the pin told you is remembered")


func test_booty() -> void:
	var d := new_director()
	var s := d.session
	var g := s.sys.gear as TradGear
	add_crack(d, "hands", [4.0, 4.0, 4.0, 4.0, 4.0])
	stand_at(d, 3.0)
	s.note(&"gear").booty = [{"id": "test_booty", "pos": [3.4, 3.1], "crack": "hands", "gear": "cam_2", "name": "A gold #2",
		"text": "Walked deep.", "worked": 0, "needs": 3}]
	check(g.booty_in_reach().size() == 1, "stuck booty in reach shows up")
	var lines := []
	for i in 3:
		lines.append(str(g.work_booty("test_booty").note))
	check(lines[0].contains("budge") and lines[1].contains("Nearly") and lines[2].contains("free"), "working it free tells you how it's going: %s" % [lines])
	check(s.rack.count("cam_2") == 2 and g.booty_in_reach().is_empty(), "freed booty goes on the harness")
	var wb := get_node_or_null("/root/WallBooty")
	if wb:
		var d2 := ClimbDirector.new()
		var r := RouteData.new()
		r.id = "nutcracker"
		r.protection = "cams"
		var p: Array[int] = [2, 2, 2]
		r.pitches = p
		d2.setup(r, 3, V2Modifiers.new(), rack())
		d2.start()
		d2.next_pitch()
		var waiting: Array = d2.session.note(&"gear").get("booty", [])
		check(waiting.size() == 1 and waiting[0].id == "nutcracker_stopper" and int(waiting[0].needs) >= 2, "the Nutcracker's old Stopper waits on its second pitch")


func test_partner_words() -> void:
	var d := new_director()
	var g := d.session.sys.gear as TradGear
	var p := V2Piece.new()
	p.kind = &"cam"
	p.gear_id = "cam_1"
	p.pos = Vector2(3, 6.2)
	p.quality = 0.9
	check(g.grade_for(p).grade == "bomber" and g.grade_for(p).line.contains("6 m"), "the partner names the piece and where: %s" % g.grade_for(p).line)
	p.tags = PackedStringArray(["tipped"])
	check(g.grade_for(p).grade == "tipped out", "a tipped piece is called out")
	p.tags = PackedStringArray(["overcammed"])
	check(g.grade_for(p).line.contains("ten minutes"), "an over-cammed one cost the partner time")


func test_bot_climbs() -> void:
	var d := ClimbDirector.new()
	d.setup(_route(), 11, V2Modifiers.new(), rack())
	d.start()
	var bot := ClimbV2TestBot.new(d)
	var ok := bot.run(900)
	check(ok, "the test bot tops out the fixture with real gear")
	check(d.session.bus.count(&"piece_placed") >= 1, "it placed gear on the way (%d)" % d.session.bus.count(&"piece_placed"))


func test_determinism() -> void:
	var a := _place_once(5)
	var b := _place_once(5)
	check(a == b and a > 0.0, "the same seed sets the same piece the same way")


func _place_once(seed: int) -> float:
	var d := new_director(seed)
	add_crack(d, "hands", [4.0, 4.0, 4.0, 4.0, 4.0])
	stand_at(d, 3.0)
	var p := (d.session.sys.gear as TradGear).place("cam_1", "hands", Vector2(3.4, 3.0))
	return p.quality if p else -1.0


func test_overlay() -> void:
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(_route(), 7, V2Modifiers.new(), rack())
	add_child(screen)
	await get_tree().process_frame
	var d := screen.director
	d.handle_verb(&"commit", true)
	add_crack(d, "hands", [3.0, 3.6, 4.2, 4.0, 4.0], 0.2)
	stand_at(d, 3.0)
	d.handle_verb(&"rack", true)
	var overlay := screen.overlays.get_node_or_null("gear") as TradGearOverlay
	check(overlay != null, "the gear overlay is mounted on the screen")
	for verb: StringName in [&"aim_right", &"commit", &"aim_right", &"aim_right", &"commit", &"aim_right", &"commit"]:
		d.handle_verb(verb, true)
		await get_tree().process_frame
	check(overlay.visible, "it shows while placing")
	d.handle_verb(&"cancel", true)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not overlay.visible, "and hides after")
	screen.queue_free()
	await get_tree().process_frame
