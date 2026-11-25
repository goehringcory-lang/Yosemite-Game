extends Node
## Saves screenshots of the climbing screen part-way up a route. Needs a window
## (not --headless). Environment:
##   SHOT_ROUTE   route id (default firefall_slab)
##   SHOT_PITCH   pitch to start on (default 0)
##   SHOT_HOURS   comma-separated game hours to shoot at (default 7,12,19)
##   SHOT_MOVES   moves to climb before each shot (default 5)
##   SHOT_INTRO   1 to shoot the route card instead of the climb
##   SHOT_SPECIAL cards to shoot instead: "crux", "pumped", "dyno", "result", "pause", "night",
##                "read" (Down held: the view up the pitch and its topo), "chalk",
##                "summit" (the top-out vista),
##                or "falcon" for a peregrine stooping past the wall, or a
##                longer check part-way through: "swing", "nail", "haul", "layback",
##                or "reach" for a hand reaching for the next hold (SHOT_REACH:
##                how far, as a fraction of the reach, default 0.8),
##                or placing gear: "place" (picking and seating a cam), "clip"
##                (off a crimp), "booty" (working stuck gear free), "rack"
##                (pieces of every quality on the wall, the rack on the harness)
##   SHOT_DIR     folder for the PNGs (default user://)
##   SHOT_UNLIT   1 to leave the wall unlit (ClimbLight off), as on Low
##   SHOT_PAD     1 to show the gamepad's buttons in the hints
## The screenshot is the window's own size (3x the 480 x 270 screen).
## Run: SHOT_ROUTE=firefall_slab SHOT_HOURS=7,19 godot --path . res://tools/shots/climb_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


## The name the pitch gives the crux point nearest above the climber.
func _crux_name(state: ClimbState) -> String:
	for r: int in state.crux_rows():
		if r > state.row:
			return ClimbProfiles.crux_at(state.spec, r).name
	return ClimbProfiles.crux_at(state.spec, state.row).name


