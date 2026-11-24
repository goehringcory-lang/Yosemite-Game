class_name HuffParty
extends RefCounted
## The HUFF crew's secret late-night forest parties: after 10 PM, the seasonal
## employees from HUFF (near Curry Village) haul speakers, dance lights, a
## cooler of cold beer, weed and little squares of paper off-trail into a
## random heavy-forest and boulder pocket somewhere in Yosemite Valley.
##
## Each night picks a different region (never the same two nights running) and
## a random reachable, off-trail heavy-forest / boulder clearing inside it.
## Within the same night, leaving and coming back finds the party in the same
## clearing.

const Terrain := preload("res://scripts/world/terrain.gd")
const FindWalk := preload("res://scripts/story/find_walk.gd")

const MET := "huff_party:met"
## Parties kick off at 10:00 PM (22:00) and run until the 2:00 AM curfew.
const START_HOUR := 22
## Beat tempo in beats per second (120 BPM, matching assets/audio/huff_party.wav).
const BEAT_HZ := 2.0
## Minimum tiles away from any road, trail, paved path, parking lot or camp pad.
const MIN_OFF_TRAIL := 4
## Forest floor terrain kinds eligible for the off-trail party clearing.
const FOREST_KINDS := [Terrain.FOREST, Terrain.FIR, Terrain.SUBALPINE]
const ROCK_KINDS := [Terrain.CLIFF, Terrain.TALUS, Terrain.SCREE, Terrain.GRANITE]
## Keep this far inside map bounds so the party stays away from region seams.
const EDGE_MARGIN := 160.0
## Minimum spacing between distinct candidate party clearings in one region.
const SPOT_GAP := 220.0
const MAX_SPOTS := 12

## Heavy-forest and boulder regions across Yosemite Valley where the HUFF crew
## throws their late-night off-trail parties.
const PARTY_REGIONS: Array[String] = [
	"curry_village",
	"upper_pines",
	"happy_isles",
	"tenaya_creek",
	"mirror_lake",
	"housekeeping_camp",
	"yosemite_village",
	"ahwahnee_trail",
	"ahwahnee_meadow",
	"the_ahwahnee",
	"leidig_meadow",
	"el_capitan_meadow",
	"bridalveil_fall",
	"four_mile_trailhead",
]

const REGION_NAMES := {
	"curry_village": "Curry Village",
	"upper_pines": "Upper Pines",
	"happy_isles": "Happy Isles",
	"tenaya_creek": "Tenaya Creek",
	"mirror_lake": "Mirror Lake",
	"housekeeping_camp": "Housekeeping Camp",
	"yosemite_village": "Yosemite Village",
	"ahwahnee_trail": "Stoneman Meadow",
	"ahwahnee_meadow": "Ahwahnee Meadow",
	"the_ahwahnee": "The Ahwahnee",
	"leidig_meadow": "Leidig Meadow",
	"el_capitan_meadow": "El Capitan Meadow",
	"bridalveil_fall": "Bridalveil Fall",
	"four_mile_trailhead": "Four Mile Trailhead",
}

const CREW_PATHS: Array[String] = [
	"res://data/characters/visitors/huff_rico.tres",
	"res://data/characters/visitors/huff_macy.tres",
	"res://data/characters/visitors/huff_devon.tres",
	"res://data/characters/visitors/huff_tessa.tres",
]

## The day ("year-season-day") you last took LSD at a HUFF party (once a day,
## like Crow).
static var paper_day := ""
## The day you last got a spare cold King Cobra tossed in your pack for the road.
static var beer_day := ""


static func today_key() -> String:
	return "%d-%d-%d" % [GameClock.year, GameClock.season, GameClock.day]


static func has_met() -> bool:
	return MET in QuestLog.heard_beats


## True while the clock is past 10:00 PM (until pass-out at 2:00 AM).
static func is_party_hours(minutes := -1) -> bool:
	var m := GameClock.minutes if minutes < 0 else minutes
	return m >= START_HOUR * 60


