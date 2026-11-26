extends Node
## What the park map knows: the fog of war over the Park map, the areas
## you've walked into, the stamps you've put down, and the one thing you're
## following (the tracked target, see Tracker).
##
## The Park map (ParkMap) starts as a plain parchment brochure: the shape of
## the land is there, faintly, and the rest fills in as you go. Walking
## outdoors clears the map around you (WALK_RADIUS), each new area clears
## around its middle (ARRIVE_RADIUS), a drive or a long trail clears a thin
## ribbon along the road, and a high lookout clears the country all around it
## (LOOKOUT_RADIUS), the way a tower does in an open-world game. Vistas can
## clear more with reveal(). The first time you reach an outdoor area its
## name comes up across the screen (HUD.show_arrival).
##
## Seen cells are one byte per pixel of res://assets/map/park_map.png
## (about 330 m), saved packed. A save from before the fog has its map
## cleared around the areas it had already discovered (seed_from_discoveries).
##
## Area positions and exits come from res://data/park/regions.json, written
## by tools/map/list_regions.tscn. An area missing from it is still recorded
## when you visit it.

signal changed
## The first time an outdoor area is walked into: {id, name, hub, subtitle}.
signal first_visit(info: Dictionary)
signal tracked_changed

const REGIONS_DATA := "res://data/park/regions.json"
## The Park map picture the fog covers, pixel for pixel.
const SIZE := Vector2i(200, 256)
const WALK_RADIUS := 450.0
const ARRIVE_RADIUS := 800.0
const LOOKOUT_RADIUS := 6500.0
const ROAD_RADIUS := 300.0
## Areas further apart than this (meters) were reached by a trip, not a
## step across a seam: the road between them is cleared too.
const TRIP_GAP := 1600.0
## Seconds between looks at where the player is.
const POLL := 0.25
const MAX_STAMPS := 24
## The stamps you can put on the map, in the picker's order.
const STAMPS := ["star", "tent", "fish", "flower", "climb"]
const STAMP_NAMES := {"star": "Star", "tent": "Campsite", "fish": "Fishing spot", "flower": "Wildflowers", "climb": "Climb"}

## One byte per map pixel: 1 seen, 0 not.
var _seen := PackedByteArray()
## Outdoor areas walked into: id -> {name, hub, lonlat: [lon, lat]}.
var visited: Dictionary = {}
## Stamps on the map: {kind, lonlat: [lon, lat]}.
var stamps: Array[Dictionary] = []
## What the Tracker points at, or {}: {kind ("stamp", "area", "hub",
## "quest", "trailhead"), id, label, lonlat: [lon, lat], region (may be "")}.
var tracked: Dictionary = {}
## Goes up each time more of the map is seen, so the map knows to redraw.
var version := 0
## False while a test or a tool wants the fog left alone.
var watching := true

## id -> {id, name, hub, indoors, lonlat, exits, exit_points}, from REGIONS_DATA.
var _regions: Dictionary = {}
var _wait := 0.0
var _last_region := ""
var _last_lonlat := Vector2.INF
var _seed_pending := false


func _ready() -> void:
	add_to_group("persist")
	_seen.resize(SIZE.x * SIZE.y)
	_load_regions()


func start_new_game() -> void:
	_seen.fill(0)
	visited.clear()
	stamps.clear()
	tracked = {}
	_last_region = ""
	_last_lonlat = Vector2.INF
	_seed_pending = false
	version += 1
	changed.emit()
	tracked_changed.emit()


# ---------------------------------------------------------------- the fog

