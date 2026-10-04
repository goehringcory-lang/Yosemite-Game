extends RefCounted
## Renders the whole-park relief map and works out the driving routes between
## hubs by pathfinding along the real road network.

const Dem = preload("res://tools/mapgen/dem.gd")

const MAP_PATH := "res://assets/map/park_map.png"
const ROUTES_PATH := "res://data/park/routes.json"
const MAP_HEIGHT := 256

## Hypsometric tints (meters -> color), park-map style.
const ELEVATION_COLORS := [
	[300.0, "b9b98c"], [800.0, "a8b07a"], [1200.0, "86a464"], [1700.0, "638c50"],
	[2200.0, "5a8050"], [2700.0, "83976c"], [3100.0, "a8a598"], [3500.0, "d2cfc6"], [4000.0, "ecebe6"],
]
const OUTSIDE := Color("e6dfc8")
const WATER := Color("4a86c8")
const RIVER := Color("3f7fc0")
const ROAD := Color("f4e2b0")
const BOUNDARY := Color("3a4a30")

## Average driving speeds (mph) by road name, tuned so travel times match the
## park's published estimates (Yosemite Guide: Valley to Wawona or Glacier
## Point about 1 hr, to Tuolumne Meadows about 1.5 hr).
const SPEEDS := {"Tioga Road": 42.0, "Tioga Pass Road": 42.0, "Big Oak Flat Road": 35.0,
	"El Portal Road": 35.0, "Wawona Road": 28.0, "Glacier Point Road": 30.0}
const DEFAULT_SPEED := 25.0
## Roads inside Yosemite Valley, left out of the "via" text.
const LOCAL_ROADS := ["Northside Drive", "Southside Drive"]
## Road names that close seasonally (see Park.SEASONAL).
const CLOSURES := {"Tioga Road": "tioga_road", "Tioga Pass Road": "tioga_road", "Glacier Point Road": "glacier_point_road"}

var osm: Dictionary
var dem: Dem
var size := Vector2i.ZERO
var mpd := Vector2.ONE


func _init(park_osm: Dictionary, elevation: Dem) -> void:
	osm = park_osm
	dem = elevation
	mpd = ParkAtlas.meters_per_degree((ParkAtlas.MAP_NORTH + ParkAtlas.MAP_SOUTH) / 2.0)
	var km_w := (ParkAtlas.MAP_EAST - ParkAtlas.MAP_WEST) * mpd.x
	var km_h := (ParkAtlas.MAP_NORTH - ParkAtlas.MAP_SOUTH) * mpd.y
	size = Vector2i(roundi(MAP_HEIGHT * km_w / km_h), MAP_HEIGHT)


func to_px(lon: float, lat: float) -> Vector2:
	return ParkAtlas.geo_to_map(Vector2(lon, lat), Vector2(size))


func px_lonlat(x: float, y: float) -> Vector2:
	return Vector2(ParkAtlas.MAP_WEST + x / size.x * (ParkAtlas.MAP_EAST - ParkAtlas.MAP_WEST),
		ParkAtlas.MAP_NORTH - y / size.y * (ParkAtlas.MAP_NORTH - ParkAtlas.MAP_SOUTH))


# ---------------------------------------------------------------- map image

