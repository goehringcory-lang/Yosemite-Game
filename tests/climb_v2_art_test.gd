extends Node
## Headless test of the v2 climber art (scripts/climb/v2/art, thread 9): the
## registry picks it up, every body position in ClimberPoses keeps its hands
## and feet on their holds, the two-bone reach never pops, a committed move
## plays hips first with planted limbs pinned, falls play out and land in the
## settled pose, the look follows the player's choices, it never changes the
## session, and a frame costs little. Every other system is pinned to its stub.
## Run: godot --headless --path . res://tests/climb_v2_art_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	ClimbSystems.pin_stubs_except([&"climber"])
	test_registry()
	test_pose_contacts()
	test_two_bone()
	test_bend_eases()
	test_move_plays_hips_first()
	test_dyno_cuts_feet()
	test_determinism()
	test_fall()
	test_gestures_return()
	test_style()
	test_other_threads()
	await test_on_screen()
	test_cost()
	ClimbSystems.pins.clear()
	PlayerLook.reset()
	print("\nOK: %d failure(s)" % failures)
	get_tree().quit(failures)


func test_registry() -> void:
	check(ClimbSystems.path_for(&"climber").ends_with("art/climber.gd"), "the registry uses the real climber art")
	var art: Object = ClimbSystems.make(&"climber")
	check(art is ClimberArt and art is ClimberView, "it is a ClimberView")
	(art as Node).free()


func test_pose_contacts() -> void:
	var all_ok := true
	var bones_ok := true
	for pose_name: String in ClimberPoses.names():
		var pose := ClimberPoses.pose(pose_name)
		var rig := ClimberRig.from_pose(pose)
		if not rig.contacts_met(0.002):
			all_ok = false
			print("      %s: a hand or foot misses its hold" % pose_name)
		for l in V2Pose.LIMBS:
			var limb: V2Limb = pose.limb(l)
			if limb.kind == &"hold" and (rig.tip[l] as Vector2).distance_to(limb.pos) > 0.002:
				all_ok = false
		var lengths := rig.bone_lengths()
		for key: String in lengths:
			var want := ClimberRig.UPPER_ARM if key.ends_with("h_upper") else (ClimberRig.FOREARM if key.ends_with("h_lower") else (ClimberRig.THIGH if key.ends_with("f_upper") else ClimberRig.SHIN))
			if lengths[key] < want - 0.003 or lengths[key] > want * ClimberRig.STRETCH + 0.003:
				bones_ok = false
				print("      %s: %s is %.3f m, wants %.3f" % [pose_name, key, lengths[key], want])
	check(all_ok, "every pose in the library keeps its hands and feet exactly on their holds (%d poses)" % ClimberPoses.names().size())
	check(bones_ok, "no bone shrinks, and none stretches past 4%")
	# Out of reach: the chest leans and the bones stretch before a hand lets go.
	var p := ClimberPoses.pose("rest on jugs")
	p.set_limb(&"rh", V2Limb.make(&"hold", p.hip + Vector2(0.3, 1.34), "x"))
	var rig := ClimberRig.from_pose(p)
	check((rig.tip[&"rh"] as Vector2).distance_to(p.limb(&"rh").pos) < 0.002, "a long reach is met by the chest leaning and stretching")
	var hang := ClimberPoses.pose("hanging on the rope")
	var hr := ClimberRig.from_pose(hang)
	check((hr.tip[&"lh"] as Vector2).y > hang.hip.y + 0.5 and (hr.tip[&"lf"] as Vector2).y < hang.hip.y - 0.6,
		"limbs parked on the hips hang: hands up on the rope, feet dangling")


func test_two_bone() -> void:
	var a := Vector2.ZERO
	var target := Vector2(0.3, 0.5)
	var last: Vector2
	var max_step := 0.0
	var ends_ok := true
	for i in 41:
		var side := -1.0 + i * 0.05
		var r := ClimberRig.two_bone(a, target, 0.31, 0.41, side)
		if r[1].distance_to(target) > 0.0001:
			ends_ok = false
		if i > 0:
			max_step = maxf(max_step, r[0].distance_to(last))
		last = r[0]
	check(ends_ok, "two-bone reach always lands the end on the target")
	check(max_step < 0.04, "swapping the bend side moves the elbow smoothly (largest step %.3f m)" % max_step)
	var far := ClimberRig.two_bone(a, Vector2(0, 2), 0.31, 0.41, 1.0)
	check(is_equal_approx(far[1].length(), 0.72 * ClimberRig.STRETCH), "out of reach, the limb stretches 4% and stops")
	var near := ClimberRig.two_bone(a, Vector2(0.01, 0.02), 0.31, 0.41, 1.0)
	check(near[0].length() < 0.32, "a hand pulled in to the shoulder folds the arm, never throws the elbow away")


