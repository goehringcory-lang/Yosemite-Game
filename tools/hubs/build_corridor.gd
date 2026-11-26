extends "res://tools/hubs/build_outer_hub.gd"
## Builds corridor areas: a stretch of trail or road between two areas of
## the park, joined to them by ordinary seams at its ends, so the walk
## between them streams on with no trip map (docs/STREAMING.md). Each
## corridor is a spec, tools/hubs/corridors/<id>.json:
##
##   {
##     "id": "pohono_trail_east", "name": "Pohono Trail", "hub": "glacier_point",
##     "geo": [-119.585, 37.718],          # lon, lat of its middle
##     "size": [64, 36],                   # tiles (16 px; doubled on the 32px grid)
##     "seed": 1915,
##     "ground": "fir",                    # forest | fir | subalpine | granite | meadow | foothill
##     "way": "trail",                     # trail | road
##     "walk_minutes": 40,                 # clock time walking it end to end
##     "ends": [
##       {"side": "west", "at": 18, "label": "Taft Point",
##        "target_region": "taft_point", "target_spawn": "east"},
##       {"side": "east", "at": 20, "label": "Glacier Point",
##        "target_region": "glacier_point", "target_spawn": "pohono_west"}
##     ],
##     "clearings": [[30, 12, 6, 4, "meadow"]],   # optional: x, y, rx, ry, ground
##     "signs": [[32, 17, "Sentinel Dome Junction", "Text..."]]   # optional
##   }
##
## Each end gets a walking RegionExit on its map edge ("To" + the target
## region, minutes 0) at "at" tiles along that edge, and a marker named for
## the side ("west", "east", "north", "south") just inside it: point the
## neighbor's exit's target_spawn at that marker, and put the neighbor's exit
## on its facing edge, and the seam lines up. The way winds from end to end.
##
## Run tools/hubs/rebuild_corridors.sh <id>... (this builder, the 32px
## migration, native ground paint, wild dressing, normal maps, re-import);
## tests/stream_test then checks both ends meet their neighbors edge to edge.
##
##   godot --headless --path . res://tools/hubs/build_corridor.tscn -- <id>...
##
## CORRIDOR_SPECS=<dir> reads the specs from another folder (res:// or an
## absolute path), for trying one out.

const SPECS := "res://tools/hubs/corridors/"
const GROUNDS := {
	"forest": Terrain.FOREST, "fir": Terrain.FIR, "subalpine": Terrain.SUBALPINE,
	"granite": Terrain.GRANITE, "meadow": Terrain.MEADOW, "foothill": Terrain.FOOTHILL,
}
const SIDES := ["west", "east", "north", "south"]


func _ready() -> void:
	var ids := OS.get_cmdline_user_args()
	if ids.is_empty():
		push_error("build_corridor: name the corridors to build, after --")
		get_tree().quit(1)
		return
	load_flora()
	import_assets()
	var failed := 0
	for id in ids:
		var spec := _read_spec(id)
		if spec.is_empty():
			failed += 1
			continue
		print("== Corridor ", id)
		_corridor(spec)
	print("Done")
	get_tree().quit(failed)


func _read_spec(id: String) -> Dictionary:
	var dir := OS.get_environment("CORRIDOR_SPECS")
	if dir == "":
		dir = SPECS
	var path := dir.path_join(id + ".json")
	if not FileAccess.file_exists(path):
		push_error("build_corridor: no spec at %s" % path)
		return {}
	var spec = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not spec is Dictionary:
		push_error("build_corridor: %s isn't a JSON object" % path)
		return {}
	var problems := check_spec(spec)
	for p in problems:
		push_error("build_corridor %s: %s" % [id, p])
	return {} if not problems.is_empty() else spec


