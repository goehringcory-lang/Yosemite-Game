extends RefCounted
## Builds one hub's map from real elevation and OpenStreetMap data.
##
## Output: scenes/regions/generated/<hub>_map.tscn (always overwritten),
## assets/map/areas/<hub>.png (the area map), and, only if missing, the
## hand-editable wrapper scenes/regions/<hub>.tscn.

const Terrain = preload("res://tools/mapgen/terrain.gd")
const Art = preload("res://tools/mapgen/art.gd")
const Buildings = preload("res://tools/mapgen/hub_buildings.gd")
const Dem = preload("res://tools/mapgen/dem.gd")
const LandPatches = preload("res://tools/mapgen/land_patches.gd")
const BlackOak = preload("res://scripts/objects/black_oak.gd")

const TILESET := preload("res://assets/tiles/world_tileset.tres")
const INFO_SIGN := "res://scenes/objects/info_sign.tscn"
const TRAVEL_POINT := "res://scenes/objects/travel_point.tscn"
const REGION_DOOR := "res://scenes/objects/region_door.tscn"
const SHUTTLE_STOP := "res://scenes/objects/shuttle_stop.tscn"
## Walkable areas at least this big (in tiles) that a river cuts off get a
## bridge to the rest of the map.
const MIN_CUT_OFF_AREA := 30
## Longest bridge the generator will build, in tiles of water.
const MAX_BRIDGE := 4
const T := 16

## Slope thresholds in degrees.
const CLIFF_SLOPE := 48.0
const STEEP_SLOPE := 34.0
const FALLS_SLOPE := 38.0
## How far below the walkable band ground must be to count as the view
## "far below" (drawn hazy under the rim, as at Glacier Point).
const BELOW_MARGIN := 120.0
const HAZE := Color(0.66, 0.74, 0.86)

# Per-cell flags set from OpenStreetMap.
const F_WOOD := 1 << 0
const F_MEADOW := 1 << 1
const F_WET := 1 << 2
const F_SCRUB := 1 << 3
const F_ROCK := 1 << 4
const F_SCREE := 1 << 5
const F_SAND := 1 << 6
const F_LAKE := 1 << 7
const F_RIVER := 1 << 8
const F_STREAM := 1 << 9
const F_CLIFF := 1 << 10
const F_ROAD := 1 << 11
const F_TRAIL := 1 << 12
const F_PAVED := 1 << 13
const F_PARKING := 1 << 14
const F_BUILDING := 1 << 15
const F_CAMP := 1 << 16
const F_SNOW := 1 << 17
const F_LAWN := 1 << 18
const F_BRIDGE := 1 << 19
const F_FALLS := 1 << 20
const F_GROVE := 1 << 21

const ROAD_RANK := {"motorway": 7, "trunk": 7, "primary": 6, "secondary": 5, "tertiary": 4,
	"primary_link": 4, "secondary_link": 4, "tertiary_link": 3, "unclassified": 3,
	"residential": 2, "living_street": 2, "service": 1}
const TRAIL_TYPES := ["path", "footway", "bridleway", "track", "steps", "pedestrian", "cycleway"]
const BUILDING_RANK := {Terrain.Flora.LODGE: 5, Terrain.Flora.WHITE_HOUSE: 4, Terrain.Flora.HOUSE: 3,
	Terrain.Flora.CABIN: 2, Terrain.Flora.TENT_CABIN: 1}

var hub: HubData
var content: Dictionary
var dem: Dem
var elements: Array = []

var w := 0
var h := 0
var mpt := 40.0
var mpd := Vector2.ONE

var elev := PackedFloat32Array()
var slope := PackedFloat32Array()
var shade := PackedFloat32Array()
var flags := PackedInt32Array()
var kind := PackedInt32Array()
var flora := PackedInt32Array()
var walkable := PackedByteArray()
var reachable := PackedByteArray()
var below := PackedByteArray()
var reserved := PackedByteArray()
## Cell index -> [rank, road name] for named roads.
var road_names: Dictionary = {}
## Name -> Array of {tags, lonlat, type}.
var named: Dictionary = {}
var point_trees: Array[Dictionary] = []
var boulders: Array[Vector2] = []

var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()


func _init(hub_data: HubData, hub_content: Dictionary, elevation: Dem, osm: Dictionary) -> void:
	hub = hub_data
	content = hub_content
	dem = elevation
	elements = osm.get("elements", [])
	mpt = hub.meters_per_tile
	mpd = ParkAtlas.meters_per_degree((hub.north + hub.south) / 2.0)
	w = ceili((hub.east - hub.west) * mpd.x / mpt)
	h = ceili((hub.north - hub.south) * mpd.y / mpt)
	rng.seed = hash(hub.id)
	noise.seed = hash(hub.id)
	noise.frequency = 0.09
	noise.fractal_octaves = 2


func build() -> Dictionary:
	print("  %s: %d x %d tiles at %d m per tile" % [hub.id, w, h, roundi(mpt)])
	var n := w * h
	# Packed arrays are values, so each one is resized by name.
	elev.resize(n)
	slope.resize(n)
	shade.resize(n)
	flags.resize(n)
	kind.resize(n)
	flora.resize(n)
	walkable.resize(n)
	reachable.resize(n)
	below.resize(n)
	reserved.resize(n)
	flora.fill(-1)
	_timed("elevation", _sample_terrain)
	_timed("OpenStreetMap", _rasterize_osm)
	_clear_buildings()
	_timed("terrain types", _classify)
	_reshape_land()
	var arrival := _spot(content.spawns.arrival)
	_flood_fill(arrival)
	var started := Time.get_ticks_msec()
	var bridges := _bridge_gaps(arrival)
	print("    bridges: %d built in %.1f s" % [bridges, (Time.get_ticks_msec() - started) / 1000.0])
	var report := _place_content()
	_timed("flora", _place_flora)
	_timed("area map", _save_area_map)
	_timed("scene", _save_scenes.bind(report))
	return report


func _timed(label: String, step: Callable) -> void:
	var started := Time.get_ticks_msec()
	step.call()
	print("    %s: %.1f s" % [label, (Time.get_ticks_msec() - started) / 1000.0])


# ---------------------------------------------------------------- geometry

