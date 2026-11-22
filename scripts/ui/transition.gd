class_name Transition
extends RefCounted
## Timing for every change of scene: the fade between places, the door wipe,
## the trip map's veil and the wipe over the minigame screens.
##
## Two things keep them smooth. [method run] steps an animation a frame at a
## time but never more than [constant MAX_STEP] of real time in one frame,
## so a long frame (laying out a new place, a first-time shader) slows the
## wipe for that frame instead of skipping half of it. And [method settle]
## waits, with the cover still up, until the new place draws at an even pace
## again, so the reveal plays over smooth frames rather than over the hitch.
##
##   await hud.fade_to_black()
##   world.enter_the_new_place()
##   await Transition.settle(self)
##   await hud.fade_from_black()

## Covering the screen between places.
const COVER_TIME := 0.45
## Uncovering the new place: a touch slower, so it opens up.
const REVEAL_TIME := 0.55
## Opening from a door into the place beyond.
const DOOR_TIME := 0.5
## Over the minigame screens (climbing, the slackline).
const SCREEN_TIME := 0.4
## The trip map's veil coming down over the world, and lifting off it.
const MAP_COVER_TIME := 0.35
const MAP_LIFT_TIME := 0.5

## The most real time one frame may move an animation on, in seconds.
const MAX_STEP := 1.0 / 30.0
## A frame this quick (ms) counts as settled (as GraphicsWatch.SLOW_MS).
const SETTLED_MS := 25.0
## Settled frames in a row before the reveal begins.
const SETTLED_FRAMES := 3
## Whether [method run] holds a long frame to MAX_STEP. Without a screen
## (the tests) nothing is seen, and the tests wait on game-time timers that
## a held-back wipe would outlast, so there it runs on the clock as tweens
## do. Tools that take pictures turn it off too, so a wipe takes the same
## real time under a fast renderer and a slow one.
static var hold_long_frames := DisplayServer.get_name() != "headless"

## Frames to wait whatever happens, and the longest wait (seconds).
const LEAST_FRAMES := 2
const MOST_WAIT := 0.6


## Eases in and out like a sine: slow off, smooth through, slow to rest. A
## curve that starts at full speed (ease-out) is where a long first frame
## shows most, so every transition uses this one.
static func smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 0.5 - 0.5 * cos(PI * t)


## Calls [param apply] with an eased 0..1 over [param seconds] (game time,
## so the tests' fast clock speeds it up as tweens are), one step a drawn
## frame, never more than MAX_STEP of real time a frame. Ends on exactly 1.
## It runs whatever the pause, as menus do.
static func run(node: Node, seconds: float, apply: Callable) -> void:
	if node == null or not node.is_inside_tree():
		apply.call(1.0)
		return
	var tree := node.get_tree()
	var t := 0.0
	var last := Time.get_ticks_usec()
	apply.call(0.0)
	while t < 1.0:
		await tree.process_frame
		if not is_instance_valid(node) or not node.is_inside_tree():
			break
		var now := Time.get_ticks_usec()
		var real := (now - last) / 1000000.0
		if hold_long_frames:
			real = minf(real, MAX_STEP)
		last = now
		t += real * Engine.time_scale / maxf(seconds, 0.001)
		apply.call(smooth(t))
	if is_instance_valid(node):
		apply.call(1.0)


## Waits, behind a cover, until frames are drawing evenly again: at least
## LEAST_FRAMES, then SETTLED_FRAMES quick ones in a row, or MOST_WAIT at
## most. Without a screen (the tests) only one frame passes.
static func settle(node: Node) -> void:
	if node == null or not node.is_inside_tree():
		return
	var tree := node.get_tree()
	if DisplayServer.get_name() == "headless":
		await tree.process_frame
		return
	var start := Time.get_ticks_usec()
	var last := start
	var frames := 0
	var quick := 0
	while true:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		frames += 1
		quick = quick + 1 if (now - last) / 1000.0 < SETTLED_MS else 0
		last = now
		if frames >= LEAST_FRAMES and quick >= SETTLED_FRAMES:
			return
		if (now - start) / 1000000.0 >= MOST_WAIT:
			return
