extends Node
## Headless test of the climbing v2 body (scripts/climb/v2/body, thread 3):
## the auto-picked hand, aiming, the hip lattice, ghost previews, and the
## techniques that fall out of the geometry, each on a tiny golden wall where
## the right hip cell must beat neutral and the tag must fire. Every other
## system is pinned to its stub, so other threads' merges can't move these.
## Run: godot --headless --path . res://tests/climb_v2_body_test.tscn
## BODY_DEBUG=1 prints each golden wall's lattice.
## Exit code is the number of failed checks.

const Fixture := preload("res://tests/climb_v2_test.gd")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	ClimbSystems.pin_stubs_except([&"body"])
	if OS.get_environment("BODY_DEBUG") != "":
		debug_fixture()
	test_registry()
	test_start_pose()
	test_preview_is_pure()
	test_auto_hand()
	test_aim()
	test_hip_button()
	test_climb_fixture()
	test_determinism()
	test_ladder_route()
	test_techniques()
	test_rests_and_hands()
	test_review_fixes()
	test_hang()
	await test_screen()
	ClimbSystems.pins.clear()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


func new_director(seed := 7, pitches := 2) -> ClimbDirector:
	var d := ClimbDirector.new()
	d.setup(Fixture.fixture_route(pitches), seed, V2Modifiers.new(), Fixture.fixture_rack())
	return d


func started(seed := 7, pitches := 2) -> ClimbDirector:
	var d := new_director(seed, pitches)
	d.start()
	d.handle_verb(&"commit", true)
	return d


func test_registry() -> void:
	check(ClimbSystems.is_real(&"body"), "the real body is at body/body.gd")
	var d := new_director()
	check(d.session.sys.body is ClimbBody, "the director builds the real body")
	check(not ClimbSystems.is_real(&"effort") and not ClimbSystems.is_real(&"wall"), "everything else is pinned to stubs")


func test_start_pose() -> void:
	var d := new_director()
	d.start()
	var p := d.session.pose
	var lh: V2Limb = p.limb(&"lh")
	var rh: V2Limb = p.limb(&"rh")
	check(lh.kind == &"hold" and rh.kind == &"hold", "both hands start on holds")
	check(lh.pos.x <= rh.pos.x, "left hand on the left")
	check((p.limb(&"lf") as V2Limb).on_rock() and (p.limb(&"rf") as V2Limb).on_rock(), "both feet start on rock")
	check(p.next_hand == (&"lh" if lh.pos.y < rh.pos.y else &"rh"), "the lower hand goes first")


func test_preview_is_pure() -> void:
	var d := started()
	var s := d.session
	var before := s.snapshot()
	var events := s.bus.trace.size()
	var body: ClimbBody = s.sys.body
	for h in s.wall.holds:
		for cell in ClimbBody.lattice():
			body.preview(h.id, cell)
		body.suggest_shift(h.id)
		body.reachable(&"lh")
		body.reachable(&"rh")
	body.rest_kind()
	body.free_hand()
	check(s.snapshot() == before, "previews and queries change nothing")
	check(s.bus.trace.size() == events, "previews send no events")


func test_auto_hand() -> void:
	var d := started()
	var s := d.session
	var phase := d.current as BodyAimPhase
	check(phase != null, "the climb phase is the body's")
	var first := s.pose.next_hand
	var m := phase.move
	check(m != null and m.valid, "the climb starts aimed at a move that goes")
	d.handle_verb(&"commit", true)
	check(s.pose.next_hand != first, "after a move the other (lower) hand goes next")
	var swapped := s.pose.next_hand
	d.handle_verb(&"swap", true)
	check(s.pose.next_hand != swapped and s.bus.trace[-1][0] in [&"move_previewed", &"aim_changed"], "swap gives the move to the other hand and re-aims")
	d.handle_verb(&"swap", true)
	check(s.pose.next_hand == swapped, "swapping back finds the same hand")


