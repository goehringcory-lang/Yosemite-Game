extends Node
## Headless test of placing gear on the climbing screen: crack widths and the
## rack (ClimbRack), picking and seating a piece (PlaceCheck), clipping off a
## bad hold (ClipCheck), what a marginal piece does in a fall, over-cammed
## pieces at the belay, and booty stuck on the wall (BootyCheck, WallBooty).
## Run: godot --headless --path . res://tests/gear_placement_test.tscn
## Exit code is the number of failed checks.

const DT := 1.0 / 60.0

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	Settings.timing = Settings.Timing.STANDARD
	Settings.hold_taps = false
	NewGame.reset()
	test_rack()
	test_widths()
	test_place_check()
	test_place_on_screen()
	test_falls()
	test_over_cammed()
	test_clip()
	test_booty_data()
	test_booty()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


func route(id: String) -> RouteData:
	return load("res://data/routes/%s.tres" % id)


## A state hanging at a crack [param width] wide on a [param grip] hold, a
## few moves up the first pitch.
func at_crack(width: int, grip: String, interactive := true, cams := 8) -> ClimbState:
	var s := ClimbState.new(route("nutcracker"), cams, 5, {"quickdraw": 4})
	s.interactive = interactive
	s.row = 3
	s.col = 2
	s.holds[3][2] = {"cost": 3, "crack": true, "width": width, "grip": grip}
	return s


## Plays [param c] by holding the trigger until it reaches [param target],
## then letting go.
func seat_at(c: PlaceCheck, target: float) -> void:
	c.press("tool")
	var t := 0.0
	while not c.is_done() and t < 20.0:
		c.step(DT, {"pull": c.pull < target})
		t += DT


# ---------------------------------------------------------------- the rack

func test_rack() -> void:
	var rack := ClimbRack.from_count(5)
	check(rack.size() == 4 and int(rack[0].count) == 2 and int(rack[0].width_min) == 3, "five cams make a rack of #0.75 (two), #1, #2, #3")
	var one := {"kind": "cam", "width_min": 4, "width_max": 4}
	var nut := {"kind": "nut", "width_min": 2, "width_max": 3}
	check(ClimbRack.misfit(one, 4) == 0 and ClimbRack.misfit(one, 5) == 1 and ClimbRack.misfit(one, 7) == 3, "a #1 fits hands, is one off wide hands, three off offwidth")
	check(ClimbRack.misfit_side(one, 3) == 1 and ClimbRack.misfit_side(one, 5) == -1, "a #1 is too big for thin hands and too small for wide hands")
	check(ClimbRack.misfit(nut, 2) == 0 and ClimbRack.misfit(nut, 3) == 0 and ClimbRack.misfit(nut, 5) == 2, "a nut fits two widths")
	check(ClimbRack.pitch_widths({"name": "The Finger Crack", "style": "crack"}) == [0, 3], "a finger crack is thin")
	check(ClimbRack.pitch_widths({"name": "Chockstone Chimney", "style": "chimney"})[1] == 7, "a chimney's cracks are wide")
	check(ClimbRack.pitch_widths({"name": "Pitch 3", "style": "slab", "widths": [1, 2]}) == [1, 2], "a spec's widths win")
	check(ClimbRack.range_text([4, 6]) == "hands to fists", "widths read the way climbers say them")
	# Once Gear knows its sizes, the rack is the real one, size by size.
	if Gear.has_method("rack_carried"):
		var saved := Gear.owned.duplicate()
		Gear.owned = {"cam_1": 2, "nut_mid": 1, "rope": 1}
		Gear.cached = {}
		var real := ClimbRack.from_gear()
		check(real.size() == 2 and real[0].kind == "nut" and int(real[1].count) == 2 and int(real[1].width_min) == 4, "the rack is what you carry: a nut and two #1s")
		Gear.owned = saved
	var s := ClimbState.new(route("nutcracker"), 6, 1, {})
	s.set_rack([{"id": "nut_mid", "kind": "nut", "width_min": 2, "width_max": 3, "color": Color.GOLD, "count": 1, "name": "Nut"},
		{"id": "cam_1", "kind": "cam", "width_min": 4, "width_max": 4, "color": Color.RED, "count": 2, "name": "#1"}])
	check(s.cams_left == 3 and s.cams_per_pitch == 3, "the rack sets how many pieces a pitch has")
	check(s.best_piece(4).id == "cam_1" and s.best_piece(2).id == "nut_mid", "the best fit is picked for each crack")
	check(s.has_fit(5) and not s.has_fit(7), "a #1 will do for wide hands, nothing for offwidth")
	check(s.crack_note().begins_with("Cracks: tight hands to fists.") and s.crack_note().contains("Nothing on your rack fits the fists"), "the belay warns when the rack is short: %s" % s.crack_note())
	s.set_rack(ClimbRack.from_count(8) + [{"id": "n", "kind": "nut", "width_min": 2, "width_max": 2, "color": Color.GOLD, "count": 1, "name": "Nut"}])
	check(s.crack_note() == "Cracks: tight hands to fists.", "...and not when it isn't")