func test_bend_eases() -> void:
	var m := ClimberMotion.new()
	m.snap(ClimberPoses.pose("rest on jugs"))
	m.bend[&"rh"] = -1.0
	m.bend_goal[&"rh"] = 1.0
	var biggest := 0.0
	var before: float = m.bend[&"rh"]
	for i in 12:
		m.step(1.0 / 60.0)
		biggest = maxf(biggest, absf(m.bend[&"rh"] - before))
		before = m.bend[&"rh"]
	check(biggest <= 2.0 / ClimberMotion.BEND_TIME / 60.0 + 0.0001 and is_equal_approx(m.bend[&"rh"], 1.0), "an elbow swaps sides over %.2f s, never in one frame" % ClimberMotion.BEND_TIME)


## A plain reach: the right hand to a hold higher up, hips and feet following.
func _reach_move(from: V2Pose, tags := PackedStringArray()) -> V2Move:
	var mv := V2Move.new()
	mv.hand = &"rh"
	mv.hold_id = "next"
	mv.from = from.copy()
	mv.to = from.copy()
	mv.to.set_limb(&"rh", V2Limb.make(&"hold", from.limb(&"rh").pos + Vector2(0.05, 0.4), "next"))
	mv.to.hip = from.hip + Vector2(0.03, 0.3)
	mv.to.set_limb(&"rf", V2Limb.make(&"hold", from.limb(&"rf").pos + Vector2(0, 0.3), "rf2"))
	mv.reach = 0.6
	mv.tags = tags
	mv.load = {&"lh": 0.3, &"rh": 0.2, &"lf": 0.3, &"rf": 0.2}
	return mv


func test_move_plays_hips_first() -> void:
	var m := ClimberMotion.new()
	var start := ClimberPoses.pose("rest on jugs")
	m.snap(start)
	var mv := _reach_move(start)
	m.retarget(mv.to, mv)
	var lh0: Vector2 = start.limb(&"lh").pos
	var lf0: Vector2 = start.limb(&"lf").pos
	var rh0: Vector2 = start.limb(&"rh").pos
	var pinned := true
	var hip_moved_first := false
	var hand_left_at := -1.0
	var hand_landed_at := -1.0
	var foot_moved_at := -1.0
	for i in 60:
		m.step(1.0 / 60.0)
		if (m.ends[&"lh"] as Vector2) != lh0 or (m.ends[&"lf"] as Vector2) != lf0:
			pinned = false
		if hand_left_at < 0.0 and (m.ends[&"rh"] as Vector2).distance_to(rh0) > 0.001:
			hand_left_at = m.time
			hip_moved_first = m.hip.distance_to(start.hip) > 0.001
		if hand_landed_at < 0.0 and (m.ends[&"rh"] as Vector2).distance_to(mv.to.limb(&"rh").pos) < 0.0005:
			hand_landed_at = m.time
		if foot_moved_at < 0.0 and (m.ends[&"rf"] as Vector2).distance_to(start.limb(&"rf").pos) > 0.001:
			foot_moved_at = m.time
	check(pinned, "limbs that stay on their holds stay exactly there while another moves")
	check(hip_moved_first, "the hips start before the hand leaves its hold")
	check(hand_landed_at > 0.2 and hand_landed_at < 0.6, "a normal reach lands in about half a second (%.2f s)" % hand_landed_at)
	check(foot_moved_at > hand_landed_at, "the feet step up after the hand latches")
	check(m.hip.distance_to(mv.to.hip) < 0.03 and m.idle() == false or m.hip.distance_to(mv.to.hip) < 0.03, "the hips end where the pose puts them")
	# Interrupting mid-move retargets from where the drawing is: no jump.
	var m2 := ClimberMotion.new()
	m2.snap(start)
	m2.retarget(mv.to, mv)
	for i in 10:
		m2.step(1.0 / 60.0)
	var before: Vector2 = m2.ends[&"rh"]
	var back := _reach_move(mv.to)
	m2.retarget(back.to, back)
	m2.step(1.0 / 60.0)
	check((m2.ends[&"rh"] as Vector2).distance_to(before) < 0.03, "a new move mid-reach carries on from where the hand is")