func test_aim() -> void:
	var d := started()
	var s := d.session
	var phase := d.current as BodyAimPhase
	var start_aim := phase.aimed
	check(start_aim != "" and start_aim in phase.aim_set, "the aim starts on a hold in the set")
	# Every hold in the set can be reached from every other by arrows.
	var seen := {start_aim: true}
	var frontier := [start_aim]
	while not frontier.is_empty():
		var from: String = frontier.pop_back()
		for dir: Vector2 in BodyAimPhase.DIRS.values():
			phase.aim_at(from)
			phase.aim_toward(dir)
			if not seen.has(phase.aimed):
				seen[phase.aimed] = true
				frontier.append(phase.aimed)
	check(seen.size() == phase.aim_set.size(), "arrows reach every hold in the aim set (%d of %d)" % [seen.size(), phase.aim_set.size()])
	phase.aim_at(start_aim)
	d.handle_verb(&"aim_up", true)
	var up := s.wall.hold(phase.aimed)
	check(up != null and up.pos.y >= s.wall.hold(start_aim).pos.y - 0.01, "Up aims at a hold no lower")


func test_hip_button() -> void:
	var d := started()
	var s := d.session
	var phase := d.current as BodyAimPhase
	var aim := phase.aimed
	d.handle_verb(&"body", true)
	d.handle_verb(&"aim_up", true)
	check(phase.hip_shift == Vector2(0, 0.15), "body + Up steps the hips 0.15 m up")
	check(phase.aimed == aim, "shifting the hips keeps the aim")
	check(s.bus.count(&"hip_changed") == 1, "a hip step sends hip_changed")
	d.handle_verb(&"aim_left", true)
	d.handle_verb(&"aim_left", true)
	d.handle_verb(&"aim_left", true)
	check(phase.hip_shift == Vector2(BodyTuning.HIP_MIN.x, 0.15), "the hips stop at the lattice's edge")
	d.handle_verb(&"body", false)
	check(phase.aimed == aim and phase.hip_shift != Vector2.ZERO, "letting go of the body button keeps aim and hips")
	d.handle_verb(&"body", true)
	d.handle_verb(&"body", false)
	check(phase.hip_shift == Vector2.ZERO, "a tap of the body button recentres the hips")
	check(ClimbBody.lattice().size() == 30 and ClimbBody.lattice()[0] == Vector2.ZERO, "30 lattice cells, neutral first")


func test_climb_fixture() -> void:
	var d := new_director()
	var bot := ClimbV2BodyBot.new(d)
	d.start()
	var ok := bot.run(900)
	var s := d.session
	print("      fixture: %d moves, %d shifted, %d swaps, pump %.2f, %d minutes" % [bot.moves, bot.shifted, bot.swaps, s.effort.pump, s.minutes])
	check(ok, "the body bot tops out the fixture's two pitches")
	check(s.result.falls == 0, "without falling")
	check(s.bus.count(&"clipped") >= 4, "clipping along the way")


func test_determinism() -> void:
	var a := new_director(11)
	ClimbV2BodyBot.new(a).run_from_start()
	var b := new_director(11)
	ClimbV2BodyBot.new(b).run_from_start()
	check(a.session.bus.names() == b.session.bus.names() and a.session.pose.to_dict() == b.session.pose.to_dict(), "the same seed climbs the same way")


func test_ladder_route() -> void:
	var climbed := 0
	var tried := 0
	for path in DirAccess.get_files_at("res://data/routes"):
		if not path.ends_with(".tres"):
			continue
		var route: RouteData = load("res://data/routes/" + path)
		if route.boulder or route.pitches.size() > 3:
			continue
		tried += 1
		var d := ClimbDirector.new()
		d.setup(route, 3, V2Modifiers.new(), Fixture.fixture_rack())
		d.start()
		var bot := ClimbV2BodyBot.new(d)
		if bot.run(2500):
			climbed += 1
		else:
			print("      stuck on %s at %.1f m (%s, %d steps, %d moves)" % [route.id, d.session.pose.high_point(), d.session.phase, bot.steps, bot.moves])
			if OS.get_environment("BODY_DEBUG") != "":
				dump(d)
		if tried >= 6:
			break
	check(tried > 0 and climbed == tried, "the body climbs real routes on the stub wall (%d of %d)" % [climbed, tried])


