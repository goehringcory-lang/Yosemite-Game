extends Node
## Times ClimbScenes.paint_base / paint_finish for every route (headless is fine).
## Run: godot --headless --path . res://tools/shots/scene_time.tscn


func _ready() -> void:
	var pal := ClimbSky.palette(19.0)
	for id in ["firefall_slab", "swan_slab", "glacier_point_apron", "nutcracker", "higher_cathedral_spire", "steck_salathe", "astroman", "separate_reality", "the_nose", "royal_arches", "snake_dike", "cathedral_peak", "lyell_glacier"]:
		var route: RouteData = load("res://data/routes/%s.tres" % id)
		var prof := ClimbProfiles.get_profile(id)
		var kit := {"quickdraw": 6, "cam": 6, "climbing_shoes": 1}
		var state := ClimbState.new(route, 6, 4, kit)
		state._start_pitch()
		var wall := ClimbRock.paint(state, prof.get("rock", "apron"), pal, 1234)
		var t0 := Time.get_ticks_usec()
		ClimbScenes.paint_base(wall.image, prof.get("ground", ""), state, pal, wall.edge, hash(id))
		var t1 := Time.get_ticks_usec()
		var last := ClimbState.new(route, 6, 4, kit)
		last.pitch = route.pitches.size() - 1
		last._start_pitch()
		var wall2 := ClimbRock.paint(last, prof.get("rock", "apron"), pal, 1234)
		var t2 := Time.get_ticks_usec()
		ClimbScenes.paint_finish(wall2.image, prof.get("finish", ""), last, pal, wall2.edge, hash(id))
		var t3 := Time.get_ticks_usec()
		print("%s base %s %.1f ms, finish %s %.1f ms" % [id, prof.get("ground", ""), (t1 - t0) / 1000.0, prof.get("finish", ""), (t3 - t2) / 1000.0])
	get_tree().quit()