func build_map() -> void:
	print("  park map: %d x %d px, about %d m per pixel" % [size.x, size.y, roundi((ParkAtlas.MAP_NORTH - ParkAtlas.MAP_SOUTH) * mpd.y / size.y)])
	var corners := PackedFloat32Array()
	corners.resize((size.x + 1) * (size.y + 1))
	for y in size.y + 1:
		for x in size.x + 1:
			var ll := px_lonlat(x, y)
			corners[y * (size.x + 1) + x] = dem.sample(ll.x, ll.y)
	var inside := _park_mask()
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var pixel_m := Vector2(mpd.x * (ParkAtlas.MAP_EAST - ParkAtlas.MAP_WEST) / size.x,
		mpd.y * (ParkAtlas.MAP_NORTH - ParkAtlas.MAP_SOUTH) / size.y)
	var light := Vector3(-0.5, 0.5, 0.7071).normalized()
	for y in size.y:
		for x in size.x:
			var a := corners[y * (size.x + 1) + x]
			var b := corners[y * (size.x + 1) + x + 1]
			var c := corners[(y + 1) * (size.x + 1) + x]
			var d := corners[(y + 1) * (size.x + 1) + x + 1]
			var e := (a + b + c + d) / 4.0
			var dzdx := ((b + d) - (a + c)) / (2.0 * pixel_m.x)
			var dzdy := ((a + b) - (c + d)) / (2.0 * pixel_m.y)
			var slope := rad_to_deg(atan(Vector2(dzdx, dzdy).length()))
			var normal := Vector3(-dzdx * 3.0, -dzdy * 3.0, 1.0).normalized()
			var hs := maxf(normal.dot(light), 0.0)
			var col := _elevation_color(e)
			if slope > 22.0:
				col = col.lerp(Color("a9a497"), clampf((slope - 22.0) / 18.0, 0.0, 0.7))
			col = col * lerpf(0.62, 1.16, clampf(hs / 0.85, 0.0, 1.0))
			col.a = 1.0
			if not inside[y * size.x + x]:
				col = col.lerp(OUTSIDE, 0.55)
			image.set_pixel(x, y, col)
	_draw_water(image)
	_draw_roads(image)
	_draw_boundary(image)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAP_PATH.get_base_dir()))
	image.save_png(MAP_PATH)