func debug_fixture() -> void:
	var d := started()
	var s := d.session
	var body: ClimbBody = s.sys.body
	for step in 6:
		var p := s.pose
		print("pose hip %s next %s lh %s rh %s lf %s rf %s" % [p.hip, p.next_hand, p.limb(&"lh").id, p.limb(&"rh").id, p.limb(&"lf").id, p.limb(&"rf").id])
		for h in body.reachable(p.next_hand):
			var m := body.preview(h.id)
			var sug: Array = body.suggest_shift(h.id)
			var sm: V2Move = sug[1]
			print("  %s %s n: v=%s r=%.2f st=%.2f se=%.2f %s %s | best %s st=%.2f se=%.2f %s" % [h.id, h.pos, m.valid, m.reach, m.strain, m.security, m.reason, m.tags, sug[0], sm.strain if sm else -1.0, sm.security if sm else -1.0, sm.tags if sm else []])
		var bot := ClimbV2BodyBot.new(d)
		var pick := bot.choose(d.current)
		if pick.is_empty():
			break
		(d.current as BodyAimPhase).aim_at(pick[0])
		(d.current as BodyAimPhase).set_hip_shift(pick[1])
		d.handle_verb(&"commit", true)


func dump(d: ClimbDirector) -> void:
	var s := d.session
	var body: ClimbBody = s.sys.body
	var p := s.pose
	print("last events %s pump %.2f" % [s.bus.names().slice(-12), s.effort.pump])
	print("pose hip %s next %s lh %s rh %s lf %s rf %s tags %s angle %s" % [p.hip, p.next_hand, p.limb(&"lh").to_dict(), p.limb(&"rh").to_dict(), p.limb(&"lf").to_dict(), p.limb(&"rf").to_dict(), p.tags, s.wall.angle])
	for hand: StringName in [&"lh", &"rh"]:
		for h in body.reachable(hand):
			var sug: Array = body.suggest_shift(h.id, hand)
			print("  %s %s %s %s best %s" % [hand, h.id, h.pos, h.kind, sug[0] if sug[1] else "none"])


# ---------------------------------------------------------------- golden walls

## A director whose session sits on a hand-made wall in a hand-made pose.
## [param holds]: [id, x, y, kind, size, "h"/"f"/"hf", pull, tags]...
func on_wall(holds: Array, hands: Array, feet: Array, next: StringName, angle := 0.0, cracks: Array = []) -> ClimbDirector:
	var d := started()
	var w := V2Wall.new()
	w.size = Vector2(6, 12)
	w.start = Vector2(3, 0)
	w.top = Vector2(3, 11)
	w.angle = angle
	for spec: Array in holds:
		var h := V2Hold.new()
		h.id = spec[0]
		h.pos = Vector2(spec[1], spec[2])
		h.kind = StringName(spec[3])
		h.size = spec[4]
		var use: String = spec[5] if spec.size() > 5 else "h"
		h.hand = use.contains("h")
		h.foot = use.contains("f")
		h.pull = spec[6] if spec.size() > 6 else Vector2(0, -1)
		h.tags = PackedStringArray(spec[7] if spec.size() > 7 else [])
		if spec.size() > 8:
			h.crack_id = spec[8]
		w.holds.append(h)
	for c: V2Crack in cracks:
		w.cracks.append(c)
	d.session.wall = w
	var p := V2Pose.new()
	for i in 2:
		var hand: StringName = [&"lh", &"rh"][i]
		var hh := w.hold(hands[i])
		p.set_limb(hand, V2Limb.make(&"hold", hh.pos, hh.id) if hh else V2Limb.make(&"free", Vector2(3, 2)))
		var foot: StringName = [&"lf", &"rf"][i]
		var fh := w.hold(feet[i])
		p.set_limb(foot, V2Limb.make(&"hold", fh.pos, fh.id) if fh else V2Limb.make(&"free", Vector2(3, 1)))
	p.next_hand = next
	p.hip = (d.session.sys.body as ClimbBody).base_hip(p, next)
	d.session.pose = p
	# A fresh turn on this pose, without the body's own hand swap.
	var phase := d.current as BodyAimPhase
	phase._turn_pose = p.to_dict()
	phase.hip_shift = Vector2.ZERO
	phase._rebuild_set()
	phase._pick_aim("")
	return d


