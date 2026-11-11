extends Node
## Headless test of the climbing screen's longer skill checks (ClimbCheck):
## the King Swing (SwingCheck), nailing a piton (NailCheck), hauling the bag
## (HaulCheck) and a layback (LaybackCheck). Scripted players play each one:
## a careful one gets up it, a careless one doesn't, and each way of getting
## it wrong goes wrong the way it says. Then ClimbState: an aid move on the
## screen waits on a piton, a big wall's belays wait on the haul, and the
## routes ask for the swing and the layback where they should.
## Run: godot --headless --path . res://tests/climb_checks_test.tscn
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
	test_swing()
	test_nail()
	test_haul()
	test_layback()
	test_route_checks()
	test_aid_on_screen()
	test_haul_on_screen()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


## Steps [param check] until it's decided (or [param seconds] run out),
## asking [param pilot] each frame for the keys held and calling it with the
## check to press keys of its own.
func play(check_: ClimbCheck, pilot: Callable, seconds := 40.0) -> void:
	var t := 0.0
	while not check_.is_done() and t < seconds:
		var held: Dictionary = pilot.call(check_)
		check_.step(DT, held)
		t += DT


# ---------------------------------------------------------------- the swing

## Runs with the swing until it'll reach the crack, then grabs at its top.
func _swing_careful(s: SwingCheck) -> Dictionary:
	if s.angle >= s.green_from() + s.window * 0.2 and absf(s.speed) < 0.15:
		s.press("tool")
		return {}
	if s.amplitude() < SwingCheck.TARGET + 0.02:
		return {"right": s.speed >= 0.0, "left": s.speed < 0.0}
	return {}


func test_swing() -> void:
	var careful := SwingCheck.new(0.22, 10.0)
	play(careful, _swing_careful)
	check(careful.result in ["perfect", "good"], "a careful swing reaches the crack (%s, %s, %.1f s)" % [careful.result, careful.detail, careful.elapsed])
	check(careful.swings >= 3, "it takes a few swings to build (%d)" % careful.swings)
	var idle := SwingCheck.new(0.22, 10.0)
	play(idle, func(_s: SwingCheck) -> Dictionary: return {})
	check(idle.result == "slip" and idle.detail == "time", "hanging still gets you nowhere (%s)" % idle.detail)
	var greedy := SwingCheck.new(0.22, 10.0)
	play(greedy, func(s: SwingCheck) -> Dictionary: return {"right": s.speed >= 0.0, "left": s.speed < 0.0})
	check(greedy.result == "slip" and greedy.detail == "slam", "running and never grabbing slams you into the corner (%s)" % greedy.detail)
	var early := SwingCheck.new(0.22, 10.0)
	early.step(DT, {})
	early.press("tool")
	check(early.result == "slip" and early.detail == "short", "grabbing before you're out there misses")
	var against := SwingCheck.new(0.22, 10.0)
	var with := SwingCheck.new(0.22, 10.0)
	for i in 30:
		with.step(DT, {"right": true})
		against.step(DT, {"right": true})
	for i in 60:
		with.step(DT, {"right": with.speed >= 0.0, "left": with.speed < 0.0})
		against.step(DT, {"left": against.speed >= 0.0, "right": against.speed < 0.0})
	check(with.amplitude() > against.amplitude() * 2.0, "running with the swing builds it, against it brakes (%.2f, %.2f)" % [with.amplitude(), against.amplitude()])
	var slow := SwingCheck.new(0.22, 10.0, 0.55)
	var fast := SwingCheck.new(0.22, 10.0, 1.0)
	for i in 20:
		slow.step(DT, {"right": true})
		fast.step(DT, {"right": true})
	check(slow.angle < fast.angle, "a slower pace slows the swing")
	check(SwingCheck.new(0.9, 10.0).green_to() < SwingCheck.SLAM, "the widest green stops short of the corner")


# ---------------------------------------------------------------- the piton

## Strikes hard while there's room, then the blow that lands mid-green, then
## steps onto it.
func _nail_careful(n: NailCheck) -> Dictionary:
	var need := n.center() - n.depth
	if absf(need) <= n.window * 0.1:
		n.press("up")
	elif need >= NailCheck.drive(1.0):
		if n.swing >= 0.97:
			n.press("tool")
	elif need >= NailCheck.drive(0.0):
		var at := (need - NailCheck.DRIVE_MIN) / (NailCheck.DRIVE_MAX - NailCheck.DRIVE_MIN)
		if absf(n.swing - at) <= 0.02:
			n.press("tool")
	else:
		n.press("up")
	return {}