func test_widths() -> void:
	for id in ["nutcracker", "astroman", "the_nose", "steck_salathe"]:
		var s := ClimbState.new(route(id), 8, 3, {})
		var ok := true
		var cracks := 0
		for p in route(id).pitches.size():
			var widths: Array = ClimbRack.pitch_widths(s.spec)
			for r: int in s.holds:
				for c: int in s.holds[r]:
					var h: Dictionary = s.holds[r][c]
					if h.get("crack", false):
						cracks += 1
						ok = ok and h.has("width") and int(h.width) >= int(widths[0]) and int(h.width) <= int(widths[1])
			s._next_pitch(0)
			if s.status != ClimbState.Status.CLIMBING:
				break
		check(ok and cracks > 0, "%s: every crack has a width in its pitch's range (%d cracks)" % [id, cracks])
	# The same seed makes the same wall, widths and all.
	var a := ClimbState.new(route("astroman"), 8, 9, {})
	var b := ClimbState.new(route("astroman"), 8, 9, {})
	check(a.holds == b.holds, "a seed's wall is the same every time")


# ---------------------------------------------------------------- the check

func _rack_left(width: int, left := 2) -> Array:
	return [{"id": "cam", "kind": "cam", "width_min": width, "width_max": width, "color": Color.RED, "count": left, "left": left, "name": "Cam"}]


func test_place_check() -> void:
	var c := PlaceCheck.new(_rack_left(4), 4, 6.0)
	check(c.cursor == 0 and c.can_use(0) and c.pieces.back().kind == "sling", "the cursor starts on the cam that fits; a sling is last")
	seat_at(c, 0.5)
	check(c.result == "perfect", "let go mid-range on the right size: solid (%s)" % c.result)
	c = PlaceCheck.new(_rack_left(4), 4, 6.0)
	seat_at(c, 0.1)
	check(c.result == "slip" and c.detail == "tipped", "let go early: tipped out")
	c = PlaceCheck.new(_rack_left(4), 4, 6.0)
	seat_at(c, 0.95)
	check(c.result == "over", "pull it all the way in and let go: over-cammed")
	var nut := [{"id": "nut_mid", "kind": "nut", "width_min": 3, "width_max": 4, "color": Color.GOLD, "count": 1, "left": 1, "name": "Nut"}]
	c = PlaceCheck.new(nut, 4, 6.0)
	seat_at(c, 0.95)
	check(c.result == "slip", "a nut never over-cams")
	c = PlaceCheck.new(_rack_left(5), 4, 6.0)
	var g := c.green()
	check(g.y < PlaceCheck.FIT_WINDOW and g.x > PlaceCheck.FIT_CENTER, "a size big: a narrow green, high on the bar")
	seat_at(c, g.x)
	check(c.result == "good" and c.detail == "off_size", "a size off, seated well, is good at best")
	c = PlaceCheck.new(_rack_left(7), 4, 6.0)
	check(not c.can_use(0) and c.is_sling(), "three sizes off won't go in: the cursor starts on the sling")
	c.press("left")
	check(c.is_sling(), "the cursor skips what won't go in")
	c.press("tool")
	check(c.result == "slip" and c.detail == "sling", "slinging a horn is quick, and marginal")
	c = PlaceCheck.new(_rack_left(4), 4, 1.0)
	var t := 0.0
	while not c.is_done() and t < 3.0:
		c.step(DT, {})
		t += DT
	check(c.result == "cancel" and c.detail == "grip", "dither while picking and your grip goes: nothing goes in")
	c = PlaceCheck.new(_rack_left(4), 4, 6.0)
	c.press("cancel")
	check(c.result == "cancel", "Esc backs out of a placement")
	c = PlaceCheck.new(_rack_left(5) + [{"id": "x", "kind": "cam", "width_min": 6, "width_max": 6, "color": Color.BLUE, "count": 3, "left": 3, "name": "#3"}], 4, 6.0)
	check(c.selected().width_min == 5, "the cursor never starts on a piece two sizes off, however many you have")
	c = PlaceCheck.new(_rack_left(3), 4, 6.0)
	seat_at(c, 0.95)
	check(c.result == "slip" and c.detail == "tipped", "a cam a size small can't over-cam: overshoot it and it tips out")
	# The key that opened the check doesn't start pulling by itself.
	c = PlaceCheck.new(_rack_left(4), 4, 6.0)
	c.step(DT, {"pull": true})
	check(c.phase == "pick", "a key still held from the protect press doesn't pull the trigger")
	# Picking among sizes.
	var two := [{"id": "a", "kind": "cam", "width_min": 3, "width_max": 3, "color": Color.GREEN, "count": 1, "left": 1, "name": "#0.75"},
		{"id": "b", "kind": "cam", "width_min": 4, "width_max": 4, "color": Color.RED, "count": 1, "left": 1, "name": "#1"}]
	c = PlaceCheck.new(two, 4, 6.0)
	check(c.selected().id == "b", "starts on the #1 in a hands crack")
	c.press("left")
	check(c.selected().id == "a", "Left picks the #0.75")


