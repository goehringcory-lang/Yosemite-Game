extends Node
## Headless test of climbing v2's cruxes and big-wall moments (thread 8,
## scripts/climb/v2/cruxes): crux spots from walls and from every route's old
## profile, hold demands and what a miss costs, pure previews, dynos, the
## crux events, and the specials played start to finish by a small bot: the
## King Swing, nailing, a chimney and an offwidth, and hauling at the belay.
## Everything but cruxes runs on the stubs (ClimbSystems.pin_stubs_except).
## Run: godot --headless --path . res://tests/climb_v2_cruxes_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	ClimbSystems.pin_stubs_except([&"cruxes"])
	test_real_system_loads()
	test_every_route_converts()
	test_profile_spots()
	test_fixture_sequence()
	test_sidepull_demands()
	test_preview_is_pure()
	test_wrong_hand_carries()
	test_dyno()
	test_crux_events()
	test_swing()
	test_nailing()
	test_nail_tones()
	test_inchworm()
	test_haul()
	test_special_snapshot()
	test_determinism()
	await test_screen()
	ClimbSystems.pins.clear()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


# ------------------------------------------------------------------ helpers

## A wall source that builds whatever pitch dictionary the test hands it.
class TestWall extends WallSource:
	var pitches: Array = []

	func pitch_count(_route: RouteData) -> int:
		return pitches.size()

	func build_pitch(_route: RouteData, pitch: int, _seed: int) -> V2Wall:
		var w := V2Wall.from_dict(pitches[mini(pitch, pitches.size() - 1)])
		w.pitch = pitch
		return w


static func route(id := "crux_test", pitches := 1, nights := 0) -> RouteData:
	var r := RouteData.new()
	r.id = id
	r.protection = "bolts"
	var p: Array[int] = []
	for i in pitches:
		p.append(3)
	r.pitches = p
	r.nights = nights
	return r


## A ladder pitch like the stub's (holds every 0.55 m, alternating sides),
## with [param extra] holds and [param zones] added.
static func ladder(height := 12.0, extra: Array = [], zones: Array = [], cracks: Array = []) -> Dictionary:
	var holds: Array = []
	var y := 1.6
	var i := 0
	while y < height - 0.3:
		holds.append({"id": "h%d" % i, "pos": [2.5 if i % 2 == 0 else 3.5, y], "kind": "edge", "size": 0.6, "foot": false})
		holds.append({"id": "f%d" % i, "pos": [2.7 if i % 2 == 0 else 3.3, y - 1.2], "kind": "edge", "size": 0.5, "hand": false})
		y += 0.55
		i += 1
	holds.append_array(extra)
	holds.append({"id": "anchor_hold", "pos": [3.0, height], "kind": "jug", "size": 1.0, "tags": ["anchor"]})
	return {"route_id": "crux_test", "size": [7.0, height + 1.5], "start": [3.0, 0.0], "top": [3.0, height],
		"holds": holds, "zones": zones, "cracks": cracks, "fixed": [{"id": "anchor", "kind": "anchor", "pos": [3.0, height + 0.3]}]}


func director_for(pitches: Array, r: RouteData = null, seed := 3) -> ClimbDirector:
	var d := ClimbDirector.new()
	d.setup(r if r else route("crux_test", pitches.size()), seed, V2Modifiers.new(), V2Rack.new())
	var w := TestWall.new()
	w.pitches = pitches
	w.attach(d.session)
	d.session.sys.wall = w
	d.start()
	d.go(&"climb")
	return d


## Commits the best valid move whose hold is no higher than [param below].
func climb_step(d: ClimbDirector, below := INF) -> bool:
	var s := d.session
	var best: V2Move = null
	for h: V2Hold in s.sys.body.reachable(s.pose.next_hand):
		if h.pos.y > below:
			continue
		var m := d.preview(h.id)
		if m.valid and (best == null or s.wall.hold(m.hold_id).pos.y > s.wall.hold(best.hold_id).pos.y):
			best = m
	if best == null:
		return false
	return d.commit(best)