func test_nail() -> void:
	var careful := NailCheck.new(0.2, 9.0, 1.2)
	play(careful, _nail_careful)
	check(careful.result == "perfect", "a careful pin is seated dead on (%s at %.2f, %d blows)" % [careful.result, careful.depth, careful.strikes])
	var tap := NailCheck.new(0.2, 9.0, 1.2)
	tap.press("up")
	check(not tap.is_done(), "stepping up before the first blow does nothing")
	tap.swing = 1.0
	tap.press("tool")
	tap.press("up")
	check(tap.result == "slip" and tap.detail == "popped", "one blow and step on it: the pin pops (%.2f deep)" % tap.depth)
	var basher := NailCheck.new(0.2, 9.0, 1.2)
	for i in 5:
		basher.swing = 1.0
		basher.press("tool")
	check(basher.result == "over", "full blows past the green over-drive it (%.2f)" % basher.depth)
	var high := NailCheck.new(0.2, 9.0, 1.2)
	var low := NailCheck.new(0.2, 9.0, 1.2)
	high.swing = 1.0
	high.strike()
	low.swing = 0.0
	low.strike()
	check(high.depth > low.depth * 4.0, "a blow high on the swing drives harder (%.2f, %.2f)" % [high.depth, low.depth])
	var dawdle := NailCheck.new(0.2, 2.0, 1.2)
	play(dawdle, func(_n: NailCheck) -> Dictionary: return {})
	check(dawdle.result == "slip", "out of time you step on whatever's there")
	var swings := NailCheck.new(0.2, 9.0, 1.2)
	var turned := false
	for i in 60:
		swings.step(DT, {})
		turned = turned or swings.swing_dir < 0.0
	check(turned and swings.swing >= 0.0 and swings.swing <= 1.0, "the hammer swings back and forth")


# ---------------------------------------------------------------- the haul

## Pulls full strokes, lets go to reset, and wiggles any snag free.
func _haul_careful(h: HaulCheck) -> Dictionary:
	if h.snag >= 0:
		h.press(h.next_side())
		return {}
	if h.stroke >= 1.0:
		return {"pull": false}
	if h.stroke > 0.0 and not h._was_pulling:
		return {"pull": false}
	return {"pull": true}


func test_haul() -> void:
	var careful := HaulCheck.new(2)
	play(careful, _haul_careful)
	check(careful.result == "perfect", "a clean haul is quick (%s, %.1f s, strain %.2f)" % [careful.result, careful.elapsed, careful.strain])
	check(careful.freed.size() == 2, "both snags were wiggled free")
	# Yanks at each snag for a second before wiggling it, and hangs on at the
	# end of every stroke a while before letting go.
	var yanker := HaulCheck.new(2)
	var yanked := [0.0]
	play(yanker, func(h: HaulCheck) -> Dictionary:
		if h.snag >= 0:
			yanked[0] += DT
			if yanked[0] < 1.0:
				return {"pull": true}
			h.press(h.next_side())
			return {}
		yanked[0] = 0.0
		if h.stroke >= 1.0 and h.strain < 0.25 * (h.height * 10.0):
			return {"pull": true}
		return _haul_careful(h))
	check(yanker.result == "slip" and yanker.detail == "sloppy", "yanking at snags and hanging on at the end of the stroke is sloppy (%s, strain %.2f)" % [yanker.detail, yanker.strain])
	var stuck := HaulCheck.new(1)
	play(stuck, func(_h: HaulCheck) -> Dictionary: return {"pull": true})
	check(stuck.result == "slip" and stuck.height <= HaulCheck.GAIN + 0.001, "never letting go hauls one stroke and no more (%.2f)" % stuck.height)
	var idle := HaulCheck.new(1)
	play(idle, func(_h: HaulCheck) -> Dictionary: return {})
	check(idle.result == "slip" and idle.detail == "partner", "do nothing and your partner hauls it in the end")
	var wiggle := HaulCheck.new(1)
	wiggle.snag = 0
	wiggle.press("left")
	wiggle.press("left")
	wiggle.press("left")
	check(wiggle.wiggles == 1, "wiggling the same side again doesn't count")
	wiggle.press("right")
	wiggle.press("left")
	wiggle.press("right")
	check(wiggle.snag == -1 and wiggle.freed.has(0), "Left, Right, Left, Right frees it")
	var easy := HaulCheck.new(1, 1.6)
	check(easy.good_seconds > HaulCheck.GOOD_SECONDS and easy.time_total > HaulCheck.LIMIT_SECONDS, "the Timing assist gives you longer")