## What's wrong with [param spec], if anything (empty when it can be built).
static func check_spec(spec: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key in ["id", "name", "hub", "geo", "size", "ends", "walk_minutes"]:
		if not spec.has(key):
			problems.append("missing \"%s\"" % key)
	if not problems.is_empty():
		return problems
	var size: Array = spec.size
	if size.size() != 2 or int(size[0]) < 32 or int(size[1]) < 24:
		problems.append("size must be [w, h], at least [32, 24] tiles")
	if str(spec.get("ground", "forest")) not in GROUNDS:
		problems.append("ground must be one of %s" % [GROUNDS.keys()])
	var ends: Array = spec.ends
	if ends.size() < 2:
		problems.append("a corridor needs two ends (or more)")
	for end in ends:
		if not end is Dictionary or str(end.get("side", "")) not in SIDES or not end.has("at") \
				or str(end.get("target_region", "")) == "" or str(end.get("target_spawn", "")) == "":
			problems.append("each end needs side (%s), at, target_region and target_spawn" % [SIDES])
			continue
		var along := int(size[1]) if end.side in ["west", "east"] else int(size[0])
		if int(end.at) < 3 or int(end.at) > along - 4:
			problems.append("end %s at %d is too near a corner (3..%d)" % [end.side, int(end.at), along - 4])
	if int(spec.walk_minutes) < 0:
		problems.append("walk_minutes can't be negative")
	return problems


## Where end [param end] meets the map edge, and the spot just inside it, in
## tiles: [edge point, inside point].
func _end_points(end: Dictionary) -> Array[Vector2]:
	var at := float(end.at)
	match str(end.side):
		"west": return [Vector2(-1, at), Vector2(2, at)]
		"east": return [Vector2(w, at), Vector2(w - 3, at)]
		"north": return [Vector2(at, -1), Vector2(at, 2)]
	return [Vector2(at, h), Vector2(at, h - 3)]


func _corridor(spec: Dictionary) -> void:
	var id: String = spec.id
	var seed_value := int(spec.get("seed", hash(id) % 100000))
	var ground: int = GROUNDS[str(spec.get("ground", "forest"))]
	init_grid(int(spec.size[0]), int(spec.size[1]), ground)
	rng.seed = seed_value
	noise.seed = seed_value
	noise.frequency = 0.08
	for c: Array in spec.get("clearings", []):
		_ellipse(float(c[0]), float(c[1]), float(c[2]), float(c[3]), GROUNDS.get(str(c[4]) if c.size() > 4 else "meadow", Terrain.MEADOW), 0.3)
	var way := Terrain.ROAD if str(spec.get("way", "trail")) == "road" else Terrain.TRAIL
	var width := 2 if way == Terrain.ROAD else 1
	# The way winds from the first end through the middle to each other end.
	var ends: Array = spec.ends
	var middle := Vector2(w / 2.0, h / 2.0)
	var first := _end_points(ends[0])
	for i in range(1, ends.size()):
		var other := _end_points(ends[i])
		var points: Array = [first[0], first[1]]
		points.append_array(_wander(first[1], middle if ends.size() > 2 else other[1], 3))
		if ends.size() > 2:
			points.append_array(_wander(middle, other[1], 2))
		points.append(other[1])
		points.append(other[0])
		_path(points, width, way, 0.35 if way == Terrain.TRAIL else 0.0)
	_mark_open()
	for end in ends:
		var p := _end_points(end)[1]
		clear_trees(int(p.x) - 3, int(p.y) - 3, int(p.x) + 3, int(p.y) + 3)

	start_region(_node_name(id), id, str(spec.name), Vector2(float(spec.geo[0]), float(spec.geo[1])))
	_root.hub_id = str(spec.hub)
	_root.walk_minutes = int(spec.walk_minutes)
	paint_ground()
	_save_ground_art("ground_" + id, seed_value)
	for s: Array in spec.get("signs", []):
		_info_sign(_node_name(str(s[2])) + "Sign", foot(float(s[0]), float(s[1])), str(s[2]), str(s[3]))
	_dress_corridor(ground)
	marker("arrival", middle.x, middle.y)
	for end in ends:
		var inside := _end_points(end)[1]
		marker(str(end.side), inside.x, inside.y)
		var at := float(end.at)
		var tile_at: Vector2
		var size: Vector2
		match str(end.side):
			"west":
				tile_at = Vector2(-0.5, at)
				size = Vector2(12, 48)
			"east":
				tile_at = Vector2(w - 0.5, at)
				size = Vector2(12, 48)
			"north":
				tile_at = Vector2(at, -0.5)
				size = Vector2(48, 12)
			_:
				tile_at = Vector2(at, h - 0.5)
				size = Vector2(48, 12)
		region_exit("To" + _node_name(str(end.target_region)), tile_pos(tile_at.x, tile_at.y), size,
				str(end.get("label", end.target_region)), str(end.target_region), str(end.target_spawn))
	place(str(spec.name), middle.x, middle.y, minf(w, h) / 2.0)
	_finish(id, 1.0)


## A few points from [param a] to [param b], pushed sideways a little so the
## way winds instead of running dead straight.
func _wander(a: Vector2, b: Vector2, bends: int) -> Array:
	var points := []
	var across := (b - a).orthogonal().normalized()
	for i in range(1, bends + 1):
		var t := float(i) / (bends + 1)
		var p := a.lerp(b, t) + across * rng.randf_range(-3.0, 3.0)
		points.append(p.clamp(Vector2(3, 3), Vector2(w - 4, h - 4)))
	return points


## Trees and plants for the corridor's ground, as the areas round it.
func _dress_corridor(ground: int) -> void:
	_reserve_entities(1, 3)
	var all := Rect2i(0, 0, w, h)
	match ground:
		Terrain.FIR, Terrain.SUBALPINE:
			_fringe_trees([ground], 2, 0.55, [["tree_white_fir", 4.0], ["tree_lodgepole", 2.0], ["tree_snag", 0.35]], 1, 20.0)
			_fringe_trees([Terrain.GRANITE], 7, 0.16, [["tree_lodgepole", 1.0]], 0, 42.0)
			_scatter_decor("plant_manzanita", [Terrain.GRANITE, ground], 18, all, 1)
			_scatter_decor("plant_shrub", [ground], 16, all, 2)
			_scatter_decor("plant_lupine", [Terrain.MEADOW, ground], 12, all, 1)
			_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 16, all, 1)
			_scatter_decor("plant_tall_grass", [Terrain.MEADOW], 18, all, 0)
			_scatter_decor("rock_granite", [Terrain.GRANITE, ground], 24, all, 1)
			_scatter_decor("log_fallen", [ground], 10, all, 2)
			_scatter_decor("log_stump", [ground], 5, all, 2)
		Terrain.GRANITE:
			_fringe_trees([Terrain.GRANITE], 6, 0.2, [["tree_lodgepole", 1.5], ["tree_white_fir", 1.0]], 0, 40.0)
			_scatter_decor("rock_granite", [Terrain.GRANITE], 40, all, 1)
			_scatter_decor("plant_manzanita", [Terrain.GRANITE], 20, all, 1)
		_:
			_dress(40, 50)


static func _node_name(text: String) -> String:
	var out := ""
	for word in text.replace("-", " ").replace("_", " ").replace("'", "").split(" ", false):
		out += word.capitalize().replace(" ", "")
	return out
