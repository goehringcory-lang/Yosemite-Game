extends Node
## Headless test of climbing v2's pump, gas and food (thread 4,
## scripts/climb/v2/effort/). Every other system is pinned to its stub, so
## other threads' merges can't move these numbers.
##   - pricing: grip, hold size, feet on, wrong-way pulls, body positions,
##     move tags, the per-move cap, easy ground, pure previews;
##   - the hang tax on clips and gear, overhead rope pulls;
##   - deep pump, bands, will_fail, hold_factor;
##   - rests: diminishing returns, jugs stall, kneebars and stances beat jugs,
##     the belay resets, low gas and bonking;
##   - food: nibble / trail / meal and where each can be eaten, digestion,
##     meals improve shake-outs, best_food;
##   - water and sun, the gas cap through the day;
##   - body signs, the ghost's signs, the overlay on the screen;
##   - calibration (an easy pitch vs a hard one) and the fixture climbed end
##     to end through the real effort system, the same way twice.
## Run: godot --headless --path . res://tests/climb_v2_effort_test.tscn
## Exit code is the number of failed checks.

const Base := preload("res://tests/climb_v2_test.gd")
const T = preload("res://scripts/climb/v2/effort/effort_tuning.gd")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	ClimbSystems.pin_stubs_except([&"effort"])
	var saved: Dictionary = Inventory.items.duplicate()
	test_registry()
	test_pricing()
	test_actions()
	test_deep_and_bands()
	test_rests()
	test_gas()
	test_food()
	test_day_and_water()
	test_signs()
	test_calibration()
	test_climb()
	await test_screen()
	Inventory.items = saved
	ClimbSystems.pins.clear()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


func new_director(seed := 7, pitches := 2, mods: V2Modifiers = null) -> ClimbDirector:
	var d := ClimbDirector.new()
	d.setup(Base.fixture_route(pitches), seed, mods if mods else V2Modifiers.new(), Base.fixture_rack())
	d.start()
	d.handle_verb(&"commit", true) # read -> climb
	return d


## A hold dropped onto the session's wall for a test.
func add_hold(s: ClimbSession, id: String, kind: StringName, size: float, pos: Vector2, pull := Vector2(0, -1)) -> V2Hold:
	var h := V2Hold.new()
	h.id = id
	h.kind = kind
	h.size = size
	h.pos = pos
	h.pull = pull
	s.wall.holds.append(h)
	s.wall._index()
	return h


## A move of the right hand onto [param h], the hips under it.
func move_to(s: ClimbSession, h: V2Hold, strain := 0.3, hands := 0.5, tags: Array = [], pose_tags: Array = []) -> V2Move:
	var m := V2Move.new()
	m.hand = &"rh"
	m.hold_id = h.id
	m.from = s.pose.copy()
	m.to = s.pose.copy()
	m.to.hip = h.pos - Vector2(0, 1.0)
	m.to.set_limb(&"rh", V2Limb.make(&"hold", h.pos, h.id))
	m.to.set_limb(&"lh", V2Limb.make(&"hold", h.pos + Vector2(-0.5, 0), h.id))
	m.to.tags = PackedStringArray(pose_tags)
	m.strain = strain
	m.load = {&"lh": hands / 2.0, &"rh": hands / 2.0, &"lf": (1.0 - hands) / 2.0, &"rf": (1.0 - hands) / 2.0}
	m.tags = PackedStringArray(tags)
	s.sys.effort.price(m)
	return m


## Puts both hands on [param h] (for hang-tax and rest checks).
func hang_on(s: ClimbSession, h: V2Hold) -> void:
	s.pose.tags = PackedStringArray()
	s.pose.set_limb(&"lh", V2Limb.make(&"hold", h.pos, h.id))
	s.pose.set_limb(&"rh", V2Limb.make(&"hold", h.pos, h.id))


func test_registry() -> void:
	check(ClimbSystems.is_real(&"effort") and not ClimbSystems.is_real(&"body"), "the real effort system plugs in by path; the rest stay stubs")
	var d := new_director()
	check(d.session.sys.effort is EffortV2, "the session's effort is EffortV2")
	check(d.session.sys.effort.make_overlay() is EffortOverlay, "it supplies the body-signs overlay")


