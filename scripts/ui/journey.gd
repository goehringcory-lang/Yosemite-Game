class_name Journey
extends CanvasLayer
## A trip that takes clock time (a drive, a long trail, a shuttle ride) shown
## on the painted park map instead of a black screen: the world dims, a framed
## piece of the map opens over it, a marker travels the real road or trail
## while the clock runs from leaving to arriving, and the places it passes
## light up. The next place is laid out under the map while it plays, so the
## map lifts straight onto it. Any key skips.
##
## World runs it (see World._journey). Headless (the tests) it is never made.
##
##   var journey := Journey.new()
##   add_child(journey)
##   await journey.cover()                       # the world dims, the map opens
##   ... swap the region under it ...
##   await journey.travel(info)                  # the marker runs the route
##   await journey.lift()                        # the map lifts off the new place

const PARK_MAP: Texture2D = preload("res://assets/map/park_map.png")

## The frame's picture, in UI pixels (480x270, see UiScale).
const PICTURE := Rect2(92, 46, 296, 168)
## Seconds the map takes to open and to lift.
const COVER_TIME := 0.3
const LIFT_TIME := 0.4
## How long the marker takes: BASE_TIME plus PER_ROOT_MINUTE for each square
## root of the trip's minutes (a 15-minute ride ~1.7 s, a 5-hour hike ~3.9 s).
const BASE_TIME := 1.0
const PER_ROOT_MINUTE := 0.17
## The most the map is blown up (whole pixels only, so it stays crisp).
const MOST_ZOOM := 4
## Map pixels kept around the route when choosing how much map to show.
const MARGIN := 10.0
## A route whose ends are both this close (meters) to the trip's ends is the
## road being driven; further, the trip draws a straight line instead.
const ROAD_SNAP := 1500.0
## A sight lights up while the marker is this close, in UI pixels.
const PASSING := 14.0
## A road is only followed if it's at most this many times as long as the
## straight way (Glacier Point Road ends right above Curry Village, but
## the drive there is no way to cross the Valley floor).
const MOST_DETOUR := 2.5

const INK := Color("2a1b14")
const GOLD := Color("f1cf6a")
const GOLD_SHADE := Color("d8a63b")
const CREAM := Color("f5eee0")
const PARCHMENT := Color("d6bd88")
const DIM := Color(0.96, 0.93, 0.88, 0.75)
const ROUTE_AHEAD := Color("93918f")
const BACKING := Color(0.08, 0.06, 0.05, 0.85)
const WOOD_DARK := Color("2a1b14")
const WOOD_MID := Color("7e531c")
const WOOD_LIGHT := Color("ad7a22")
const WOOD_BEVEL := Color("92693d")
const WOOD_SHADE := Color("6b4829")
const FONT_SIZE := 8

## Places named on the map as the marker passes them, besides the hubs:
## real longitude/latitude (x/y).
const SIGHTS := [
	{"name": "Half Dome", "at": Vector2(-119.5332, 37.7459)},
	{"name": "El Capitan", "at": Vector2(-119.6377, 37.7340)},
	{"name": "Yosemite Falls", "at": Vector2(-119.5966, 37.7566)},
	{"name": "Bridalveil Fall", "at": Vector2(-119.6465, 37.7168)},
	{"name": "Tunnel View", "at": Vector2(-119.6772, 37.7156)},
	{"name": "Vernal Fall", "at": Vector2(-119.5440, 37.7277)},
	{"name": "Nevada Fall", "at": Vector2(-119.5330, 37.7250)},
	{"name": "Sentinel Dome", "at": Vector2(-119.5844, 37.7231)},
	{"name": "Clouds Rest", "at": Vector2(-119.4895, 37.7676)},
	{"name": "Crane Flat", "at": Vector2(-119.8000, 37.7530)},
	{"name": "Olmsted Point", "at": Vector2(-119.4850, 37.8110)},
	{"name": "Tenaya Lake", "at": Vector2(-119.4560, 37.8300)},
	{"name": "Cathedral Peak", "at": Vector2(-119.4060, 37.8476)},
	{"name": "Lembert Dome", "at": Vector2(-119.3548, 37.8786)},
	{"name": "Mariposa Grove", "at": Vector2(-119.6020, 37.5145)},
]