# ---------------------------------------------------------------- the layback

## Pulls up into the middle of the green, steps, and lets the tension ease
## while the green catches up.
func _layback_careful(l: LaybackCheck) -> Dictionary:
	var mid := (l.band_from() + l.band_to()) / 2.0
	if l.tension >= mid:
		l.press("up")
		return {"pull": false}
	return {"pull": true}


func test_layback() -> void:
	var careful := LaybackCheck.new(0.22, 9.0)
	play(careful, _layback_careful)
	check(careful.result == "perfect" and careful.steps == LaybackCheck.NEED, "a careful layback walks up the flake (%s, %d steps, strain %.2f)" % [careful.result, careful.steps, careful.strain])
	var lazy := LaybackCheck.new(0.22, 9.0)
	lazy.step(DT, {})
	lazy.press("up")
	check(lazy.result == "slip" and lazy.detail == "barn_door", "stepping without pulling barn-doors you off")
	var crusher := LaybackCheck.new(0.22, 9.0)
	play(crusher, func(_l: LaybackCheck) -> Dictionary: return {"pull": true})
	check(crusher.result == "slip" and crusher.detail == "pumped", "pulling flat out pumps you off (%.1f s)" % crusher.elapsed)
	var band := LaybackCheck.new(0.22, 9.0)
	var low := band.band_from()
	band.tension = band.band_from() + 0.05
	band.step_up()
	check(band.band_from() > low and band.steps == 1, "each step holds in the green, and the green creeps up")
	check(LaybackCheck.new(0.9, 9.0).band_from() + LaybackCheck.BAND_CLIMB * (LaybackCheck.NEED - 1) + LaybackCheck.MAX_WINDOW <= 1.0,
		"even the widest green fits on the bar at the top of the flake")


# ---------------------------------------------------------------- the routes

func route(id: String) -> RouteData:
	return load("res://data/routes/%s.tres" % id)


## The gear the story has handed over when a route comes up, as in climb_test.
func kit_for(r: RouteData) -> Dictionary:
	var kit := {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 5, "rope": 1}
	for id: String in r.required_gear:
		kit[id] = maxi(int(kit.get(id, 0)), int(r.required_gear[id]))
	return kit


func _kinds(r: RouteData, index: int) -> Array:
	var spec := ClimbProfiles.pitch_spec(r, index)
	var out := []
	for row: int in spec.cruxes:
		out.append(ClimbProfiles.crux_at(spec, row).kind)
	return out


func test_route_checks() -> void:
	var nose := route("the_nose")
	var king := ClimbProfiles.pitch_spec(nose, 4)
	check(ClimbProfiles.crux_at(king, king.crux).kind == "swing", "the King Swing is a swing (its pitch: %s)" % [_kinds(nose, 4)])
	var arches := ClimbProfiles.pitch_spec(route("royal_arches"), 3)
	check(ClimbProfiles.crux_at(arches, arches.crux).kind == "swing", "so is Royal Arches' Pendulum")
	for i in [3, 7]:
		var kinds := _kinds(nose, i)
		check(not kinds.is_empty() and kinds.all(func(k: String) -> bool: return k == "layback"), "%s is laybacked (%s)" % [ClimbProfiles.pitch_spec(nose, i).name, kinds])
	check(not _kinds(route("nutcracker"), 2).is_empty() and _kinds(route("nutcracker"), 2).all(func(k: String) -> bool: return k == "layback"), "Nutcracker's Hand-Crack Corner is laybacked")
	check(not _kinds(route("astroman"), 2).is_empty() and _kinds(route("astroman"), 2).all(func(k: String) -> bool: return k == "layback"), "Astroman's Enduro Corner is laybacked")
	check(_kinds(route("astroman"), 5) == ["dyno", "rhythm"], "the Harding Slot keeps its chicken wing and its rhythm")
	check(_kinds(route("the_nose"), 6) == ["timing", "timing", "timing"] or _kinds(route("the_nose"), 6).all(func(k: String) -> bool: return k == "timing"), "the Great Roof is still a timing crux")
	# Each kind gets the right rules, and the screen's own meters get none.
	var state := ClimbState.new(nose, 10, 1, kit_for(nose))
	for pair in [["swing", "SwingCheck"], ["layback", "LaybackCheck"], ["nail", "NailCheck"], ["haul", "HaulCheck"]]:
		state.pending = {"kind": pair[0], "name": "x"}
		var made := state.make_check()
		check(made != null and made.get_script().get_global_name() == pair[1], "a %s check is played by %s" % pair)
	state.pending = {"kind": "timing", "name": "x"}
	check(state.make_check() == null, "a timing crux is the screen's own meter")
	state.pending = {}
	check(state.crux_seconds("swing") > state.crux_seconds("mash") and state.crux_seconds("layback") > state.crux_seconds("mash"),
		"the swing and the layback get more time than a mantel")


