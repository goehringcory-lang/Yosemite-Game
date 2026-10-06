extends Node
## Headless test of the climbing minigame: every route's pitches are authored,
## every route can be topped out by a careful climber with the gear the story
## has handed over by then, and each piece of gear does its job.
## Run: godot --headless --path . res://tests/climb_test.tscn
## Exit code is the number of failed checks. CLIMB_STATS=1 prints the table
## of success rates and times for tuning.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func route(id: String) -> RouteData:
	return load("res://data/routes/%s.tres" % id)


## The gear and food a player has when a route comes up in the story.
func kit_for(r: RouteData) -> Dictionary:
	var kit := {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 5, "rope": 1}
	for id: String in r.required_gear:
		kit[id] = maxi(int(kit.get(id, 0)), int(r.required_gear[id]))
	return kit


func food_for(r: RouteData) -> void:
	Inventory.items.clear()
	var energy := int(ClimbProfiles.get_profile(r.id).get("food", 0))
	if energy <= 0:
		return
	if r.nights > 0:
		Inventory.add("acorn_cake", ceili(energy / 45.0))
	else:
		Inventory.add("trail_mix", ceili(energy / 30.0))


func _ready() -> void:
	await get_tree().process_frame
	test_profiles_cover_routes()
	test_pitch_generation()
	test_every_route_is_climbable()
	test_gear_verbs()
	test_crux()
	test_weather_and_snow()
	test_nights()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


func test_profiles_cover_routes() -> void:
	for r in Guidebook.routes():
		var profile := ClimbProfiles.get_profile(r.id)
		check(not profile.is_empty(), "%s has a climbing profile" % r.id)
		check(profile.get("pitches", []).size() == r.pitches.size(), "%s: one authored pitch per pitch (%d)" % [r.id, r.pitches.size()])
		check(not profile.get("view", []).is_empty() and not profile.get("facts", []).is_empty(), "%s has a view and facts" % r.id)
		check(ClimbProfiles.BELAYERS.has(profile.get("belayer", "")), "%s has a belayer" % r.id)


func test_pitch_generation() -> void:
	for r in Guidebook.routes():
		var bad := 0
		for seed in 12:
			var state := ClimbState.new(r, 4, seed, kit_for(r))
			for p in r.pitches.size():
				state.pitch = p
				state._start_pitch()
				# Every row must offer a hold within reach of some hold below.
				for row in range(1, state.top_row):
					if state.holds[row].is_empty():
						bad += 1
				var reach := {state.col: true}
				for row in range(1, state.top_row + 1):
					var next := {}
					for c: int in reach:
						for dx in [-1, 0, 1]:
							if state.holds[row].has(c + dx):
								next[c + dx] = true
					if next.is_empty():
						bad += 1
					reach = next
		check(bad == 0, "%s: every pitch has a line from the belay to the top" % r.id)


## CLIMB_STATS=1 sweeps how much food you carry (trail mix, 30 energy each) and
## prints the least that gets a careful climber up 90 % of the time.
func print_food_sweep() -> void:
	for r in Guidebook.routes():
		var line := "SWEEP %-24s" % r.id
		var first := -1
		for mixes in [0, 1, 2, 3, 4, 5, 6, 8, 10, 12]:
			var tops := 0
			var runs := 60
			for seed in runs:
				Inventory.items.clear()
				if mixes > 0:
					Inventory.add("trail_mix", mixes)
				var state := ClimbState.new(r, int(kit_for(r).get("cam", 0)), seed, kit_for(r))
				ClimbBot.new().play(state)
				tops += 1 if state.status == ClimbState.Status.TOPPED_OUT else 0
			line += "  %d:%3d%%" % [mixes, tops * 100 / runs]
			if first < 0 and tops * 100 / runs >= 90:
				first = mixes
		print(line + "   -> %d mix (%d energy)" % [first, first * 30])
	Inventory.items.clear()