func test_pricing() -> void:
	var d := new_director()
	var s := d.session
	var y := s.pose.hip.y + 1.5
	var jug := add_hold(s, "t_jug", &"jug", 0.95, Vector2(3, y))
	var edge := add_hold(s, "t_edge", &"edge", 0.6, Vector2(3, y))
	var crimp := add_hold(s, "t_crimp", &"crimp", 0.3, Vector2(3, y))
	var snap := s.snapshot()
	var mj := move_to(s, jug)
	var me := move_to(s, edge)
	var mc := move_to(s, crimp)
	check(mj.cost.pump < me.cost.pump and me.cost.pump < mc.cost.pump, "a crimp pumps more than an edge, an edge more than a jug (%.3f %.3f %.3f)" % [mj.cost.pump, me.cost.pump, mc.cost.pump])
	check(abs(me.cost.pump - 0.031) < 0.008, "an ordinary edge move costs about 0.03 pump (%.3f)" % me.cost.pump)
	var feet := move_to(s, crimp, 0.3, 0.35)
	var cut := move_to(s, crimp, 0.3, 0.8)
	check(feet.cost.pump < mc.cost.pump and mc.cost.pump < cut.cost.pump, "weight on the feet is cheaper; feet cut costs more (%.3f %.3f %.3f)" % [feet.cost.pump, mc.cost.pump, cut.cost.pump])
	var strained := move_to(s, edge, 0.9)
	check(strained.cost.pump > me.cost.pump and strained.cost.gas > me.cost.gas, "a stretched move costs more pump and gas")
	var side := add_hold(s, "t_side", &"sidepull", 0.6, Vector2(3, y), Vector2(1, 0))
	var good := move_to(s, side)
	good.to.hip = side.pos + Vector2(1.0, -0.2)
	s.sys.effort.price(good)
	var bad := move_to(s, side)
	bad.to.hip = side.pos + Vector2(-1.0, -0.2)
	s.sys.effort.price(bad)
	check(bad.cost.pump > good.cost.pump * 1.3, "leaning the wrong way off a sidepull costs more (%.3f vs %.3f)" % [bad.cost.pump, good.cost.pump])
	var flag := move_to(s, crimp, 0.3, 0.5, [], ["flag"])
	var knee := move_to(s, crimp, 0.3, 0.5, [], ["dropknee", "stem", "flag"])
	check(flag.cost.pump < mc.cost.pump and knee.cost.pump >= mc.cost.pump * T.POSE_FLOOR - 0.0001, "body positions save pump, down to a floor")
	var off_beta := move_to(s, edge)
	if off_beta.get("crux_cost") != null:
		off_beta.set("crux_cost", 2.0)
		s.sys.effort.price(off_beta)
		check(off_beta.cost.pump > me.cost.pump * 1.9, "off the crux's beta a move costs crux_cost times more")
	var dyno := move_to(s, edge, 0.3, 0.5, ["dyno"])
	check(dyno.cost.pump > me.cost.pump and dyno.cost.gas > me.cost.gas, "a dyno costs more")
	var worst := move_to(s, add_hold(s, "t_worst", &"sloper", 0.0, Vector2(3, y)), 1.0, 1.0, ["dyno"])
	check(worst.cost.pump <= T.MOVE_CAP + 0.0001, "no move costs more than the cap (%.3f)" % worst.cost.pump)
	var easy := move_to(s, jug, 0.1, 0.2)
	check(easy.cost.pump < 0.0, "easy ground with the weight on the feet gives a little back")
	check(s.snapshot() == snap, "pricing is pure (the session didn't change)")
	var wet := V2Modifiers.new()
	wet.wet = 1.0
	wet.has_chalk = false
	var d2 := new_director(7, 2, wet)
	var c2 := add_hold(d2.session, "t_crimp", &"crimp", 0.3, Vector2(3, y))
	check(move_to(d2.session, c2).cost.pump > mc.cost.pump * 1.4, "wet rock and no chalk make small holds much worse")
	var relaxed := V2Modifiers.new()
	relaxed.assists.append("relaxed")
	var d3 := new_director(7, 2, relaxed)
	var c3 := add_hold(d3.session, "t_crimp", &"crimp", 0.3, Vector2(3, y))
	check(move_to(d3.session, c3).cost.pump < mc.cost.pump, "the relaxed assist lowers pump")


