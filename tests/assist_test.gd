extends Node
## Headless test of the assist settings (Settings.timing and
## Settings.hold_taps): that they save and load, and that Relaxed and Gentle
## timing slow the marker and widen the green on every timed activity: the
## climbing cruxes (and the swing, the layback, the piton and the haul), the cast and the fish, the Half Dome cables, and the
## trail crew's rock bar. Standard leaves each one as designed. The pause
## menu's rows are in tests/settings_test.gd, and holding instead of tapping
## on a crux is in tests/climb_screen_test.gd.
## Run: godot --headless --path . res://tests/assist_test.tscn
## Exit code is the number of failed checks. Uses its own settings file.

const TEST_PATH := "user://assist_test.cfg"

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	Settings.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Settings.load_settings()
	test_settings()
	test_climbing()
	test_fishing()
	test_cables()
	test_rock_work()
	Settings.reset_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_settings() -> void:
	check(Settings.timing == Settings.Timing.STANDARD and not Settings.hold_taps, "the assists are off by default")
	check(Settings.pace() == 1.0 and Settings.room() == 1.0, "Standard timing changes nothing")
	Settings.timing = Settings.Timing.GENTLE
	Settings.hold_taps = true
	check(Settings.save() == OK, "the assists save")
	Settings.reset_defaults()
	check(Settings.timing == Settings.Timing.STANDARD and not Settings.hold_taps, "reset turns them off")
	Settings.load_settings()
	check(Settings.timing == Settings.Timing.GENTLE and Settings.hold_taps, "and they load back")
	check(Settings.pace() < 1.0 and Settings.room() > 1.0, "Gentle is slower with more room")
	Settings.timing = Settings.Timing.RELAXED
	check(Settings.pace() < 1.0 and Settings.pace() > Settings.TIMING_PACE[Settings.Timing.GENTLE]
		and Settings.room() > 1.0 and Settings.room() < Settings.TIMING_ROOM[Settings.Timing.GENTLE], "Relaxed sits between Standard and Gentle")
	var config := ConfigFile.new()
	config.set_value("assist", "timing", 99)
	config.save(TEST_PATH)
	Settings.load_settings()
	check(Settings.timing == Settings.Timing.GENTLE, "a bad timing value in the file is clamped")
	Settings.reset_defaults()


## Runs [param measure] at Standard, Relaxed and Gentle timing and returns
## the three results.
func _at_each(measure: Callable) -> Array:
	var out := []
	for level in Settings.Timing.size():
		Settings.timing = level as Settings.Timing
		out.append(measure.call())
	Settings.timing = Settings.Timing.STANDARD
	return out


func _rising(values: Array) -> bool:
	return values[0] < values[1] and values[1] < values[2]


func _falling(values: Array) -> bool:
	return values[0] > values[1] and values[1] > values[2]


func test_climbing() -> void:
	var nose: RouteData = load("res://data/routes/the_nose.tres")
	var state := ClimbState.new(nose, 10, 1, {"climbing_shoes": 1})
	var windows := _at_each(state.crux_window)
	var speeds := _at_each(state.crux_speed)
	check(_rising(windows), "a crux's green widens with the timing (%.2f, %.2f, %.2f)" % windows)
	check(_falling(speeds), "and its marker slows (%.2f, %.2f, %.2f)" % speeds)
	check(is_equal_approx(windows[2], windows[0] * Settings.TIMING_ROOM[2]), "Gentle widens the green by its share")
	check(_rising(_at_each(state.crux_seconds.bind("mash"))) and _rising(_at_each(state.crux_seconds.bind("rhythm"))),
		"the quick-tap and left-right cruxes give more time")
	# The longer checks (ClimbCheck) get the same help.
	var check_of := func(kind: String) -> ClimbCheck:
		state.pending = {"kind": kind, "name": kind}
		var made := state.make_check()
		state.pending = {}
		return made
	check(_rising(_at_each(func() -> float: return check_of.call("swing").window)) and _falling(_at_each(func() -> float: return check_of.call("swing").pace)),
		"the King Swing's green widens and the swing slows")
	check(_rising(_at_each(func() -> float: return check_of.call("layback").window)) and _falling(_at_each(func() -> float: return check_of.call("layback").pace)),
		"a layback's green widens and the tension slows")
	check(_rising(_at_each(func() -> float: return check_of.call("nail").window)) and _falling(_at_each(func() -> float: return check_of.call("nail").swing_speed)),
		"a piton's green widens and the hammer slows")
	check(_rising(_at_each(func() -> float: return check_of.call("haul").good_seconds)) and _rising(_at_each(func() -> float: return check_of.call("haul").time_total)),
		"hauling the bag gives you longer")
	# Slowed down, a swing takes longer in real time, but never runs out
	# sooner for it: a patient swing that makes it on Standard makes it on Gentle.
	var swung := _at_each(func() -> String:
		var s: SwingCheck = check_of.call("swing")
		var t := 0.0
		while not s.is_done() and t < 60.0:
			var held := {}
			if s.angle >= s.green_from() + s.window * 0.2 and absf(s.speed) < 0.15:
				s.press("tool")
			elif s.amplitude() < SwingCheck.TARGET + 0.02:
				held = {"right": s.speed >= 0.0, "left": s.speed < 0.0}
			s.step(1.0 / 60.0, held)
			t += 1.0 / 60.0
		return s.result)
	check(swung.all(func(r: String) -> bool: return r in ["perfect", "good"]), "a patient swing makes it at every timing (%s)" % [swung])
	var swan: RouteData = load("res://data/routes/swan_slab.tres")
	var easy := ClimbState.new(swan, 0, 1, {"climbing_shoes": 1})
	easy.chalk_moves = 5
	Settings.timing = Settings.Timing.GENTLE
	check(easy.crux_window() <= ClimbState.ASSIST_MAX_WINDOW, "the widest green still fits on the bar (%.2f)" % easy.crux_window())
	Settings.timing = Settings.Timing.STANDARD