func test_every_route_is_climbable() -> void:
	var stats := OS.get_environment("CLIMB_STATS") != ""
	if stats:
		print_food_sweep()
	for r in Guidebook.routes():
		var tops := 0
		var falls := 0
		var minutes := 0
		var aided := 0
		var runs := 40
		for seed in runs:
			food_for(r)
			var state := ClimbState.new(r, int(kit_for(r).get("cam", 0)), seed, kit_for(r))
			ClimbBot.new().play(state)
			if state.status == ClimbState.Status.TOPPED_OUT:
				tops += 1
				falls += state.falls
				minutes += state.minutes
				aided += 1 if state.aid_moves > 0 else 0
		Inventory.items.clear()
		var rate := tops / float(runs)
		if stats:
			print("STATS %-24s %-12s tops %2d/%d  falls/top %.1f  hours %.1f  aided %d" % [r.id, r.grade.substr(0, 12), tops, runs, falls / float(maxi(tops, 1)), minutes / 60.0 / maxi(tops, 1), aided])
		check(rate >= 0.85, "a careful climber with the recommended food tops out %s (%d of %d)" % [r.id, tops, runs])


func test_gear_verbs() -> void:
	var nose := route("the_nose")
	var kit := kit_for(nose)
	var state := ClimbState.new(nose, 10, 3, kit)
	# Fixed lines on the first pitch: ascenders jug them, and you can't fall.
	var jugged := false
	for dx in [-1, 0, 1]:
		if state.can_jug(dx):
			jugged = state.jug(dx)
			break
	check(jugged and state.jug_moves == 1 and state.minutes >= ClimbState.MINUTES_PER_JUG, "ascenders jug a fixed rope")
	var bare := ClimbState.new(nose, 10, 3, {"quickdraw": 5})
	var any_jug := false
	for dx in [-1, 0, 1]:
		any_jug = any_jug or bare.can_jug(dx)
	check(not any_jug, "without ascenders there's no jugging")
	# Aid: only on hard moves of a wall pitch, with a cam to stand on.
	var roof := ClimbState.new(nose, 10, 5, kit)
	roof.pitch = 6
	roof._start_pitch()
	check(roof.spec.style == "roof" and roof.spec.get("hard_aid", false), "the Great Roof allows aid")
	var aid_dx := 99
	for r in range(1, roof.top_row):
		roof.stamina = 100
		for dx in [-1, 0, 1]:
			if roof.can_aid(dx):
				aid_dx = dx
				break
		if aid_dx != 99:
			break
		var dir := 0
		for d in [0, -1, 1]:
			if not roof.hold_at(roof.row + 1, roof.col + d).is_empty():
				dir = d
				break
		roof.move(dir)
	if aid_dx != 99:
		var cams := roof.cams_left
		check(roof.aid_step(aid_dx) and roof.aid_moves == 1 and roof.cams_left == cams - 1, "aiders pull through a hard move for a cam")
		check(roof.style_rating() == "Aided" and not roof.is_free(), "an aided climb isn't free")
	else:
		check(false, "found a hard move to aid on the Great Roof")
	# A belay device softens catches.
	var apron := route("glacier_point_apron")
	var soft := ClimbState.new(apron, 2, 7, {"belay_device": 1})
	var hard := ClimbState.new(apron, 2, 7, {})
	for s in [soft, hard]:
		s.stamina = 1
		for d in [0, -1, 1]:
			if s.move(d):
				break
	check(soft.stamina == hard.stamina + ClimbState.DEVICE_CATCH, "a belay device makes a softer catch (%d vs %d)" % [soft.stamina, hard.stamina])
	# Old pitons take quickdraws on a cam route.
	var spire := ClimbState.new(route("higher_cathedral_spire"), 6, 2, kit_for(route("higher_cathedral_spire")))
	check(not spire.bolts.is_empty() and spire.bolt_kinds.values().has("pin"), "the Spire has the 1934 pitons to clip")
	var clipped := false
	for i in 12:
		if spire.can_clip():
			clipped = spire.clip_bolt()
			break
		spire.stamina = 100
		spire.move(_up(spire))
	check(clipped and spire.protection.back().hw == "pin" and spire.quickdraws_left == int(kit_for(route("higher_cathedral_spire")).quickdraw) - 1, "a quickdraw clips an old piton")
	# Chimneys reward alternating sides.
	var steck := ClimbState.new(route("steck_salathe"), 6, 4, kit_for(route("steck_salathe")))
	steck.pitch = 1
	steck._start_pitch()
	check(steck.style() == "chimney" and steck.allowed_cols() == [1, 2, 3], "Chockstone Chimney is narrow")
	steck.col = 2
	steck.last_dx = 1
	var left := steck.move_cost(1, 1)
	var right := steck.move_cost(1, 3)
	var base_l := int(steck.hold_at(1, 1).cost)
	var base_r := int(steck.hold_at(1, 3).cost)
	check(left <= maxi(base_l - 1 - 1, 1) + 0 and right >= base_r - 1, "alternating sides in a chimney is cheaper than repeating (%d vs %d)" % [left, right])