func test_actions() -> void:
	var d := new_director()
	var s := d.session
	var e: EffortV2 = s.sys.effort
	var jug := add_hold(s, "t_jug", &"jug", 0.95, Vector2(3, 3))
	var crimp := add_hold(s, "t_crimp", &"crimp", 0.3, Vector2(3, 3))
	hang_on(s, jug)
	var on_jug := e.price_action(&"clip")
	var pull_jug := e.price_action(&"rope_pull", {"arms": 1})
	hang_on(s, crimp)
	var on_crimp := e.price_action(&"clip")
	check(on_crimp.pump > on_jug.pump * 2.0, "clipping off a crimp costs far more than off a jug (%.3f vs %.3f)" % [on_crimp.pump, on_jug.pump])
	check(e.price_action(&"offer").pump > on_crimp.pump, "fiddling a cam off a crimp costs more again")
	check(e.price_action(&"offer", {"hand_hold": "t_jug"}).pump < e.price_action(&"offer").pump, "an offer priced from the hand on the jug is cheaper than from the crimp (gear passes hand_hold)")
	hang_on(s, jug)
	check(e.price_action(&"rope_pull", {"arms": 3}).pump > pull_jug.pump, "an overhead pull (3 arm-lengths) is harder")
	check(e.price_action(&"fall", {"drop_m": 8.0}).gas > e.price_action(&"fall", {"drop_m": 1.0}).gas, "a longer fall costs more gas")
	check(e.price_action(&"chalk").pump < 0.0, "a chalk dip eases the pump")
	s.pose.tags.append("hang")
	check(e.price_action(&"clip").pump < on_jug.pump, "no hang tax when hanging on the rope")


func test_deep_and_bands() -> void:
	var d := new_director()
	var s := d.session
	var e: EffortV2 = s.sys.effort
	e.apply(V2Cost.make(0.55))
	check(e.deep() == 0.0 and e.band() == &"working", "pump under the red line leaves no deep pump")
	e.apply(V2Cost.make(0.3))
	check(e.deep() > 0.05 and e.deep() < 0.15, "pump gained over the red line partly sticks (deep %.3f)" % e.deep())
	check(e.band() == &"pumped", "0.85 is pumped")
	check(e.hold_factor() < 1.0 and e.hold_factor(0.5) == 1.0, "small holds get unreliable only when pumped")
	var crimp := add_hold(s, "t_crimp", &"crimp", 0.3, s.pose.hip + Vector2(0, 1.5))
	var jug := add_hold(s, "t_jug", &"jug", 0.95, s.pose.hip + Vector2(0, 1.5))
	var m := move_to(s, crimp, 0.3)
	check(e.will_fail(m), "boxed after a crimp move: the ghost says it will fail")
	check(not e.will_fail(move_to(s, jug, 0.2)), "a relaxed move to a jug still goes")
	check(not e.pumped_out(), "not pumped out yet")
	e.apply(V2Cost.make(0.5))
	check(e.pumped_out() and s.effort.pump == 1.0, "pump stops at 1: pumped out")
	var dd := e.deep()
	for i in 10:
		e.rest(&"jug")
	check(s.effort.pump >= dd - 0.0001, "shaking out on a jug can't clear deep pump (%.3f >= %.3f)" % [s.effort.pump, dd])
	for i in 3:
		e.rest(&"stance")
	check(e.deep() < dd, "a no-hands stance works deep pump off")