func table(d: ClimbDirector, hold_id: String, label: String) -> void:
	if OS.get_environment("BODY_DEBUG") == "":
		return
	var body: ClimbBody = d.session.sys.body
	print("  -- %s -> %s" % [label, hold_id])
	for cell in ClimbBody.lattice():
		var m := body.preview(hold_id, cell)
		print("    %s v=%s r=%.2f st=%.2f se=%.2f %s %s" % [cell, m.valid, m.reach, m.strain, m.security, m.tags, m.reason])


func score(m: V2Move) -> float:
	return m.security - 0.9 * m.strain if m and m.valid else -INF


func test_techniques() -> void:
	# High step: the next hold is out of reach until the hips stand up on a high foot.
	var d := on_wall([["a", 2.8, 3.0, "jug", 0.9], ["b", 3.2, 2.6, "edge", 0.6], ["t", 3.1, 3.75, "crimp", 0.35],
		["f1", 2.8, 1.3, "edge", 0.6, "f"], ["f2", 3.3, 2.1, "edge", 0.6, "f"]], ["a", "b"], ["f1", ""], &"rh")
	var body: ClimbBody = d.session.sys.body
	table(d, "t", "high step")
	var n := body.preview("t")
	var best: Array = body.suggest_shift("t")
	check(not n.valid and n.reason.begins_with("too far"), "a hold above reach is too far from neutral hips")
	check(best[1] != null and best[0].y > 0.0 and (best[1] as V2Move).has_tag("highstep"), "standing up on a high foot gets there (a high step)")
	d.current.aim_at("t")
	check((d.current as BodyAimPhase).fix.contains("up"), "the hint says to bring the hips up")

	# Flag: reaching right with only a left foot swings the body open; leaning
	# the hips back left lets the free leg flag and holds it.
	d = on_wall([["a", 2.4, 3.0, "jug", 0.9], ["b", 2.6, 2.6, "edge", 0.6], ["t", 3.25, 3.15, "edge", 0.6],
		["f1", 2.3, 1.6, "edge", 0.6, "f"]], ["a", "b"], ["f1", ""], &"rh", 20.0)
	body = d.session.sys.body
	table(d, "t", "flag")
	n = body.preview("t")
	best = body.suggest_shift("t")
	var bm: V2Move = best[1]
	check(n.valid and n.has_tag("barndoor"), "reaching across from one foot barn-doors at neutral")
	check(bm != null and bm.has_tag("flag") and not bm.has_tag("barndoor") and score(bm) > score(n), "a flag holds it, and costs less")

	# Drop-knee: a hold far to the right; turning the hips in on a high
	# outside foot brings it into reach.
	d = on_wall([["a", 2.6, 3.0, "jug", 0.9], ["b", 2.8, 2.5, "edge", 0.6], ["t", 3.85, 3.25, "edge", 0.6],
		["f1", 2.6, 1.4, "edge", 0.6, "f"], ["f2", 3.35, 1.95, "edge", 0.6, "f"]], ["a", "b"], ["f1", "f2"], &"rh")
	body = d.session.sys.body
	table(d, "t", "drop knee")
	n = body.preview("t")
	var turned := body.preview("t", Vector2(0.3, 0))
	check(turned.valid and turned.has_tag("dropknee") and (not n.valid or turned.reach < n.reach), "turning the hips in on a high foot is a drop-knee that reaches further")

	# Layback: two holds that pull left (a flake facing left); leaning the hips
	# off with the feet up is a layback, and holds better than square.
	d = on_wall([["a", 3.0, 3.0, "sidepull", 0.55, "h", Vector2(-1, 0)], ["b", 3.0, 2.4, "sidepull", 0.55, "h", Vector2(-1, 0)],
		["t", 3.05, 3.6, "sidepull", 0.55, "h", Vector2(-1, 0)], ["f1", 3.25, 1.75, "edge", 0.5, "f"], ["f2", 3.2, 1.3, "edge", 0.5, "f"]],
		["a", "b"], ["f2", "f1"], &"rh")
	body = d.session.sys.body
	table(d, "t", "layback")
	n = body.preview("t")
	var lean := body.preview("t", Vector2(-0.3, 0))
	check(lean.valid and lean.has_tag("layback") and lean.security > n.security, "leaning off sidepulls with the feet up is a layback, and holds better")

	# Stem: the only feet are wide on both walls of a corner.
	d = on_wall([["a", 2.8, 3.0, "edge", 0.6], ["b", 3.2, 2.6, "edge", 0.6], ["t", 3.0, 3.5, "edge", 0.6],
		["f1", 2.35, 1.5, "edge", 0.6, "f"], ["f2", 3.65, 1.5, "edge", 0.6, "f"]], ["a", "b"], ["f1", "f2"], &"rh")
	body = d.session.sys.body
	table(d, "t", "stem")
	n = body.preview("t")
	check(n.valid and n.has_tag("stem") and float(n.load[&"lf"]) + float(n.load[&"rf"]) > 0.5, "wide feet around the hips stem, and the feet take the weight")
	d.commit(n)
	check(body.rest_kind() == &"stem", "a stem is a rest")

	# Jams: a crack takes a hand by its width.
	var widths := {1.8: "finger_jam", 4.2: "hand_jam", 5.8: "fist_jam", 7.0: "offwidth"}
	var grips := {}
	for w: float in widths:
		var c := V2Crack.new()
		c.id = "c"
		c.points = PackedVector2Array([Vector2(3.1, 1.0), Vector2(3.1, 5.0)])
		c.widths = PackedFloat32Array([w, w])
		d = on_wall([["a", 2.8, 3.0, "jug", 0.9], ["b", 3.1, 2.6, "jam", 0.6, "h", Vector2(0, -1), [], "c"],
			["t", 3.1, 3.4, "jam", 0.6, "h", Vector2(0, -1), [], "c"], ["f1", 2.9, 1.6, "edge", 0.6, "f"], ["f2", 3.2, 1.9, "edge", 0.6, "f"]],
			["a", "b"], ["f1", "f2"], &"rh", 0.0, [c])
		body = d.session.sys.body
		var best_cell := ClimbBody.clamp_shift(Vector2(3.1 - body.base_hip().x, 0))
		var jm := body.preview("t", best_cell)
		check(jm.valid and jm.has_tag(widths[w]), "a %.1f crack, hips square: %s" % [w, widths[w]])
		d.commit(jm)
		grips[w] = body.grip_of(&"rh")
	check(grips[4.2] > grips[1.8] and grips[4.2] > grips[5.8] and grips[5.8] > grips[7.0], "hands jam best in hand-size cracks, worst in offwidths")

	# Dyno and lunge.
	d = on_wall([["a", 2.8, 3.0, "jug", 0.9], ["b", 3.2, 2.6, "edge", 0.6], ["t", 3.1, 4.0, "jug", 0.9], ["l", 3.1, 3.72, "jug", 0.9],
		["f1", 2.8, 1.6, "edge", 0.6, "f"], ["f2", 3.2, 1.9, "edge", 0.6, "f"]], ["a", "b"], ["f1", "f2"], &"rh")
	body = d.session.sys.body
	table(d, "t", "dyno")
	n = body.preview("t")
	var low := body.preview("t", Vector2(0, -0.45))
	check(not n.valid and n.reason.contains("sit the hips low"), "a far jug says to sit low and throw")
	check(low.valid and low.has_tag("dyno") and low.security < 0.5, "from low hips it's a dyno, and a risky one")
	var lunge := body.preview("l")
	table(d, "l", "lunge")
	check(lunge.valid and lunge.has_tag("lunge"), "just past reach on a good hold is a lunge")

	# Lock-off: shoving the hips up on an easy move costs more than neutral
	# (no free "always hips up").
	d = on_wall([["a", 2.8, 3.0, "edge", 0.6], ["b", 3.2, 2.7, "edge", 0.6], ["t", 3.2, 3.45, "edge", 0.6],
		["f1", 2.8, 1.6, "edge", 0.6, "f"], ["f2", 3.2, 1.6, "edge", 0.6, "f"]], ["a", "b"], ["f1", "f2"], &"rh")
	body = d.session.sys.body
	table(d, "t", "lock-off")
	n = body.preview("t")
	var up := body.preview("t", Vector2(0, 0.3))
	check(n.valid and up.valid and up.strain > n.strain and up.has_tag("lockoff"), "hips shoved up lock the staying arm off: more strain on an easy move")
	var best_easy: V2Move = body.suggest_shift("t")[1]
	check(score(n) >= score(best_easy) - 0.12, "on easy ground neutral hips are nearly as good as the best")

	# Matching and reposition.
	d = on_wall([["a", 2.8, 3.0, "crimp", 0.3], ["b", 3.2, 2.7, "edge", 0.6], ["t", 3.25, 3.3, "edge", 0.6], ["f1", 2.8, 1.6, "edge", 0.6, "f"], ["f2", 3.2, 1.9, "edge", 0.6, "f"]],
		["a", "b"], ["f1", "f2"], &"rh")
	body = d.session.sys.body
	check(not body.preview("a").valid and body.preview("a").reason.contains("match"), "a crimp is too small to match")
	var rep := body.preview("b", Vector2(0, -0.3))
	check(rep.valid and rep.has_tag("reposition") and (rep.to.limb(&"rh") as V2Limb).id == "b", "aiming at your own hold with a hip shift repositions the body")
	d.commit(rep)
	check(d.session.pose.next_hand == &"rh", "a reposition keeps the same hand next")
	check(not body.preview("b").valid, "a reposition with neutral hips does nothing (not a free move)")