## Trails that bend well away from a straight line, by "from>to" region ids:
## the real longitude/latitude they pass through on the way.
const TRAIL_BENDS := {
	"happy_isles>glacier_point": [Vector2(-119.5440, 37.7277), Vector2(-119.5330, 37.7250), Vector2(-119.5520, 37.7190), Vector2(-119.5640, 37.7230)],
	"glacier_point>happy_isles": [Vector2(-119.5640, 37.7230), Vector2(-119.5520, 37.7190), Vector2(-119.5330, 37.7250), Vector2(-119.5440, 37.7277)],
	"little_yosemite_valley>happy_isles": [Vector2(-119.5330, 37.7250), Vector2(-119.5440, 37.7277)],
	"little_yosemite_valley>half_dome": [Vector2(-119.5190, 37.7420)],
	"half_dome>little_yosemite_valley": [Vector2(-119.5190, 37.7420)],
}

var _canvas: Control
var _alpha := 0.0
## What is being drawn: the route in UI pixels, how far along (0..1).
var _points := PackedVector2Array()
var _lengths: Array[float] = []
var _progress := 0.0
var _title := ""
var _subtitle := ""
var _start_minutes := 0
var _minutes := 0
var _miles := 0.0
var _on_foot := false
var _src := Rect2()
var _dest := Rect2()
var _zoom := 1
## Sights inside the picture: {name, at (UI px), hub}.
var _sights: Array[Dictionary] = []
var _skip := false
var _running := false


func _init() -> void:
	name = "Journey"
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiScale.layer(self)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	UiScale.fit(_canvas)
	_canvas.draw.connect(_draw_journey)
	add_child(_canvas)


## The world dims and the empty frame opens (the old place still shows
## through the dimming).
func cover() -> void:
	await _fade_to(1.0, COVER_TIME)


## Runs the marker along the trip in [param info]:
## {from, to (longitude/latitude), from_region, to_region, title, subtitle,
## start_minutes, minutes, miles, on_foot, path (optional longitude/latitude
## points of the road)}.
func travel(info: Dictionary) -> void:
	_title = info.get("title", "")
	_subtitle = info.get("subtitle", "")
	_start_minutes = int(info.get("start_minutes", GameClock.minutes))
	_minutes = int(info.get("minutes", 0))
	_miles = float(info.get("miles", 0.0))
	_on_foot = bool(info.get("on_foot", false))
	var lonlats := route_lonlats(info)
	_frame(lonlats)
	_running = true
	var seconds := BASE_TIME + PER_ROOT_MINUTE * sqrt(maxf(_minutes, 1))
	var t := 0.0
	while t < seconds and not _skip:
		await get_tree().process_frame
		t += get_process_delta_time()
		_progress = ease_trip(clampf(t / seconds, 0.0, 1.0))
		_canvas.queue_redraw()
	_progress = 1.0
	_canvas.queue_redraw()
	# A moment at the end to read where you are.
	if not _skip:
		await get_tree().create_timer(0.35, true, false, true).timeout
	_running = false


## The map lifts off the new place.
func lift() -> void:
	await _fade_to(0.0, LIFT_TIME)


func _input(event: InputEvent) -> void:
	if not _running:
		return
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed():
		_skip = true
		get_viewport().set_input_as_handled()


