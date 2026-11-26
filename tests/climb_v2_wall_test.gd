extends Node
## Headless test of climbing v2's wall and routes (thread 2,
## scripts/climb/v2/wall): every route has an authored plan, every pitch of
## every route passes WallCheck (a climbable line, protection with no runout
## longer than the plan allows, sane cracks and cruxes), walls are the same
## every time, trad routes have constrictions for nuts, swing cruxes join up,
## the fixture route still gets the frozen fixture, a route with no plan gets
## an automatic one, and a scripted climber gets up every route on the real
## walls with every other system a stub.
## Run: godot --headless --path . res://tests/climb_v2_wall_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	ClimbSystems.pin_stubs_except([&"wall"])
	test_registry()
	test_every_route_has_a_plan()
	test_every_pitch_is_sound()
	test_determinism()
	test_trad_has_constrictions()
	test_cruxes()
	test_fixture_and_auto()
	test_bot_climbs_every_route()
	ClimbSystems.pins.clear()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


static func routes() -> Array[RouteData]:
	var out: Array[RouteData] = []
	for file in DirAccess.get_files_at("res://data/routes"):
		if file.ends_with(".tres"):
			out.append(load("res://data/routes/" + file))
	return out


static func full_rack() -> V2Rack:
	var r := V2Rack.new()
	var items := []
	for w in ClimbRack.MAX_WIDTH + 1:
		items.append({"id": "cam_w%d" % w, "kind": "cam", "width_min": w, "width_max": w, "count": 2, "name": ClimbRack.width_size(w)})
	items.append({"id": "nut_small", "kind": "nut", "width_min": 0, "width_max": 1, "count": 2, "name": "Small nut"})
	items.append({"id": "nut_mid", "kind": "nut", "width_min": 2, "width_max": 3, "count": 2, "name": "Nut"})
	items.append({"id": "quickdraw", "kind": "draw", "width_min": -1, "width_max": -1, "count": 30, "name": "Quickdraw"})
	items.append({"id": "sling", "kind": "sling", "width_min": -1, "width_max": -1, "count": 4, "name": "Sling"})
	r.items.assign(items)
	return r


func test_registry() -> void:
	check(ClimbSystems.is_real(&"wall"), "the registry runs the real wall source (wall/wall.gd)")
	check(ClimbSystems.make(&"wall") is RouteWall, "it is a RouteWall, a WallSource")


func test_every_route_has_a_plan() -> void:
	var all := routes()
	check(all.size() >= 14, "found the routes (%d)" % all.size())
	for route in all:
		check(WallPlan.has_file(route.id), "%s has an authored plan" % route.id)
		var n := RouteWall.new().pitch_count(route)
		check(n == route.pitches.size(), "%s: %d pitches, as many as the route has (%d)" % [route.id, n, route.pitches.size()])


func test_every_pitch_is_sound() -> void:
	var pitches := 0
	for route in routes():
		for i in RouteWall.new().pitch_count(route):
			var w := RouteWall.build(route, i)
			var probs := WallCheck.problems(w)
			check(probs.is_empty(), "%s p%d is sound%s" % [route.id, i + 1, "" if probs.is_empty() else ": " + "; ".join(probs)])
			check(str(w.info.get("name", "")) != "" and str(w.info.get("beta", "")) != "", "%s p%d has a name and beta" % [route.id, i + 1])
			pitches += 1
	check(pitches >= 60, "checked every pitch (%d)" % pitches)


func test_determinism() -> void:
	for route in routes():
		var a := JSON.stringify(RouteWall.build(route, 0).to_dict())
		var b := JSON.stringify(RouteWall.new().build_pitch(route, 0, 12345).to_dict())
		check(a == b, "%s is the same rock every time, whatever the seed" % route.id)
	var nut: RouteData = load("res://data/routes/nutcracker.tres")
	var w := RouteWall.build(nut, 1)
	var back := V2Wall.from_dict(JSON.parse_string(JSON.stringify(w.to_dict())))
	check(JSON.stringify(back.to_dict()) == JSON.stringify(w.to_dict()), "a wall survives a round trip through JSON")


## Nuts need constrictions: every trad route has some, and the Nutcracker
## (first climbed on nuts alone) has one on every pitch.
func test_trad_has_constrictions() -> void:
	for route in routes():
		if route.protection == "bolts" or route.top_rope or route.boulder or route.id == "lyell_glacier":
			continue
		var found := 0
		for i in RouteWall.new().pitch_count(route):
			for c in RouteWall.build(route, i).cracks:
				found += c.constrictions.size()
		check(found >= 3, "%s has constrictions for nuts (%d)" % [route.id, found])
	var nut: RouteData = load("res://data/routes/nutcracker.tres")
	for i in nut.pitches.size():
		var n := 0
		for c in RouteWall.build(nut, i).cracks:
			n += c.constrictions.size()
		check(n > 0, "nutcracker p%d takes a nut" % (i + 1))
	var bolted: RouteData = load("res://data/routes/snake_dike.tres")
	check(WallCheck.longest_runout(RouteWall.build(bolted, 3)) > 6.0, "Snake Dike is really runout (graded R)")