func _fishing() -> FishingMinigame:
	var game := FishingMinigame.new()
	add_child(game)
	game.set_process(false)
	game.start(Fishing.get_fish("brown_trout"), 5, {})
	return game


func test_fishing() -> void:
	var game := _fishing()
	check(_rising(_at_each(game.window)), "the cast's green widens with the timing")
	# how far the marker sweeps in a tenth of a second once the meter opens
	var sweep := func() -> float:
		var cast := _fishing()
		cast.step(FishingMinigame.UNROLL + 0.01, false)
		var from := cast.meter_pos
		cast.step(0.1, false)
		var moved := cast.meter_pos - from
		cast.queue_free()
		return moved
	var sweeps := _at_each(sweep)
	check(_falling(sweeps) and sweeps[2] > 0.0, "and its marker slows (%.3f, %.3f, %.3f)" % sweeps)
	# how far a hooked fish swims toward a far depth in a tenth of a second
	var swim := func() -> float:
		var reel := _fishing()
		reel._retarget = 9.0
		reel.fish_at = 0.1
		reel._target = 0.9
		reel._move_fish(0.1)
		var moved := reel.fish_at - 0.1
		reel.queue_free()
		return moved
	var swims := _at_each(swim)
	check(_falling(swims) and swims[2] > 0.0, "the fish on the line swims slower (%.3f, %.3f, %.3f)" % swims)
	game.queue_free()


func test_cables() -> void:
	var game := CablesMinigame.new()
	add_child(game)
	game.set_process(false)
	game.start("crowded", 7)
	check(_rising(_at_each(game.window)), "the cables' green widens with the timing")
	var sweep := func() -> float:
		game.start("crowded", 7)
		game.step(CablesMinigame.GRACE + 0.01)
		var from := game.meter_pos
		game.step(0.1)
		return game.meter_pos - from
	var sweeps := _at_each(sweep)
	check(_falling(sweeps) and sweeps[2] > 0.0, "and the marker slows (%.3f, %.3f, %.3f)" % sweeps)
	Settings.timing = Settings.Timing.GENTLE
	game.start("dawn", 7)
	var half := game.window() / 2.0
	check(game.meter_center - half >= 0.0 and game.meter_center + half <= 1.0, "the widest green at dawn still fits on the bar")
	check(game.judge(game.meter_center + half * 0.9) == "good" and game.judge(game.meter_center + half * 1.1) == "miss", "the wider green is what a stop is judged by")
	Settings.timing = Settings.Timing.STANDARD
	game.queue_free()


func test_rock_work() -> void:
	var game := RockWork.new()
	add_child(game)
	game.set_process(false)
	game.start(7)
	check(is_equal_approx(game.window(), RockWork.WINDOW), "the rock bar's green is as designed at Standard")
	check(_rising(_at_each(game.window)), "and widens with the timing")
	var sweep := func() -> float:
		game.start(7)
		game.step(RockWork.GRACE + 0.01)
		var from := game.meter_pos
		game.step(0.1)
		return game.meter_pos - from
	var sweeps := _at_each(sweep)
	check(_falling(sweeps) and sweeps[2] > 0.0, "and the marker slows (%.3f, %.3f, %.3f)" % sweeps)
	Settings.timing = Settings.Timing.GENTLE
	game.start(7)
	var half := game.window() / 2.0
	check(game.judge(game.meter_center + half * 0.9) == "good" and game.judge(game.meter_center + half * 1.1) == "miss", "the wider green is what a heave is judged by")
	Settings.timing = Settings.Timing.STANDARD
	game.queue_free()