func test_place_on_screen() -> void:
	var s := at_crack(4, "crimp")
	var before := s.cams_left
	check(s.place_cam() and s.pending.get("kind", "") == "place", "on the screen, a crack off a crimp asks for the placing check")
	var c := s.make_check() as PlaceCheck
	check(c != null and c.width == 4, "the check reads the crack's width")
	check(c.time_total < ClimbState.GRIP_SECONDS.jug, "a crimp gives you less time than a jug")
	seat_at(c, 0.5)
	s.resolve_crux(c.result)
	var piece: Dictionary = s.protection.back()
	check(s.pending.is_empty() and piece.quality == "solid" and s.protection_row == 3, "seated well: a solid piece, and the rope runs through it")
	check(s.cams_left == before - 1 and int(s.rack_left[piece.key]) == 1, "the #1 comes off your harness (%s)" % piece.key)
	check(s.solid_placements == 1 and s.placements == 1, "it counts as a solid placement")
	# The right size off a jug just goes in.
	s = at_crack(4, "jug")
	check(s.place_cam() and s.pending.is_empty() and s.protection.back().quality == "good", "the right size off a jug goes straight in")
	# ...but the wrong size off a jug still asks.
	s = at_crack(7, "jug")
	check(s.place_cam() and s.pending.get("kind", "") == "place", "nothing that fits: you still have to choose")
	# A Esc'd placement spends nothing.
	s = at_crack(4, "crimp")
	var cams_before := s.cams_left
	s.place_cam()
	var cc := s.make_check() as PlaceCheck
	cc.press("cancel")
	s.resolve_crux(cc.result)
	check(s.pending.is_empty() and s.cams_left == cams_before and s.protection.is_empty(), "backing out places nothing and spends nothing")
	# With your harness empty you can still sling a horn on the screen.
	s = at_crack(4, "crimp")
	s.cams_left = 0
	for k in s.rack_left:
		s.rack_left[k] = 0
	check(s.can_place_cam() and s.place_cam() and s.pending.get("kind", "") == "place", "out of cams, you can still sling a horn")
	cc = s.make_check() as PlaceCheck
	check(cc.pieces.size() == 1 and cc.is_sling(), "...and the sling is all there is")
	cc.press("tool")
	s.resolve_crux(cc.result)
	check(s.protection.back().hw == "sling" and s.protection.back().quality == "marginal" and s.cams_left == 0, "a slung horn: marginal, and free")
	# Off the screen (tests, bots), every piece is good.
	s = at_crack(7, "crimp", false)
	check(s.place_cam() and s.pending.is_empty() and s.protection.back().quality == "good", "bots place every piece good, as before")
	# Pumped, the grip runs short.
	s = at_crack(4, "edge")
	var fresh := s.grip_seconds()
	s.pump = 5
	check(s.grip_seconds() < fresh, "pumped forearms give you less time to place")