## Climbs until the phase changes from climb or the hands are above [param y].
func climb_to(d: ClimbDirector, y: float, limit := 60) -> void:
	for i in limit:
		if d.session.phase != &"climb" or d.session.pose.high_point() >= y:
			return
		if not climb_step(d):
			return


func cruxes(d: ClimbDirector) -> CruxesV2:
	return d.session.sys.cruxes as CruxesV2


# -------------------------------------------------------------------- tests

func test_real_system_loads() -> void:
	check(ClimbSystems.path_for(&"cruxes").ends_with("cruxes/cruxes.gd"), "the registry loads thread 8's cruxes")
	var d := director_for([ladder()])
	check(d.session.sys.cruxes is CruxesV2, "the session runs CruxesV2")
	check(d.session.sys.body is BodyStub and d.session.sys.effort is EffortStub, "everything else stays on stubs")


## Every route's every pitch reads into v2 crux kinds: no timing, rhythm or
## mash survives, and every special has a kind the system can play.
func test_every_route_converts() -> void:
	var dir := DirAccess.open("res://data/routes")
	var bad: Array = []
	var count := 0
	var kinds := {}
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var r: RouteData = load("res://data/routes/" + f)
		if r == null or r.boulder:
			continue
		for p in r.pitches.size():
			var w := WallSourceStub.ladder(r, p)
			for s: Dictionary in CruxReader.spots_for(w, r, p):
				count += 1
				kinds[s.kind] = true
				if not str(s.kind) in ["sequence", "dyno", "swing", "nail", "chimney", "offwidth"]:
					bad.append("%s p%d %s" % [r.id, p, s.kind])
				if str(s.kind) in CruxReader.SPECIALS and not CruxesV2.SPECIAL_SCRIPTS.has(StringName(str(s.kind))):
					bad.append("%s p%d no special for %s" % [r.id, p, s.kind])
	print("      %d crux spots, kinds %s" % [count, kinds.keys()])
	check(count > 20 and bad.is_empty(), "every route's cruxes convert to v2 kinds %s" % [bad])
	check(kinds.has("swing") and kinds.has("nail") and kinds.has("dyno") and (kinds.has("chimney") or kinds.has("offwidth")), "the routes use every kind of special")


func test_profile_spots() -> void:
	var nose: RouteData = load("res://data/routes/the_nose.tres")
	var w := WallSourceStub.ladder(nose, 4)
	var spots := CruxReader.spots_for(w, nose, 4)
	check(spots.size() >= 1 and spots.any(func(s: Dictionary) -> bool: return s.kind == "swing" and s.name == "King Swing"), "the Nose's pitch 5 has the King Swing")
	var roof := CruxReader.spots_for(WallSourceStub.ladder(nose, 6), nose, 6)
	check(roof.all(func(s: Dictionary) -> bool: return s.kind == "nail"), "the Great Roof (hard aid) is nailed")
	var astro: RouteData = load("res://data/routes/astroman.tres")
	var slot := CruxReader.spots_for(WallSourceStub.ladder(astro, 5), astro, 5)
	var kinds := slot.map(func(s: Dictionary) -> String: return s.kind)
	check("dyno" in kinds and ("offwidth" in kinds or "chimney" in kinds), "Astroman's Harding Slot has the chicken wing dyno and a squeeze: %s" % [kinds])
	var swan: RouteData = load("res://data/routes/swan_slab.tres")
	var ss := CruxReader.spots_for(WallSourceStub.ladder(swan, 0), swan, 0)
	check(not ss.is_empty() and ss[0].preset == "slab", "Swan Slab's crux is a slab: stand tall")
	var r := CruxReader.rect_of(spots[0])
	check(r.position.y > w.start.y and r.end.y < w.top.y + 1.0, "a profile crux sits inside the pitch")