## Is the map pixel [param cell] seen?
func is_seen(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= SIZE.x or cell.y >= SIZE.y:
		return false
	return _seen[cell.y * SIZE.x + cell.x] != 0


## Is this longitude/latitude on the seen part of the map?
func is_seen_at(lonlat: Vector2) -> bool:
	return is_seen(Vector2i(to_cell(lonlat).floor()))


## How much of the park map is seen, 0..1.
func seen_fraction() -> float:
	return float(_seen.count(1)) / float(_seen.size())


## The map pixel (fractional) for a longitude/latitude.
static func to_cell(lonlat: Vector2) -> Vector2:
	return ParkAtlas.geo_to_map(lonlat, Vector2(SIZE))


## Meters one map pixel covers, east-west and north-south (about 330 m).
static func meters_per_cell() -> Vector2:
	var mpd := ParkAtlas.meters_per_degree((ParkAtlas.MAP_NORTH + ParkAtlas.MAP_SOUTH) / 2.0)
	return Vector2((ParkAtlas.MAP_EAST - ParkAtlas.MAP_WEST) * mpd.x / SIZE.x,
		(ParkAtlas.MAP_NORTH - ParkAtlas.MAP_SOUTH) * mpd.y / SIZE.y)


## Clears the map within [param radius_m] meters of [param lonlat]
## (longitude, latitude). Returns how many map pixels it cleared.
func reveal(lonlat: Vector2, radius_m: float) -> int:
	var fresh := _clear_circle(lonlat, radius_m)
	if fresh > 0:
		version += 1
		changed.emit()
	return fresh


## Clears a ribbon [param radius_m] meters either side of a line of
## longitude/latitude points.
func reveal_path(lonlats: PackedVector2Array, radius_m: float) -> int:
	var fresh := 0
	var step := meters_per_cell().x * 0.5
	for i in range(1, lonlats.size()):
		var a := lonlats[i - 1]
		var b := lonlats[i]
		var steps := maxi(1, ceili(Wayfinding.meters_between(a, b).length() / step))
		for s in steps + 1:
			fresh += _clear_circle(a.lerp(b, float(s) / steps), radius_m)
	if fresh > 0:
		version += 1
		changed.emit()
	return fresh


func _clear_circle(lonlat: Vector2, radius_m: float) -> int:
	var c := to_cell(lonlat)
	var per := meters_per_cell()
	var r := Vector2(radius_m / per.x, radius_m / per.y)
	var fresh := 0
	for y in range(floori(c.y - r.y), ceili(c.y + r.y) + 1):
		if y < 0 or y >= SIZE.y:
			continue
		for x in range(floori(c.x - r.x), ceili(c.x + r.x) + 1):
			if x < 0 or x >= SIZE.x:
				continue
			var d := (Vector2(x + 0.5, y + 0.5) - c) / r
			# always the pixel underfoot, however small the circle
			if d.length_squared() <= 1.0 or (x == floori(c.x) and y == floori(c.y)):
				var i := y * SIZE.x + x
				if _seen[i] == 0:
					_seen[i] = 1
					fresh += 1
	return fresh


## The fog as a picture over [param base] (the park map's own image): plain
## parchment with a faint print of the land and light hatching where unseen,
## clear where seen, with a one-pixel dithered edge between.
func fog_image(base: Image) -> Image:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var paper := Color("d9c49a")
	var hatch := Color("c4ab7c")
	var ink := Color("8a6f4a")
	var has_base := base != null and base.get_width() == SIZE.x and base.get_height() == SIZE.y
	for y in SIZE.y:
		for x in SIZE.x:
			if _seen[y * SIZE.x + x] != 0:
				continue
			var edge := _seen_near(x, y)
			if edge and (x + y) % 2 == 0:
				continue
			var color := paper
			if has_base:
				# the brochure's faint print of the land: dark ground darker
				var under := base.get_pixel(x, y)
				color = paper.lerp(ink, clampf(0.55 - under.get_luminance(), 0.0, 0.55) * 0.55)
			if (x + 2 * y) % 6 == 0:
				color = color.lerp(hatch, 0.6)
			color.a = 0.82 if edge else 1.0
			image.set_pixel(x, y, color)
	return image


func _seen_near(x: int, y: int) -> bool:
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_seen(Vector2i(x, y) + d):
			return true
	return false


# ---------------------------------------------------------------- walking about

func _process(delta: float) -> void:
	if _seed_pending:
		_seed_pending = false
		seed_from_discoveries()
	if not watching:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = POLL
	var world := get_tree().get_first_node_in_group("world")
	if world == null or not bool(world.get("_started")):
		return
	var region: Region = world.get("region")
	var player: Node2D = world.get("player")
	if region == null or player == null or region.indoors or not region.is_inside_tree():
		return
	walk(region, region.to_local(player.global_position))


## The player is at [param at] (pixels) in [param region]: clears the map
## around them, and handles arriving somewhere new. Called by _process; tests
## call it directly.
func walk(region: Region, at: Vector2) -> void:
	var here := Wayfinding.lonlat_of(region, at)
	if region.region_id != _last_region:
		_arrive(region, here)
	_last_lonlat = here
	reveal(here, WALK_RADIUS)


func _arrive(region: Region, here: Vector2) -> void:
	var id := region.region_id
	var middle := Wayfinding.lonlat_of(region, region.get_bounds().get_center())
	# a drive or a long trail: the road there is cleared too
	if _last_lonlat != Vector2.INF and Wayfinding.meters_between(_last_lonlat, here).length() > TRIP_GAP:
		reveal_path(Journey.route_lonlats({"from": _last_lonlat, "to": here, "from_region": _last_region, "to_region": id}), ROAD_RADIUS)
	_last_region = id
	reveal(middle, ARRIVE_RADIUS)
	if id in Discoveries.VIEWPOINTS:
		reveal(middle, LOOKOUT_RADIUS)
	if visited.has(id):
		return
	visited[id] = {"name": region.display_name, "hub": region.hub_id, "lonlat": [middle.x, middle.y]}
	var info := {"id": id, "name": region.display_name, "hub": region.hub_id, "subtitle": subtitle_for(region.region_id, region.hub_id)}
	first_visit.emit(info)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_arrival"):
		hud.show_arrival(info.name, info.subtitle)
	changed.emit()


## The line under an area's name on arrival: its part of the park, or for
## the hub's own area, the hub's tagline.
static func subtitle_for(region_id: String, hub_id: String) -> String:
	var hub := Park.get_hub(hub_id)
	if hub == null:
		return ""
	if hub.id == region_id:
		return "%s. %s" % [hub.get_elevation_text(), hub.tagline.trim_suffix(".")]
	return hub.display_name


## A save from before the fog: clears the map around every area it had
## already discovered, so returning players don't open a blank map.
func seed_from_discoveries() -> void:
	for entry: Dictionary in Discoveries.places():
		if not Discoveries.is_found(entry.key) or entry.name != region_name(entry.region):
			continue
		var data: Dictionary = _regions.get(entry.region, {})
		if data.is_empty() or visited.has(entry.region):
			continue
		var at := _v2(data.lonlat)
		visited[entry.region] = {"name": data.name, "hub": data.hub, "lonlat": data.lonlat}
		_clear_circle(at, ARRIVE_RADIUS)
		if entry.region in Discoveries.VIEWPOINTS:
			_clear_circle(at, LOOKOUT_RADIUS)
	version += 1
	changed.emit()


# ---------------------------------------------------------------- areas

## The area's data from regions.json, or {}.
func region_data(id: String) -> Dictionary:
	return _regions.get(id, {})


func region_name(id: String) -> String:
	return str(_regions.get(id, {}).get("name", visited.get(id, {}).get("name", "")))


## An area's middle (longitude/latitude): where you saw it, else from
## regions.json, else Vector2.INF.
func region_lonlat(id: String) -> Vector2:
	if visited.has(id):
		return _v2(visited[id].lonlat)
	if _regions.has(id):
		return _v2(_regions[id].lonlat)
	return Vector2.INF


func _load_regions() -> void:
	if not FileAccess.file_exists(REGIONS_DATA):
		push_warning("No region list yet. Run tools/map/list_regions.tscn to build %s." % REGIONS_DATA)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(REGIONS_DATA))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read %s" % REGIONS_DATA)
		return
	for entry: Dictionary in data.get("regions", []):
		_regions[str(entry.id)] = entry