func test_dyno_cuts_feet() -> void:
	var m := ClimberMotion.new()
	var start := ClimberPoses.pose("rest on jugs")
	m.snap(start)
	var mv := _reach_move(start, PackedStringArray(["dyno"]))
	m.retarget(mv.to, mv)
	var lowest := start.hip.y
	var feet_off := false
	for i in 90:
		m.step(1.0 / 60.0)
		lowest = minf(lowest, m.hip.y)
		if (m.ends[&"lf"] as Vector2).distance_to(start.limb(&"lf").pos) > 0.05:
			feet_off = true
	check(lowest < start.hip.y - 0.08, "a dyno crouches before it launches")
	check(feet_off, "a dyno cuts the feet loose")
	check((m.ends[&"lf"] as Vector2).distance_to(mv.to.limb(&"lf").pos) < 0.001, "and they come back onto their holds")


func test_determinism() -> void:
	var runs: Array = []
	for r in 2:
		var m := ClimberMotion.new()
		var start := ClimberPoses.pose("rest on jugs")
		m.snap(start)
		var mv := _reach_move(start, PackedStringArray(["lunge"]))
		m.pump = 0.8
		m.retarget(mv.to, mv)
		var rig := ClimberRig.new()
		var trace: Array = []
		for i in 40:
			m.step(1.0 / 30.0)
			m.apply(rig)
			trace.append([rig.joint[&"lh"], rig.tip[&"rh"], rig.head])
		runs.append(trace)
	check(runs[0] == runs[1], "the same moves animate the same way every time (no randomness)")


func test_fall() -> void:
	var m := ClimberMotion.new()
	var start := ClimberPoses.pose("rest on jugs", Vector2(3, 6))
	m.snap(start)
	var settled := V2Pose.new()
	settled.hip = Vector2(3.4, 3.2)
	settled.tags.append("hang")
	for l in V2Pose.LIMBS:
		settled.limbs[l] = V2Limb.make(&"free", settled.hip)
	var fall := V2Fall.new()
	fall.from_pos = start.hip
	fall.drop_m = 2.8
	fall.settle_pos = settled.hip
	m.retarget(settled, null)
	m.start_fall(fall, Vector2(3.5, 5.0))
	var lowest := 99.0
	var limbs_up := false
	for i in int(4.0 * 60):
		m.step(1.0 / 60.0)
		lowest = minf(lowest, m.hip.y)
		if m.falling() and (m.ends[&"lh"] as Vector2).y > m.hip.y + 0.45:
			limbs_up = true
	check(lowest < settled.hip.y - 0.05, "the rope stretches at the catch: the body drops below where it settles")
	check(limbs_up, "the arms trail up while falling")
	check(not m.falling() and m.hip.distance_to(settled.hip) < 0.001, "after the fall the climber hangs exactly at the settled pose")
	check(m.caught_at > 0.0, "the catch is marked (the rope whips)")


func test_gestures_return() -> void:
	var m := ClimberMotion.new()
	var start := ClimberPoses.pose("rest on jugs")
	m.snap(start)
	m.gesture(&"rh", [Vector2(0.03, 0.12), Vector2(0.14, 1.12)], 0.3)
	var rig := ClimberRig.new()
	var moved := false
	for i in 30:
		m.step(1.0 / 60.0)
		m.apply(rig)
		if (rig.ends[&"rh"] as Vector2).distance_to(start.limb(&"rh").pos) > 0.1:
			moved = true
	check(moved and (rig.ends[&"rh"] as Vector2).distance_to(start.limb(&"rh").pos) < 0.001, "a gesture (a rope pull) plays and the hand goes back to its place")