## Climbs until [param predicate] says stop, answering any crux as an
## average move. Returns false if it never got there.
func _climb_until(s: ClimbState, predicate: Callable) -> bool:
	for i in 400:
		if predicate.call(s):
			return true
		if s.status != ClimbState.Status.CLIMBING:
			return false
		if not s.pending.is_empty():
			s.resolve_crux("good")
			continue
		s.stamina = ClimbState.MAX_STAMINA
		var dx := 0
		for d in [0, -1, 1]:
			if not s.hold_at(s.row + 1, s.col + d).is_empty():
				dx = d
				break
		s.move(dx)
	return false


func _aid_dx(s: ClimbState) -> int:
	for d in [0, -1, 1]:
		if s.can_aid(d):
			return d
	return 99


## A state on the Great Roof, with an aid move in reach.
func _on_the_roof(interactive: bool) -> ClimbState:
	var nose := route("the_nose")
	var s := ClimbState.new(nose, 10, 7, kit_for(nose))
	s.interactive = interactive
	s.pitch = 6
	s._start_pitch()
	_climb_until(s, func(st: ClimbState) -> bool: return _aid_dx(st) != 99 and st.pending.is_empty())
	return s


func test_aid_on_screen() -> void:
	var bot := _on_the_roof(false)
	var dx := _aid_dx(bot)
	check(dx != 99, "there's a hard move to aid on the Great Roof")
	var mins := bot.minutes
	var row := bot.row
	bot.aid_step(dx)
	check(bot.row == row + 1 and bot.minutes - mins == ClimbState.MINUTES_PER_AID and bot.protection.back().hw == "cam",
		"off the screen, aid is a cam and %d minutes as before" % ClimbState.MINUTES_PER_AID)
	var outcomes := {"perfect": ClimbState.MINUTES_PER_AID_PERFECT, "good": ClimbState.MINUTES_PER_AID, "over": ClimbState.MINUTES_PER_AID_OVER}
	for result: String in outcomes:
		var s := _on_the_roof(true)
		var d := _aid_dx(s)
		var r0 := s.row
		var m0 := s.minutes
		var cams := s.cams_left
		s.aid_step(d)
		check(s.pending.get("kind", "") == "nail" and s.row == r0 and s.cams_left == cams, "on the screen, aid waits on a piton (%s)" % result)
		check(s.make_check() is NailCheck, "...a NailCheck")
		s.resolve_crux(result)
		check(s.pending.is_empty() and s.row == r0 + 1 and s.cams_left == cams - 1 and s.aid_moves == 1 and s.protection.back().hw == "pin"
			and s.minutes - m0 == outcomes[result], "a %s pin makes the move in %d minutes (took %d)" % [result, outcomes[result], s.minutes - m0])
		check(not s.is_free() and s.style_rating() == "Aided", "...and it's still aid")
	var popped := _on_the_roof(true)
	var pd := _aid_dx(popped)
	var pr := popped.row
	var pm := popped.minutes
	var pc := popped.cams_left
	var ps := popped.stamina
	var pf := popped.falls
	popped.aid_step(pd)
	popped.resolve_crux("slip")
	check(popped.pending.is_empty() and popped.row == pr and popped.cams_left == pc and popped.aid_moves == 0 and popped.falls == pf
		and popped.minutes - pm == ClimbState.MINUTES_PER_POP and ps - popped.stamina == ClimbState.POP_STAMINA,
		"a popped pin costs %d minutes and %d stamina, and you're still where you were" % [ClimbState.MINUTES_PER_POP, ClimbState.POP_STAMINA])
	check(popped.can_aid(pd), "...so you can nail another")
	var events := popped.take_events().map(func(e: Dictionary) -> String: return e.type)
	check(events.has("nail_start") and events.has("nail"), "the screen hears about the piton (%s)" % [events])


