extends "res://tests/climb_v2_cruxes_test.gd"
## Saves screenshots of climbing v2's cruxes and specials (thread 8) on the
## real v2 screen, using the test pitches. Needs a window (not --headless).
##   SHOT_SPECIAL  sidepull | dyno | swing | nail | chimney | haul (default swing)
##   SHOT_OUT      the PNG (default user://climb_v2_<special>.png)
## Run: SHOT_SPECIAL=nail xvfb-run -a godot --path . res://tools/shots/climb_v2_crux_shot.tscn


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _ready() -> void:
	ClimbSystems.pin_stubs_except([&"cruxes"])
	var kind := _env("SHOT_SPECIAL", "swing")
	var pitch: Dictionary = {"sidepull": sidepull_pitch(), "dyno": dyno_pitch(), "swing": swing_pitch(),
		"nail": nail_pitch(), "chimney": chimney_pitch("chimney"), "haul": ladder(10.0)}.get(kind, swing_pitch())
	var r := route("crux_shot", 3, 1 if kind == "haul" else 0)
	var screen: ClimbScreenV2 = load("res://scenes/climb/climb_screen_v2.tscn").instantiate()
	screen.setup(r, 3, V2Modifiers.new(), V2Rack.new())
	add_child(screen)
	await get_tree().process_frame
	var d := screen.director
	var w := TestWall.new()
	w.pitches = [pitch, pitch, pitch]
	w.attach(d.session)
	d.session.sys.wall = w
	d.next_pitch()
	d.go(&"climb")
	d.session.notes[&"cruxes"]["bag"] = true
	match kind:
		"sidepull":
			climb_to(d, 4.6)
			if d.session.pose.next_hand != &"rh":
				d.session.sys.body.swap_hand()
			d.session.bus.send(&"move_previewed", [d.preview("sp")])
		"dyno":
			climb_to(d, 5.2)
			d.session.bus.send(&"move_previewed", [d.preview("dyno_jug")])
		"swing":
			climb_to(d, 6.5)
			var ph := d.current as CruxSpecialPhase
			ph.do_option(ph.options()[1])
			ph.do_option(swing_bot(ph))
			ph.do_option(swing_bot(ph))
		"nail":
			climb_to(d, 5.2)
			var ph := d.current as CruxSpecialPhase
			for i in 6:
				ph.do_option(nail_bot(ph))
		"chimney":
			climb_to(d, 5.0)
			var ph := d.current as CruxSpecialPhase
			for i in 4:
				ph.do_option(worm_bot(ph))
		"haul":
			climb_to(d, 10.5, 80)
			var ph := d.current as CruxSpecialPhase
			if ph:
				ph.do_option(ph.options()[0])
	screen.climber.show_pose(d.session.pose)
	for i in 60:
		await get_tree().process_frame
	var path := _env("SHOT_OUT", "user://climb_v2_%s.png" % kind)
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path), " phase ", d.session.phase)
	ClimbSystems.pins.clear()
	get_tree().quit()