func _piece(r: int, quality: String) -> Dictionary:
	return {"cell": Vector2i(2, r), "kind": "cam", "hw": "cam", "quality": quality, "key": "cam:4-4", "name": "Cam #1", "color": Color.RED}


func test_falls() -> void:
	# A marginal piece holds a short fall.
	var s := at_crack(4, "edge", false)
	s.protection.append(_piece(2, "good"))
	s.protection.append(_piece(5, "marginal"))
	s.protection_row = 5
	s.row = 6
	s._fall()
	check(s.status == ClimbState.Status.CLIMBING and s.rips == 0 and s.row == 4, "a marginal piece holds a fall from just above it")
	# From two moves up it rips, and the piece below catches a longer fall.
	s = at_crack(4, "edge", false)
	s.protection.append(_piece(4, "good"))
	s.protection.append(_piece(5, "marginal"))
	s.protection_row = 5
	s.row = 7
	var left := s.cams_left
	s._fall()
	check(s.rips == 1 and s.protection.size() == 1 and s.protection_row == 4, "from higher, the marginal piece rips and the next one down catches")
	check(s.status == ClimbState.Status.CLIMBING and s.row == 1, "...and you fall further (to row %d)" % s.row)
	check(s.cams_left == left + 1, "the ripped cam slides down the rope back to you")
	check(s.message.begins_with("Your Cam #1 rips out!"), "the message says it ripped: %s" % s.message)
	# A rip that leaves you too far out ends the climb.
	s = at_crack(4, "edge", false)
	s.protection.append(_piece(1, "good"))
	s.protection.append(_piece(5, "marginal"))
	s.protection_row = 5
	s.row = 7
	s._fall()
	check(s.status == ClimbState.Status.RETREATED, "a rip into a long runout sends you down")
	# Solid and over-cammed pieces always hold.
	for q in ["solid", "good", "over"]:
		s = at_crack(4, "edge", false)
		s.protection.append(_piece(5, q))
		s.protection_row = 5
		s.row = 7
		s._fall()
		check(s.rips == 0 and s.status == ClimbState.Status.CLIMBING, "a %s piece holds" % q)


func test_over_cammed() -> void:
	var s := at_crack(4, "edge", false)
	s.protection.append(_piece(3, "over"))
	s.protection.append(_piece(5, "over"))
	var before := s.minutes
	s._finish_pitch()
	check(s.minutes - before >= 2 * ClimbState.STUCK_MINUTES, "your second spends time cleaning each over-cammed piece")
	check(s.message.contains("over-cammed"), "and the belay says so: %s" % s.message)


func test_clip() -> void:
	var s := ClimbState.new(route("firefall_slab"), 0, 2, {"quickdraw": 6})
	s.interactive = true
	var bolt_row: int = s.bolts.keys()[0]
	s.row = bolt_row
	s.col = int(s.bolts[bolt_row])
	s.holds[bolt_row][s.col] = {"cost": 3, "crack": false, "grip": "crimp"}
	var draws := s.quickdraws_left
	check(s.protect() and s.pending.get("kind", "") == "clip", "clipping off a crimp is a check")
	var c := s.make_check() as ClipCheck
	check(c != null, "a ClipCheck plays it")
	s.resolve_crux("slip")
	check(s.quickdraws_left == draws and s.protection.is_empty() and s.pending.is_empty(), "a fumble leaves you unclipped, free to try again")
	check(s.protect() and s.pending.get("kind", "") == "clip", "...and you can")
	s.resolve_crux("perfect")
	check(s.quickdraws_left == draws - 1 and s.protection.size() == 1 and s.protection_row == bolt_row, "clipped")
	# A careful clipper presses at the gate.
	c = ClipCheck.new(4.0)
	var t := 0.0
	while not c.is_done() and t < 4.0:
		c.step(DT, {})
		if absf(c.pos - ClipCheck.CENTER) < 0.02:
			c.press("tool")
		t += DT
	check(c.result == "perfect", "press as the rope reaches the gate: a clean clip")
	# Off an edge, the draw just goes on.
	s = ClimbState.new(route("firefall_slab"), 0, 2, {"quickdraw": 6})
	s.interactive = true
	s.row = bolt_row
	s.col = int(s.bolts[bolt_row])
	s.holds[bolt_row][s.col] = {"cost": 3, "crack": false, "grip": "edge"}
	check(s.protect() and s.pending.is_empty() and s.protection.size() == 1, "off an edge you clip without a check")


