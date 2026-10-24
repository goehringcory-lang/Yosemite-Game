extends Node
## Saves screenshots of Glacier Point's viewers (scripts/ui/binocular_view.gd)
## at a few bearings, hours and powers. Needs a window (not --headless).
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/binocular_shot.tscn
##   SHOT_ONLY=half_dome ...   (one shot)

## name, bearing, hour, zoom index, tilt, season
const SHOTS := [
	["half_dome", 65.0, 11.0, 0, 0.0, GameClock.Season.SUMMER],
	["half_dome_16x", 65.0, 11.0, 1, NAN, GameClock.Season.SUMMER],
	["yosemite_falls", 330.0, 15.0, 0, 0.0, GameClock.Season.SPRING],
	["el_capitan_dusk", 272.0, 19.0, 0, 0.0, GameClock.Season.SUMMER],
	["falls_sunrise", 100.0, 6.6, 0, 0.0, GameClock.Season.SUMMER],
	["curry_village", 9.0, 13.0, 0, 0.72, GameClock.Season.SUMMER],
	["night", 65.0, 22.5, 0, 0.0, GameClock.Season.SUMMER],
	["first_look", 65.0, 11.0, 0, 0.0, GameClock.Season.SUMMER],
]


func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var only := OS.get_environment("SHOT_ONLY")
	for shot: Array in SHOTS:
		if only != "" and shot[0] != only:
			continue
		GameClock.season = shot[5]
		GameClock.day = 10
		GameClock.minutes = int(shot[2] * 60.0)
		# the last shot is a first visit: nothing named yet, mid-lock
		Park.spotted_peaks.clear()
		if shot[0] != "first_look":
			for t: Dictionary in BinocularView.VIEWS.glacier_point.targets:
				Park.spotted_peaks[t.id] = true
			Park.spotted_peaks.erase("mt_clark")
			Park.spotted_peaks.erase("basket_dome")
		var view := BinocularView.new()
		view.setup("glacier_point", shot[1])
		add_child(view)
		view.tilt = 0.0 if is_nan(shot[4]) else shot[4]
		await get_tree().create_timer(0.3).timeout
		while not view._ready_to_draw:
			await get_tree().process_frame
		if shot[3] > 0:
			await get_tree().create_timer(1.0).timeout
			view._set_zoom(shot[3])
		var wait := 2.2 if shot[0] != "first_look" else 1.2
		await get_tree().create_timer(wait).timeout
		if shot[0] == "first_look":
			Park.spotted_peaks.erase("half_dome")
			view._lock = 0.3
		await get_tree().process_frame
		await get_tree().process_frame
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/binoculars_%s.png" % [dir, shot[0]])
		view.queue_free()
		await get_tree().process_frame
	get_tree().quit()
