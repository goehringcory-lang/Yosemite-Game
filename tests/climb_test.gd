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
	test_eating()
	test_nights_by_the_clock()
	test_late_starts()
	test_snow_rules()
	test_fixed_ropes()
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
	var state := _nose_at(kit, 2)
	state.stamina = 60
	state.move(_up(state))
	check(state.nights_spent == 1 and state.stamina == ClimbState.MAX_STAMINA, "El Cap Tower: a night on the ledge")
	var night_event := false
	for e in state.take_events():
		night_event = night_event or (e.type == "bivy" and e.place == "ledge")
	check(night_event, "the night is reported to the screen")
	Inventory.items.clear()
	state = _nose_at(kit, 2)
	state.move(_up(state))
	check(state.status == ClimbState.Status.RETREATED, "no meal, no night on the wall")
	Inventory.items.clear()


## A Nose climb standing one move below the top of pitch [param index] (0-based).
func _nose_at(kit: Dictionary, index: int) -> ClimbState:
	var state := ClimbState.new(route("the_nose"), 10, 1, kit)
	state.pitch = index
	state._start_pitch()
	state.row = state.top_row - 1
	return state


## The food rules: no eating at full stamina, the night meals are kept, small
## food goes first, and the route card counts meals as well as energy.
func test_eating() -> void:
	var nose := route("the_nose")
	var kit := kit_for(nose)
	Inventory.items.clear()
	Inventory.add("acorn_cake", 4)
	var state := ClimbState.new(nose, 10, 1, kit)
	check(not state.eat("acorn_cake") and "not hungry" in state.message and Inventory.count("acorn_cake") == 4, "you can't eat at full stamina")
	check(not state.can_eat(), "no 'E: eat' at full stamina")
	state.stamina = 20
	var eaten := 0
	for i in 6:
		if state.can_eat() and state.eat(state.next_food()):
			eaten += 1
		state.stamina = 20
	check(eaten == 2 and Inventory.count("acorn_cake") == 2 and state.meals_in_pack() == nose.nights, "eating at every belay leaves a meal for each of the two nights (%d eaten)" % eaten)
	check(not state.eat("acorn_cake") and "Save this" in state.message, "the last meals are saved for the nights")
	# Play on from El Cap Tower: the night is still there.
	state = _nose_at(kit, 2)
	state.stamina = 60
	state.move(_up(state))
	check(state.nights_spent == 1 and Inventory.count("acorn_cake") == 1, "a climber who ate at the belays still gets the first night")
	# Small food first, and what's a meal.
	Inventory.items.clear()
	Inventory.add("trail_mix", 1)
	Inventory.add("dried_apples", 2)
	var lunch := ClimbState.new(route("nutcracker"), 4, 1, kit_for(route("nutcracker")))
	lunch.stamina = 40
	check(lunch.next_food() == "dried_apples" and lunch.meals_in_pack() == 1, "dried apples go first, trail mix is a real meal")
	# The route card: energy alone isn't enough for a night on the wall.
	Inventory.items.clear()
	Inventory.add("dried_apples", 20)
	var wall := ClimbState.new(nose, 10, 1, kit)
	var advice := int(ClimbProfiles.get_profile("the_nose").get("food", 0))
	check(FoodDB.carried_energy() >= advice and wall.meals_in_pack() == 0 and not wall.food_ready(advice), "20 dried apples have the energy but no night meals")
	Inventory.items.clear()
	Inventory.add("acorn_cake", ceili(advice / 45.0))
	check(wall.food_ready(advice) and wall.meals_in_pack() >= nose.nights, "acorn cakes for the energy and the nights turn the card green")
	Inventory.items.clear()
	# The smallest real meal goes for the night.
	Inventory.add("acorn_cake", 1)
	Inventory.add("trail_mix", 1)
	state = _nose_at(kit, 2)
	state.move(_up(state))
	check(state.nights_spent == 1 and Inventory.count("trail_mix") == 0 and Inventory.count("acorn_cake") == 1, "the night eats the smallest real meal")
	Inventory.items.clear()