func test_booty_data() -> void:
	var ids := {}
	for b in WallBooty.all():
		var r := route(str(b.route))
		var ok := r != null and not r.boulder and not r.top_rope and int(b.pitch) < r.pitches.size()
		if ok:
			var spec := ClimbProfiles.pitch_spec(r, int(b.pitch))
			ok = int(b.row) >= 1 and int(b.row) < int(spec.rows) and not spec.get("style", "") in ["snow", "ice"]
		ok = ok and not ids.has(b.id) and str(b.get("name", "")) != "" and str(b.get("text", "")) != ""
		ok = ok and int(b.get("width", 0)) >= 0 and int(b.get("width", 0)) <= ClimbRack.MAX_WIDTH
		ids[b.id] = true
		check(ok, "booty %s sits on a real pitch and row" % b.id)
	check(WallBooty.all().size() >= 6, "there's booty on several routes")


func test_booty() -> void:
	NewGame.reset()
	var waiting := WallBooty.waiting("astroman")
	check(waiting.size() == 1 and waiting[0].id == "astroman_grey", "Astroman has its booty waiting")
	var s := ClimbState.new(route("astroman"), 8, 4, {})
	s.interactive = true
	s.set_booty(waiting)
	var b: Dictionary = waiting[0]
	var col: int = s._path[int(b.row)]
	var hold := s.hold_at(int(b.row), col)
	check(hold.get("crack", false) and int(hold.get("booty", -1)) == 0 and int(hold.width) == int(b.width), "the booty's crack is on the line, as wide as the data says")
	s.row = int(b.row)
	s.col = col
	check(s.can_take_booty() and s.protect() and s.pending.get("kind", "") == "booty", "at the booty, protect starts working it free")
	var c := s.make_check() as BootyCheck
	var t := 0.0
	while not c.is_done() and t < 20.0:
		c.step(DT, {})
		if absf(c.pos - c.center) < 0.02:
			c.press("tool")
		t += DT
	check(c.result == "perfect" and c.knocks == BootyCheck.NEED, "three good knocks and it's free")
	var st := s.stamina
	s.resolve_crux("slip")
	check(s.booty_taken.is_empty() and s.can_take_booty() and s.stamina == st, "a failed try leaves it stuck, costing only time")
	check(s.protect() and s.pending.get("kind", "") == "place", "after a try, the button protects you in that crack")
	var pc := s.make_check() as PlaceCheck
	pc.press("tool") # nothing fits a #0.3 crack on this rack: a sling
	s.resolve_crux(pc.result)
	check(s.protection_row == s.row, "...a piece goes in beside the booty")
	check(s.protect() and s.pending.get("kind", "") == "booty", "...then tries the booty again")
	s.make_check()
	s.resolve_crux("good")
	check(s.booty_taken.size() == 1 and not s.hold_at(s.row, s.col).has("booty"), "worked free")
	var got := false
	for e in s.take_events():
		if e.type == "booty":
			got = WallBooty.take(e.booty)
	var gear_id := str(b.gear) if Gear.get_gear(str(b.gear)) else "cam"
	check(got and WallBooty.is_found("astroman_grey") and Gear.count(gear_id) >= 1, "it's yours: %s" % gear_id)
	check(WallBooty.waiting("astroman").is_empty() and not WallBooty.take(b), "found once a game")
	var saved := WallBooty.save_data()
	WallBooty.start_new_game()
	WallBooty.load_data(saved)
	check(WallBooty.is_found("astroman_grey"), "found booty is saved")
	# Bots don't stop for booty.
	s = ClimbState.new(route("astroman"), 8, 4, {})
	s.set_booty(WallBooty.all().filter(func(x: Dictionary) -> bool: return x.route == "astroman"))
	s.row = int(b.row)
	s.col = s._path[int(b.row)]
	check(not s.can_take_booty(), "off the screen there's no booty to work")