func test_rests() -> void:
	var d := new_director()
	var s := d.session
	var e: EffortV2 = s.sys.effort
	s.effort.pump = 0.7
	var gains: Array[float] = []
	for i in 4:
		var before := s.effort.pump
		var c := e.rest(&"jug")
		gains.append(before - s.effort.pump)
		if i == 0:
			check(c.minutes == T.REST_MINUTES and c.gas > 0.0, "a shake-out takes a minute and a little gas")
	check(gains[0] > gains[1] and gains[1] > gains[2], "each shake-out wins back less (%s)" % [gains])
	for i in 20:
		e.rest(&"jug")
	check(e.rest_gain(&"jug") == 0.0 and s.effort.pump >= 0.25, "a jug stalls out above its floor (%.3f)" % s.effort.pump)
	s.effort.pump = 0.7
	check(e.rest_gain(&"kneebar") > e.rest_gain(&"stem") and e.rest_gain(&"stem") > e.rest_gain(&"jug"), "a kneebar beats a stem, a stem beats a jug")
	check(e.rest_gain(&"stance") > e.rest_gain(&"kneebar"), "a no-hands stance is best on the wall")
	var n := s.bus.count(&"rested")
	var c := e.rest(&"belay")
	check(s.effort.pump <= e.deep() + 0.0001 and c.minutes == T.BELAY_MINUTES and s.bus.count(&"rested") == n + 1, "the belay clears the pump")
	check(d.rest(&"") == false or s.sys.body.rest_kind() != &"", "no rest without a rest spot")


func test_gas() -> void:
	var d := new_director()
	var s := d.session
	var e: EffortV2 = s.sys.effort
	s.effort.pump = 0.7
	var full := e.rest_gain(&"stance")
	s.effort.gas = 0.2
	check(e.rest_gain(&"stance") < full * 0.7, "low on gas, shake-outs win back less")
	var crimp := add_hold(s, "t_crimp", &"crimp", 0.3, s.pose.hip + Vector2(0, 1.5))
	s.effort.gas = 1.0
	var p_full := move_to(s, crimp).cost.pump
	s.effort.gas = 0.1
	check(is_equal_approx(move_to(s, crimp).cost.pump, p_full), "low gas never makes moves dearer")
	s.effort.gas = 0.0
	s.effort.pump = 0.8
	for i in 10:
		e.rest(&"stance")
	check(s.effort.pump >= T.BONK_FLOOR - 0.0001 and e.signs().bonked == 1.0, "bonked: the arms can't recover past half")
	check(e.price_action(&"clip").gas > 0.0, "minutes on the wall burn gas")


func test_food() -> void:
	var d := new_director()
	var s := d.session
	var e: EffortV2 = s.sys.effort
	Inventory.items = {"wild_strawberry": 2, "trail_mix": 1, "autumn_hand_pie": 1}
	check(e.food_class("wild_strawberry") == &"nibble" and e.food_class("trail_mix") == &"trail" and e.food_class("autumn_hand_pie") == &"meal", "food classes come from energy alone")
	var crimp := add_hold(s, "t_crimp", &"crimp", 0.3, Vector2(3, 3))
	var jug := add_hold(s, "t_jug", &"jug", 0.95, Vector2(3, 3))
	hang_on(s, crimp)
	check(not e.can_eat_here("wild_strawberry") and not e.eat("wild_strawberry"), "no letting go of a crimp to eat")
	hang_on(s, jug)
	check(e.can_eat_here("wild_strawberry") and not e.can_eat_here("trail_mix"), "berries off a jug; trail mix needs a real rest")
	s.effort.gas = 0.5
	s.effort.pump = 0.6
	check(e.eat("wild_strawberry") and Inventory.count("wild_strawberry") == 1, "a berry is eaten from the pack")
	check(absf(s.effort.gas - 0.6) < 0.001 and s.effort.pump < 0.6, "a nibble lands at once and steadies the arms")
	s.pose.tags = PackedStringArray(["hang"])
	check(e.can_eat_here("trail_mix") and e.can_eat_here("autumn_hand_pie"), "hanging on the rope, both hands are free")
	var g := s.effort.gas
	check(e.eat("trail_mix") and absf(s.effort.gas - (g + 0.15)) < 0.001, "trail food: half now")
	e.apply(V2Cost.make(0.0, 0.0, T.TRAIL_MINUTES))
	check(absf(s.effort.gas - (g + 0.30)) < 0.001, "and half over ten minutes (%.3f)" % s.effort.gas)
	s.effort.pump = 0.7
	var before := e.rest_gain(&"stance")
	s.effort.gas = 0.6
	check(e.eat("autumn_hand_pie") and s.effort.gas == 0.6, "a meal arrives slowly, not at once")
	check(e.rest_gain(&"stance") > before, "after a meal every shake-out is better")
	e.apply(V2Cost.make(0.0, 0.0, T.MEAL_MINUTES))
	check(s.effort.gas == s.effort.gas_cap, "the meal fills you up over twenty minutes (gas over the cap is wasted)")
	check(s.bus.count(&"food_eaten") == 3 and Inventory.count("autumn_hand_pie") == 0, "food_eaten for each")
	# best_food: the one that fits the gap, nothing when full.
	Inventory.items = {"wild_strawberry": 1, "trail_mix": 1, "beef_jerky": 1}
	s.effort.gas = s.effort.gas_cap
	s.effort.pump = 0.1
	check(e.best_food() == "", "nothing worth eating when full and fresh")
	s.effort.gas = s.effort.gas_cap - 0.29
	check(e.best_food() == "trail_mix", "the biggest food that fits the gap (%s)" % e.best_food())
	s.effort.gas = s.effort.gas_cap - 0.05
	s.effort.pump = 0.6
	check(e.best_food() == "wild_strawberry", "pumped and full: a berry to steady the arms")
	s.pose.tags = PackedStringArray()
	hang_on(s, crimp)
	s.effort.gas = 0.2
	check(e.best_food() == "", "nothing can be eaten off a crimp")
	check(not d.eat(), "the eat verb does nothing there")
	s.phase = &"belay"
	check(e.best_food() == "beef_jerky" and e.can_eat_here("beef_jerky"), "at the belay anything can be eaten")
	s.phase = &"climb"