func _ready() -> void:
	LitSprites.enabled = OS.get_environment("SHOT_UNLIT") != "1"
	if _env("SHOT_PAD", "0") == "1":
		Settings.ensure_loaded()
		Settings.prompts = Settings.Prompts.GAMEPAD
	var route: RouteData = load("res://data/routes/%s.tres" % _env("SHOT_ROUTE", "firefall_slab"))
	var dir := _env("SHOT_DIR", "user://")
	Gear.owned = {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 6, "rope": 1, "cam": 6}
	for id: String in route.required_gear:
		Gear.owned[id] = maxi(int(Gear.owned.get(id, 0)), int(route.required_gear[id]))
	Inventory.items.clear()
	Inventory.add("trail_mix", 2)
	Inventory.add("acorn_cake", 4)
	GameClock.paused = true
	for hour in _env("SHOT_HOURS", "7,12,19").split(","):
		GameClock.minutes = int(hour) * 60
		var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
		game.setup(route, 4)
		if _env("SHOT_SPECIAL", "") in ["place", "clip", "booty", "rack"]:
			game.state.set_rack(_full_rack())
		game.state.pitch = int(_env("SHOT_PITCH", "0"))
		game.state._start_pitch()
		add_child(game)
		await get_tree().process_frame
		if _env("SHOT_INTRO", "0") == "1":
			for f in 40:
				await get_tree().process_frame
			_save(dir, route.id, "intro_" + hour)
			game.queue_free()
			await get_tree().process_frame
			continue
		game.skip_intro()
		game._scout_t = -1.0 # no look up the line in the picture
		for f in 3:
			await get_tree().process_frame
		if _env("SHOT_BANNER", "0") != "1":
			game._banner_age = 99.0
			game._speech_age = 99.0
		for i in int(_env("SHOT_MOVES", "5")):
			var before := Vector3i(game.state.col, game.state.row, game.state.pitch)
			game.state.protect()
			game.state.move(_cheapest(game.state))
			if not game.state.pending.is_empty():
				game._resolve_crux("good")
			game.state.protect()
			game._after_action(before)
			for f in 8:
				await get_tree().process_frame
		if game.state.row >= 2 and not game.state.chalked_this_pitch:
			game.state.chalk_up()
			game._events()
		match _env("SHOT_SPECIAL", ""):
			"crux":
				game.state.pending = {"kind": "timing", "name": _crux_name(game.state), "window": 0.3}
				game._start_crux()
			"pumped":
				Inventory.add("trail_mix", 1)
				game.state.pending = {"kind": "timing", "name": _crux_name(game.state), "window": 0.3, "pumped": true}
				game._start_pumped()
			"rhythm", "mash":
				game.state.pending = {"kind": _env("SHOT_SPECIAL", ""), "name": "The Narrows", "window": 0.3}
				game._start_crux()
				game._crux.done = 4
			"dyno":
				game.state.pending = {"kind": "dyno", "name": "Chicken wing dyno", "window": 0.22}
				game._start_crux()
				game._crux.holding = true
				game._crux.charge = game._crux.center - 0.1
				game._crux.speed = 0.0
			"swing", "nail", "haul", "layback":
				# Part-way through, held still (pace 0) for the picture.
				var kind := _env("SHOT_SPECIAL", "")
				var names := {"swing": "King Swing", "nail": "Nail a pin", "haul": "Haul the bag", "layback": "The layback"}
				game.state.pending = {"kind": kind, "name": names[kind], "window": 0.24, "row": game.state.row, "cell": Vector2i(game.state.col, game.state.row)}
				game._start_crux()
				game._crux_grace = 0.0
				var c: ClimbCheck = game._crux.check
				match kind:
					"swing":
						c.angle = 0.78
						c.speed = 0.4
						c.pace = 0.0
					"nail":
						c.depth = 0.47
						c.strikes = 2
						c.swing = 0.82
						c.swing_speed = 0.0
					"haul":
						c.height = c.snags[0]
						c.snag = 0
						c.stroke = 0.35
						c.strain = 0.3
						c.wiggles = 1
						c.last_side = -1
						c.pace = 0.0
					"layback":
						c.steps = 2
						c.tension = 0.56
						c.strain = 0.25
						c.pace = 0.0
			"read":
				# Holding Down: the view up the pitch and its topo sketch.
				game._pitch_age = 99.0
				game._look = 1.0
				game._view_row = game._look_row()
				game.set_process(false)
				game._canvas.queue_redraw()
				if game._wall_view:
					game._back.queue_redraw()
					game._wall_view.queue_redraw()
			"chalk":
				# Mid-pitch, the sketch long faded: only the chalk shows the way.
				game._pitch_age = 99.0
			"summit":
				# The top-out vista, with its words up.
				game.state.status = ClimbState.Status.TOPPED_OUT
				game.state.events.append({"type": "topout"})
				game._events()
				game._summit_age = 3.0
			"place", "booty", "rack":
				var st := game.state
				var kind := _env("SHOT_SPECIAL", "")
				st.holds[st.row][st.col] = {"cost": 4, "crack": true, "width": 4, "grip": "crimp"}
				if kind == "rack":
					# A ladder of pieces below: bomber, good, a tipped-out one up top.
					st.protection.clear()
					var rack := st.rack_now()
					var qualities := ["solid", "good", "over", "marginal"]
					for i in mini(st.row - 1, 4):
						var r := st.row - 1 - (mini(st.row - 1, 4) - 1 - i)
						var piece: Dictionary = rack[(3 + i * 2) % rack.size()]
						st.protection.append({"cell": Vector2i(clampi(st.col + (1 if i % 2 == 0 else -1), 0, ClimbState.COLUMNS - 1), r), "kind": "cam", "hw": "nut" if piece.kind == "nut" else "cam",
							"quality": qualities[i % 4], "color": piece.color, "key": ClimbRack.key(piece), "name": piece.name})
					st.protection_row = st.protection.back().cell.y if not st.protection.is_empty() else 0
					game._crux_result = ""
				elif kind == "booty":
					st.booty = [{"id": "shot", "name": "A battered #4", "gear": "cam_4", "width": 7}]
					st.holds[st.row][st.col]["booty"] = 0
					st.holds[st.row][st.col]["width"] = 7
					st.take_booty()
					game._start_crux()
					game._crux_grace = 0.0
					var b: BootyCheck = game._crux.check
					b.knocks = 1
					b.pos = b.center - 0.05
					b.speed = 0.0
				else:
					st.protection_row = mini(st.protection_row, st.row - 1)
					st.place_cam()
					game._start_crux()
					game._crux_grace = 0.0
					var c: PlaceCheck = game._crux.check
					c.phase = "seat"
					c.pull = 0.44
					c.pull_speed = 0.0
					c.time_left = c.time_total * 0.55
					# hold the trigger for the picture
					c.chosen = c.selected()
				if kind != "rack":
					game.set_process(false)
					game._canvas.queue_redraw()
			"clip":
				var st := game.state
				var bolt_row := -1
				for r: int in st.bolts:
					bolt_row = r
					break
				if bolt_row < 0:
					# no bolt on this pitch: put one beside you
					st.bolts[st.row] = st.col
					st.bolt_kinds[st.row] = "bolt"
					bolt_row = st.row
				st.row = bolt_row
				st.col = int(st.bolts[bolt_row])
				st.protection_row = 0
				st.holds[st.row][st.col] = {"cost": 4, "crack": false, "grip": "crimp"}
				st.clip_bolt()
				game._start_crux()
				game._crux_grace = 0.0
				var cc: ClipCheck = game._crux.check
				cc.pos = ClipCheck.CENTER - 0.12
				cc.speed = 0.0
				game.set_process(false)
				game._canvas.queue_redraw()
			"storm":
				game.state.start_minutes = 15 * 60
				for k in 60:
					game._weather(0.05)
					game._fx.update(0.05)
			"result":
				game.state.status = ClimbState.Status.TOPPED_OUT
				game._phase = ClimbMinigame.Phase.RESULT
				game._result_age = 2.0
			"medal":
				# A clean, flawless repeat of a route sent once before with a
				# fall: the result card's new medal and best time.
				game._record_before = {"count": 1, "falls": 1, "minutes": game.state.minutes + 40, "medal": Achievements.BRONZE}
				game.state.perfect_cruxes = 3
				game.best_flow = 3
				game.state.status = ClimbState.Status.TOPPED_OUT
				game._phase = ClimbMinigame.Phase.RESULT
				game._result_age = 2.0
			"record":
				# The route card of a route you've sent: your medal and the next.
				game._record_before = {"count": 3, "falls": 0, "minutes": 95, "medal": Achievements.SILVER}
				game._phase = ClimbMinigame.Phase.INTRO
				game._card_age = 2.0
			"perfect":
				# A third perfect crux in a row, caught as the stamp pops.
				game.flow = 2
				game.best_flow = 2
				game.state.pending = {"kind": "timing", "name": _crux_name(game.state), "window": 0.3}
				game._start_crux()
				game._resolve_crux("perfect")
				for f in 4:
					await get_tree().process_frame
				game._crux_result_age = 0.12
				game.set_process(false)
				game._canvas.queue_redraw()
			"reach":
				# The hand part-way to the hardest hold in reach, held still.
				# Climb on until the technique asked for (SHOT_TECHNIQUE) is in reach.
				var want_t := _env("SHOT_TECHNIQUE", "")
				for extra in 30:
					if want_t == "" or [-1, 0, 1].any(func(d: int) -> bool: return game.state.technique_at(game.state.row + 1, game.state.col + d) == want_t):
						break
					var was := Vector3i(game.state.col, game.state.row, game.state.pitch)
					game.state.stamina = ClimbState.MAX_STAMINA
					game.state.move(_cheapest(game.state))
					if not game.state.pending.is_empty():
						game._resolve_crux("good")
					game._after_action(was)
					for f in 2:
						await get_tree().process_frame
				var pick := 99
				var rank := {"crimp": 4, "sloper": 3, "jam": 3, "edge": 2, "jug": 1}
				for dx in [-1, 0, 1]:
					var t := game.state.technique_at(game.state.row + 1, game.state.col + dx)
					var want := _env("SHOT_TECHNIQUE", "")
					if want != "" and t != want:
						continue
					if rank.has(t) and (pick == 99 or rank[t] > rank.get(game.state.technique_at(game.state.row + 1, game.state.col + pick), 0)):
						pick = dx
				game._move_t = 1.0
				if pick != 99 and game.state.pending.is_empty() and game.start_reach(pick):
					# Held still: a slow frame would carry the hand past the hold.
					game.reaching.held = game.reaching.duration * float(_env("SHOT_REACH", "0.8"))
					game._move_t = 1.0
					game._shown = Vector2(game.state.col, game.state.row)
					game._banner_age = 99.0
					game._toast_age = 99.0
					game.set_process(false)
					game._canvas.queue_redraw()
			"pause":
				game._phase = ClimbMinigame.Phase.PAUSE
			"falcon":
				game.send_falcon()
			"night":
				game._night = {"night": 1, "place": "hanging", "meal": "an acorn cake"}
				game._phase = ClimbMinigame.Phase.NIGHT
				game._night_age = 2.0
		for f in 40:
			await get_tree().process_frame
		if _env("SHOT_SPECIAL", "") == "falcon":
			# catch it mid-stoop, over the sky
			game._falcon_from = Vector2(ClimbMinigame.SCREEN.x * 0.92, -8.0)
			game._falcon_t = 0.42
			await get_tree().process_frame
		_save(dir, route.id, hour)
		game.queue_free()
		await get_tree().process_frame
	get_tree().quit()