func test_rests_and_hands() -> void:
	var d := on_wall([["a", 2.8, 3.0, "jug", 0.95], ["b", 3.2, 2.7, "crimp", 0.3], ["k", 3.0, 1.9, "edge", 0.7, "f", Vector2(0, -1), ["kneebar"]],
		["f1", 2.8, 1.6, "edge", 0.6, "f"]], ["a", "b"], ["f1", ""], &"rh")
	var body: ClimbBody = d.session.sys.body
	check(body.rest_kind() == &"jug", "a jug with a foot on is a rest")
	check(body.free_hand() == &"rh", "clip with the hand on the crimp, hang off the jug")
	d.session.pose.set_limb(&"rf", V2Limb.make(&"hold", Vector2(3.0, 1.9), "k"))
	check(body.rest_kind() == &"kneebar", "a kneebar is a rest")
	d = on_wall([["a", 2.8, 3.0, "crimp", 0.3], ["b", 3.2, 2.7, "crimp", 0.3], ["f1", 2.8, 1.6, "edge", 0.6, "f"]], ["a", "b"], ["f1", ""], &"rh")
	body = d.session.sys.body
	check(body.rest_kind() == &"", "two crimps are no rest")
	# Auto-swap: the right hand has nowhere to go, the left does.
	d = on_wall([["a", 2.0, 3.0, "crimp", 0.3], ["b", 2.9, 3.4, "edge", 0.6], ["t", 1.7, 3.9, "edge", 0.5],
		["f1", 2.6, 1.8, "edge", 0.6, "f"], ["f2", 3.0, 1.8, "edge", 0.6, "f"]], ["a", "b"], ["f1", "f2"], &"rh")
	var phase := d.current as BodyAimPhase
	d.session.pose.next_hand = &"rh"
	phase.enter(d)
	check(d.session.pose.next_hand == &"lh" and phase.auto_swapped, "the body swaps hands itself when the next hand has nowhere to go")


