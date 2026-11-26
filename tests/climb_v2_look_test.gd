extends Node
## Headless test of thread 10's look for climbing v2 (scripts/climb/v2/look):
## the registry picks it up, the wall paints from V2Wall data (holds stand
## out, cracks go deep, the arete ends the rock, the same wall paints the
## same), the camera (snap, read pan, dead zone, lead, catch shake, reduce
## motion, clamps, whole pixels), the light by the hour, exposure, the
## sounds each event plays and their mix rules, and that the look never
## changes the climb: a full climb with the real look plays exactly as with
## the stub. Every other system is pinned to its stub.
## Run: godot --headless --path . res://tests/climb_v2_look_test.tscn
## Exit code is the number of failed checks.

const T := preload("res://scripts/climb/v2/look/look_tuning.gd")
const V2Test := preload("res://tests/climb_v2_test.gd")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	ClimbSystems.pin_stubs_except([&"look"])
	test_registry()
	test_paint()
	test_camera()
	test_light()
	test_sound()
	await test_screen_and_purity()
	test_paint_time()
	ClimbSystems.pins.clear()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


func fixture_wall() -> V2Wall:
	var w := V2Wall.from_dict(V2Data.load_json(WallSourceStub.FIXTURE))
	w.route_id = "v2_fixture"
	return w


func test_registry() -> void:
	check(ClimbSystems.is_real(&"look"), "the registry finds the real look at look/look.gd")
	var look: Object = ClimbSystems.make(&"look")
	check(look is ClimbLookLive and look is ClimbLook, "it is a ClimbLook")
	(look as Node).free()


func test_paint() -> void:
	var w := fixture_wall()
	var p := LookWallPaint.paint(w, 7)
	var rect: Rect2 = p.rect
	var h: Image = p.height
	check(h.get_width() == int(ceil(rect.size.x * ClimbV2.PX_PER_M)) and h.get_height() == int(ceil(rect.size.y * ClimbV2.PX_PER_M)),
		"the height picture covers the face and its margins at PX_PER_M (%dx%d)" % [h.get_width(), h.get_height()])
	check(rect.position.x < 0.0 and rect.end.x > w.size.x and rect.end.y > w.size.y, "rock carries on past the climbable face")
	# A hold stands out against the same spot painted without it.
	var bare := V2Wall.from_dict(w.to_dict())
	bare.holds.clear()
	var hb: Image = LookWallPaint.paint(bare, 7).height
	var hold := w.hold("h0")
	var c := LookWallPaint.to_px(hold.pos, rect)
	var diff := 0.0
	for dy in range(-4, 5):
		for dx in range(-8, 9):
			diff += absf(h.get_pixel(int(c.x) + dx, int(c.y) + dy).r - hb.get_pixel(int(c.x) + dx, int(c.y) + dy).r)
	check(diff > 3.0, "an edge is carved into the rock (relief changed by %.1f)" % diff)
	# Its lip is proud on top and drops away on the pull side (below).
	var lip := h.get_pixel(int(c.x), int(c.y) - 1).r - hb.get_pixel(int(c.x), int(c.y) - 1).r
	check(lip > 0.1, "the edge's lip stands proud (%.2f)" % lip)
	# Chalk on hand holds, none on a foot-only chip.
	var marks: Image = p.marks
	var mc := LookWallPaint.to_px(hold.pos, rect, ClimbV2.PX_PER_M * 0.5)
	var chalk := 0.0
	for dy in range(-3, 2):
		for dx in range(-3, 4):
			chalk = maxf(chalk, marks.get_pixel(int(mc.x) + dx, int(mc.y) + dy).b)
	check(chalk > 0.2, "hand holds carry chalk (%.2f)" % chalk)
	if not w.cracks.is_empty():
		var crack := w.cracks[0]
		var mid := crack.points[0].lerp(crack.points[crack.points.size() - 1], 0.5)
		var cp := LookWallPaint.to_px(mid, rect)
		var low := 1.0
		for dx in range(-3, 4):
			low = minf(low, h.get_pixel(int(cp.x) + dx, int(cp.y)).r)
		check(low < 0.25, "a crack goes deep into the rock (%.2f)" % low)
	var tone: Image = p.tone
	var on_face := LookWallPaint.to_px(Vector2(3, 5), rect, ClimbV2.PX_PER_M / 4.0)
	var past := LookWallPaint.to_px(Vector2(float(p.arete) + 0.75, 5), rect, ClimbV2.PX_PER_M / 4.0)
	check(tone.get_pixel(int(on_face.x), int(on_face.y)).g > 0.9 and tone.get_pixel(mini(int(past.x), tone.get_width() - 1), int(past.y)).g < 0.1,
		"rock on the face, sky past the arete")
	var again := LookWallPaint.paint(fixture_wall(), 7)
	check((again.height as Image).get_data() == h.get_data() and (again.marks as Image).get_data() == marks.get_data(),
		"the same wall and seed paint the same picture")
	check((LookWallPaint.paint(fixture_wall(), 8).height as Image).get_data() != h.get_data(), "another seed paints other rock")
	var later := fixture_wall()
	later.pitch = 1
	var ledge := LookWallPaint.paint(later, 7)
	var lp := LookWallPaint.to_px(later.start + Vector2(0, -0.05), ledge.rect)
	check((ledge.height as Image).get_pixel(int(lp.x), int(lp.y) - 2).r > (LookWallPaint.paint(w, 7).height as Image).get_pixel(int(lp.x), int(lp.y) - 2).r,
		"later pitches start from a belay ledge")