func test_style() -> void:
	PlayerLook.reset()
	var shipped := ClimberStyle.current()
	check(shipped.shirt[ClimberStyle.BASE] == ClimbSprites.DEFAULT_COLORS.shirt, "the shipped look keeps the old climber's colors")
	PlayerLook.set_choice("top", 4)
	PlayerLook.set_choice("hair_style", 2)
	PlayerLook.set_choice("hat", 3)
	var mine := ClimberStyle.current()
	check(mine != shipped and mine.shirt[ClimberStyle.BASE] == Palette32.nearest(Color("b3362b")) and mine.hair_style == "braid" and mine.hat_kind == "beanie",
		"the climber wears the shirt, hair and hat the player chose")
	PlayerLook.reset()


## Signs from the effort thread and tells from the crux thread show on the body.
func test_other_threads() -> void:
	var art: ClimberArt = load("res://scripts/climb/v2/art/climber.gd").new()
	var session := ClimberPoses.session_for(["rest on jugs"])
	session.pose = ClimberPoses.pose("rest on jugs", Vector2(1.5, 2.0))
	art.bind(session)
	check(art.draws_effort_signs(), "the climber tells the effort thread it draws the strain signs")
	session.note(&"effort")["signs"] = {"tremble": 1.0, "chicken_wing": 1.0, "band": "boxed"}
	check(art.effort_signs().get("tremble") == 1.0, "it reads the effort thread's signs from the session notes")
	var m := ClimberMotion.new()
	m.snap(session.pose)
	m.signs = art.effort_signs()
	var shook := false
	for i in 60:
		m.step(1.0 / 60.0)
		if m.tremor(&"lh").length() > 0.004:
			shook = true
	check(shook, "a trembling sign shakes the loaded arm")
	var mv := _reach_move(session.pose)
	mv.tags = PackedStringArray(["crux_miss:hip_x1", "crux_miss:hand_rh"])
	art._ghost_tells = ClimberArt.crux_tells(mv)
	check(art._ghost_tells == PackedStringArray(["hip_x1", "hand_rh"]), "crux tells are read from the move's tags")
	var calm := ClimberRig.from_pose(mv.to)
	var widest := 0.0
	for i in 20:
		widest = maxf(widest, art.ghost_rig(mv, i * 0.05).hip.x - calm.hip.x)
	check(widest > 0.08, "a barn-door tell swings the ghost open that way")
	art.free()


func test_on_screen() -> void:
	var route := RouteData.new()
	route.id = "v2_fixture"
	route.display_name = "Fixture"
	route.protection = "bolts"
	route.pitches.assign([2, 2])
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(route, 7, V2Modifiers.new(), ClimberPoses.session_for(["rest on jugs"]).rack)
	add_child(screen)
	await get_tree().process_frame
	var art := screen.climber as ClimberArt
	check(art != null, "the v2 screen builds the climber art")
	var bot := ClimbV2TestBot.new(screen.director)
	var steps := 0
	while steps < 30 and not screen.director.done:
		bot.step()
		steps += 1
		for f in 3:
			await get_tree().process_frame
	# Looking on doesn't touch the session.
	var before := screen.session.snapshot()
	var trace_before := screen.session.bus.trace.size()
	for f in 20:
		await get_tree().process_frame
	check(screen.session.snapshot() == before and screen.session.bus.trace.size() == trace_before, "drawing the climber never changes the session or sends events")
	check(art.rig.contacts_met(0.06) or not art.motion.idle(), "on screen the drawn climber is on its holds")
	if screen.session.phase == &"climb":
		screen.director.handle_verb(&"aim_up", true)
		await get_tree().process_frame
		check(art._ghost_sprite.visible, "aiming shows the ghost")
		screen.director.take_fall()
		await get_tree().process_frame
		check(art.motion.falling() and not art._ghost_sprite.visible, "a fall plays and hides the ghost")
	screen.queue_free()
	await get_tree().process_frame


func test_cost() -> void:
	var m := ClimberMotion.new()
	m.snap(ClimberPoses.pose("big reach"))
	m.pump = 0.9
	var rig := ClimberRig.new()
	var t0 := Time.get_ticks_usec()
	for i in 500:
		m.update_bends(PackedStringArray())
		m.step(1.0 / 60.0)
		m.apply(rig)
	var per := (Time.get_ticks_usec() - t0) / 500.0
	check(per < 400.0, "animating and solving the skeleton costs %.0f us a frame (budget 400)" % per)