func test_hang() -> void:
	var d := started()
	var s := d.session
	var body: ClimbBody = s.sys.body
	var bot := ClimbV2BodyBot.new(d)
	for i in 6:
		bot.step()
	d.take_fall()
	check(s.pose.tags.has("hang") and body.rest_kind() == &"hang", "after a fall you hang on the rope, and can rest there")
	d.handle_verb(&"commit", true)
	check(s.phase == &"climb", "back to climbing")
	var m := (d.current as BodyAimPhase).move
	check(m != null and m.valid, "from the rope a hand can grab a hold")
	d.handle_verb(&"commit", true)
	check(not s.pose.tags.has("hang"), "and you're back on the rock")
	check(bot.run(900), "and climb on to the top")


func test_screen() -> void:
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(Fixture.fixture_route(1), 7, V2Modifiers.new(), Fixture.fixture_rack())
	add_child(screen)
	await get_tree().process_frame
	var overlay := screen.overlays.get_node_or_null("body")
	check(overlay is BodyOverlay, "the body's overlay is on the screen")
	var s := screen.session
	_press(screen, &"use_tool")
	await get_tree().process_frame
	check(s.phase == &"climb" and screen._hint.text.contains("hand next"), "the hint says which hand goes")
	var y := s.pose.high_point()
	_press(screen, &"use_tool")
	check(s.pose.high_point() > y, "Space on the screen takes the aimed move")
	_hold(screen, &"run", true)
	_press(screen, &"move_down")
	_hold(screen, &"run", false)
	check((screen.director.current as BodyAimPhase).hip_shift == Vector2(0, -0.15), "Shift + Down on the screen sits the hips")
	await get_tree().process_frame
	screen.queue_free()