func _session(w: V2Wall) -> ClimbSession:
	var s := ClimbSession.new()
	s.wall = w
	s.pose.hip = w.start + Vector2(0, 0.9)
	return s


func _run(cam: LookCamera, s: ClimbSession, seconds: float, aim: Variant = null) -> void:
	var t := 0.0
	while t < seconds:
		cam.step(1.0 / 60.0, s, aim)
		t += 1.0 / 60.0


func test_camera() -> void:
	var w := fixture_wall()
	w.size = Vector2(6, 30)
	w.top = Vector2(3, 29)
	var s := _session(w)
	var cam := LookCamera.new()
	cam.snap_to(w, s.pose.hip)
	cam.phase_changed(&"read")
	check(cam.zoom == T.ZOOM_WIDE and cam.focus.y > 15.0, "reading starts wide at the top of the pitch (y %.1f)" % cam.focus.y)
	var top := cam.focus.y
	_run(cam, s, T.READ_HOLD * 0.5)
	check(absf(cam.focus.y - top) < 0.3, "it holds on the top a moment")
	_run(cam, s, 12.0)
	check(cam.focus.y < top - 8.0, "then pans down the pitch (y %.1f)" % cam.focus.y)
	cam.phase_changed(&"climb")
	_run(cam, s, 4.0)
	check(cam.zoom == T.ZOOM_CLOSE, "climbing comes back to the close stop")
	var rest := cam.focus
	s.pose.hip += Vector2(0.1, 0.15)
	_run(cam, s, 2.0)
	check(cam.focus.distance_to(rest) < 0.02, "a small hip shift stays inside the dead zone")
	s.pose.hip = Vector2(3, 6)
	_run(cam, s, 4.0)
	check(absf(cam.focus.y - (6.0 + T.CLIMB_LIFT - T.DEAD_ZONE.y)) < 0.1, "climbing higher, the view follows the hips (y %.2f)" % cam.focus.y)
	var before := cam.focus
	_run(cam, s, 3.0, Vector2(4.5, 7.5))
	var lead := cam.focus - before
	check(lead.x > 0.2 and lead.y > 0.2 and lead.length() <= T.LEAD_MAX + 0.05, "aiming leads the view toward the hold (%.2f, %.2f)" % [lead.x, lead.y])
	var t := cam.world_transform()
	check(t.origin == t.origin.round(), "the world sits on whole pixels")
	cam.fall_caught(3.0)
	cam.step(0.02, s, null)
	check(absf(cam.offset.y) > 1.0, "a caught fall shakes the view (%.1f px)" % cam.offset.y)
	_run(cam, s, 1.0)
	check(cam.offset == Vector2.ZERO, "the shake dies away")
	cam.reduce_motion = true
	cam.fall_caught(5.0)
	cam.move_committed()
	cam.step(0.02, s, Vector2(5, 8))
	check(cam.offset == Vector2.ZERO, "reduce motion: no shake, no settle")
	cam.reduce_motion = false
	# Clamps: the left edge of the view never runs past the painted rock.
	s.pose.hip = Vector2(-20, 6)
	_run(cam, s, 6.0)
	var left := cam.to_wall(Vector2(0, 270)).x
	check(left >= -T.MARGIN_LEFT - 0.05, "no sky past the rock on the left (edge %.2f m)" % left)
	s.pose.hip = Vector2(3, -5)
	_run(cam, s, 6.0)
	check(cam.to_wall(Vector2(480, 540)).y >= w.start.y - T.MARGIN_BELOW - 0.05, "nor under the foot of the pitch")
	cam.phase_changed(&"result")
	_run(cam, s, 8.0)
	check(cam.zoom == T.ZOOM_WIDE, "topping out pulls back to see the pitch")
	cam.phase_changed(&"fall")
	s.pose.hip = Vector2(3, 10)
	_run(cam, s, 1.5)
	check(cam.focus.y < 10.0, "a fall is framed below the climber (y %.2f)" % cam.focus.y)