func to_cell(lon: float, lat: float) -> Vector2:
	return Vector2((lon - hub.west) * mpd.x / mpt, (hub.north - lat) * mpd.y / mpt)


func cell_lonlat(i: int, j: int) -> Vector2:
	return Vector2(hub.west + (i + 0.5) * mpt / mpd.x, hub.north - (j + 0.5) * mpt / mpd.y)


func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * T + Vector2(T, T) / 2.0


func _points(geometry: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Variant in geometry:
		if p is Dictionary:
			out.append(to_cell(p.lon, p.lat))
	return out


# ---------------------------------------------------------------- elevation

func _sample_terrain() -> void:
	var corners := PackedFloat32Array()
	corners.resize((w + 1) * (h + 1))
	for j in h + 1:
		for i in w + 1:
			var lon := hub.west + i * mpt / mpd.x
			var lat := hub.north - j * mpt / mpd.y
			corners[j * (w + 1) + i] = dem.sample(lon, lat)
	var light := Vector3(-0.5, 0.5, 0.7071).normalized()
	for j in h:
		for i in w:
			var a := corners[j * (w + 1) + i]
			var b := corners[j * (w + 1) + i + 1]
			var c := corners[(j + 1) * (w + 1) + i]
			var d := corners[(j + 1) * (w + 1) + i + 1]
			var k := j * w + i
			elev[k] = (a + b + c + d) / 4.0
			var dzdx := ((b + d) - (a + c)) / (2.0 * mpt)
			var dzdy_north := ((a + b) - (c + d)) / (2.0 * mpt)
			slope[k] = rad_to_deg(atan(Vector2(dzdx, dzdy_north).length()))
			var normal := Vector3(-dzdx * 1.5, -dzdy_north * 1.5, 1.0).normalized()
			shade[k] = maxf(normal.dot(light), 0.0)


# ---------------------------------------------------------------- OSM

func _rasterize_osm() -> void:
	var building_polys: Array = []
	for e: Dictionary in elements:
		var tags: Dictionary = e.get("tags", {})
		if tags.has("name"):
			_remember_name(e, tags)
		match e.type:
			"node":
				_osm_node(e, tags)
			"way":
				var pts := _points(e.get("geometry", []))
				if pts.size() < 2:
					continue
				var nodes: Array = e.get("nodes", [])
				var closed: bool = nodes.size() > 3 and nodes[0] == nodes[-1]
				if tags.has("building") and closed:
					building_polys.append([[pts], tags])
					continue
				if closed and tags.get("area", "") != "no" and not tags.has("highway") and not tags.has("waterway"):
					_osm_area([pts], tags)
				elif closed and tags.get("area", "") == "yes":
					_osm_area([pts], tags)
				else:
					_osm_line(pts, tags)
			"relation":
				var rings: Array = []
				for m: Dictionary in e.get("members", []):
					if m.get("type", "") == "way" and m.has("geometry"):
						var ring := _points(m.geometry)
						if ring.size() >= 2:
							rings.append(ring)
				if rings.is_empty():
					continue
				if tags.has("building"):
					building_polys.append([rings, tags])
				else:
					_osm_area(rings, tags)
	# Buildings last, so camp sites are known when picking cabin styles.
	for entry: Array in building_polys:
		_osm_building(entry[0], entry[1])


func _remember_name(e: Dictionary, tags: Dictionary) -> void:
	var lonlat := Vector2.INF
	if e.type == "node":
		lonlat = Vector2(e.lon, e.lat)
	elif e.type == "way" and e.has("geometry"):
		lonlat = _representative_point(e.geometry, e.get("nodes", []))
	elif e.type == "relation":
		var all_points: Array = []
		for m: Dictionary in e.get("members", []):
			if m.get("role", "") == "outer" and m.has("geometry"):
				all_points.append_array(m.geometry)
		if not all_points.is_empty():
			lonlat = _representative_point(all_points, [1, 2, 3, 1])
	if lonlat == Vector2.INF:
		return
	var list: Array = named.get(tags.name, [])
	list.append({"tags": tags, "lonlat": lonlat, "type": e.type})
	named[tags.name] = list


## Centroid for areas; for lines, the vertex closest to the centroid.
func _representative_point(geometry: Array, nodes: Array) -> Vector2:
	var sum := Vector2.ZERO
	var count := 0
	for p: Variant in geometry:
		if p is Dictionary:
			sum += Vector2(p.lon, p.lat)
			count += 1
	if count == 0:
		return Vector2.INF
	var centroid := sum / count
	var closed: bool = nodes.size() > 3 and nodes[0] == nodes[-1]
	if closed:
		return centroid
	var best := Vector2.INF
	for p: Variant in geometry:
		if p is Dictionary:
			var v := Vector2(p.lon, p.lat)
			if best == Vector2.INF or v.distance_squared_to(centroid) < best.distance_squared_to(centroid):
				best = v
	return best


func _osm_node(e: Dictionary, tags: Dictionary) -> void:
	var c := Vector2i(to_cell(e.lon, e.lat).floor())
	if not in_map(c):
		return
	if tags.get("waterway", "") == "waterfall":
		flags[idx(c)] |= F_FALLS
	elif tags.get("natural", "") == "tree" and tags.has("name"):
		point_trees.append({"cell": c, "name": tags.name})


func _osm_area(rings: Array, tags: Dictionary) -> void:
	var natural: String = tags.get("natural", "")
	var landuse: String = tags.get("landuse", "")
	var leisure: String = tags.get("leisure", "")
	var water: String = tags.get("water", "")
	var flag := 0
	if natural == "water" or tags.get("waterway", "") == "riverbank" or landuse == "reservoir":
		flag = F_RIVER if water in ["river", "stream", "canal", "rapids"] or tags.get("waterway", "") == "riverbank" else F_LAKE
	elif natural == "wetland":
		flag = F_WET
	elif natural in ["grassland", "heath"] or landuse in ["meadow", "grass"]:
		flag = F_MEADOW
	elif leisure in ["golf_course", "park", "pitch"]:
		flag = F_LAWN
	elif natural == "wood" or landuse == "forest":
		flag = F_WOOD
		if tags.get("name", "") == "Mariposa Grove":
			_fill(rings, F_GROVE)
	elif natural == "scrub":
		flag = F_SCRUB
	elif natural == "bare_rock":
		flag = F_ROCK
	elif natural in ["scree", "shingle"]:
		flag = F_SCREE
	elif natural in ["beach", "sand"]:
		flag = F_SAND
	elif natural == "glacier":
		flag = F_SNOW
	elif tags.get("amenity", "") == "parking":
		flag = F_PARKING
	elif tags.get("tourism", "") in ["camp_site", "caravan_site"]:
		flag = F_CAMP
	elif tags.get("highway", "") == "pedestrian":
		flag = F_PAVED
	elif natural in ["stone", "rock"]:
		var sum := Vector2.ZERO
		for p in rings[0]:
			sum += p
		boulders.append(sum / rings[0].size())
		return
	if flag != 0:
		_fill(rings, flag)


func _osm_line(pts: PackedVector2Array, tags: Dictionary) -> void:
	var highway: String = tags.get("highway", "")
	var waterway: String = tags.get("waterway", "")
	var flag := 0
	if waterway == "river":
		flag = F_RIVER
	elif waterway in ["stream", "brook", "canal"]:
		if tags.get("intermittent", "") == "yes" and not tags.has("name"):
			return
		flag = F_STREAM
	elif tags.get("natural", "") == "cliff":
		flag = F_CLIFF
	elif ROAD_RANK.has(highway):
		if tags.get("service", "") in ["parking_aisle", "drive-through"]:
			return
		flag = F_ROAD
	elif highway in TRAIL_TYPES:
		if tags.get("footway", "") in ["sidewalk", "crossing"] or tags.get("indoor", "") == "yes":
			return
		var surface: String = tags.get("surface", "")
		flag = F_PAVED if highway == "cycleway" or surface in ["paved", "asphalt", "concrete", "paving_stones"] else F_TRAIL
	elif tags.get("railway", "") in ["abandoned", "disused"]:
		flag = F_TRAIL
	if flag == 0:
		return
	if tags.get("bridge", "") not in ["", "no"]:
		flag |= F_BRIDGE
	var cells := _trace(pts)
	var rank: int = ROAD_RANK.get(highway, 0)
	for c in cells:
		var k := idx(c)
		flags[k] |= flag
		if flag & F_ROAD and tags.has("name") and rank >= 3:
			var current: Array = road_names.get(k, [0, ""])
			if rank > current[0]:
				road_names[k] = [rank, tags.name]


## Marks the footprint's cells and gives each a building style. The cells only
## say where buildings are and what kind: hub_buildings.gd turns them into one
## building to a footprint when the scene is written.
func _osm_building(rings: Array, tags: Dictionary) -> void:
	var cells := _fill(rings, F_BUILDING)
	if cells.is_empty():
		var sum := Vector2.ZERO
		var count := 0
		for ring: PackedVector2Array in rings:
			for p in ring:
				sum += p
				count += 1
		var c := Vector2i((sum / maxi(count, 1)).floor())
		if not in_map(c):
			return
		flags[idx(c)] |= F_BUILDING
		cells = [c]
	var area := _polygon_area_m2(rings)
	for c: Vector2i in cells:
		var style := _building_style(tags, area, flags[idx(c)])
		var k := idx(c)
		if flora[k] < 0 or BUILDING_RANK.get(style, 0) > BUILDING_RANK.get(flora[k], 0):
			flora[k] = style


func _building_style(tags: Dictionary, area_m2: float, cell_flags: int) -> int:
	var F := Terrain.Flora
	var building: String = tags.get("building", "yes")
	var big: bool = building in ["hotel", "apartments", "dormitory", "commercial", "retail", "office",
		"public", "church", "civic", "museum", "school"] or tags.get("tourism", "") in ["hotel", "museum"]
	if content.get("style", "") == "wawona" and (big or tags.get("name", "").contains("Cottage") or tags.get("name", "").contains("Wawona Hotel")):
		return F.WHITE_HOUSE
	if building == "tent" or (building == "cabin" and cell_flags & F_CAMP):
		return F.TENT_CABIN
	if big or area_m2 > 900.0:
		return F.LODGE
	if building in ["house", "residential", "detached"] or area_m2 > 140.0:
		return F.HOUSE
	return F.CABIN


func _polygon_area_m2(rings: Array) -> float:
	var ring: PackedVector2Array = rings[0]
	var area := 0.0
	for k in ring.size() - 1:
		area += ring[k].x * ring[k + 1].y - ring[k + 1].x * ring[k].y
	return absf(area) / 2.0 * mpt * mpt


## Even-odd fill of cell centers inside the rings. Returns the filled cells.
func _fill(rings: Array, flag: int) -> Array[Vector2i]:
	var filled: Array[Vector2i] = []
	var min_y := INF
	var max_y := -INF
	for ring: PackedVector2Array in rings:
		for p in ring:
			min_y = minf(min_y, p.y)
			max_y = maxf(max_y, p.y)
	for j in range(maxi(0, floori(min_y)), mini(h, ceili(max_y))):
		var yc := j + 0.5
		var xs: Array[float] = []
		for ring: PackedVector2Array in rings:
			for k in ring.size() - 1:
				var a := ring[k]
				var b := ring[k + 1]
				if (a.y <= yc) != (b.y <= yc):
					xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for p in range(0, xs.size() - 1, 2):
			for i in range(maxi(0, ceili(xs[p] - 0.5)), mini(w - 1, floori(xs[p + 1] - 0.5)) + 1):
				flags[j * w + i] |= flag
				filled.append(Vector2i(i, j))
	return filled


## Cells a polyline passes through, 4-connected so walls and roads have no
## diagonal gaps.
func _trace(pts: PackedVector2Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var prev := Vector2i(-99999, -99999)
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var steps := ceili(maxf(absf(b.x - a.x), absf(b.y - a.y)) * 3.0) + 1
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps)
			var c := Vector2i(p.floor())
			if c == prev:
				continue
			if prev.x != -99999 and c.x != prev.x and c.y != prev.y:
				var bridge_cell := Vector2i(c.x, prev.y)
				if in_map(bridge_cell):
					out.append(bridge_cell)
			if in_map(c):
				out.append(c)
			prev = c
	return out


# ---------------------------------------------------------------- terrain types

func _zone(e: float) -> int:
	if e < 1100.0:
		return Terrain.FOOTHILL
	if e < 1950.0:
		return Terrain.FOREST
	if e < 2550.0:
		return Terrain.FIR
	if e < 3150.0:
		return Terrain.SUBALPINE
	return Terrain.ALPINE


func _classify() -> void:
	var water_flags := F_LAKE | F_RIVER | F_STREAM
	for k in w * h:
		var f := flags[k]
		var s := slope[k]
		var e := elev[k]
		var t := _zone(e)
		var steep := false
		var in_band := e >= hub.walk_min_elevation and e <= hub.walk_max_elevation
		# Trails outside the walkable band are drawn as the ground they
		# cross, so the rims don't show paths the player can't take.
		var trail := f & (F_TRAIL | F_PAVED) != 0 and in_band
		if f & F_BUILDING and not f & F_ROAD:
			t = Terrain.BUILT
		elif f & F_ROAD and f & F_BRIDGE and f & water_flags:
			t = Terrain.BRIDGE
		elif f & F_ROAD:
			t = Terrain.ROAD
		elif f & F_PARKING:
			t = Terrain.PARKING
		elif trail and (f & F_BRIDGE or not f & (F_LAKE | F_RIVER)):
			t = Terrain.BRIDGE if f & F_BRIDGE and f & water_flags else (Terrain.PAVED if f & F_PAVED else Terrain.TRAIL)
		elif f & F_LAKE:
			t = Terrain.LAKE
		elif f & F_RIVER:
			t = Terrain.FALLS if s >= FALLS_SLOPE or f & F_FALLS else Terrain.RIVER
		elif f & F_STREAM:
			t = Terrain.FALLS if s >= FALLS_SLOPE or f & F_FALLS else Terrain.CREEK
		elif f & F_SNOW:
			t = Terrain.SNOW
		elif f & F_SAND and s < STEEP_SLOPE:
			t = Terrain.SAND
		elif f & F_LAWN and s < STEEP_SLOPE:
			t = Terrain.LAWN
		elif f & (F_MEADOW | F_WET) and s < 25.0:
			t = Terrain.WET_MEADOW if f & F_WET else Terrain.MEADOW
		elif s >= CLIFF_SLOPE or f & F_CLIFF:
			t = Terrain.CLIFF
		elif s >= STEEP_SLOPE:
			if f & (F_SCREE | F_ROCK) or not f & (F_WOOD | F_SCRUB):
				t = Terrain.TALUS
			else:
				t = Terrain.SCRUB if f & F_SCRUB else t
				steep = true
		elif f & F_SCREE:
			t = Terrain.SCREE
		elif f & F_ROCK:
			t = Terrain.GRANITE
		elif f & F_SCRUB:
			t = Terrain.SCRUB
		elif f & F_CAMP:
			t = Terrain.CAMP
		kind[k] = t

		var always_open := t in [Terrain.ROAD, Terrain.PARKING, Terrain.BRIDGE]
		var open := not Terrain.is_solid(t) and not steep and t != Terrain.BUILT and (in_band or always_open)
		walkable[k] = 1 if open else 0
		if content.get("haze_below", false) and e < hub.walk_min_elevation - BELOW_MARGIN:
			below[k] = 1
			walkable[k] = 0


## The "clear" land patches (land_patches.gd): no buildings there, and the
## ground that isn't too steep is woods, so it gets dense forest.
func _clear_buildings() -> void:
	var clear := LandPatches.mask(content, "clear", w, h, func(p: Vector2) -> Vector2: return to_cell(p.x, p.y))
	for k in w * h:
		if clear[k] == 0:
			continue
		if flags[k] & F_BUILDING:
			flags[k] &= ~F_BUILDING
			flora[k] = -1
		if slope[k] < STEEP_SLOPE:
			flags[k] |= F_WOOD


## The rest of the land patches: "unpave" (paving that leads nowhere in a
## "clear" area becomes forest), then slab or talus at the foot of the cliff,
## kept off the spawn points.
func _reshape_land() -> void:
	var to := func(p: Vector2) -> Vector2: return to_cell(p.x, p.y)
	var spots: Array[Vector2i] = []
	for spec: Dictionary in content.get("spawns", {}).values():
		spots.append(_spot_cell(spec))
	if LandPatches.wants(content, "unpave"):
		for c in LandPatches.unpave(kind, w, h, LandPatches.mask(content, "clear", w, h, to), spots):
			walkable[idx(c)] = 1 if elev[idx(c)] >= hub.walk_min_elevation and elev[idx(c)] <= hub.walk_max_elevation else 0
	var slabs := LandPatches.mask(content, "slabs", w, h, to)
	var talus := LandPatches.mask(content, "talus", w, h, to)
	if not LandPatches.any(slabs) and not LandPatches.any(talus):
		return
	var keep := PackedByteArray()
	keep.resize(w * h)
	for c in spots:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if in_map(c + Vector2i(dx, dy)):
					keep[idx(c + Vector2i(dx, dy))] = 1
	for c in LandPatches.reshape(kind, w, h, slabs, talus, keep):
		if kind[idx(c)] == Terrain.TALUS:
			walkable[idx(c)] = 0


func _flood_fill(start: Vector2i) -> void:
	reachable.fill(0)
	var queue: Array[Vector2i] = [start]
	reachable[idx(start)] = 1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if in_map(n) and walkable[idx(n)] and not reachable[idx(n)]:
				reachable[idx(n)] = 1
				queue.append(n)


## Water a bridge can cross (not lakes or waterfalls).
func _bridgeable(c: Vector2i) -> bool:
	return kind[idx(c)] in [Terrain.RIVER, Terrain.CREEK] and not below[idx(c)]


## Connects walkable areas that rivers cut off from the arrival point by
## turning the shortest water crossing into a bridge. Returns how many it built.
func _bridge_gaps(arrival: Vector2i) -> int:
	var built := 0
	var steps: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var came_from := PackedInt32Array()
	var depth := PackedInt32Array()
	came_from.resize(w * h)
	depth.resize(w * h)
	for attempt in 40:
		var sizes := _cut_off_sizes()
		came_from.fill(-1)
		depth.fill(0)
		# Breadth-first from everything reachable, through water only.
		var queue := PackedInt32Array()
		for k in w * h:
			if not reachable[k]:
				continue
			var c := Vector2i(k % w, k / w)
			for d in steps:
				var n := c + d
				if in_map(n) and came_from[idx(n)] == -1 and _bridgeable(n):
					came_from[idx(n)] = k
					depth[idx(n)] = 1
					queue.append(idx(n))
		var head := 0
		var goal_from := -1
		while head < queue.size() and goal_from < 0:
			var k := queue[head]
			head += 1
			var c := Vector2i(k % w, k / w)
			for d in steps:
				var n := c + d
				if not in_map(n):
					continue
				var nk := idx(n)
				if reachable[nk] or came_from[nk] != -1:
					continue
				if walkable[nk] and sizes[nk] >= MIN_CUT_OFF_AREA:
					goal_from = k
					break
				if depth[k] < MAX_BRIDGE and _bridgeable(n):
					came_from[nk] = k
					depth[nk] = depth[k] + 1
					queue.append(nk)
		if goal_from < 0:
			break
		var k := goal_from
		while not reachable[k]:
			kind[k] = Terrain.BRIDGE
			walkable[k] = 1
			k = came_from[k]
		built += 1
		_flood_fill(arrival)
	return built


## For each walkable cell not reachable from the arrival point, the size of
## the area it belongs to (0 for everything else).
func _cut_off_sizes() -> PackedInt32Array:
	var sizes := PackedInt32Array()
	sizes.resize(w * h)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var steps: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for k in w * h:
		if not walkable[k] or reachable[k] or seen[k]:
			continue
		var area := PackedInt32Array([k])
		seen[k] = 1
		var head := 0
		while head < area.size():
			var c := Vector2i(area[head] % w, area[head] / w)
			head += 1
			for d in steps:
				var n := c + d
				if in_map(n) and walkable[idx(n)] and not reachable[idx(n)] and not seen[idx(n)]:
					seen[idx(n)] = 1
					area.append(idx(n))
		for cell in area:
			sizes[cell] = area.size()
	return sizes


## Nearest cell to [param from] matching [param test], by breadth-first search.
func _nearest(from: Vector2i, test: Callable, max_radius := 60) -> Vector2i:
	from = from.clamp(Vector2i.ZERO, Vector2i(w - 1, h - 1))
	if test.call(from):
		return from
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if not in_map(n) or seen.has(n) or absi(n.x - from.x) + absi(n.y - from.y) > max_radius:
				continue
			if test.call(n):
				return n
			seen[n] = true
			queue.append(n)
	return from


# ---------------------------------------------------------------- content

## Looks up a spot from {"osm": name, "kind": "key=value"} or {"at": lon/lat}.
func lonlat_of(spec: Dictionary) -> Vector2:
	if spec.has("at"):
		return spec.at
	var candidates: Array = named.get(spec.osm, [])
	var best := Vector2.INF
	var best_score := -1
	for cand: Dictionary in candidates:
		var tags: Dictionary = cand.tags
		var score := 1
		if spec.has("kind"):
			var parts: PackedStringArray = str(spec.kind).split("=")
			if tags.get(parts[0], "") != parts[1]:
				continue
			score = 5
		if tags.get("highway", "") == "bus_stop":
			score = 0
		var c := to_cell(cand.lonlat.x, cand.lonlat.y)
		if c.x < 0 or c.y < 0 or c.x > w or c.y > h:
			continue
		if score > best_score:
			best = cand.lonlat
			best_score = score
	if best == Vector2.INF:
		push_warning("%s: no OpenStreetMap feature named '%s'" % [hub.id, spec.osm])
	return best


func _spot_cell(spec: Dictionary) -> Vector2i:
	var lonlat := lonlat_of(spec)
	if lonlat == Vector2.INF:
		return Vector2i(-1, -1)
	return Vector2i(to_cell(lonlat.x, lonlat.y).floor())


## The walkable cell nearest to a spot (used before reachability is known).
func _spot(spec: Dictionary) -> Vector2i:
	var c := _spot_cell(spec)
	return _nearest(c, func(n: Vector2i) -> bool: return walkable[idx(n)] == 1)


func _reachable_cell(c: Vector2i) -> Vector2i:
	return _nearest(c, func(n: Vector2i) -> bool: return reachable[idx(n)] == 1)


## A reachable cell with open ground around it, for an object the player walks up to.
func _object_cell(c: Vector2i) -> Vector2i:
	return _nearest(c, func(n: Vector2i) -> bool:
		if not reachable[idx(n)] or reserved[idx(n)] or kind[idx(n)] in [Terrain.ROAD, Terrain.BRIDGE]:
			return false
		var open := 0
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var m := n + d
			if in_map(m) and reachable[idx(m)] and not reserved[idx(m)]:
				open += 1
		return open >= 3)


func _reserve(c: Vector2i, radius := 1) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var n := c + Vector2i(dx, dy)
			if in_map(n):
				reserved[idx(n)] = 1


var _objects: Array[Dictionary] = []
var _places: Array[Dictionary] = []
var _spawns: Dictionary = {}
var _exits: Array[Dictionary] = []
var _doors: Array[Dictionary] = []


func _place_content() -> Dictionary:
	var report := {"hub": hub.id, "size": Vector2i(w, h), "warnings": []}
	for spawn_name: String in content.spawns:
		var c := _spot_cell(content.spawns[spawn_name])
		if c.x < 0:
			report.warnings.append("spawn %s not found" % spawn_name)
			continue
		var cell := _reachable_cell(c)
		_spawns[spawn_name] = cell
		_reserve(cell, 0)
	for sign: Dictionary in content.get("signs", []):
		var c := _spot_cell(sign)
		if c.x < 0:
			report.warnings.append("sign %s not found" % sign.title)
			continue
		var cell := _object_cell(c)
		_objects.append({"scene": INFO_SIGN, "cell": cell, "title": sign.title, "text": sign.text})
		_reserve(cell)
	for travel: Dictionary in content.get("travel", []):
		var c := _spot_cell(travel)
		if c.x < 0:
			report.warnings.append("travel point %s not found" % travel.label)
			continue
		var cell := _object_cell(c)
		_objects.append({"scene": TRAVEL_POINT, "cell": cell, "label": travel.label})
		_reserve(cell)
	for door: Dictionary in content.get("exits", []):
		if not _spawns.has(door.spawn):
			continue
		# The door sits beside the spawn point, so arriving here doesn't
		# put the player on top of it.
		var spawn_cell: Vector2i = _spawns[door.spawn]
		var cell := _object_cell(spawn_cell + Vector2i(0, -1))
		if cell == spawn_cell:
			cell = _object_cell(spawn_cell + Vector2i(1, 0))
		_objects.append({"scene": REGION_DOOR, "cell": cell, "label": door.label,
			"target_region": door.target_region, "target_spawn": door.target_spawn})
		_reserve(cell)
	for stop: Dictionary in content.get("shuttle", []):
		if not _spawns.has(stop.spawn):
			continue
		var spawn_cell: Vector2i = _spawns[stop.spawn]
		var cell := _object_cell(spawn_cell + Vector2i(-1, 0))
		_objects.append({"scene": SHUTTLE_STOP, "cell": cell, "label": stop.name})
		_reserve(cell)
	for place: Dictionary in content.get("places", []):
		var lonlat := lonlat_of(place)
		if lonlat == Vector2.INF:
			report.warnings.append("place %s not found" % place.name)
			continue
		_places.append({"name": place.name, "pos": to_cell(lonlat.x, lonlat.y) * T,
			"radius": float(place.get("radius", 150)) / mpt * T,
			"banner": place.get("banner", true), "label": place.get("label", false)})
	_find_road_exits(report)
	for spawn_name: String in _spawns:
		if not reachable[idx(_spawns[spawn_name])]:
			report.warnings.append("spawn %s is not reachable" % spawn_name)
	var walk_count := 0
	var reach_count := 0
	for k in w * h:
		walk_count += walkable[k]
		reach_count += reachable[k]
	report["walkable"] = walk_count
	report["reachable"] = reach_count
	return report


## Every named road that leaves the map edge becomes an exit.
func _find_road_exits(report: Dictionary) -> void:
	var mapping: Dictionary = content.get("road_exits", {})
	var done := {}
	for k: int in road_names:
		var c := Vector2i(k % w, k / w)
		var edge := ""
		if c.x == 0:
			edge = "west"
		elif c.x == w - 1:
			edge = "east"
		elif c.y == 0:
			edge = "north"
		elif c.y == h - 1:
			edge = "south"
		if edge == "":
			continue
		if not reachable[k]:
			continue
		var road: String = road_names[k][1]
		var target: String = mapping.get(road + "@" + edge, mapping.get(road, ""))
		if target == "" or done.has(road + edge):
			continue
		done[road + edge] = true
		var exit := {"cell": c, "edge": edge, "road": road}
		if ParkAtlas.HUBS.any(func(hd: HubData) -> bool: return hd.id == target):
			exit["travel_to"] = target
		else:
			exit["message"] = target
		_exits.append(exit)
		report.warnings.append("road exit: %s (%s edge) -> %s" % [road, edge, target.left(40)])


# ---------------------------------------------------------------- flora

func _weighted(options: Array) -> int:
	var total := 0.0
	for o: Array in options:
		total += o[1]
	var roll := rng.randf() * total
	for o: Array in options:
		roll -= o[1]
		if roll <= 0.0:
			return o[0]
	return options[-1][0]


func _place_flora() -> void:
	var F := Terrain.Flora
	for tree: Dictionary in point_trees:
		var k := idx(tree.cell)
		if flora[k] < 0 and not Terrain.is_solid(kind[k]) and kind[k] not in [Terrain.ROAD, Terrain.TRAIL, Terrain.PAVED]:
			flora[k] = F.SEQUOIA
	for b: Vector2 in boulders:
		var c := Vector2i(b.floor())
		if in_map(c) and flora[idx(c)] < 0 and kind[idx(c)] not in [Terrain.ROAD, Terrain.TRAIL, Terrain.PAVED, Terrain.BRIDGE]:
			flora[idx(c)] = F.BOULDER
	for j in h:
		for i in w:
			var k := j * w + i
			if flora[k] >= 0 or reserved[k] or below[k]:
				continue
			var t := kind[k]
			var f := flags[k]
			var e := elev[k]
			var clump := 0.55 + noise.get_noise_2d(i, j) * 0.9
			var density := 0.0
			var options: Array = []
			var zone := _zone(e)
			var wood := f & F_WOOD != 0
			match t:
				Terrain.FOOTHILL:
					density = 0.32 if wood else 0.12
					options = [[F.GRAY_PINE, 3], [F.LIVE_OAK, 4], [F.BLACK_OAK_TRUNK, 2], [F.MANZANITA, 3]]
				Terrain.FOREST, Terrain.CAMP:
					density = 0.42 if wood else 0.14
					if t == Terrain.CAMP:
						density = 0.16
					options = [[F.PONDEROSA, 4], [F.INCENSE_CEDAR, 3], [F.BLACK_OAK_TRUNK, 3], [F.WHITE_FIR, 1], [F.DOGWOOD, 1], [F.SNAG, 0.4]]
					if f & F_GROVE:
						density = 0.45
						options = [[F.SEQUOIA, 5], [F.SUGAR_PINE, 2], [F.WHITE_FIR, 2], [F.INCENSE_CEDAR, 1]]
					elif e > 1650.0:
						options = [[F.PONDEROSA, 2], [F.SUGAR_PINE, 2], [F.WHITE_FIR, 3], [F.INCENSE_CEDAR, 2], [F.BLACK_OAK_TRUNK, 1], [F.SNAG, 0.4]]
					if t == Terrain.CAMP and rng.randf() < 0.05:
						flora[k] = F.CAMP_TENT
						continue
				Terrain.FIR:
					density = 0.42 if wood else 0.16
					options = [[F.RED_FIR, 4], [F.WHITE_FIR, 2], [F.JEFFREY_PINE, 2], [F.LODGEPOLE, 1], [F.SNAG, 0.6]]
				Terrain.SUBALPINE:
					density = 0.36 if wood else 0.13
					options = [[F.LODGEPOLE, 8], [F.WHITEBARK, 1], [F.HEMLOCK, 1], [F.SNAG, 0.5]]
				Terrain.ALPINE:
					density = 0.03
					options = [[F.WHITEBARK, 1]]
				Terrain.SCRUB:
					density = 0.3
					options = [[F.MANZANITA, 5], [F.SHRUB, 2]]
					if zone == Terrain.FOOTHILL:
						options.append([F.LIVE_OAK, 2])
				Terrain.GRANITE:
					density = 0.05
					options = [[F.ERRATIC, 2], [F.JEFFREY_PINE if zone != Terrain.FOOTHILL else F.GRAY_PINE, 2]]
					if zone == Terrain.SUBALPINE:
						options = [[F.ERRATIC, 3], [F.LODGEPOLE, 2], [F.WHITEBARK, 1]]
				Terrain.MEADOW:
					density = 0.012
					options = [[F.BLACK_OAK_TRUNK if zone == Terrain.FOREST else F.LODGEPOLE, 1]]
				Terrain.WET_MEADOW:
					density = 0.02
					options = [[F.WILLOW, 2], [F.LODGEPOLE if zone == Terrain.SUBALPINE else F.BLACK_OAK_TRUNK, 1]]
				Terrain.TALUS:
					density = 0.05
					options = [[F.INCENSE_CEDAR if zone == Terrain.FOREST else F.JEFFREY_PINE, 1], [F.LIVE_OAK if zone == Terrain.FOREST else F.WHITEBARK, 1]]
			if density <= 0.0 or rng.randf() > density * clump:
				continue
			flora[k] = _weighted(options)


# ---------------------------------------------------------------- output

func _variant(i: int, j: int) -> int:
	return (i * 7 + j * 13 + (i * j) % 5) % Art.VARIANTS


func _shade_alt(k: int) -> int:
	if kind[k] not in Terrain.SHADED:
		return 0
	var s := shade[k]
	if s > 0.84:
		return 1
	if s > 0.58:
		return 0
	if s > 0.38:
		return 2
	return 3


func _layer(layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = TILESET
	return layer


func _save_scenes(report: Dictionary) -> void:
	var map := Node2D.new()
	map.name = "Map"
	map.set_script(load("res://scripts/world/region_map.gd"))
	map.y_sort_enabled = true
	map.set("geo_west", hub.west)
	map.set("geo_north", hub.north)
	map.set("meters_per_tile", mpt)
	map.set("meters_per_degree", mpd)
	map.set("size_in_tiles", Vector2i(w, h))
	map.set("area_map_path", _area_map_path())

	var below_layer := _layer("Below")
	below_layer.z_index = -11
	below_layer.modulate = HAZE
	var ground := _layer("Ground")
	ground.z_index = -10
	var blocker := _layer("Blocker")
	blocker.visible = false
	var flora_layer := _layer("Flora")
	flora_layer.y_sort_enabled = true
	var canopy := _layer("OakCanopy")
	canopy.y_sort_enabled = true
	canopy.set_script(load("res://scripts/world/seasonal_canopy.gd"))
	for layer in [below_layer, ground, blocker, flora_layer, canopy]:
		map.add_child(layer)

	# Building cells are not stamped as tiles: a cell is 35 to 45 m, so a
	# sprite on each made dense grids. hub_buildings.gd places one building to
	# a footprint after the spawns and objects are known.
	var building_cells := {}
	for j in h:
		for i in w:
			var k := j * w + i
			var atlas := Vector2i(_variant(i, j), kind[k])
			var target := below_layer if below[k] else ground
			target.set_cell(Vector2i(i, j), Art.SOURCE_TERRAIN, atlas, _shade_alt(k))
			if flora[k] >= 0 and Buildings.is_building(flora[k]):
				building_cells[Vector2i(i, j)] = flora[k]
			elif flora[k] >= 0:
				var frame := Terrain.frame_coords(flora[k])
				flora_layer.set_cell(Vector2i(i, j), Art.SOURCE_FLORA, frame)
				if flora[k] == Terrain.Flora.BLACK_OAK_TRUNK:
					canopy.set_cell(Vector2i(i, j), Art.SOURCE_FLORA, Terrain.frame_coords(Terrain.Flora.BLACK_OAK_CANOPY))
	# Collision: unwalkable cells that touch walkable ground, plus a ring
	# just outside the map.
	for j in range(-1, h + 1):
		for i in range(-1, w + 1):
			var c := Vector2i(i, j)
			if in_map(c) and walkable[idx(c)]:
				continue
			var touches := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := c + Vector2i(dx, dy)
					if in_map(n) and walkable[idx(n)]:
						touches = true
			if touches:
				blocker.set_cell(c, Art.SOURCE_BLOCKER, Vector2i.ZERO)

	var objects := _group(map, "Objects")
	objects.y_sort_enabled = true
	for obj in _objects:
		var node: Node2D = (load(obj.scene) as PackedScene).instantiate()
		node.position = cell_center(obj.cell) + Vector2(0, 4)
		match obj.scene:
			INFO_SIGN:
				node.name = "Sign_" + _node_name(obj.title)
				node.set("title", obj.title)
				node.set("text", obj.text)
			TRAVEL_POINT:
				node.name = "Travel_" + _node_name(obj.label)
				node.set("label", obj.label)
			SHUTTLE_STOP:
				node.name = "Shuttle_" + _node_name(obj.label)
				node.set("stop_name", obj.label)
			REGION_DOOR:
				node.name = "Door_" + _node_name(obj.label)
				node.set("label", obj.label)
				node.set("target_region", obj.target_region)
				node.set("target_spawn", obj.target_spawn)
		objects.add_child(node)

	var places := _group(map, "Places")
	for place in _places:
		var marker := Marker2D.new()
		marker.set_script(load("res://scripts/world/place.gd"))
		marker.name = _node_name(place.name)
		marker.position = place.pos
		marker.set("display_name", place.name)
		marker.set("radius", place.radius)
		marker.set("show_banner", place.banner)
		marker.set("show_on_map", place.label)
		places.add_child(marker)

	var spawns := _group(map, "Spawns")
	for spawn_name: String in _spawns:
		var marker := Marker2D.new()
		marker.name = spawn_name
		marker.position = cell_center(_spawns[spawn_name])
		spawns.add_child(marker)

	var exits := _group(map, "Exits")
	for exit in _exits:
		var area := Area2D.new()
		area.set_script(load("res://scripts/world/region_exit.gd"))
		area.name = "%s_%s" % [_node_name(exit.road), exit.edge]
		area.position = cell_center(exit.cell)
		area.set("travel_to", exit.get("travel_to", ""))
		area.set("message", exit.get("message", ""))
		area.set("label", exit.road)
		var shape := CollisionShape2D.new()
		shape.name = "Shape"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(T * 3, T) if exit.edge in ["north", "south"] else Vector2(T, T * 3)
		shape.shape = rect
		area.add_child(shape)
		exits.add_child(area)

	var hotel_at := Vector2(-1, -1)
	if content.get("style", "") == "wawona" and _spawns.has("wawona_hotel"):
		hotel_at = cell_center(_spawns["wawona_hotel"])
	Buildings.add_to(map, building_cells, hotel_at)

	for child in map.get_children():
		_own(child, map)
	var generated_path := "res://scenes/regions/generated/%s_map.tscn" % hub.id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(generated_path.get_base_dir()))
	var packed := PackedScene.new()
	assert(packed.pack(map) == OK)
	assert(ResourceSaver.save(packed, generated_path) == OK)
	packed.take_over_path(generated_path)
	map.free()
	_ensure_wrapper(packed)


func _group(parent: Node, group_name: String) -> Node2D:
	var node := Node2D.new()
	node.name = group_name
	parent.add_child(node)
	return node


func _own(node: Node, owner: Node) -> void:
	node.owner = owner
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		_own(child, owner)


static func _node_name(text: String) -> String:
	var out := ""
	for ch in text:
		out += ch if ch.is_valid_identifier() or ch.is_valid_int() else ("_" if ch == " " else "")
	return out


## Adds the hub's forage spawner (see scripts/world/forage_spawner.gd). It
## reads the generated terrain, flora, and oaks. Its name is unique across
## the project because saves key persist nodes by name.
static func add_forage(region: Node, hub_id: String, amount_scale: float) -> void:
	var entities := region.get_node("Entities")
	var node_name := "Forage_" + hub_id
	if entities.has_node(node_name):
		return
	var forage := Node2D.new()
	forage.name = node_name
	forage.y_sort_enabled = true
	forage.set_script(load("res://scripts/world/forage_spawner.gd"))
	entities.add_child(forage)
	forage.owner = region
	forage.set("ground", region.get_node("Map/Ground"))
	forage.set("flora", region.get_node("Map/Flora"))
	forage.set("oak_canopy", region.get_node("Map/OakCanopy"))
	forage.set("amount_scale", amount_scale)


## The hand-editable scene that holds the generated map. Created once.
func _ensure_wrapper(map_scene: PackedScene) -> void:
	var path := hub.scene_path()
	if FileAccess.file_exists(path):
		return
	var region := Node2D.new()
	region.name = hub.display_name.replace(" ", "")
	region.set_script(load("res://scripts/world/region.gd"))
	region.y_sort_enabled = true
	region.set("region_id", hub.id)
	region.set("hub_id", hub.id)
	region.set("display_name", hub.display_name)
	var map := map_scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	region.add_child(map)
	map.owner = region
	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	region.add_child(entities)
	entities.owner = region
	var markers := Node2D.new()
	markers.name = "Markers"
	region.add_child(markers)
	markers.owner = region
	add_forage(region, hub.id, 6.0 if hub.id == "yosemite_valley" else 4.0)
	var packed := PackedScene.new()
	assert(packed.pack(region) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	region.free()


# ---------------------------------------------------------------- area map

const MAP_COLORS := {
	Terrain.FOREST: "6d8547", Terrain.MEADOW: "86bd62", Terrain.WET_MEADOW: "6aa864",
	Terrain.FOOTHILL: "b8a864", Terrain.FIR: "556e42", Terrain.SUBALPINE: "8e9a66",
	Terrain.SCRUB: "6b7446", Terrain.GRANITE: "c6c2b7", Terrain.CLIFF: "a09c91",
	Terrain.TALUS: "8a857a", Terrain.SCREE: "a29d8f", Terrain.RIVER: "3a74b0",
	Terrain.LAKE: "2f64a0", Terrain.CREEK: "5b8fbf", Terrain.FALLS: "dce9f3",
	Terrain.SAND: "e2d6b4", Terrain.ROAD: "e8dcc0", Terrain.PARKING: "c8c0b0",
	Terrain.BRIDGE: "e8dcc0", Terrain.TRAIL: "d8b884", Terrain.PAVED: "d8d0c0",
	Terrain.CAMP: "b39a6c", Terrain.SNOW: "f4f8fb", Terrain.ALPINE: "b0aca2",
	Terrain.LAWN: "7fbf60", Terrain.BUILT: "a8a090",
}


func _area_map_path() -> String:
	return "res://assets/map/areas/%s.png" % hub.id


func _save_area_map() -> void:
	# Hubs with an illustrated map (tools/mapgen/oblique) keep it: the view file sits beside the picture.
	if FileAccess.file_exists(_area_map_path().replace(".png", "_view.json")):
		print("  keeping the illustrated area map for %s" % hub.id)
		return
	var image := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for j in h:
		for i in w:
			var k := j * w + i
			var col := Color(MAP_COLORS.get(kind[k], "808080"))
			var fl := flora[k]
			if fl >= 0:
				if fl >= Terrain.Flora.TENT_CABIN and fl <= Terrain.Flora.WHITE_HOUSE:
					col = Color("8a4a3a")
				elif fl not in [Terrain.Flora.BOULDER, Terrain.Flora.ERRATIC, Terrain.Flora.CAMP_TENT]:
					col = col.darkened(0.22)
			if kind[k] not in [Terrain.ROAD, Terrain.BRIDGE, Terrain.RIVER, Terrain.LAKE, Terrain.CREEK]:
				col = col * lerpf(0.72, 1.12, clampf(shade[k] / 0.9, 0.0, 1.0))
				col.a = 1.0
			if below[k]:
				col = col.lerp(HAZE, 0.45)
			image.set_pixel(i, j, col)
	var path := _area_map_path()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	image.save_png(path)
