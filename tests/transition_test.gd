extends Node
## Checks the timing every change of scene shares (Transition): the curve
## eases in and out and ends on exactly 1, a long frame slows a wipe rather
## than skipping it, and a door, a fade and a trip on the map each end with
## the cover gone and the HUD fully back.
## Run: godot --headless --path . res://tests/transition_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://transition_test_save.json"
	SaveManager.delete_save()
	Settings.tips = false
	Settings.journeys = true

	# The curve: still at both ends, never going back.
	check(is_equal_approx(Transition.smooth(0.0), 0.0) and is_equal_approx(Transition.smooth(1.0), 1.0), "the curve runs 0 to 1")
	check(Transition.smooth(0.05) < 0.01 and Transition.smooth(0.95) > 0.99, "it eases off and eases to rest")
	var rising := true
	for i in 20:
		rising = rising and Transition.smooth((i + 1) / 20.0) >= Transition.smooth(i / 20.0)
	check(rising, "it never goes back")
	check(Transition.REVEAL_TIME >= Transition.COVER_TIME, "uncovering is no quicker than covering")

	# A long frame (as when a place is first laid out) must not skip a wipe.
	Transition.hold_long_frames = true
	var steps: Array[float] = []
	var stalled := [false]
	await Transition.run(self, 0.5, func(t: float) -> void:
		steps.append(t)
		if steps.size() == 3 and not stalled[0]:
			stalled[0] = true
			OS.delay_msec(400))
	check(steps[-1] == 1.0, "a transition ends on exactly 1")
	var after_stall := steps[3] - steps[2] if steps.size() > 3 else 1.0
	# one frame may move it on by at most MAX_STEP of the 0.5 s: 1/15 of
	# the way in time, a little more on the curve's steepest part
	check(after_stall < 0.15, "a 400 ms frame moves a 0.5 s wipe on by a step, not most of the way (%.2f)" % after_stall)
	check(steps.size() > 10, "it plays over many frames (%d)" % steps.size())
	# headless, as the other tests run, it keeps to the clock
	Transition.hold_long_frames = false

	Engine.time_scale = 4.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	await world.go_to_region("curry_village", "arrival")
	var hud: HUD = world.hud

	# A door.
	await world.go_to_region("curry_store", "door")
	for i in 30:
		await get_tree().process_frame
	check(world.region.region_id == "curry_store" and world.get_node_or_null("DoorCover") == null, "through a door, the picture of the old place is gone")
	check(not world._busy and not world._transitioning, "...and the world goes on")

	# A fade (the trip map off).
	world.journeys = false
	await world.go_to_region("happy_isles", "arrival", 20)
	world.journeys = true
	check(world.region.region_id == "happy_isles" and is_zero_approx(hud.fade.color.a), "after a fade the cover is clear")
	check(not world._busy and not world._transitioning, "...and the world goes on")

	# A trip on the map: the HUD fades out under it and all the way back.
	world.journeys_headless = true
	world.go_to_region("glacier_point", "ledge_trail_top", 180, {"title": "Four Mile Trail", "on_foot": true})
	await get_tree().process_frame
	await get_tree().process_frame
	var dimmed: bool = hud.opacity < 1.0
	for i in 2000:
		if not world._busy:
			break
		await get_tree().process_frame
	check(dimmed, "the HUD fades as the map comes down, not in one frame")
	check(world.region.region_id == "glacier_point" and is_equal_approx(hud.opacity, 1.0) and hud.visible, "after the trip the HUD is fully back")
	check(not world._busy and not world._transitioning, "...and the world goes on")

	Engine.time_scale = 1.0
	print("%d failed" % failures)
	get_tree().quit(failures)