func test_light() -> void:
	var noon: Dictionary = ClimbLookLive.sun_at(12.5)
	var dusk: Dictionary = ClimbLookLive.sun_at(19.3)
	check(float(noon.strength) > float(dusk.strength) and float(dusk.strength) >= T.SUN_MIN, "the sun is strongest at midday, and never too weak to show holds")
	check(float(ClimbLookLive.sun_at(23.0).strength) == 0.0, "no sun at night")
	check((ClimbLookLive.sun_at(7.5).travel as Vector2).x > 0.0 and (ClimbLookLive.sun_at(17.0).travel as Vector2).x < 0.0,
		"morning light comes from the left, evening light from the right")
	check(ClimbLookLive.night_at(12.0) == 0.0 and ClimbLookLive.night_at(23.0) == 1.0 and ClimbLookLive.night_at(20.0) > 0.0 and ClimbLookLive.night_at(20.0) < 1.0,
		"night falls through dusk")


func test_sound() -> void:
	var s := _session(fixture_wall())
	var snd := LookSound.new()
	snd.mute = true
	snd.listen(s.bus, s)
	var m := V2Move.new()
	m.hold_id = "h0"
	s.bus.send(&"move_committed", [m])
	check(snd.played.size() == 1 and snd.played[0].begins_with("climb_move_"), "an edge sounds like a hand on rock (%s)" % [snd.played])
	snd.step(1.0, 0.0, 0.0)
	s.bus.send(&"clipped", ["b1", false])
	s.bus.send(&"clipped", ["b2", false])
	check(snd.played.count("climb_clip") == 1, "the same sound never doubles up inside the gap")
	snd.step(1.0, 0.0, 0.0)
	var f := V2Fall.new()
	f.drop_m = 6.0
	s.bus.send(&"fall_started", [f])
	s.bus.send(&"fall_caught", [f])
	check(snd.played.has("climb2_whoosh") and snd.played.has("climb2_catch") and snd.played.has("slack_twang"), "a long fall: the air, the catch, the rope's twang")
	snd.played.clear()
	var last := ""
	var repeats := 0
	for i in 30:
		snd.step(1.0, 0.0, 0.0)
		snd.play("climb_move")
		if snd.played[-1] == last:
			repeats += 1
		last = snd.played[-1]
	check(repeats == 0, "a sound with takes never plays the same take twice running")
	snd.played.clear()
	for i in 300:
		snd.step(1.0 / 30.0, 0.0, 0.0)
	check(not snd.played.has("climb2_breath_1") and not snd.played.has("climb2_breath_2") and not snd.played.has("climb2_breath_3"), "fresh forearms: no hard breathing")
	var e := V2Effort.new()
	e.pump = 0.9
	s.bus.send(&"effort_changed", [e])
	for i in 300:
		snd.step(1.0 / 30.0, 0.0, 0.0)
	var breaths := snd.played.filter(func(id: String) -> bool: return id.begins_with("climb2_breath")).size()
	check(breaths >= 5, "pumped: breathing hard, often (%d breaths in 10 s)" % breaths)
	snd.played.clear()
	for tone in ["rising", "rising", "ring", "clack"]:
		snd.special_step(&"nail", {"tone": tone})
	check(snd.played.count("climb_pin") == 4, "every hammer tap on a pin sounds, even fast ones")
	snd.step(1.0, 0.0, 0.0)
	snd.special_step(&"swing", {"stage": "swing", "peak": 0.8})
	snd.special_step(&"swing", {"stage": "grabbed"})
	check(snd.played.has("climb2_whoosh") and snd.played.has("climb2_slap"), "a pendulum whooshes and slaps the far hold")
	for id in ["climb2_rope_pull", "climb2_catch", "climb2_breath_1", "climb2_nut", "climb2_slap"]:
		check(ResourceLoader.exists("res://assets/audio/%s.wav" % id), "the %s sound is built" % id)