func test_haul_on_screen() -> void:
	var nose := route("the_nose")
	var outcomes := {"perfect": ClimbState.MINUTES_PER_HAUL_CLEAN, "good": ClimbState.MINUTES_PER_HAUL, "slip": ClimbState.MINUTES_PER_HAUL_SLOPPY}
	for result: String in outcomes:
		var s := ClimbState.new(nose, 10, 3, kit_for(nose))
		s.interactive = true
		var got := _climb_until(s, func(st: ClimbState) -> bool: return st.pending.get("kind", "") == "haul")
		check(got and s.pitch == 0 and s.row == s.top_row, "at the top of the first pitch the bag waits to be hauled (%s)" % result)
		check(s.make_check() is HaulCheck and not s.can_eat(), "...a HaulCheck, and nothing else till it's up")
		var m0 := s.minutes
		var st0 := s.stamina
		s.resolve_crux(result)
		var belay := ClimbState.BELAY_REST + ClimbState.DEVICE_REST * int(s.has_device)
		check(s.pitch == 1 and s.row == 0 and s.pending.is_empty() and s.minutes - m0 == outcomes[result],
			"a %s haul takes %d minutes (took %d), then the next pitch" % [result, outcomes[result], s.minutes - m0])
		if result == "slip":
			check(s.stamina == mini(st0 - ClimbState.SLOPPY_HAUL_STAMINA + belay, ClimbState.MAX_STAMINA), "a sloppy haul tires you (%d from %d)" % [s.stamina, st0])
	# Off the screen the haul is the flat 10 minutes it always was.
	var bot := ClimbState.new(nose, 10, 3, kit_for(nose))
	_climb_until(bot, func(st: ClimbState) -> bool: return st.pitch == 1)
	check(bot.pending.is_empty() and bot.pitch == 1, "off the screen there's nothing to haul by hand")
	# The night on El Cap Tower still follows the haul off that pitch.
	Inventory.items.clear()
	Inventory.add("acorn_cake", 4)
	var night := ClimbState.new(nose, 10, 3, kit_for(nose))
	night.interactive = true
	night.pitch = 2
	night._start_pitch()
	night.start_minutes = 15 * 60
	_climb_until(night, func(st: ClimbState) -> bool: return st.pending.get("kind", "") == "haul")
	night.take_events()
	night.resolve_crux("good")
	var types := night.take_events().map(func(e: Dictionary) -> String: return e.type)
	check(night.nights_spent == 1 and types.find("haul") >= 0 and types.find("haul") < types.find("bivy"), "the bag comes up, then the night on El Cap Tower (%s)" % [types])
	check(posmod(night.start_minutes + night.minutes, 24 * 60) == ClimbState.WAKE_MINUTES, "...and you still wake at 6:30")
	Inventory.items.clear()
	# No haul off the last pitch: you're on top.
	var top := ClimbState.new(nose, 10, 3, kit_for(nose))
	top.interactive = true
	top.pitch = nose.pitches.size() - 1
	top._start_pitch()
	_climb_until(top, func(st: ClimbState) -> bool: return st.status != ClimbState.Status.CLIMBING or st.pending.get("kind", "") == "haul")
	check(top.status == ClimbState.Status.TOPPED_OUT, "the last pitch tops out with no haul")
	# A harder pitch has a second snag.
	var hard := ClimbState.new(nose, 10, 3, kit_for(nose))
	hard.pitch = 6
	hard._start_pitch()
	check(hard.haul_snags() == 2 and ClimbState.new(nose, 10, 3, kit_for(nose)).haul_snags() == 1, "the bag snags twice on a 5, once on a 4")