## Which region tonight's party is in for a given day number (1-indexed
## sequential day) or ("year-season-day") key. Never repeats the previous
## night's region.
static func party_region_for(year: int, season: int, day: int) -> String:
	var idx := _region_index(year, season, day)
	var prev := _prev_day(year, season, day)
	if prev.x > 0:
		var prev_idx := _region_index(prev.x, prev.y, prev.z)
		if idx == prev_idx:
			idx = (idx + 1) % PARTY_REGIONS.size()
	return PARTY_REGIONS[idx]


static func _region_index(year: int, season: int, day: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("huff_party@%d-%d-%d" % [year, season, day])
	return rng.randi() % PARTY_REGIONS.size()


static func _prev_day(year: int, season: int, day: int) -> Vector3i:
	if day > 1:
		return Vector3i(year, season, day - 1)
	if season > 0:
		return Vector3i(year, season - 1, GameClock.DAYS_PER_SEASON)
	if year > 1:
		return Vector3i(year - 1, 3, GameClock.DAYS_PER_SEASON)
	return Vector3i(0, 0, 0)


## Tonight's party region id (regardless of current hour), for HUFF rumors.
static func tonight_region() -> String:
	return party_region_for(GameClock.year, GameClock.season, GameClock.day)


## The region where a HUFF party is actively happening right now, or "" before
## 10:00 PM.
static func where_now() -> String:
	if not is_party_hours():
		return ""
	return tonight_region()


static func region_label(id: String) -> String:
	return str(REGION_NAMES.get(id, id.replace("_", " ").capitalize()))


## Picks a random off-trail, heavy-forest and boulder clearing in [param region]
## for [param key] (usually the date key). Returns Vector2.INF if none exists.
static func pick_spot(region: Region, key: String) -> Vector2:
	var spots := candidate_spots(region)
	if spots.is_empty():
		return Vector2.INF
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("huff_spot:%s:%s" % [region.region_id, key])
	return spots[rng.randi() % spots.size()]


## Reachable off-trail heavy-forest and boulder spots in [param region], in the
## region's local pixels (cached on the region after first scan).
static func candidate_spots(region: Region) -> Array[Vector2]:
	if region.has_meta("huff_party_spots"):
		var cached: Array[Vector2] = []
		cached.assign(region.get_meta("huff_party_spots"))
		return cached
	var spots := _scan_spots(region)
	region.set_meta("huff_party_spots", spots)
	return spots


## True if [param local_pos] in [param region] is off-trail (at least
## MIN_OFF_TRAIL cells from any road, trail, path, parking or built tile).
static func is_off_trail(region: Region, local_pos: Vector2, min_cells := MIN_OFF_TRAIL) -> bool:
	var ground := region.get_ground()
	if ground == null:
		return true
	var off := _path_distance_cached(region, ground)
	var cell := ground.local_to_map(ground.to_local(region.to_global(local_pos)))
	return int(off.get(cell, 99)) >= min_cells


static func _path_distance_cached(region: Region, ground: TileMapLayer) -> Dictionary:
	if region.has_meta("huff_path_dist"):
		return region.get_meta("huff_path_dist")
	var dist := FindWalk.path_distance(ground)
	region.set_meta("huff_path_dist", dist)
	return dist


static func _scan_spots(region: Region) -> Array[Vector2]:
	var ground := region.get_ground()
	if ground == null:
		return []
	var off := _path_distance_cached(region, ground)
	var grid := WalkGrid.of(region)
	var rocks := Chongo.boulders(region)
	var rock_pts: Array[Vector2] = []
	for r: Node2D in rocks:
		rock_pts.append(region.to_local(r.global_position))
	var tree_pts: Array[Vector2] = []
	for node in region.find_children("*", "Sprite2D", true, false):
		var sp := node as Sprite2D
		if sp.texture == null:
			continue
		var file := sp.texture.resource_path.get_file()
		if file.begins_with("tree_") and not "apple" in file:
			tree_pts.append(region.to_local(sp.global_position))
	var bounds := region.get_bounds().grow(-EDGE_MARGIN)
	var start := FindWalk.start_of(region)
	var start_world := start.global_position if start else Vector2.INF
	var strict := _collect_scored(region, ground, off, grid, bounds, tree_pts, rock_pts, MIN_OFF_TRAIL, 2, true)
	var picked := _pick_spread(region, grid, start_world, strict)
	if not picked.is_empty():
		return picked
	# Fallback: slightly gentler tree/boulder count while still off-trail forest.
	var relaxed := _collect_scored(region, ground, off, grid, bounds, tree_pts, rock_pts, MIN_OFF_TRAIL, 1, false)
	picked = _pick_spread(region, grid, start_world, relaxed)
	if not picked.is_empty():
		return picked
	var widest := _collect_scored(region, ground, off, grid, bounds, tree_pts, rock_pts, 3, 0, false)
	return _pick_spread(region, grid, start_world, widest)


static func _collect_scored(region: Region, ground: TileMapLayer, off: Dictionary, grid: WalkGrid,
		bounds: Rect2, tree_pts: Array[Vector2], rock_pts: Array[Vector2],
		min_off: int, min_trees: int, need_rock: bool) -> Array:
	var scored: Array = []
	var huff_center := Vector2(2916.0, 616.0)
	var apron := region.get_spawn("apron_trailhead")
	var apron_local := region.to_local(apron.global_position) if apron else Vector2.INF
	for cell: Vector2i in ground.get_used_cells():
		# Stride by 2 cells for speed (~64px spacing).
		if (cell.x & 1) != 0 or (cell.y & 1) != 0:
			continue
		if ground.get_cell_source_id(cell) != FindWalk.SOURCE_TERRAIN:
			continue
		var kind := ground.get_cell_atlas_coords(cell).y
		if not kind in FOREST_KINDS:
			continue
		var d: int = off.get(cell, 99)
		if d < min_off:
			continue
		var local_pos := region.to_local(ground.to_global(ground.map_to_local(cell)))
		if not bounds.has_point(local_pos):
			continue
		if region.region_id == "curry_village":
			if local_pos.distance_to(huff_center) < 280.0:
				continue
			if apron_local != Vector2.INF and local_pos.distance_to(apron_local) < 180.0:
				continue
		var world_pos := region.to_global(local_pos)
		if not _has_room(grid, world_pos):
			continue
		var near_trees := 0
		for tp: Vector2 in tree_pts:
			if tp.distance_squared_to(local_pos) <= 220.0 * 220.0:
				near_trees += 1
		if near_trees < min_trees:
			continue
		var near_rocks := 0
		for rp: Vector2 in rock_pts:
			if rp.distance_squared_to(local_pos) <= 260.0 * 260.0:
				near_rocks += 1
		var near_talus := _near_rock_tiles(ground, cell)
		if need_rock and near_rocks == 0 and near_talus == 0:
			continue
		var score := float(mini(d, 12)) * 5.0 + float(mini(near_trees, 12)) * 3.0 \
			+ float(mini(near_rocks, 6)) * 12.0 + float(mini(near_talus, 8)) * 2.5
		scored.append([score, local_pos])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	return scored


static func _near_rock_tiles(ground: TileMapLayer, cell: Vector2i) -> int:
	var count := 0
	for dy in range(-5, 6, 2):
		for dx in range(-5, 6, 2):
			var c := cell + Vector2i(dx, dy)
			if ground.get_cell_source_id(c) == FindWalk.SOURCE_TERRAIN \
					and ground.get_cell_atlas_coords(c).y in ROCK_KINDS:
				count += 1
	return count


static func _has_room(grid: WalkGrid, world_pos: Vector2) -> bool:
	for delta: Vector2 in [Vector2.ZERO, Vector2(36, 0), Vector2(-36, 0), Vector2(0, 32), Vector2(0, -24)]:
		if not grid.is_open(world_pos + delta):
			return false
	return true


static func _pick_spread(region: Region, grid: WalkGrid, start_world: Vector2, scored: Array) -> Array[Vector2]:
	var picked: Array[Vector2] = []
	for item: Array in scored:
		if picked.size() >= MAX_SPOTS:
			break
		var pos: Vector2 = item[1]
		if picked.any(func(other: Vector2) -> bool: return other.distance_to(pos) < SPOT_GAP):
			continue
		if start_world != Vector2.INF and grid.route(start_world, region.to_global(pos)).is_empty():
			continue
		picked.append(pos)
	return picked