func _elevation_color(e: float) -> Color:
	var stops: Array = ELEVATION_COLORS
	if e <= stops[0][0]:
		return Color(stops[0][1])
	for i in stops.size() - 1:
		if e <= stops[i + 1][0]:
			var t: float = (e - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
			return Color(stops[i][1]).lerp(Color(stops[i + 1][1]), t)
	return Color(stops[-1][1])


func _rings_of(e: Dictionary) -> Array:
	var rings: Array = []
	if e.type == "way":
		rings.append(_px_points(e.get("geometry", [])))
	elif e.type == "relation":
		for m: Dictionary in e.get("members", []):
			if m.get("type", "") == "way" and m.has("geometry"):
				rings.append(_px_points(m.geometry))
	return rings


func _px_points(geometry: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Variant in geometry:
		if p is Dictionary:
			out.append(to_px(p.lon, p.lat))
	return out


## Even-odd scanline fill of pixel centers. Returns the filled pixels.
func _fill(rings: Array) -> Array[Vector2i]:
	var filled: Array[Vector2i] = []
	var min_y := INF
	var max_y := -INF
	for ring: PackedVector2Array in rings:
		for p in ring:
			min_y = minf(min_y, p.y)
			max_y = maxf(max_y, p.y)
	for y in range(maxi(0, floori(min_y)), mini(size.y, ceili(max_y))):
		var yc := y + 0.5
		var xs: Array[float] = []
		for ring: PackedVector2Array in rings:
			for k in ring.size() - 1:
				var a := ring[k]
				var b := ring[k + 1]
				if (a.y <= yc) != (b.y <= yc):
					xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for p in range(0, xs.size() - 1, 2):
			for x in range(maxi(0, ceili(xs[p] - 0.5)), mini(size.x - 1, floori(xs[p + 1] - 0.5)) + 1):
				filled.append(Vector2i(x, y))
	return filled


func _park_mask() -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(size.x * size.y)
	for e: Dictionary in osm.get("elements", []):
		if _is_boundary(e):
			for p in _fill(_rings_of(e)):
				mask[p.y * size.x + p.x] = 1
	return mask


func _is_boundary(e: Dictionary) -> bool:
	var tags: Dictionary = e.get("tags", {})
	return e.type == "relation" and tags.get("name", "") == "Yosemite National Park" and tags.get("boundary", "") in ["protected_area", "national_park"]


func _line(image: Image, a: Vector2, b: Vector2, col: Color, dash := 0) -> void:
	var steps := ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for s in steps + 1:
		var p := a.lerp(b, float(s) / steps).floor()
		if dash > 0 and int(p.x + p.y) % (dash * 2) >= dash:
			continue
		if p.x >= 0 and p.y >= 0 and p.x < size.x and p.y < size.y:
			image.set_pixel(int(p.x), int(p.y), col)


func _polyline(image: Image, pts: PackedVector2Array, col: Color, dash := 0) -> void:
	for k in pts.size() - 1:
		_line(image, pts[k], pts[k + 1], col, dash)


func _draw_water(image: Image) -> void:
	for e: Dictionary in osm.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		if tags.get("natural", "") == "glacier":
			for p in _fill(_rings_of(e)):
				image.set_pixelv(p, Color("f4f8fb"))
		elif tags.get("natural", "") == "water":
			for p in _fill(_rings_of(e)):
				image.set_pixelv(p, WATER)
	for e: Dictionary in osm.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		if e.type == "way" and tags.get("waterway", "") == "river":
			_polyline(image, _px_points(e.get("geometry", [])), RIVER)


func _draw_roads(image: Image) -> void:
	for e: Dictionary in osm.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		if e.type == "way" and tags.get("highway", "") in ["motorway", "trunk", "primary", "secondary"]:
			_polyline(image, _px_points(e.get("geometry", [])), ROAD)
		elif e.type == "way" and tags.get("highway", "") == "tertiary" and tags.get("name", "") in ["Glacier Point Road", "Hetch Hetchy Road", "Mariposa Grove Road"]:
			_polyline(image, _px_points(e.get("geometry", [])), ROAD)


func _draw_boundary(image: Image) -> void:
	for e: Dictionary in osm.get("elements", []):
		if _is_boundary(e):
			for ring in _rings_of(e):
				_polyline(image, ring, BOUNDARY, 2)


# ---------------------------------------------------------------- routes

## Finds the driving route between every pair of road-accessible hubs.
func build_routes() -> void:
	var coords := {} # node id -> Vector2(lon, lat)
	var edges := {} # node id -> Array of [other id, meters, road name]
	for e: Dictionary in osm.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		if e.type != "way" or not tags.get("highway", "") in ["motorway", "trunk", "primary", "secondary", "tertiary",
				"unclassified", "residential", "primary_link", "secondary_link", "tertiary_link"]:
			continue
		var nodes: Array = e.get("nodes", [])
		var geometry: Array = e.get("geometry", [])
		if nodes.size() != geometry.size():
			continue
		var road: String = tags.get("name", "")
		for k in nodes.size():
			if geometry[k] is Dictionary:
				coords[int(nodes[k])] = Vector2(geometry[k].lon, geometry[k].lat)
		for k in nodes.size() - 1:
			var a := int(nodes[k])
			var b := int(nodes[k + 1])
			if not coords.has(a) or not coords.has(b):
				continue
			var meters := _meters(coords[a], coords[b])
			edges.get_or_add(a, []).append([b, meters, road])
			edges.get_or_add(b, []).append([a, meters, road])

	var hubs: Array[HubData] = []
	for hub in ParkAtlas.HUBS:
		if hub.road_access:
			hubs.append(hub)
	var anchors := {}
	for hub in hubs:
		anchors[hub.id] = _nearest_node(coords, edges, Vector2(hub.longitude, hub.latitude))
	var routes: Array = []
	for i in hubs.size():
		var previous := _dijkstra(edges, anchors[hubs[i].id])
		for j in range(i + 1, hubs.size()):
			var route := _route(hubs[i], hubs[j], anchors[hubs[j].id], previous, coords)
			if route.is_empty():
				push_warning("No road route from %s to %s" % [hubs[i].id, hubs[j].id])
				continue
			routes.append(route)
			print("  %s <-> %s: %.1f mi, %d min via %s%s" % [route.a, route.b, route.miles, route.minutes_ab,
				route.via, "" if route.closures.is_empty() else " (seasonal: %s)" % ", ".join(route.closures)])
	var file := FileAccess.open(ROUTES_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"generated_by": "tools/mapgen", "routes": routes}, "\t"))


func _meters(a: Vector2, b: Vector2) -> float:
	var local := ParkAtlas.meters_per_degree((a.y + b.y) / 2.0)
	return Vector2((b.x - a.x) * local.x, (b.y - a.y) * local.y).length()