## The fixture's crux zone keeps its authored hand sequence.
func test_fixture_sequence() -> void:
	var w := V2Wall.from_dict(V2Data.load_json(WallSourceStub.FIXTURE))
	var spots := CruxReader.spots_for(w, null, 0)
	check(spots.size() == 1 and spots[0].id == "crux_top" and spots[0].sequence == ["lh", "rh", "lh"], "a wall crux zone becomes a spot with its sequence")
	# A special zone whose first hold is also tagged special:<kind> is one spot.
	var tagged := V2Wall.from_dict(swing_pitch())
	for h in tagged.holds:
		if h.id == "h9":
			h.tags.append("special:swing")
	check(CruxReader.spots_for(tagged, null, 0).size() == 1, "a tagged hold inside its special zone doesn't make a second spot")
	var h := w.hold("h14")
	var dem := CruxReader.demands(h, spots[0], w, 1)
	check(dem.any(func(x: Dictionary) -> bool: return x.id == "beta" and x.step.hand == "rh"), "step 2 of the authored beta asks for the right hand")


## A crux with a right-hand sidepull (pulled right, so you lean left off it).
func sidepull_pitch() -> Dictionary:
	var extra := [{"id": "sp", "pos": [3.4, 5.5], "kind": "sidepull", "pull": [1, 0], "size": 0.5, "foot": false}]
	var zones := [{"id": "sp_crux", "kind": "crux", "rect": [0.0, 5.0, 7.0, 1.2], "data": {"name": "The sidepull"}}]
	return ladder(12.0, extra, zones)


func test_sidepull_demands() -> void:
	var d := director_for([sidepull_pitch()])
	climb_to(d, 4.6)
	var s := d.session
	if s.pose.next_hand != &"rh":
		s.sys.body.swap_hand()
	var square := d.preview("sp")
	check(square.valid and square.crux_id == "sp_crux" and square.has_tag("crux"), "a move onto the sidepull is in the crux")
	check(not square.in_sequence and square.has_tag("crux_miss:hip_x-1"), "square hips miss the lean (tag says lean left)")
	var lean := d.preview("sp", Vector2(-0.15, 0))
	check(lean.in_sequence and not lean.has_tag("crux_miss:hip_x-1"), "one press of the body button to lean left is the beta")
	check(square.crux_cost > lean.crux_cost + 0.4 and lean.crux_cost >= 1.0, "barn-dooring costs more (%.2f vs %.2f)" % [square.crux_cost, lean.crux_cost])
	check(square.cost.pump > lean.cost.pump, "and effort charges it as pump (%.3f vs %.3f)" % [square.cost.pump, lean.cost.pump])
	s.sys.body.swap_hand()
	var wrong := d.preview("sp", Vector2(-0.15, 0))
	check(wrong.has_tag("crux_miss:hand_rh"), "the left hand on a right-hand sidepull is crossed up")


func test_preview_is_pure() -> void:
	var d := director_for([sidepull_pitch()])
	climb_to(d, 4.6)
	var before := JSON.stringify(d.session.snapshot())
	for h: V2Hold in d.session.sys.body.reachable(d.session.pose.next_hand):
		d.preview(h.id)
		d.preview(h.id, Vector2(-0.3, -0.15))
	check(JSON.stringify(d.session.snapshot()) == before, "crux previews change nothing")


func test_wrong_hand_carries() -> void:
	var d := director_for([sidepull_pitch()])
	climb_to(d, 4.6)
	var s := d.session
	if s.pose.next_hand != &"lh":
		s.sys.body.swap_hand()
	var m := d.preview("sp", Vector2(-0.15, 0))
	d.commit(m)
	var n: Dictionary = s.notes[&"cruxes"]
	check(float(n.get("carry", 0.0)) > 0.0, "a crossed-up move leaves you awkward for the next one")
	check(str(n.get("said", "")).contains("Crossed up"), "and you learn why: %s" % n.get("said", ""))
	var next: V2Move = null
	for h: V2Hold in s.sys.body.reachable(s.pose.next_hand):
		var p := d.preview(h.id)
		if p.valid and p.crux_id == "sp_crux":
			next = p
			break
	check(next == null or next.crux_cost > CruxTuning.ON_BETA_COST, "the next crux move costs more while crossed up")