## A rack for the gear shots: three nuts, then a cam of every size, doubles
## in the hand sizes.
func _full_rack() -> Array:
	var out := []
	for n in [[0, 1, "Nut (small)"], [2, 3, "Nut (mid)"], [3, 4, "Nut (big)"]]:
		out.append({"id": "nut", "kind": "nut", "width_min": n[0], "width_max": n[1], "color": ClimbRack.width_color(n[0]), "count": 1, "name": n[2]})
	for w in ClimbRack.WIDTHS.size():
		out.append({"id": "cam_%d" % w, "kind": "cam", "width_min": w, "width_max": w, "color": ClimbRack.width_color(w),
			"count": 2 if w in [3, 4, 5] else 1, "name": "Cam " + ClimbRack.width_size(w)})
	return out


func _save(dir: String, route_id: String, tag: String) -> void:
	var image := get_viewport().get_texture().get_image()
	# doubled like the other shots, so screens compare at one scale
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/climb_%s_%s.png" % [dir, route_id, tag])


func _cheapest(state: ClimbState) -> int:
	var best := 0
	var best_cost := 9999
	for dx in [-1, 0, 1]:
		var r := state.row + 1
		if state.hold_at(r, state.col + dx).is_empty():
			continue
		var cost := state.move_cost(r, state.col + dx)
		if state.bolts.has(r) and absi(int(state.bolts[r]) - (state.col + dx)) > 1:
			cost += 20
		if cost < best_cost:
			best = dx
			best_cost = cost
	return best