static func _v2(pair) -> Vector2:
	if pair is Vector2:
		return pair
	return Vector2(float(pair[0]), float(pair[1]))


# ---------------------------------------------------------------- stamps and tracking

## Puts a stamp of [param kind] at [param lonlat]. Returns false when the
## map is full (MAX_STAMPS) or the kind is unknown.
func add_stamp(kind: String, lonlat: Vector2) -> bool:
	if not kind in STAMPS or stamps.size() >= MAX_STAMPS:
		return false
	stamps.append({"kind": kind, "lonlat": [lonlat.x, lonlat.y]})
	changed.emit()
	return true


func remove_stamp(index: int) -> void:
	if index < 0 or index >= stamps.size():
		return
	var stamp := stamps[index]
	stamps.remove_at(index)
	if tracked.get("kind", "") == "stamp" and _v2(tracked.lonlat) == _v2(stamp.lonlat):
		untrack()
	changed.emit()


## Follows [param target] ({kind, id, label, lonlat, region}); following the
## same thing again stops following it. Returns true if it's tracked now.
func track(target: Dictionary) -> bool:
	if is_tracked(target):
		untrack()
		return false
	tracked = target.duplicate()
	if tracked.lonlat is Vector2:
		tracked.lonlat = [tracked.lonlat.x, tracked.lonlat.y]
	tracked_changed.emit()
	return true