func dyno_pitch() -> Dictionary:
	var extra := [{"id": "dyno_jug", "pos": [3.0, 6.2], "kind": "jug", "size": 0.9, "foot": false, "tags": ["dyno"]}]
	var zones := [{"id": "dyno", "kind": "crux", "rect": [0.0, 5.6, 7.0, 0.8], "data": {"kind": "dyno", "name": "The dyno"}}]
	return ladder(12.0, extra, zones)


func test_dyno() -> void:
	var d := director_for([dyno_pitch()])
	climb_to(d, 5.2)
	var straight := d.preview("dyno_jug")
	# Two presses down: legs bent and both feet on their holds.
	var crouched := d.preview("dyno_jug", Vector2(0, -0.3))
	if not straight.valid:
		# Out of static reach from here: one more move up the ladder.
		climb_step(d, 6.05)
		straight = d.preview("dyno_jug")
		crouched = d.preview("dyno_jug", Vector2(0, -0.3))
	check(straight.valid and straight.has_tag("dyno"), "the jump to the key hold is a dyno")
	check(straight.crux_risk > crouched.crux_risk + 0.1, "launching from straight legs is riskier (%.2f vs %.2f)" % [straight.crux_risk, crouched.crux_risk])
	check(crouched.crux_risk < 0.25, "a good launch rarely misses (%.2f)" % crouched.crux_risk)
	check(straight.risk >= straight.crux_risk, "falls (stub) adds the crux risk")
	d.session.effort.pump = 0.8
	var pumped := d.preview("dyno_jug", Vector2(0, -0.3))
	check(pumped.crux_risk > crouched.crux_risk + 0.15, "pump widens the miss chance (%.2f)" % pumped.crux_risk)


func test_crux_events() -> void:
	var d := director_for([sidepull_pitch()])
	climb_to(d, 4.6)
	var s := d.session
	if s.pose.next_hand != &"rh":
		s.sys.body.swap_hand()
	d.commit(d.preview("sp", Vector2(-0.15, 0)))
	climb_to(d, 7.5)
	check(s.bus.count(&"crux_entered") == 1 and s.bus.count(&"crux_sent") == 1, "entering and leaving a crux send crux_entered and crux_sent")
	check(s.result.perfect_cruxes + s.result.slipped_cruxes == 1, "the director counts the crux")


# ---------------------------------------------------------------- specials

func swing_pitch() -> Dictionary:
	# The far crack: jams up a line at x 6.3.
	var extra := []
	for i in 8:
		extra.append({"id": "far%d" % i, "pos": [6.3, 2.4 + 0.5 * i], "kind": "jam", "size": 0.6, "foot": true})
	var zones := [{"id": "swing", "kind": "crux", "rect": [0.0, 6.4, 7.0, 0.8], "data": {"special": "swing", "name": "King Swing"}}]
	return ladder(14.0, extra, zones)


## The phase's choices; [param pick] chooses one (a Callable on options).
func play(d: ClimbDirector, pick: Callable, limit := 40) -> int:
	var steps := 0
	while d.session.phase == &"special" and steps < limit:
		var ph := d.current as CruxSpecialPhase
		var o: Dictionary = pick.call(ph)
		ph.do_option(o)
		steps += 1
	return steps


func swing_bot(ph: CruxSpecialPhase) -> Dictionary:
	var sw := ph.special as SwingSpecial
	var opts := ph.options()
	for o: Dictionary in opts:
		if o.id == "grab":
			return o
	if sw.state.stage == "lower":
		return opts[1]
	# The kick whose ghost peak lands in reach, else the strongest.
	var best: Dictionary = {}
	for o: Dictionary in opts:
		if o.id == "kick":
			var p := sw.next_peak(str(o.footing))
			if sw.in_reach(p):
				return o
			if best.is_empty() or p > sw.next_peak(str(best.footing)) and p <= float(sw.state.d) + CruxTuning.SWING_SLAM_M:
				best = o
	return best