func test_screen_and_purity() -> void:
	var traces := []
	for real in [false, true]:
		if real:
			ClimbSystems.pin_stubs_except([&"look"])
		else:
			ClimbSystems.pin_stubs_except([])
		var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
		screen.setup(V2Test.fixture_route(2), 7, V2Modifiers.new(), V2Test.fixture_rack())
		add_child(screen)
		await get_tree().process_frame
		var s := screen.session
		var look := screen.look
		if real:
			check(look is ClimbLookLive, "the screen mounts the real look")
			check(look.is_in_group("climb_screen") and (look as ClimbLookLive).exposure() >= 0.0, "Sound's climb ambience finds it")
			(look as ClimbLookLive).sound.mute = true
			check(screen.world.scale == Vector2(T.ZOOM_WIDE, T.ZOOM_WIDE), "the climb opens on the wide read view")
			var low := (look as ClimbLookLive).exposure()
			s.pose.hip.y += 8.0
			check((look as ClimbLookLive).exposure() > low, "higher up is more exposed")
			s.pose.hip.y -= 8.0
		var bot := ClimbV2TestBot.new(screen.director)
		var n := 0
		while not screen.director.done and n < 900:
			bot.step()
			n += 1
			if n % 15 == 0:
				await get_tree().process_frame
		traces.append([s.bus.names(), s.result.to_dict()])
		await get_tree().process_frame
	check(traces[0][0] == traces[1][0], "the climb's events are the same with the real look as with the stub (%d events)" % traces[1][0].size())
	check(traces[0][1] == traces[1][1], "and so is the result: the look never changes the climb")
	ClimbSystems.pin_stubs_except([&"look"])


func test_paint_time() -> void:
	var w := fixture_wall()
	w.size = Vector2(6, 40)
	w.top = Vector2(3, 39)
	var t0 := Time.get_ticks_msec()
	LookWallPaint.paint(w, 3)
	var ms := Time.get_ticks_msec() - t0
	print("      a 40 m pitch paints in %d ms" % ms)
	check(ms < 6000, "a 40 m pitch paints in reasonable time (%d ms)" % ms)