func _fade_to(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_method(func(a: float) -> void:
		_alpha = a
		_canvas.queue_redraw(), _alpha, alpha, seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Slow away, steady, slow in: the clock and marker move like a drive.
static func ease_trip(x: float) -> float:
	return x * x * (3.0 - 2.0 * x) * 0.6 + x * 0.4


## The trip as longitude/latitude points: the stretch of a park road both
## ends lie on (driving), a trail's known bends (on foot), or else straight.
static func route_lonlats(info: Dictionary) -> PackedVector2Array:
	var from: Vector2 = info.from
	var to: Vector2 = info.to
	var out := PackedVector2Array([from])
	var bends: Array = TRAIL_BENDS.get("%s>%s" % [info.get("from_region", ""), info.get("to_region", "")], [])
	if not bends.is_empty():
		out.append_array(PackedVector2Array(bends))
	elif not bool(info.get("on_foot", false)):
		var road := road_between(from, to, info.get("path", []))
		out.append_array(road)
	out.append(to)
	return out


## The stretch of road from near [param from] to near [param to]: of
## [param preferred] if it reaches both, else of any of the park's routes
## (Park.routes) that does. Empty when no road does.
static func road_between(from: Vector2, to: Vector2, preferred: Array = []) -> PackedVector2Array:
	var candidates: Array = []
	if not preferred.is_empty():
		candidates.append(preferred)
	for route: Dictionary in Park.routes:
		var path: Array = []
		for point: Array in route.path:
			path.append(Vector2(point[0], point[1]))
		candidates.append(path)
	var best := PackedVector2Array()
	var best_score := INF
	for path: Array in candidates:
		var i := _nearest(path, from)
		var j := _nearest(path, to)
		if i < 0 or i == j:
			continue
		var gap_a := Wayfinding.meters_between(from, path[i]).length()
		var gap_b := Wayfinding.meters_between(to, path[j]).length()
		if gap_a > ROAD_SNAP or gap_b > ROAD_SNAP or gap_a + gap_b >= best_score:
			continue
		var straight := Wayfinding.meters_between(from, to).length()
		var along := 0.0
		for k in range(mini(i, j), maxi(i, j)):
			along += Wayfinding.meters_between(path[k], path[k + 1]).length()
		if along > straight * MOST_DETOUR + 500.0:
			continue
		best_score = gap_a + gap_b
		best = PackedVector2Array()
		var step := 1 if j > i else -1
		var k := i
		while true:
			best.append(path[k])
			if k == j:
				break
			k += step
	return best


static func _nearest(path: Array, to: Vector2) -> int:
	var best := -1
	var best_d := INF
	for k in path.size():
		var d := Wayfinding.meters_between(to, path[k]).length_squared()
		if d < best_d:
			best_d = d
			best = k
	return best


## Picks the piece of map to show and how far to blow it up, and works out
## where everything sits in UI pixels.
func _frame(lonlats: PackedVector2Array) -> void:
	var size := PARK_MAP.get_size()
	var on_map := PackedVector2Array()
	for p in lonlats:
		on_map.append(ParkAtlas.geo_to_map(p, size))
	var box := Rect2(on_map[0], Vector2.ZERO)
	for p in on_map:
		box = box.expand(p)
	box = box.grow(MARGIN)
	_zoom = clampi(floori(minf(PICTURE.size.x / box.size.x, PICTURE.size.y / box.size.y)), 1, MOST_ZOOM)
	var src_size := Vector2(floorf(PICTURE.size.x / _zoom), floorf(PICTURE.size.y / _zoom))
	src_size = src_size.min(size)
	var origin := (box.get_center() - src_size / 2.0).round()
	origin = origin.clamp(Vector2.ZERO, size - src_size)
	_src = Rect2(origin, src_size)
	var dest_size := src_size * _zoom
	_dest = Rect2((PICTURE.position + (PICTURE.size - dest_size) / 2.0).floor(), dest_size)
	_points = PackedVector2Array()
	_lengths = [0.0]
	for p in on_map:
		_points.append(_to_screen(p))
		if _points.size() > 1:
			_lengths.append(_lengths[-1] + _points[-1].distance_to(_points[-2]))
	_sights.clear()
	for hub in ParkAtlas.HUBS:
		_add_sight(hub.display_name, Vector2(hub.longitude, hub.latitude), true)
	for sight: Dictionary in SIGHTS:
		_add_sight(sight.name, sight.at, false)


func _add_sight(sight_name: String, lonlat: Vector2, hub: bool) -> void:
	var at := _to_screen(ParkAtlas.geo_to_map(lonlat, PARK_MAP.get_size()))
	if not _dest.grow(-2).has_point(at):
		return
	for other in _sights:
		if other.name == sight_name:
			return
	_sights.append({"name": sight_name, "at": at, "hub": hub})


func _to_screen(map_point: Vector2) -> Vector2:
	return _dest.position + (map_point - _src.position) * _zoom


## Where the marker is now, and the route behind it.
func _marker() -> Dictionary:
	var total: float = _lengths[-1] if not _lengths.is_empty() else 0.0
	var want := total * _progress
	var behind := PackedVector2Array()
	if _points.is_empty():
		return {"at": Vector2.ZERO, "behind": behind}
	behind.append(_points[0])
	for k in range(1, _points.size()):
		if _lengths[k] >= want:
			var span: float = _lengths[k] - _lengths[k - 1]
			var f := 0.0 if span <= 0.0 else (want - _lengths[k - 1]) / span
			var at := _points[k - 1].lerp(_points[k], f)
			behind.append(at)
			return {"at": at, "behind": behind}
		behind.append(_points[k])
	return {"at": _points[-1], "behind": behind}


## A region's name for the map's subtitle, loaded or not.
static func place_name(region_id: String) -> String:
	var listed := Wayfinding._region_name(region_id)
	return listed if listed != "" else region_id.capitalize()


static func clock_text(minutes: int) -> String:
	var hour := floori(minutes / 60.0) % 24
	var h12 := hour % 12
	return "%d:%02d %s" % [12 if h12 == 0 else h12, minutes % 60, "AM" if hour < 12 else "PM"]


func _draw_journey() -> void:
	if _alpha <= 0.0:
		return
	var c := _canvas
	c.modulate.a = _alpha
	c.draw_rect(Rect2(Vector2.ZERO, UiScale.SCREEN), BACKING)
	var outer := PICTURE.grow(6)
	outer.position.y -= 22
	outer.size.y += 22 + 16
	_draw_frame(c, outer)
	c.draw_rect(PICTURE, PARCHMENT)
	var font := c.get_theme_default_font()
	if _points.is_empty():
		return
	c.draw_texture_rect_region(PARK_MAP, _dest, _src)
	# The whole way, then the part already gone, then the marker.
	var mark := _marker()
	if _on_foot:
		_dotted(c, _points, ROUTE_AHEAD)
		_dotted(c, mark.behind, GOLD)
	else:
		c.draw_polyline(_points, INK, 3.0)
		c.draw_polyline(_points, ROUTE_AHEAD, 1.0)
		if mark.behind.size() > 1:
			c.draw_polyline(mark.behind, INK, 3.0)
			c.draw_polyline(mark.behind, GOLD, 1.0)
	# Sights: a dot each; the name of the one the marker is passing, then
	# the hubs' and the trip's ends' where they fit.
	var nearest := {}
	var nearest_d := PASSING
	for sight: Dictionary in _sights:
		var d: float = sight.at.distance_to(mark.at)
		if d < nearest_d:
			nearest_d = d
			nearest = sight
	for sight: Dictionary in _sights:
		_dot(c, sight.at, GOLD if sight == nearest else (CREAM if sight.hub else PARCHMENT))
	var passing := ""
	if not nearest.is_empty() and not nearest.hub and _progress > 0.02 and _progress < 0.98:
		passing = nearest.name
	var taken: Array[Rect2] = []
	var order: Array[Dictionary] = []
	if not nearest.is_empty():
		order.append(nearest)
	for sight: Dictionary in _sights:
		if sight == nearest:
			continue
		if sight.hub or sight.at.distance_to(_points[0]) < PASSING or sight.at.distance_to(_points[-1]) < PASSING:
			order.append(sight)
	for sight: Dictionary in order:
		var width := font.get_string_size(sight.name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var at: Vector2 = (sight.at + Vector2(5, 3)).floor()
		if at.x + width > _dest.end.x - 2:
			at.x = sight.at.x - 5 - width
		var rect := Rect2(at - Vector2(2, 8), Vector2(width + 4, 11))
		var clash := false
		for other in taken:
			clash = clash or other.intersects(rect)
		if clash:
			continue
		taken.append(rect)
		c.draw_rect(rect, Color(INK, 0.7))
		c.draw_string(font, at, sight.name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, GOLD if sight == nearest else CREAM)
	_marker_square(c, mark.at)
	# Title above the map; the clock and the distance below it.
	c.draw_string(font, Vector2(PICTURE.position.x, PICTURE.position.y - 12), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, GOLD)
	c.draw_string(font, Vector2(PICTURE.position.x, PICTURE.position.y - 3), _subtitle, HORIZONTAL_ALIGNMENT_LEFT, PICTURE.size.x, FONT_SIZE, DIM)
	var now := _start_minutes + roundi(_minutes * _progress)
	var foot := Vector2(PICTURE.position.x, PICTURE.end.y + 11)
	c.draw_string(font, foot, clock_text(now), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, CREAM)
	var right := ""
	if _miles > 0.0:
		right = "%.1f of %s mi" % [_miles * _progress, str(_miles)]
	else:
		right = "%s on foot" % Park.format_minutes(roundi(_minutes * _progress)) if _on_foot else Park.format_minutes(roundi(_minutes * _progress))
	c.draw_string(font, Vector2(PICTURE.position.x, foot.y), right, HORIZONTAL_ALIGNMENT_RIGHT, PICTURE.size.x, FONT_SIZE, CREAM)
	if passing != "":
		c.draw_string(font, Vector2(PICTURE.position.x, foot.y), "Passing " + passing, HORIZONTAL_ALIGNMENT_CENTER, PICTURE.size.x, FONT_SIZE, GOLD)


static func _dot(c: Control, at: Vector2, fill: Color) -> void:
	var o := (at - Vector2(1, 1)).floor()
	c.draw_rect(Rect2(o - Vector2(1, 1), Vector2(5, 5)), INK)
	c.draw_rect(Rect2(o, Vector2(3, 3)), fill)


static func _marker_square(c: Control, at: Vector2) -> void:
	var o := (at - Vector2(3, 3)).floor()
	c.draw_rect(Rect2(o + Vector2(1, 1), Vector2(7, 7)), Color(INK, 0.5))
	c.draw_rect(Rect2(o, Vector2(7, 7)), INK)
	c.draw_rect(Rect2(o + Vector2(1, 1), Vector2(5, 5)), GOLD)
	c.draw_rect(Rect2(o + Vector2(1, 4), Vector2(5, 2)), GOLD_SHADE)
	c.draw_rect(Rect2(o + Vector2(2, 2), Vector2(1, 1)), CREAM)


static func _dotted(c: Control, points: PackedVector2Array, color: Color) -> void:
	var walked := 0.0
	for k in range(1, points.size()):
		var a := points[k - 1]
		var b := points[k]
		var length := a.distance_to(b)
		var d := 0.0
		while d < length:
			if fmod(walked + d, 5.0) < 2.5:
				var p := a.lerp(b, d / length).floor()
				c.draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), INK)
				c.draw_rect(Rect2(p, Vector2(1, 1)), color)
			d += 1.0
		walked += length


## The wooden frame round the map, as on the park map.
static func _draw_frame(c: Control, outer: Rect2) -> void:
	var inner := outer.grow(-1)
	c.draw_rect(Rect2(outer.position + Vector2(2, 3), outer.size), Color(0.082, 0.078, 0.11, 0.3))
	c.draw_rect(outer, WOOD_DARK)
	c.draw_rect(inner, WOOD_MID)
	c.draw_rect(Rect2(outer.position, Vector2(outer.size.x, 1)), WOOD_LIGHT)
	c.draw_rect(Rect2(outer.position, Vector2(1, outer.size.y)), WOOD_LIGHT)
	c.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), WOOD_BEVEL)
	c.draw_rect(Rect2(inner.position, Vector2(1, inner.size.y)), WOOD_BEVEL)
	c.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(inner.size.x, 1)), WOOD_SHADE)
	c.draw_rect(Rect2(inner.position + Vector2(inner.size.x - 1, 0), Vector2(1, inner.size.y)), WOOD_SHADE)
	c.draw_rect(outer.grow(-4), Color(WOOD_DARK, 0.85))