## A night lasts until 6:30 the next morning; the calendar moves on; the nights
## fall where the profile says.
func test_nights_by_the_clock() -> void:
	var nose := route("the_nose")
	var kit := kit_for(nose)
	Inventory.items.clear()
	Inventory.add("acorn_cake", 8)
	for start_hour in [9.0, 14.0, 19.5, 25.0]:
		var state := _nose_at(kit, 2)
		state.start_minutes = int(start_hour * 60)
		state.move(_up(state))
		var wake := state.start_minutes + state.minutes
		check(wake % (24 * 60) == ClimbState.WAKE_MINUTES, "a night starting at %.1f h ends at 6:30 (%d)" % [start_hour, wake % (24 * 60)])
		check(wake / (24 * 60) == state.start_minutes / (24 * 60) + (0 if start_hour >= 24.0 else 1), "...on the next morning")
	# Nights land on the pitches the profile marks: El Cap Tower and the Great Roof.
	var camp := _nose_at(kit, 5)
	camp.move(_up(camp))
	check(camp.nights_spent == 0, "Camp IV is a rest, not a night")
	var roof := _nose_at(kit, 6)
	roof.move(_up(roof))
	var places: Array[String] = []
	for e in roof.take_events():
		if e.type == "bivy":
			places.append(e.place)
	check(roof.nights_spent == 1 and places == ["hanging"], "the Great Roof is the hanging camp")
	# The whole Nose by the bot: two nights, ending on the third morning or afternoon.
	food_for(nose)
	var full := ClimbState.new(nose, 10, 2, kit)
	full.start_minutes = 6 * 60
	ClimbBot.new().play(full)
	places.clear()
	for e in full.take_events():
		if e.type == "bivy":
			places.append(e.place)
	var end := full.start_minutes + full.minutes - full.nights_spent * 24 * 60
	check(full.status == ClimbState.Status.TOPPED_OUT and places == ["ledge", "hanging"], "the Nose has its nights at El Cap Tower and the Great Roof")
	check(end >= ClimbState.WAKE_MINUTES and end < 18 * 60, "a 6 AM start tops out the Nose on the third day, in the morning or afternoon (%d:%02d)" % [end / 60, end % 60])
	# The calendar: each night is a new day, not a pass-out, and food keeps spoiling.
	var saved := GameClock.save_data()
	GameClock.day = 3
	GameClock.minutes = 6 * 60
	Inventory.items.clear()
	Inventory.add("miners_lettuce", 1)
	Inventory.add("acorn_cake", 1)
	var passed_out := GameClock.advance_through_nights(full.minutes, full.nights_spent)
	check(not passed_out and GameClock.day == 5 and GameClock.minutes == end, "the Nose ends two days later, at %d:%02d, without passing out" % [end / 60, end % 60])
	check(Inventory.count("miners_lettuce") == 0 and Inventory.count("acorn_cake") == 1, "the days on the wall spoil fresh food but not cakes")
	GameClock.minutes = 6 * 60
	check(GameClock.advance_through_nights(20 * 60, 0), "a day climb that runs past 2 AM passes you out")
	GameClock.load_data(saved)
	Inventory.items.clear()


## Climbs that would still be going at 2 AM aren't started.
func test_late_starts() -> void:
	var apron := route("glacier_point_apron")
	check(ClimbState.starts_too_late(apron, 23 * 60 + 30), "a 11:30 PM start on the Apron is refused (about %d min)" % ClimbState.estimate_minutes(apron))
	check(not ClimbState.starts_too_late(apron, 8 * 60), "...but the morning is fine")
	check(not ClimbState.starts_too_late(route("the_nose"), 23 * 60), "a climb with nights on the wall isn't held to the curfew")
	for r in Guidebook.routes():
		if r.nights > 0:
			continue
		var slowest := 0
		for seed in 12:
			food_for(r)
			var state := ClimbState.new(r, int(kit_for(r).get("cam", 0)), seed, kit_for(r))
			ClimbBot.new().play(state)
			slowest = maxi(slowest, state.minutes)
		check(ClimbState.estimate_minutes(r) >= slowest and ClimbState.estimate_minutes(r) < slowest * 2, "%s: the estimate (%d min) covers the slowest climb (%d) without much slack" % [r.id, ClimbState.estimate_minutes(r), slowest])
	Inventory.items.clear()


func test_snow_rules() -> void:
	var lyell := route("lyell_glacier")
	var kit := kit_for(lyell)
	var slush := ClimbState.new(lyell, 0, 2, kit)
	slush.start_minutes = 13 * 60
	var storm := ClimbState.new(lyell, 0, 2, kit)
	storm.start_minutes = 15 * 60
	var dawn := ClimbState.new(lyell, 0, 2, kit)
	dawn.start_minutes = 6 * 60
	var c: int = dawn.holds[1].keys()[0]
	check(not slush.is_stormy() and storm.is_stormy(), "storms start after STORM_HOUR (2:30 PM), slush after noon")
	check(slush.move_cost(1, c) == dawn.move_cost(1, c) + 1 and storm.move_cost(1, c) == dawn.move_cost(1, c) + 1, "slush and storm don't stack (%d, %d, %d)" % [dawn.move_cost(1, c), slush.move_cost(1, c), storm.move_cost(1, c)])
	var minutes_before := dawn.minutes
	check(not dawn.can_chalk() and not dawn.chalk_up() and dawn.minutes == minutes_before and not dawn.chalked_this_pitch, "chalk does nothing on snow, so it isn't offered")
	var rock := ClimbState.new(route("nutcracker"), 4, 1, kit_for(route("nutcracker")))
	check(not rock.can_chalk(), "no chalking on a ledge")
	rock.move(_up(rock))
	check(rock.can_chalk() and rock.chalk_up(), "chalk works on rock")
	var firefall := ClimbState.new(route("firefall_slab"), 0, 1, kit_for(route("firefall_slab")))
	check(not rock.route_has_fixed_pieces() and firefall.route_has_fixed_pieces(), "only routes with bolts or pitons show the quickdraw slot")


func test_fixed_ropes() -> void:
	var nose := route("the_nose")
	for stamina in [1, 2, 3]:
		var state := ClimbState.new(nose, 10, 3, kit_for(nose))
		state.stamina = stamina
		var jugged := false
		for dx in [-1, 0, 1]:
			if state.can_jug(dx):
				jugged = state.jug(dx)
				break
		check(jugged and state.status == ClimbState.Status.CLIMBING and state.falls == 0 and state.stamina >= 1, "jugging a fixed rope at %d stamina doesn't fall (%d left)" % [stamina, state.stamina])