func test_day_and_water() -> void:
	var sunny := V2Modifiers.new()
	sunny.sun = 1.0
	var d := new_director(7, 3, sunny)
	var s := d.session
	var e: EffortV2 = s.sys.effort
	var crimp := add_hold(s, "t_crimp", &"crimp", 0.3, s.pose.hip + Vector2(0, 1.5))
	var wet_cost := move_to(s, crimp).cost.pump
	e.apply(V2Cost.make(0.0, 0.0, 200))
	check(s.effort.water < 0.3, "the sun drinks your water (%.2f)" % s.effort.water)
	check(move_to(s, crimp).cost.pump > wet_cost * 1.1, "dry arms pump faster")
	check(EffortSigns.make(s.effort, s.note(&"effort"), s.mods, 0.0, false).thirst > 0.0, "thirst shows")
	e.rest(&"belay")
	check(s.effort.water == 1.0, "a drink at the belay")
	var cap := s.effort.gas_cap
	d._top_out()
	d.next_pitch()
	check(s.effort.gas_cap < cap and s.effort.gas_cap >= T.CAP_MIN, "each new pitch lowers the gas cap a little")
	cap = s.effort.gas_cap
	e.apply(V2Cost.make(0.0, 0.0, T.DAY_MINUTES + 130))
	check(s.effort.gas_cap < cap - 0.03, "a long day lowers it more")


func test_signs() -> void:
	var d := new_director()
	var s := d.session
	var e: EffortV2 = s.sys.effort
	check(e.signs().band == "fresh" and e.signs().tremble == 0.0, "fresh: no tremble")
	e.apply(V2Cost.make(0.8))
	var sg := e.signs()
	check(sg.band == "pumped" and sg.tremble > 0.5 and sg.shake_want > 0.5, "pumped: the forearms tremble and want shaking out")
	check(s.note(&"effort").signs == sg, "signs are published in session.notes.effort")
	e.apply(V2Cost.make(0.2))
	check(e.signs().chicken_wing > 0.5 and e.signs().band == "boxed", "boxed: chicken wings")
	Inventory.items = {"trail_mix": 1}
	s.effort.gas = 0.15
	e.apply(V2Cost.new())
	check(e.signs().hunger > 0.3 and e.signs().hip_sag > 0.3 and e.signs().breath > 0.5, "low gas: hips sag, breathing, a glance at the pack")
	s.effort.pump = 0.6
	e.apply(V2Cost.new())
	var h := add_hold(s, "t_crimp", &"crimp", 0.3, s.pose.hip + Vector2(0, 1.5))
	var m := move_to(s, h, 0.9, 0.9)
	var g := e.ghost_signs(m)
	check(g.tremble > e.signs().tremble and g.fail == 0.0, "the ghost shows the pump the move leaves")
	s.effort.pump = 0.88
	check(e.ghost_signs(m).fail == 1.0, "the ghost says when a move won't go")
	check(s.effort.pump == 0.88, "ghost signs are pure")