func _up(s: ClimbState) -> int:
	for d in [0, -1, 1]:
		if not s.hold_at(s.row + 1, s.col + d).is_empty():
			return d
	return 0


func test_crux() -> void:
	var r := route("firefall_slab")
	var state := ClimbState.new(r, 0, 5, kit_for(r))
	state.pitch = 1
	state._start_pitch()
	check(state.crux_row() == 8, "Firefall Slab's bulge is the crux of pitch two")
	state.interactive = true
	var guard := 0
	while state.pending.is_empty() and state.status == ClimbState.Status.CLIMBING and guard < 20:
		guard += 1
		state.stamina = 100
		if state.can_clip():
			state.clip_bolt()
		state.move(_up(state))
	check(not state.pending.is_empty() and state.pending.kind == "timing", "stepping onto the crux asks for a skill check")
	check(not state.move(0) and not state.chalk_up() and not state.protect(), "nothing else works until the crux resolves")
	var before := state.stamina
	state.resolve_crux("perfect")
	check(state.stamina > before and state.perfect_cruxes == 1, "a perfect crux gives stamina back")
	var slip := ClimbState.new(r, 0, 5, kit_for(r))
	slip.pitch = 1
	slip._start_pitch()
	slip.interactive = true
	guard = 0
	while slip.pending.is_empty() and guard < 20:
		guard += 1
		slip.stamina = 100
		if slip.can_clip():
			slip.clip_bolt()
		slip.move(_up(slip))
	var s0 := slip.stamina
	slip.resolve_crux("slip")
	check(slip.slipped_cruxes == 1 and (slip.stamina < s0 or slip.falls == 1), "a slip costs stamina")
	var easy := ClimbState.new(route("swan_slab"), 0, 1, {})
	var tough := ClimbState.new(route("the_nose"), 10, 1, kit_for(route("the_nose")))
	check(easy.crux_window() > tough.crux_window(), "a top rope is the most forgiving crux (%.2f vs %.2f)" % [easy.crux_window(), tough.crux_window()])
	var shod := ClimbState.new(r, 0, 1, {"climbing_shoes": 1})
	var barefoot := ClimbState.new(r, 0, 1, {})
	check(shod.crux_window() > barefoot.crux_window(), "climbing shoes widen the crux window")


func test_weather_and_snow() -> void:
	var lyell := route("lyell_glacier")
	var morning := ClimbState.new(lyell, 0, 2, kit_for(lyell))
	morning.start_minutes = 6 * 60
	var afternoon := ClimbState.new(lyell, 0, 2, kit_for(lyell))
	afternoon.start_minutes = 15 * 60
	check(afternoon.move_cost(1, afternoon.holds[1].keys()[0]) > morning.move_cost(1, morning.holds[1].keys()[0]), "afternoon slush and storms cost more than a dawn start")
	check(afternoon.is_stormy() and not morning.is_stormy(), "thunderstorms build over the high country after two")
	var valley := ClimbState.new(route("nutcracker"), 4, 1, kit_for(route("nutcracker")))
	valley.start_minutes = 15 * 60
	check(not valley.is_stormy(), "the valley doesn't storm")
	morning.stamina = 1
	morning.move(_up(morning))
	check(morning.status == ClimbState.Status.CLIMBING and morning.falls == 1 and "self-arrest" in morning.message, "an ice axe stops a slide on the glacier")


func test_nights() -> void:
	var nose := route("the_nose")
	var kit := kit_for(nose)
	Inventory.items.clear()
	Inventory.add("acorn_cake", 4)
	var state := ClimbState.new(nose, 10, 1, kit)
	state.pitch = 2
	state.row = state.top_row - 1
	state.stamina = 60
	state.move(_up(state))
	check(state.nights_spent == 1 and state.stamina == ClimbState.MAX_STAMINA, "El Cap Tower: a night on the ledge")
	var night_event := false
	for e in state.take_events():
		night_event = night_event or (e.type == "bivy" and e.place == "ledge")
	check(night_event, "the night is reported to the screen")
	Inventory.items.clear()
	state = ClimbState.new(nose, 10, 1, kit)
	state.pitch = 2
	state.row = state.top_row - 1
	state.move(_up(state))
	check(state.status == ClimbState.Status.RETREATED, "no meal, no night on the wall")
	Inventory.items.clear()