func _nearest_node(coords: Dictionary, edges: Dictionary, lonlat: Vector2) -> int:
	var best := -1
	var best_d := INF
	for id: int in edges:
		var d := _meters(coords[id], lonlat)
		if d < best_d:
			best_d = d
			best = id
	return best


## Shortest-path tree from [param start]: node id -> [previous id, meters, road].
func _dijkstra(edges: Dictionary, start: int) -> Dictionary:
	var dist := {start: 0.0}
	var previous := {start: [-1, 0.0, ""]}
	var heap_cost: Array[float] = [0.0]
	var heap_node: Array[int] = [start]
	var done := {}
	while not heap_node.is_empty():
		var node := heap_node[0]
		_heap_pop(heap_cost, heap_node)
		if done.has(node):
			continue
		done[node] = true
		for edge: Array in edges.get(node, []):
			var next: int = edge[0]
			var nd: float = dist[node] + edge[1]
			if nd < dist.get(next, INF):
				dist[next] = nd
				previous[next] = [node, edge[1], edge[2]]
				_heap_push(heap_cost, heap_node, nd, next)
	return previous


func _heap_push(cost: Array[float], node: Array[int], c: float, n: int) -> void:
	cost.append(c)
	node.append(n)
	var i := cost.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if cost[parent] <= cost[i]:
			break
		_heap_swap(cost, node, i, parent)
		i = parent


func _heap_pop(cost: Array[float], node: Array[int]) -> void:
	var last := cost.size() - 1
	_heap_swap(cost, node, 0, last)
	cost.remove_at(last)
	node.remove_at(last)
	var i := 0
	while true:
		var smallest := i
		for child in [2 * i + 1, 2 * i + 2]:
			if child < cost.size() and cost[child] < cost[smallest]:
				smallest = child
		if smallest == i:
			break
		_heap_swap(cost, node, i, smallest)
		i = smallest


func _heap_swap(cost: Array[float], node: Array[int], a: int, b: int) -> void:
	var c := cost[a]
	cost[a] = cost[b]
	cost[b] = c
	var n := node[a]
	node[a] = node[b]
	node[b] = n


func _route(from: HubData, to: HubData, target: int, previous: Dictionary, coords: Dictionary) -> Dictionary:
	if not previous.has(target):
		return {}
	var path_ids: Array[int] = []
	var path_roads: Array[String] = []
	var road_meters := {}
	var road_order: Array[String] = []
	var total := 0.0
	var minutes := 0.0
	var closures := {}
	var node := target
	while node != -1:
		path_ids.push_front(node)
		var step: Array = previous[node]
		var road: String = step[2]
		var meters: float = step[1]
		total += meters
		minutes += meters / 1609.34 / SPEEDS.get(road, DEFAULT_SPEED) * 60.0
		if road != "":
			road_meters[road] = road_meters.get(road, 0.0) + meters
			path_roads.push_front(road)
		if CLOSURES.has(road):
			closures[CLOSURES[road]] = true
		node = step[0]
	# Name the roads that make up most of the trip, in driving order.
	for road in path_roads:
		if road_meters[road] > 2500.0 and road not in road_order and road not in LOCAL_ROADS:
			road_order.append(road)
	var path: Array = []
	var last := Vector2.INF
	for k in path_ids.size():
		var p: Vector2 = coords[path_ids[k]]
		if k == 0 or k == path_ids.size() - 1 or _meters(last, p) > 250.0:
			path.append([snappedf(p.x, 0.00001), snappedf(p.y, 0.00001)])
			last = p
	var rounded := maxi(10, roundi(minutes / 10.0) * 10)
	return {
		"id": "%s-%s" % [from.id, to.id],
		"a": from.id,
		"b": to.id,
		"mode": "drive",
		"via": _join(road_order.slice(0, 3)),
		"miles": snappedf(total / 1609.34, 0.1),
		"minutes_ab": rounded,
		"minutes_ba": rounded,
		"closures": closures.keys(),
		"path": path,
		"spawn_a": "arrival",
		"spawn_b": "arrival",
	}


static func _join(names: Array) -> String:
	if names.size() <= 1:
		return "" if names.is_empty() else str(names[0])
	return ", ".join(names.slice(0, names.size() - 1)) + " and " + str(names[-1])
