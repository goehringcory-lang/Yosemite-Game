extends Node
## Climbing v2 route tools (thread 2, wall and routes).
##
##   godot --headless --path . res://tools/climb_v2/convert_routes.tscn -- draft
##       Writes an automatic plan (from the old ClimbProfiles spec) for every
##       route that has no data/climb/v2/routes/<id>.json yet: a first draft
##       to edit by hand. Never overwrites an existing file.
##   godot --headless --path . res://tools/climb_v2/convert_routes.tscn -- dump <dir>
##       Builds every pitch of every route and writes <dir>/<id>_p<n>.json
##       (V2Wall.to_dict) plus <dir>/report.txt (checks, runouts, counts), for
##       tools/climb_v2/topo.py to draw.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "dump"
	var routes := _routes()
	if mode == "draft":
		for route in routes:
			var path := WallPlan.DIR + route.id + ".json"
			if FileAccess.file_exists(path):
				print("keep  ", path)
				continue
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(JSON.stringify(WallPlan.auto(route), "\t", false) + "\n")
			print("wrote ", path)
	else:
		var dir := args[1] if args.size() > 1 else "user://climb_v2_walls"
		DirAccess.make_dir_recursive_absolute(dir)
		var report := PackedStringArray()
		for route in routes:
			var src := RouteWall.new()
			for i in src.pitch_count(route):
				var w := RouteWall.build(route, i)
				var f := FileAccess.open("%s/%s_p%d.json" % [dir, route.id, i + 1], FileAccess.WRITE)
				f.store_string(JSON.stringify(w.to_dict()))
				var hands := 0
				for h in w.holds:
					if h.hand:
						hands += 1
				var probs := WallCheck.problems(w)
				report.append("%-24s p%d  %5.1f m  %3d hand holds  %2d cracks  %2d fixed  %d cruxes  path %2d moves  runout %.1f m  %s" % [
					route.id, i + 1, w.top.y, hands, w.cracks.size(), w.fixed.size(),
					w.zones.filter(func(z: V2Zone) -> bool: return z.kind == &"crux").size(),
					WallCheck.climb_path(w).size(), WallCheck.longest_runout(w),
					"ok" if probs.is_empty() else "; ".join(probs)])
		var f := FileAccess.open(dir + "/report.txt", FileAccess.WRITE)
		f.store_string("\n".join(report) + "\n")
		print("\n".join(report))
	get_tree().quit()


func _routes() -> Array[RouteData]:
	var out: Array[RouteData] = []
	for file in DirAccess.get_files_at("res://data/routes"):
		if file.ends_with(".tres"):
			out.append(load("res://data/routes/" + file))
	return out