func test_swing() -> void:
	var d := director_for([swing_pitch()])
	climb_to(d, 6.5)
	var s := d.session
	check(s.phase == &"special" and (d.current as CruxSpecialPhase).special is SwingSpecial, "climbing into the King Swing opens the swing")
	var ph := d.current as CruxSpecialPhase
	check(ph.options().size() >= 2 and ph.options().size() <= 3 and ph.options()[0].id == "lower", "first you choose how far to lower out (%d choices)" % ph.options().size())
	var sw := ph.special as SwingSpecial
	var lands_short := sw.preview(ph.options()[0])
	var lands_long := sw.preview(ph.options().back())
	check(V2Data.vec(lands_long.land).y < V2Data.vec(lands_short.land).y, "more rope lands you lower on the crack")
	var steps := play(d, swing_bot)
	check(s.phase == &"climb", "the swing ends back in the climb (%d steps)" % steps)
	check(steps >= 3 and steps <= 9, "it takes a handful of swings, not a mash (%d)" % steps)
	check(s.pose.hip.x > 5.2, "you're across at the far crack (hips at x %.1f)" % s.pose.hip.x)
	check(s.bus.count(&"special_step") == steps and s.bus.count(&"special_finished") == 1, "each swing is a special_step")
	check(s.bus.names([&"special_started", &"special_finished"]) == [&"special_started", &"special_finished"], "started then finished")
	check(not s.sys.body.reachable(s.pose.next_hand).is_empty(), "and you can climb on from there")
	check((s.sys.cruxes as CruxesV2).special_at(Vector2(3.0, 6.8)) == &"", "the swing doesn't start again")
	# Wet footing skates: a kick off it goes less far than off an edge.
	var d2 := director_for([swing_pitch()])
	climb_to(d2, 6.5)
	var sw2 := (d2.current as CruxSpecialPhase).special as SwingSpecial
	check(sw2.next_peak("wet") < sw2.next_peak("edge") * 0.5, "a wet stripe gives a weak kick")


func nail_pitch() -> Dictionary:
	var zones := [{"id": "scars", "kind": "crux", "rect": [0.0, 5.0, 7.0, 2.4], "data": {"special": "nail", "name": "Pin scars"}}]
	return ladder(12.0, [], zones)


## Picks the pin that fits, drives it to a ring, tests, steps up.
func nail_bot(ph: CruxSpecialPhase) -> Dictionary:
	var ns := ph.special as NailSpecial
	var opts := ph.options()
	if ns.state.stage == "pick":
		for o: Dictionary in opts:
			if o.id == "pin" and ns.fit(str(o.pin)) == "snug":
				return o
		for o: Dictionary in opts:
			if o.id == "backclean":
				return o
		for o: Dictionary in opts:
			if o.id == "pin":
				return o
		return opts.back()
	var pin: Dictionary = ns.state.pin
	for want in ["tap", "test", "step"]:
		for o: Dictionary in opts:
			if o.id == want and (want != "tap" or float(pin.depth) < CruxTuning.RING_DEPTH):
				return o
	return opts[0]


func test_nailing() -> void:
	var d := director_for([nail_pitch()])
	climb_to(d, 5.2)
	var s := d.session
	check(s.phase == &"special" and (d.current as CruxSpecialPhase).special is NailSpecial, "the pin scars open nailing")
	var ns := (d.current as CruxSpecialPhase).special as NailSpecial
	var scars := (ns.state.scars as Array).size()
	var steps := play(d, nail_bot, 80)
	check(s.phase == &"climb", "you nail through and climb on (%d steps)" % steps)
	check(s.result.aid_moves == scars, "each pin is an aid move (%d of %d)" % [s.result.aid_moves, scars])
	var taps := s.bus.trace.filter(func(e: Array) -> bool: return e[0] == &"special_step" and e[1][1].get("stage", "") == "tap")
	check(not taps.is_empty() and taps.any(func(e: Array) -> bool: return e[1][1].tone == "ring"), "you hear the pins ring")
	check(taps.size() <= scars * CruxTuning.MAX_TAPS + 4, "a few taps a pin, not a mash (%d)" % taps.size())
	check(s.pose.high_point() > 6.8 or s.pose.hip.y > 6.5, "you're above the scars")