func untrack() -> void:
	if tracked.is_empty():
		return
	tracked = {}
	tracked_changed.emit()


func is_tracked(target: Dictionary) -> bool:
	if tracked.is_empty() or target.get("kind", "") != tracked.get("kind", ""):
		return false
	if target.get("kind", "") == "stamp":
		return _v2(target.lonlat).is_equal_approx(_v2(tracked.lonlat))
	return str(target.get("id", "")) == str(tracked.get("id", ""))


## Has the tracked thing gone (a finished quest)? Then stop following it.
func refresh_tracked() -> void:
	if tracked.get("kind", "") != "quest":
		return
	for target: Dictionary in QuestTarget.all():
		if target.quest.id == tracked.id:
			# the quest's next step may have moved
			tracked.region = target.region
			var at := region_lonlat(target.region)
			if at != Vector2.INF:
				tracked.lonlat = [at.x, at.y]
			return
	untrack()


# ---------------------------------------------------------------- saving

func save_data() -> Dictionary:
	return {
		"seen": Marshalls.raw_to_base64(_seen.compress(FileAccess.COMPRESSION_DEFLATE)),
		"visited": visited.duplicate(true),
		"stamps": stamps.duplicate(true),
		"tracked": tracked.duplicate(true),
	}


func load_data(data: Dictionary) -> void:
	_seen.fill(0)
	var packed := str(data.get("seen", ""))
	if packed != "":
		var raw := Marshalls.base64_to_raw(packed).decompress(SIZE.x * SIZE.y, FileAccess.COMPRESSION_DEFLATE)
		if raw.size() == _seen.size():
			_seen = raw
	visited = (data.get("visited", {}) as Dictionary).duplicate(true)
	stamps.clear()
	for stamp in data.get("stamps", []):
		if stamp is Dictionary and str(stamp.get("kind", "")) in STAMPS:
			stamps.append(stamp.duplicate(true))
	tracked = (data.get("tracked", {}) as Dictionary).duplicate(true)
	_last_region = ""
	_last_lonlat = Vector2.INF
	# a save from before the fog: clear around what it had found, once
	# Discoveries has loaded too
	_seed_pending = packed == ""
	version += 1
	changed.emit()
	tracked_changed.emit()