func _press(screen: ClimbScreenV2, action: StringName) -> void:
	_hold(screen, action, true)
	_hold(screen, action, false)


func _hold(screen: ClimbScreenV2, action: StringName, down: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = down
	screen._unhandled_input(e)


func test_review_fixes() -> void:
	# The body turns back square after a drop-knee.
	var d := on_wall([["a", 2.6, 3.0, "jug", 0.9], ["b", 2.8, 2.5, "edge", 0.6], ["t", 3.85, 3.25, "edge", 0.6], ["u", 3.3, 3.9, "edge", 0.6],
		["f1", 2.6, 1.4, "edge", 0.6, "f"], ["f2", 3.35, 1.95, "edge", 0.6, "f"]], ["a", "b"], ["f1", "f2"], &"rh")
	var body: ClimbBody = d.session.sys.body
	var turned := body.preview("t", Vector2(0.3, 0))
	d.commit(turned)
	check(d.session.pose.facing != 0, "a drop-knee turns the body side-on")
	var next := body.preview("u")
	check(next.to.facing == 0, "and the next move squares it up again")
	# A crack reads the same wherever it is on the wall.
	for x: float in [1.0, 3.0, 4.6]:
		var c := V2Crack.new()
		c.id = "c"
		c.points = PackedVector2Array([Vector2(x, 1.0), Vector2(x, 5.0)])
		c.widths = PackedFloat32Array([4.2, 4.2])
		d = on_wall([["a", x - 0.3, 3.0, "jug", 0.9], ["b", x, 2.6, "jam", 0.6, "h", Vector2(0, -1), [], "c"],
			["t", x, 3.4, "jam", 0.6, "h", Vector2(0, -1), [], "c"], ["f1", x - 0.2, 1.6, "edge", 0.6, "f"], ["f2", x + 0.1, 1.9, "edge", 0.6, "f"]],
			["a", "b"], ["f1", "f2"], &"rh", 0.0, [c])
		body = d.session.sys.body
		var cell := ClimbBody.clamp_shift(Vector2(x - body.base_hip().x, 0))
		var m := body.preview("t", cell)
		var off := body.preview("t", cell + Vector2(-0.15, 0))
		check(m.has_tag("hand_jam") and not off.has_tag("hand_jam"), "a crack at x=%.1f: square is a jam, one step off is not" % x)
	# Swapping keeps the turn: a refresh (a rest, food) doesn't lose the aim.
	d = started()
	var phase := d.current as BodyAimPhase
	d.handle_verb(&"swap", true)
	var aim := phase.aimed
	var hand := d.session.pose.next_hand
	phase.refresh()
	check(phase.aimed == aim and d.session.pose.next_hand == hand, "a rest after a swap keeps the hand and the aim")
	# Inside a crux the body gives no hip hints.
	d = on_wall([["a", 2.8, 3.0, "jug", 0.9], ["b", 3.2, 2.6, "edge", 0.6], ["t", 3.1, 4.0, "jug", 0.9],
		["f1", 2.8, 1.6, "edge", 0.6, "f"], ["f2", 3.2, 1.9, "edge", 0.6, "f"]], ["a", "b"], ["f1", "f2"], &"rh")
	var z := V2Zone.new()
	z.id = "crux"
	z.kind = &"crux"
	z.rect = Rect2(2, 2, 2, 3)
	d.session.wall.zones.append(z)
	body = d.session.sys.body
	phase = d.current as BodyAimPhase
	phase.aim_at("t")
	check(body.preview("t").reason == "too far" and phase.fix == "", "inside a crux a move just says too far, no hip hint")
	# A dyno lands with the hips up at the hold, not left in the crouch.
	z.rect = Rect2()
	var dyno := body.preview("t", Vector2(0, -0.45))
	check(dyno.has_tag("dyno") and dyno.to.hip.y > body.base_hip().y, "a dyno arrives with the hips higher than standing")