func test_nail_tones() -> void:
	var d := director_for([nail_pitch()])
	climb_to(d, 5.2)
	var ns := (d.current as CruxSpecialPhase).special as NailSpecial
	var sc := ns.scar()
	var big := ""
	var small := ""
	for id: String in ns.state.iron:
		var f := ns.fit(id)
		if f == "tight" and big == "":
			big = id
		if f == "loose":
			small = id
	if big != "":
		ns.state.scars[0].depth = 1.0
		ns.apply({"id": "pin", "pin": big})
		var fx := ns.apply({"id": "tap"})
		fx = ns.apply({"id": "tap"})
		check(str(fx.step.tone) == "ping" and bool(ns.state.pin.stopped), "a pin too big pings and stalls: tie it off")
		check(float(ns.state.pin.quality) < 0.5, "and it isn't much of a piece (%.2f)" % float(ns.state.pin.quality))
		ns.apply({"id": "pull"})
	if small != "":
		ns.apply({"id": "pin", "pin": small})
		var fx := ns.apply({"id": "tap"}) if ns.state.pin.taps == 0 else {}
		check(ns.state.pin.fit == "loose", "a pin too small clacks in loose")
		ns.apply({"id": "pull"})
	ns.state.scars[0].depth = 0.55
	var snug := ""
	for id: String in ns.state.iron:
		if ns.fit(id) == "snug" and int(ns.state.iron[id].count) > 0:
			snug = id
	if snug != "":
		ns.apply({"id": "pin", "pin": snug})
		var fx := ns.apply({"id": "tap"})
		check(str(fx.step.tone) == "thunk" and bool(ns.state.pin.stopped), "a shallow scar bottoms out with a thunk")
	check(sc.has("width"), "scars have widths to read")


func chimney_pitch(kind := "chimney") -> Dictionary:
	var zones := [{"id": "squeeze", "kind": "crux", "rect": [0.0, 4.8, 7.0, 3.0], "data": {"special": kind, "name": "The squeeze"}}]
	return ladder(12.0, [], zones)


func worm_bot(ph: CruxSpecialPhase) -> Dictionary:
	var w := ph.special as InchwormSpecial
	var opts := ph.options()
	if w.state.stage == "side":
		for o: Dictionary in opts:
			if float(o.side) == float(w.state.lean):
				return o
	var best: Dictionary = {}
	var best_score := -INF
	for o: Dictionary in opts:
		if o.id == "shuffle":
			var q := float(w.lock_at(str(o.half), float(o.y)).q)
			var score := q * 2.0 + float(o.y) * 0.5 if q >= CruxTuning.WORM_SLIP_BELOW else -10.0 - float(o.y)
			if score > best_score:
				best_score = score
				best = o
	return best


func test_inchworm() -> void:
	for kind in ["chimney", "offwidth"]:
		var d := director_for([chimney_pitch(kind)])
		climb_to(d, 5.0)
		var s := d.session
		check(s.phase == &"special" and (d.current as CruxSpecialPhase).special is InchwormSpecial, "the %s opens the inchworm" % kind)
		var ph := d.current as CruxSpecialPhase
		check(ph.options().size() == 2 and ph.options()[0].id == "side", "first you choose which side goes in")
		var gas0 := s.effort.gas
		var pump0 := s.effort.pump
		var steps := play(d, worm_bot, 60)
		check(s.phase == &"climb", "you squirm out the top of the %s (%d shuffles)" % [kind, steps])
		check(s.pose.hip.y > 7.0, "above the section (hips %.1f)" % s.pose.hip.y)
		check(gas0 - s.effort.gas > 0.0, "it costs gas (%.3f) and a little pump (%.3f)" % [gas0 - s.effort.gas, s.effort.pump - pump0])
	# A lock with no purchase slips you back.
	var d2 := director_for([chimney_pitch("offwidth")])
	climb_to(d2, 5.0)
	var w := (d2.current as CruxSpecialPhase).special as InchwormSpecial
	w.apply({"id": "side", "side": w.state.lean})
	var worst: Dictionary = {}
	for o: Dictionary in w.options():
		if o.id == "shuffle" and (worst.is_empty() or float(w.lock_at("upper", float(o.y)).q) < float(w.lock_at("upper", float(worst.y)).q)):
			worst = o
	var q := float(w.lock_at("upper", float(worst.y)).q)
	var before := float(w.state.upper)
	var fx := w.apply(worst)
	if q < CruxTuning.WORM_SLIP_BELOW:
		check(float(w.state.upper) < before and bool(fx.step.slipped), "a lock that won't seat slides you back")
	else:
		check(float(w.state.upper) > before, "every spot here locks (q %.2f)" % q)
	check(w.width_at(5.0) != w.width_at(6.0), "the crack flares and pinches")


