class_name WallSourceStub
extends WallSource
## Stand-in wall source until thread 2's lands (and kept for tests): the
## frozen fixture pitch for route "v2_fixture", else a plain ladder of
## alternating holds with bolts or a crack, sized from the route.

const FIXTURE := "res://data/climb/v2/fixture_pitch.json"
const FIXTURE_ROUTE := "v2_fixture"


func build_pitch(route: RouteData, pitch: int, _seed: int) -> V2Wall:
	var route_id := route.id if route else FIXTURE_ROUTE
	if route_id == FIXTURE_ROUTE:
		var w := V2Wall.from_dict(V2Data.load_json(FIXTURE))
		w.route_id = route_id
		w.pitch = pitch
		return w
	return ladder(route, pitch)


## A simple climbable pitch: holds every 0.55 m, alternating sides, feet
## between, a bolt every 3 m (or a hand crack on a "cams" route), an anchor.
static func ladder(route: RouteData, pitch: int) -> V2Wall:
	var w := V2Wall.new()
	w.route_id = route.id if route else ""
	w.pitch = pitch
	var n := maxi(1, route.pitches.size()) if route else 1
	var height := clampf(float(route.total_height_ft() if route else 100) * 0.3048 / n, 10.0, 40.0)
	w.size = Vector2(6, height + 1.5)
	w.start = Vector2(3, 0)
	w.top = Vector2(3, height)
	var bolted := route == null or route.protection == "bolts"
	var y := 1.6
	var i := 0
	while y < height - 0.3:
		var h := V2Hold.new()
		h.id = "h%d" % i
		h.pos = Vector2(2.5 if i % 2 == 0 else 3.5, y)
		h.kind = &"jug" if i % 6 == 5 else &"edge"
		h.size = 0.9 if h.kind == &"jug" else 0.6
		w.holds.append(h)
		var f := V2Hold.new()
		f.id = "f%d" % i
		f.pos = Vector2(2.7 if i % 2 == 0 else 3.3, y - 1.2)
		f.hand = false
		w.holds.append(f)
		y += 0.55
		i += 1
	var top := V2Hold.new()
	top.id = "anchor_hold"
	top.pos = w.top
	top.kind = &"jug"
	top.size = 1.0
	top.tags = PackedStringArray(["anchor"])
	w.holds.append(top)
	if bolted:
		var b := 3.0
		var k := 0
		while b < height - 1.0:
			var p := V2Piece.new()
			p.id = "bolt%d" % k
			p.pos = Vector2(3.0, b)
			p.fixed = true
			w.fixed.append(p)
			b += 3.0
			k += 1
	else:
		var c := V2Crack.new()
		c.id = "crack0"
		c.points = PackedVector2Array([Vector2(4.3, 1.0), Vector2(4.3, height - 1.0)])
		c.widths = PackedFloat32Array([4.0, 4.0])
		w.cracks.append(c)
	var anchor := V2Piece.new()
	anchor.id = "anchor"
	anchor.kind = &"anchor"
	anchor.pos = w.top + Vector2(0, 0.3)
	anchor.fixed = true
	w.fixed.append(anchor)
	return w