func test_cruxes() -> void:
	var nose: RouteData = load("res://data/routes/the_nose.tres")
	var swing := RouteWall.build(nose, 4)
	var zone: V2Zone = null
	for z in swing.zones:
		if z.kind == &"crux" and z.data.get("special", "") == "swing":
			zone = z
	check(zone != null, "the Nose's King Swing is a swing crux")
	if zone:
		var from := swing.hold(str(zone.data.get("from", "")))
		var to := swing.hold(str(zone.data.get("to", "")))
		check(from != null and to != null and from.has_tag("special:swing"), "the swing has a jug to swing from and a crack to land in")
		check(from and to and from.pos.distance_to(to.pos) > 3.0, "it crosses blank rock too far to reach")
		var free := swing.holds.filter(func(h: V2Hold) -> bool: return h.has_tag("free_variation"))
		check(not free.is_empty(), "a hard free way round exists too")
	var specials := {}
	for rid in ["royal_arches", "the_nose", "steck_salathe", "astroman"]:
		var route: RouteData = load("res://data/routes/%s.tres" % rid)
		for i in route.pitches.size():
			for z in RouteWall.build(route, i).zones:
				if z.kind == &"crux":
					specials["%s:%s" % [rid, z.data.get("name", "")]] = [z.data.get("special", ""), z.data.get("kind", "")]
	check(specials.get("royal_arches:Pendulum", [""])[0] == "swing", "the Royal Arches pendulum is a swing for the crux system")
	check(specials.get("the_nose:Great Roof", [""])[0] == "nail", "the Great Roof (an aid crux) is nailed")
	check(specials.get("steck_salathe:The Narrows", [""])[0] == "chimney", "the Narrows is a chimney special")
	check(specials.get("steck_salathe:Wilson Overhang", [""])[0] == "offwidth", "the Wilson Overhang is an offwidth special")
	check(specials.get("astroman:Chicken wing", ["", ""])[1] == "dyno", "the chicken wing lunge is a dyno")
	var harding := RouteWall.build(load("res://data/routes/astroman.tres"), 5)
	check(harding.holds.any(func(h: V2Hold) -> bool: return h.has_tag("dyno")), "the dyno's target hold is tagged")
	var sep: RouteData = load("res://data/routes/separate_reality.tres")
	var roof := RouteWall.build(sep, 0)
	var seq_ok := true
	var named := 0
	for z in roof.zones:
		if z.kind == &"crux":
			named += 1
			var seq: Array = z.data.get("sequence", [])
			for i in seq.size():
				var tag := "seq:%d:%s" % [i, seq[i]]
				if not roof.holds.any(func(h: V2Hold) -> bool: return h.has_tag(tag)):
					seq_ok = false
	check(named == 2, "Separate Reality has its roof and lip cruxes")
	check(seq_ok, "every move of a crux sequence has its hold")
	var lefts := roof.holds.filter(func(h: V2Hold) -> bool: return h.has_tag("roof"))
	check(not lefts.is_empty(), "roof holds are tagged for the art and body")
	var mantel := RouteWall.build(load("res://data/routes/nutcracker.tres"), 4)
	check(mantel.zones.any(func(z: V2Zone) -> bool: return z.data.get("hip", "") == "mantel" and str(z.data.get("read", "")) != ""), "the Nutcracker mantel tells the hips what to do, and has a mentor's read")


func test_fixture_and_auto() -> void:
	var fx := RouteData.new()
	fx.id = "v2_fixture"
	var w := RouteWall.new().build_pitch(fx, 0, 1)
	var frozen := V2Wall.from_dict(V2Data.load_json("res://data/climb/v2/fixture_pitch.json"))
	check(w.holds.size() == frozen.holds.size(), "the fixture route still gets the frozen fixture")
	var other: RouteData = (load("res://data/routes/astroman.tres") as RouteData).duplicate()
	other.id = "no_such_route"
	WallPlan.clear_cache()
	var plan := WallPlan.for_route(other)
	check(plan.get("auto", false), "a route with no file gets an automatic plan")
	var auto_ok := true
	for i in other.pitches.size():
		var aw := WallBuilder.build(WallPlan.pitch(other, i), other.id, i)
		if not WallCheck._check_climbable_ok(aw):
			auto_ok = false
	check(auto_ok, "the automatic plan is climbable on every pitch")


func test_bot_climbs_every_route() -> void:
	for route in routes():
		if route.boulder:
			continue
		var d := ClimbDirector.new()
		# Pump is the effort thread's to balance; at half the stub's pump this
		# proves the rock goes, not the tuning.
		var mods := V2Modifiers.new()
		mods.pump_mult = 0.5
		d.setup(route, 5, mods, full_rack())
		d.start()
		var bot := UpBot.new(d)
		bot.rest_at = 0.2
		var ok := bot.run(6000)
		check(ok, "%s climbs end to end on its real walls (%d steps, %d falls)" % [route.id, bot.steps, d.session.result.falls])


## The foundation's test bot, but it reads the route first: it follows
## WallCheck.plan (the fewest moves to the anchor, with the body stub's
## reach), swapping hands when the plan wants the other one. Off the plan
## (after a fall), it takes the highest hold upward.
class UpBot extends ClimbV2TestBot:
	func best_move() -> V2Move:
		var s := director.session
		var lh: V2Limb = s.pose.limb(&"lh")
		var rh: V2Limb = s.pose.limb(&"rh")
		var states := WallCheck.plan(s.wall, lh.id, rh.id, false)
		if not states.is_empty():
			var want: Array = states[0]
			var hand: StringName = &"lh" if want[0] != lh.id else &"rh"
			var target: String = want[0] if hand == &"lh" else want[1]
			if s.pose.next_hand != hand:
				s.sys.body.swap_hand()
			var m := director.preview(target)
			if m.valid:
				return m
		var hold: V2Limb = s.pose.limb(s.pose.next_hand)
		var best: V2Move = null
		var best_y := -INF
		for h in s.sys.body.reachable(s.pose.next_hand):
			if hold.kind == &"hold" and h.pos.y < hold.pos.y + 0.05:
				continue
			var m := director.preview(h.id)
			if m.valid and h.pos.y > best_y:
				best = m
				best_y = h.pos.y
		return best