func test_haul() -> void:
	var r := route("haul_test", 2, 1)
	var d := director_for([ladder(10.0), ladder(10.0)], r)
	var s := d.session
	s.notes[&"cruxes"]["bag"] = true
	climb_to(d, 10.5, 80)
	check(s.phase == &"special" and (d.current as CruxSpecialPhase).special is HaulSpecial, "topping out a big-wall pitch starts the haul")
	var lips := ((d.current as CruxSpecialPhase).special.state.lips as Array).size()
	var steps := play(d, func(ph: CruxSpecialPhase) -> Dictionary:
		var opts := ph.options()
		return opts[0], 20)
	check(s.phase == &"belay", "the bag docks and you're on belay (%d decisions)" % steps)
	check(steps >= 2 and steps <= 2 + lips * 3, "a few decisions per haul, not fifty presses (%d, %d lips)" % [steps, lips])
	check((s.sys.cruxes as CruxesV2).belay_special() == &"", "you only haul once a pitch")
	# The last pitch has nothing to haul to.
	var d2 := director_for([ladder(10.0)], route("haul_last", 1, 1))
	d2.session.notes[&"cruxes"]["bag"] = true
	check((d2.session.sys.cruxes as CruxesV2).belay_special() == &"", "no haul off the last pitch")


func test_special_snapshot() -> void:
	var d := director_for([swing_pitch()])
	climb_to(d, 6.5)
	var ph := d.current as CruxSpecialPhase
	ph.do_option(ph.options()[1])
	ph.do_option(swing_bot(ph))
	var snap := d.session.snapshot()
	var peak := float(ph.special.state.peak)
	ph.do_option(swing_bot(ph))
	d.session.restore(snap)
	d.go(&"special", {"kind": &"swing"})
	var ph2 := d.current as CruxSpecialPhase
	check(is_equal_approx(float(ph2.special.state.peak), peak), "a snapshot holds the swing mid-way")


func test_determinism() -> void:
	var a := _nail_trace(5)
	var b := _nail_trace(5)
	check(a == b and a != "", "the same seed nails the same way")


func _nail_trace(seed: int) -> String:
	var d := director_for([nail_pitch()], null, seed)
	climb_to(d, 5.2)
	play(d, nail_bot, 80)
	return JSON.stringify(d.session.bus.trace.filter(func(e: Array) -> bool: return e[0] == &"special_step").map(func(e: Array) -> Variant: return e[1][1]))


func test_screen() -> void:
	ClimbV2.force = true
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	var nose: RouteData = load("res://data/routes/the_nose.tres")
	screen.setup(nose, 11, V2Modifiers.new(), V2Rack.new())
	add_child(screen)
	await get_tree().process_frame
	var overlay := screen.overlays.get_node_or_null("cruxes")
	check(overlay is CruxOverlay, "the screen mounts the crux overlay")
	await get_tree().process_frame
	check(is_instance_valid(screen), "the screen runs with real cruxes")
	screen.queue_free()
	ClimbV2.force = null