## Calibration: 25 moves of a 5.9 pitch (edges, feet on, a little stretch)
## vs 25 moves of a 5.11 (crimps and pinches, steep, stretched).
func test_calibration() -> void:
	var d := new_director()
	var s := d.session
	var e: EffortV2 = s.sys.effort
	var edge := add_hold(s, "t_edge", &"edge", 0.6, s.pose.hip + Vector2(0, 1.5))
	var easy_total := 0.0
	for i in 25:
		easy_total += move_to(s, edge, 0.3, 0.4).cost.pump
	var crimp := add_hold(s, "t_crimp", &"crimp", 0.35, s.pose.hip + Vector2(0, 1.5))
	var pinch := add_hold(s, "t_pinch", &"pinch", 0.45, s.pose.hip + Vector2(0, 1.5))
	var hard_total := 0.0
	for i in 25:
		hard_total += move_to(s, [crimp, pinch, edge][i % 3], 0.5, 0.6).cost.pump
	check(easy_total > 0.35 and easy_total < 0.75, "a 5.9 pitch is comfortable: %.2f pump gross" % easy_total)
	check(hard_total > 1.1 and hard_total < 1.8, "a 5.11 pitch needs planned rests: %.2f pump gross" % hard_total)
	check(e.rest_gain(&"jug") == 0.0, "no shake-out when fresh")


func test_climb() -> void:
	var results := []
	for run in 2:
		var d := ClimbDirector.new()
		d.setup(Base.fixture_route(2), 11, V2Modifiers.new(), Base.fixture_rack())
		d.start()
		var bot := ClimbV2TestBot.new(d)
		var peak := 0.0
		var ok := false
		while not d.done and bot.steps < 800:
			bot.step()
			if not d.done:
				peak = maxf(peak, d.session.effort.pump)
		ok = d.done and d.session.result.success
		var s := d.session
		results.append([ok, s.result.moves, s.minutes, snappedf(s.effort.gas, 0.0001), snappedf(s.effort.pump, 0.0001)])
		if run == 0:
			check(ok, "the scripted climber tops out the fixture with the real effort system (%d steps)" % bot.steps)
			check(peak < 1.0 and peak > 0.3, "the pump built up and never boxed out (peak %.2f)" % peak)
			check(s.bus.count(&"rested") >= 1, "it shook out on the way (%d rests)" % s.bus.count(&"rested"))
			check(s.effort.gas < 1.0 and s.effort.gas > 0.5, "two pitches cost some gas (%.2f left)" % s.effort.gas)
			check(s.bus.count(&"effort_changed") > s.result.moves, "effort_changed for every spend")
	check(results[0] == results[1], "the same seed climbs the same way: %s" % [results[0]])


func test_screen() -> void:
	var screen := ClimbScreenV2.new()
	screen.setup(Base.fixture_route(2), 7, V2Modifiers.new(), Base.fixture_rack())
	add_child(screen)
	await get_tree().process_frame
	var overlay := screen.overlays.get_node_or_null("effort")
	check(overlay is EffortOverlay, "the screen mounts the effort overlay in its slot")
	var s := screen.session
	screen.director.handle_verb(&"commit", true)
	s.sys.effort.apply(V2Cost.make(0.85))
	s.bus.send(&"rested", [&"jug"])
	s.bus.send(&"food_eaten", ["wild_strawberry", 0.1])
	for i in 5:
		await get_tree().process_frame
	check(overlay._puffs.size() > 0 and overlay._food_label != "", "a shake-out throws chalk, eating shows the food")
	check(overlay._climber == screen.climber, "it draws on the climber")
	screen.queue_free()
	await get_tree().process_frame
