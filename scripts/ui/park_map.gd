class_name ParkMap
extends CanvasLayer
## The map screen. The Park tab shows all of Yosemite (a relief map made from
## real elevation data) with the hubs and the roads between them. The Area tab
## shows the current hub in detail. Press M to look around; open it from a map
## kiosk or by driving off the edge of a hub to travel.
##
## Yosemite Valley has an illustrated area map (see tools/mapgen/oblique). M
## opens it first. Arrow keys move between the labeled places, and at a Valley
## shuttle stop [E] rides to the chosen stop.

signal travel_requested(leg: Dictionary)
signal shuttle_requested(stop: Dictionary)
signal closed

enum Tab { PARK, AREA }

const PARK_MAP: Texture2D = preload("res://assets/map/park_map.png")
## Hubs are cycled through in this order, roughly west to east.
const HUB_ORDER := ["el_portal", "yosemite_valley", "glacier_point", "wawona", "tuolumne_meadows"]
## Which side of its marker each hub's name goes on (x: -1 left, 1 right;
## y: -1 above, 0 level, 1 below), so the close-together hubs don't overlap.
const LABEL_SIDE := {
	"yosemite_valley": Vector2(-1, -1), "glacier_point": Vector2(1, 1), "el_portal": Vector2(1, 1),
	"wawona": Vector2(1, 0), "tuolumne_meadows": Vector2(-1, -1),
}
const MAP_POS := Vector2(6, 7)
const INFO_RECT := Rect2(212, 7, 262, 256)
const AREA_BOX := Rect2(6, 18, 468, 222)
const FONT_SIZE := 8
## Signs may slide this far (pixels) from their spot to clear a neighbor.
const NUDGE_X := [0, 4, -4, 8, -8, 12, -12, 16, -16, 24, -24]
const NUDGE_Y := [0, 3, -3, 6, -6, 9, -9, 12, -12, 15, -15, 18, -18]
const SCREEN := Vector2(480, 270)

const INK := Color("1a1410")
const GOLD := Color("ffd24a")
const CLOSED := Color("e0503c")
const LOCKED := Color("9a948a")
const HERE := Color("ff4a4a")
const TEXT := Color("f7f0dc")
const DIM := Color(0.97, 0.94, 0.86, 0.6)
## Sub-heading text: light enough to read on the dark panel.
const SUBHEAD := Color("d9cdb0")

# Illustrated area map: wood frame, parchment signs, slate ribbons.
const WOOD_PLANK := Color("2a190b")
const WOOD_PLANK_LINE := Color("34210f")
const WOOD_DARK := Color("1b0f07")
const WOOD_MID := Color("8a5a2e")
const WOOD_LIGHT := Color("c98f4d")
const PARCHMENT := Color("f6e5b5")
const PARCHMENT_SHADE := Color("e2c684")
const BROWN := Color("3b2416")
const SLATE := Color("2b3550")
const SLATE_SHADE := Color("1f2740")
const SLATE_DARK := Color("141a2b")
const CREAM := Color("f6ecd0")
const SIGN_GOLD := Color("f4c94a")
const SIGN_GOLD_SHADE := Color("d9a52c")
const FALL_BLUE := Color("9fd3ee")
const GEAR_LOCKED := Color("6d7488")
const KIOSK_GREEN := Color("4f9a3c")
const HERE_RED := Color("ff5a3c")

var _tab := Tab.PARK
var _travel := false
var _region: Region
var _hub_here := ""
var _here := Vector2.ZERO # longitude/latitude of the player
var _here_name := ""
var _selected := ""
var _legs: Dictionary = {} # destination hub id -> leg

## The illustrated area map's data (empty when the hub has none): the
## projection, labeled points, kiosks, and route starts.
var _view: Dictionary = {}
var _relief: Image
var _points: Array = []
## Top-left of each point's sign on the area canvas, nudged clear of the
## other signs and the markers (same order as _points).
var _sign_at: Array[Vector2] = []
var _cursor := -1
## Name of the shuttle stop the player is riding from, while choosing where to go.
var _shuttle_from := ""
var _routes: Dictionary = {}

var _park_view: Control
var _park_canvas: Control
var _area_view: Control
var _area_frame: Control
var _area_rect: TextureRect
var _area_canvas: Control
var _area_scale := 1
var _area_title: Label
var _area_footer: Label
var _area_hint: Label
var _name_label: Label
var _sub_label: Label
var _desc_label: Label
var _acts_label: Label
var _route_label: Label
var _hint_label: Label


func _ready() -> void:
	layer = 20
	add_to_group("park_map")
	visible = false
	_build()


## Shows the map. [param travel] lets the player pick a destination.
func open(region: Region, player_position: Vector2, travel: bool, preselect := "") -> void:
	_show(region, player_position, travel, preselect, "")


## Shows the Valley map to pick a shuttle stop. [param from_stop] is the stop
## the player is standing at.
func open_shuttle(region: Region, player_position: Vector2, from_stop: String) -> void:
	_show(region, player_position, false, "", from_stop)


func _show(region: Region, player_position: Vector2, travel: bool, preselect: String, from_stop: String) -> void:
	_region = region
	_travel = travel
	_shuttle_from = from_stop
	_hub_here = region.hub_id
	_here = region.to_lonlat(player_position)
	var place := region.place_at(player_position)
	_here_name = place.display_name if place else region.display_name
	_legs.clear()
	for leg in Park.legs_from(_hub_here):
		var best: Dictionary = _legs.get(leg.to, {})
		if best.is_empty() or (leg.open and not best.open) or (leg.open == best.open and leg.minutes < best.minutes):
			_legs[leg.to] = leg
	_selected = preselect
	if _selected == "":
		_selected = _hub_here
		if travel:
			for id: String in HUB_ORDER:
				if _legs.has(id) and _legs[id].open:
					_selected = id
					break
	_load_area_map()
	# Looking around opens the illustrated hub map first; a kiosk opens the park map to travel.
	_tab = Tab.AREA if not _view.is_empty() and not travel else Tab.PARK
	_start_cursor()
	_refresh()
	visible = true


func is_open() -> bool:
	return visible


func close() -> void:
	visible = false
	_shuttle_from = ""
	closed.emit()


func _process(_delta: float) -> void:
	if visible:
		# Redraw every frame for the blinking "you are here" marker.
		_park_canvas.queue_redraw()
		_area_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("map") or event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("tab_next") or event.is_action_pressed("tab_previous"):
		_tab = Tab.AREA if _tab == Tab.PARK else Tab.PARK
		_refresh()
	elif _tab != Tab.PARK:
		_area_input(event)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _hub_near(_park_canvas.get_local_mouse_position())
		if clicked != "" and clicked == _selected:
			_confirm()
		elif clicked != "":
			_select(clicked)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		_cycle(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		_cycle(1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("use_tool") or event.is_action_pressed("ui_accept"):
		_confirm()


func _cycle(step: int) -> void:
	var i := HUB_ORDER.find(_selected)
	_select(HUB_ORDER[wrapi(i + step, 0, HUB_ORDER.size())])


func _select(hub_id: String) -> void:
	_selected = hub_id
	_refresh()


func _confirm() -> void:
	if not _travel or not _legs.has(_selected):
		return
	var leg: Dictionary = _legs[_selected]
	if leg.open:
		close()
		travel_requested.emit(leg)


func _hub_near(point: Vector2) -> String:
	var best := ""
	var best_d := 10.0
	for hub in ParkAtlas.HUBS:
		var d := _map_point(Vector2(hub.longitude, hub.latitude)).distance_to(point)
		if d < best_d:
			best_d = d
			best = hub.id
	return best


func _map_point(lonlat: Vector2) -> Vector2:
	return ParkAtlas.geo_to_map(lonlat, PARK_MAP.get_size()).floor()


# ---------------------------------------------------------------- area map navigation

## Arrow keys move to the nearest labeled place in that direction; [E] rides
## the shuttle when choosing a stop.
func _area_input(event: InputEvent) -> void:
	if _points.is_empty():
		return
	var dir := Vector2.ZERO
	if event.is_action_pressed("move_left"):
		dir = Vector2.LEFT
	elif event.is_action_pressed("move_right"):
		dir = Vector2.RIGHT
	elif event.is_action_pressed("move_up"):
		dir = Vector2.UP
	elif event.is_action_pressed("move_down"):
		dir = Vector2.DOWN
	if dir != Vector2.ZERO:
		_move_cursor(dir)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _point_near(_area_canvas.get_local_mouse_position())
		if clicked >= 0 and clicked == _cursor:
			_ride()
		elif clicked >= 0:
			_cursor = clicked
			_refresh()
	elif event.is_action_pressed("interact") or event.is_action_pressed("use_tool") or event.is_action_pressed("ui_accept"):
		_ride()


func _move_cursor(dir: Vector2) -> void:
	if _cursor < 0:
		_start_cursor()
		return
	var from := _label_pos(_points[_cursor])
	var best := -1
	var best_score := INF
	for i in _points.size():
		if i == _cursor:
			continue
		var delta := _label_pos(_points[i]) - from
		var along := delta.dot(dir)
		if along <= 1.0:
			continue
		var off := absf(delta.dot(Vector2(-dir.y, dir.x)))
		# Prefer places straight ahead over ones far off to the side.
		var score := along + off * 2.0
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_cursor = best
		_refresh()


func _point_near(at: Vector2) -> int:
	var best := -1
	var best_d := 14.0
	for i in _points.size():
		var d := _label_pos(_points[i]).distance_to(at / float(_area_scale))
		if d < best_d:
			best_d = d
			best = i
	return best


## Starts on the shuttle stop being ridden from, or the place nearest the player.
func _start_cursor() -> void:
	_cursor = -1
	if _points.is_empty():
		return
	if _shuttle_from != "":
		for i in _points.size():
			if _points[i].get("stop", "") == _shuttle_from:
				_cursor = i
				return
	var here := _view_point(_here)
	var best_d := INF
	for i in _points.size():
		var d := (_v2(_points[i].anchor) - here).length()
		if d < best_d:
			best_d = d
			_cursor = i


## Rides the shuttle to the chosen stop, when choosing one.
func _ride() -> void:
	if _shuttle_from == "" or _cursor < 0:
		return
	var stop_name: String = _points[_cursor].get("stop", "")
	if stop_name == "" or stop_name == _shuttle_from:
		return
	for stop: Dictionary in ShuttleStop.STOPS:
		if stop.name == stop_name:
			close()
			shuttle_requested.emit(stop)
			return


func _label_pos(point: Dictionary) -> Vector2:
	return _v2(point.label)


func _v2(pair: Array) -> Vector2:
	return Vector2(float(pair[0]), float(pair[1]))


# ---------------------------------------------------------------- text

func _refresh() -> void:
	_park_view.visible = _tab == Tab.PARK
	_area_view.visible = _tab == Tab.AREA
	var hub := Park.get_hub(_selected)
	_name_label.text = hub.display_name
	_sub_label.text = "%s. %s" % [hub.get_elevation_text(), hub.tagline]
	_desc_label.text = hub.description
	_acts_label.text = "\n".join(Array(hub.activities).map(func(a: String) -> String: return "- " + a))
	_route_label.text = _route_text(hub)
	_route_label.modulate = GOLD if _legs.has(_selected) and _legs[_selected].open else (TEXT if _selected == _hub_here else CLOSED)
	var tab_hint := "[Tab] Area"
	if _travel:
		_hint_label.text = "[Arrows] Choose   [E] Travel   [Esc] Close   %s" % tab_hint
	else:
		_hint_label.text = "Travel from a map kiosk or a road out of the area.\n[Arrows] Choose   [M] Close   %s" % tab_hint
	_area_title.text = "" if not _view.is_empty() else "%s area map" % Park.get_hub(_hub_here).display_name
	_refresh_area_text()
	_park_canvas.queue_redraw()
	_area_canvas.queue_redraw()
	_area_frame.queue_redraw()


func _refresh_area_text() -> void:
	if _view.is_empty():
		_area_footer.text = "You are at %s.   [Tab] Park map   [M] Close" % _here_name
		_area_hint.text = ""
		return
	var selected: Dictionary = _points[_cursor] if _cursor >= 0 else {}
	var lines := ""
	if not selected.is_empty():
		lines = "%s. %s" % [selected.name, selected.blurb]
		var stop_name: String = selected.get("stop", "")
		if _shuttle_from != "" and stop_name != "" and stop_name != _shuttle_from:
			lines += "  [E] Ride here, free, %d min." % ShuttleStop.RIDE_MINUTES
		elif _shuttle_from != "" and stop_name == _shuttle_from:
			lines += "  You are at this stop."
		elif stop_name != "":
			lines += "  Valley shuttle stop."
	else:
		lines = "You are at %s." % _here_name
	_area_footer.text = lines
	if _shuttle_from != "":
		_area_hint.text = "[Arrows] Stop   [E] Ride   [Esc] Stay"
	else:
		_area_hint.text = "[Arrows] Look   [Tab] Park map   [M] Close"


func _route_text(hub: HubData) -> String:
	if hub.id == _hub_here:
		return "You are here."
	if not _legs.has(hub.id):
		return "No road leads there from here."
	var leg: Dictionary = _legs[hub.id]
	if not leg.open:
		return ("Locked. " if leg.locked else "Closed. ") + leg.closed_reason
	return "Drive %s mi via %s, about %s." % [str(leg.miles), leg.via, Park.format_minutes(leg.minutes)]


# ---------------------------------------------------------------- drawing

func _draw_park() -> void:
	var canvas := _park_canvas
	var font := canvas.get_theme_default_font()
	var leg: Dictionary = _legs.get(_selected, {})
	var points := PackedVector2Array()
	if not leg.is_empty():
		for lonlat: Vector2 in leg.path:
			points.append(_map_point(lonlat) + Vector2(0.5, 0.5))
		var color := GOLD if leg.open else (LOCKED if leg.locked else CLOSED)
		canvas.draw_polyline(points, INK, 3.0)
		canvas.draw_polyline(points, color, 1.0)
	# Markers first, then the names, so no name is hidden under a marker.
	var markers: Array[Rect2] = []
	for hub in ParkAtlas.HUBS:
		var p := _map_point(Vector2(hub.longitude, hub.latitude))
		var fill := TEXT
		if hub.id != _hub_here and _legs.has(hub.id) and not _legs[hub.id].open:
			fill = LOCKED if _legs[hub.id].locked else CLOSED
		var r := 3.0 if hub.id == _selected else 2.0
		canvas.draw_rect(Rect2(p - Vector2(r + 1, r + 1), Vector2(r * 2 + 3, r * 2 + 3)), INK)
		canvas.draw_rect(Rect2(p - Vector2(r, r), Vector2(r * 2 + 1, r * 2 + 1)), GOLD if hub.id == _selected else fill)
		markers.append(Rect2(p - Vector2(r + 1, r + 1), Vector2(r * 2 + 3, r * 2 + 3)))
	var taken: Array[Rect2] = []
	for hub in ParkAtlas.HUBS:
		var p := _map_point(Vector2(hub.longitude, hub.latitude))
		var width := font.get_string_size(hub.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var at := _park_label_at(p, Vector2(width, FONT_SIZE), LABEL_SIDE.get(hub.id, Vector2(1, 0)), points, markers, taken)
		taken.append(Rect2(at - Vector2(0, FONT_SIZE - 1), Vector2(width, FONT_SIZE + 2)))
		_text(canvas, font, at, hub.display_name, GOLD if hub.id == _selected else TEXT)
	if (Time.get_ticks_msec() / 400) % 2 == 0:
		var here := _map_point(_here)
		canvas.draw_rect(Rect2(here - Vector2(1, 1), Vector2(3, 3)), HERE)


## Baseline of a hub's name: its preferred side of the marker, or the nearest
## spot around it that stays off the route, the markers and the other names.
func _park_label_at(p: Vector2, size: Vector2, side: Vector2, route: PackedVector2Array, markers: Array[Rect2], taken: Array[Rect2]) -> Vector2:
	var bounds := Rect2(Vector2.ZERO, PARK_MAP.get_size())
	var best := p
	var best_cost := INF
	var tries := 0
	for sx: float in [side.x, -side.x]:
		for sy: float in [side.y, -side.y, 0.0, 1.0, -1.0]:
			var at := p + Vector2(5 if sx > 0 else -5 - size.x, 3 + sy * 6)
			var rect := Rect2(at - Vector2(0, size.y - 1), size + Vector2(0, 2))
			var cost := tries * 0.5
			tries += 1
			if not bounds.encloses(rect):
				cost += 1000.0
			for other: Rect2 in taken:
				cost += _overlap(rect.grow(2), other) * 4.0
			for marker: Rect2 in markers:
				cost += _overlap(rect, marker) * 4.0
			for i in range(1, route.size()):
				var steps := ceili(route[i - 1].distance_to(route[i]) / 2.0)
				for step in maxi(steps, 1):
					if rect.grow(1).has_point(route[i - 1].lerp(route[i], float(step) / maxi(steps, 1))):
						cost += 3.0
			if cost < best_cost:
				best_cost = cost
				best = at
	return best


func _draw_area() -> void:
	if not _view.is_empty():
		_draw_area_illustrated()
		return
	var canvas := _area_canvas
	var hub := Park.get_hub(_hub_here)
	if _area_rect.texture == null or hub == null:
		return
	var font := canvas.get_theme_default_font()
	var taken: Array[Rect2] = []
	for place in _region.get_places():
		if not place.show_on_map:
			continue
		var p := _area_point(hub, _region.to_lonlat(place.position))
		canvas.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), INK)
		var size := font.get_string_size(place.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		for offset: Vector2 in [Vector2(3, 3), Vector2(-3 - size.x, 3), Vector2(-size.x / 2, -4), Vector2(-size.x / 2, 10)]:
			var box := Rect2(p + offset - Vector2(0, size.y - 3), size)
			if not taken.any(func(other: Rect2) -> bool: return other.intersects(box.grow(1))) and Rect2(Vector2.ZERO, _area_canvas.size).encloses(box):
				taken.append(box)
				_text(canvas, font, p + offset, place.display_name, TEXT)
				break
	if (Time.get_ticks_msec() / 400) % 2 == 0:
		var here := _area_point(hub, _here)
		canvas.draw_rect(Rect2(here - Vector2(2, 2), Vector2(4, 4)), INK)
		canvas.draw_rect(Rect2(here - Vector2(1, 1), Vector2(2, 2)), HERE)


## Pixel on the area map for a longitude/latitude inside [param hub].
func _area_point(hub: HubData, lonlat: Vector2) -> Vector2:
	if not _view.is_empty():
		return _view_point(lonlat) * _area_scale
	var mpd := ParkAtlas.meters_per_degree((hub.north + hub.south) / 2.0)
	var tile := Vector2((lonlat.x - hub.west) * mpd.x, (hub.north - lonlat.y) * mpd.y) / hub.meters_per_tile
	return (tile * _area_scale).floor()


## Lifts a longitude/latitude onto the illustrated map, which is drawn as seen
## from the south with the real terrain height, so tall places sit higher up.
func _view_point(lonlat: Vector2) -> Vector2:
	var sx: float = (lonlat.x - float(_view.west)) / (float(_view.east) - float(_view.west)) * float(_view.width)
	var sy: float = (float(_view.lat0) - lonlat.y) / float(_view.dlat)
	var elevation := _relief_at(sx, sy)
	return Vector2(sx, sy - float(_view.t0) - (elevation - float(_view.eb)) * float(_view.hs)).floor()


func _relief_at(sx: float, sy: float) -> float:
	if _relief == null:
		return float(_view.eb)
	var x := clampi(int(sx), 0, _relief.get_width() - 1)
	var y := clampi(int(sy), 0, _relief.get_height() - 1)
	return _relief.get_pixel(x, y).r * 255.0 * float(_view.relief_step) + float(_view.relief_base)


func _draw_area_illustrated() -> void:
	var canvas := _area_canvas
	var font := canvas.get_theme_default_font()
	var s := float(_area_scale)
	var choosing := _shuttle_from != ""
	# Markers first so the signs stay readable on top of them.
	for point: Dictionary in _points:
		_draw_dot(canvas, point)
	for kiosk: Dictionary in _view.kiosks:
		_draw_kiosk(canvas, _v2(kiosk.anchor) * s)
	for climb: Dictionary in _view.climbs:
		_draw_climb(canvas, _v2(climb.anchor) * s, _route_ready(climb.route))
	for i in _points.size():
		if i != _cursor:
			_draw_point(canvas, font, i, false, choosing and not _points[i].has("stop"))
	if _cursor >= 0:
		_draw_point(canvas, font, _cursor, true, false)
	_draw_here(canvas, _view_point(_here) * s)


## The size of a point's sign.
func _sign_size(font: Font, point: Dictionary) -> Vector2:
	var tier: String = point.tier
	var icon := 7.0 if tier == "landmark" or tier == "fall" else (8.0 if tier == "home" else 0.0)
	var width := ceilf(font.get_string_size(point.name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	return Vector2(width + 7.0 + icon, 12.0)


## Where a point's sign goes before any nudging.
func _sign_home(font: Font, point: Dictionary) -> Vector2:
	return (_label_pos(point) * float(_area_scale) - _sign_size(font, point) / 2.0).floor()


## Rects (on the area canvas) of everything a sign should stay off of: the
## dots, kiosks and climb markers.
func _marker_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var s := float(_area_scale)
	for point: Dictionary in _points:
		if point.tier != "landmark" and point.tier != "fall" and point.tier != "home":
			rects.append(Rect2((_v2(point.anchor) * s).floor() - Vector2(2, 2), Vector2(5, 5)))
	for kiosk: Dictionary in _view.kiosks:
		rects.append(Rect2((_v2(kiosk.anchor) * s - Vector2(3, 8)).floor() - Vector2(1, 1), Vector2(9, 10)))
	for climb: Dictionary in _view.climbs:
		rects.append(Rect2((_v2(climb.anchor) * s).floor() - Vector2(6, 6), Vector2(13, 13)))
	return rects


## Nudges each sign off its neighbors and the markers, as little as it can.
## Signs keep their picture-space order; the nearest free spot wins.
func _place_signs() -> void:
	_sign_at.clear()
	if _view.is_empty() or _area_rect.texture == null:
		return
	var font := _area_canvas.get_theme_default_font()
	var bounds := Rect2(Vector2.ZERO, _area_rect.size)
	var markers := _marker_rects()
	var placed: Array[Rect2] = []
	for point: Dictionary in _points:
		var size := _sign_size(font, point)
		var home := _sign_home(font, point)
		var best := home
		var best_cost := INF
		for dy: int in NUDGE_Y:
			for dx: int in NUDGE_X:
				var rect := Rect2(home + Vector2(dx, dy), size)
				var cost := absf(dx) * 0.5 + absf(dy) * 0.5
				if not bounds.encloses(rect):
					cost += 1000.0
				for other: Rect2 in placed:
					cost += _overlap(rect.grow(2), other) * 4.0
				for marker: Rect2 in markers:
					cost += _overlap(rect, marker) * 4.0
				if cost < best_cost:
					best_cost = cost
					best = rect.position
		placed.append(Rect2(best, size))
		_sign_at.append(best)


func _overlap(a: Rect2, b: Rect2) -> float:
	var common := a.intersection(b)
	return common.size.x * common.size.y


func _draw_point(canvas: Control, font: Font, index: int, selected: bool, dimmed: bool) -> void:
	var point: Dictionary = _points[index]
	var text: String = point.name
	var tier: String = point.tier
	var ribbon := tier == "landmark" or tier == "fall"
	var icon := 7.0 if ribbon else (8.0 if tier == "home" else 0.0)
	var size := _sign_size(font, point)
	var pos := _sign_at[index] if index < _sign_at.size() else _sign_home(font, point)
	var fill := PARCHMENT
	var shade := PARCHMENT_SHADE
	var border := BROWN
	var ink := BROWN
	if ribbon:
		fill = SLATE
		shade = SLATE_SHADE
		border = SLATE_DARK
		ink = CREAM
	elif tier == "home":
		fill = SIGN_GOLD
		shade = SIGN_GOLD_SHADE
	if selected:
		fill = SIGN_GOLD
		shade = SIGN_GOLD_SHADE
		border = INK
		ink = BROWN
		canvas.draw_rect(Rect2(pos - Vector2(1, 1), size + Vector2(2, 3)), TEXT)
	var alpha := 0.55 if dimmed else 1.0
	# a soft drop shadow, then the box with a lit top edge
	canvas.draw_rect(Rect2(pos + Vector2(1, 2), size), Color(0.05, 0.03, 0.02, 0.3 * alpha))
	canvas.draw_rect(Rect2(pos + Vector2(0, 1), size), Color(border, alpha))
	canvas.draw_rect(Rect2(pos, size), Color(border, alpha))
	canvas.draw_rect(Rect2(pos + Vector2(1, 1), size - Vector2(2, 2)), Color(fill, alpha))
	canvas.draw_rect(Rect2(pos + Vector2(1, 1), Vector2(size.x - 2, 1)), Color(fill.lightened(0.35), alpha))
	canvas.draw_rect(Rect2(pos + Vector2(1, size.y - 3), Vector2(size.x - 2, 2)), Color(shade, alpha))
	var text_x := pos.x + 4.0 + icon
	if ribbon:
		var c := FALL_BLUE if tier == "fall" else CREAM
		var o := pos + Vector2(3, 3)
		canvas.draw_colored_polygon(PackedVector2Array([o + Vector2(0, 6), o + Vector2(2.5, 1), o + Vector2(3.5, 3), o + Vector2(4.5, 2), o + Vector2(6, 6)]), Color(c, alpha))
	elif tier == "home":
		var o := pos + Vector2(3, 3)
		canvas.draw_colored_polygon(PackedVector2Array([o + Vector2(3, 0), o + Vector2(6, 3), o + Vector2(5, 3), o + Vector2(5, 6), o + Vector2(1, 6), o + Vector2(1, 3), o + Vector2(0, 3)]), BROWN)
	var ascent := font.get_ascent(FONT_SIZE)
	var baseline := pos.y + (size.y - 2.0 - (ascent + font.get_descent(FONT_SIZE))) / 2.0 + 1.0 + ascent
	canvas.draw_string(font, Vector2(text_x, floorf(baseline)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(ink, alpha))


## Places sit on a dot where they actually are.
func _draw_dot(canvas: Control, point: Dictionary) -> void:
	if point.tier == "landmark" or point.tier == "fall" or point.tier == "home":
		return
	var dot := (_v2(point.anchor) * float(_area_scale)).floor()
	canvas.draw_rect(Rect2(dot - Vector2(1, 1), Vector2(3, 3)), INK)
	canvas.draw_rect(Rect2(dot, Vector2(1, 1)), TEXT)


func _draw_kiosk(canvas: Control, at: Vector2) -> void:
	var o := (at - Vector2(3, 8)).floor()
	canvas.draw_rect(Rect2(o, Vector2(7, 5)), WOOD_DARK)
	canvas.draw_rect(Rect2(o + Vector2(1, 1), Vector2(5, 3)), KIOSK_GREEN)
	canvas.draw_rect(Rect2(o + Vector2(2, 2), Vector2(3, 1)), Color("e8f7c8"))
	canvas.draw_rect(Rect2(o + Vector2(1, 5), Vector2(1, 3)), WOOD_DARK)
	canvas.draw_rect(Rect2(o + Vector2(5, 5), Vector2(1, 3)), WOOD_DARK)


func _draw_climb(canvas: Control, at: Vector2, ready: bool) -> void:
	var c := at.floor()
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(5, 0), c + Vector2(0, 5), c + Vector2(-5, 0)]), WOOD_DARK)
	canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3.5), c + Vector2(3.5, 0), c + Vector2(0, 3.5), c + Vector2(-3.5, 0)]), SIGN_GOLD if ready else GEAR_LOCKED)
	if ready:
		canvas.draw_rect(Rect2(c + Vector2(0, -2), Vector2(1, 4)), BROWN)
	else:
		canvas.draw_rect(Rect2(c + Vector2(-1, 0), Vector2(3, 2)), Color("e9e3d0"))
		canvas.draw_rect(Rect2(c + Vector2(0, -1), Vector2(1, 1)), Color("e9e3d0"))


## A red arrow that bobs above where the player is.
func _draw_here(canvas: Control, at: Vector2) -> void:
	var bob: float = [0.0, -1.0, -2.0, -1.0][(Time.get_ticks_msec() / 160) % 4]
	var tip := at.floor() + Vector2(0, bob)
	canvas.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-4, -6), tip + Vector2(-4, -9), tip + Vector2(4, -9), tip + Vector2(4, -6)]), WOOD_DARK)
	canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -1.5), tip + Vector2(-2.5, -6), tip + Vector2(-2.5, -7.5), tip + Vector2(2.5, -7.5), tip + Vector2(2.5, -6)]), HERE_RED)


func _route_ready(route_id: String) -> bool:
	if not _routes.has(route_id):
		var path := "res://data/routes/%s.tres" % route_id
		_routes[route_id] = load(path) if ResourceLoader.exists(path) else null
	var route: RouteData = _routes[route_id]
	return route != null and Gear.has_all(route.required_gear)


## Planks behind the map, the wood frame around it, and the title plaque.
func _draw_area_frame() -> void:
	var canvas := _area_frame
	if _view.is_empty():
		return
	var font := canvas.get_theme_default_font()
	canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), WOOD_PLANK)
	for y in range(0, int(SCREEN.y), 15):
		canvas.draw_rect(Rect2(0, y + 14, SCREEN.x, 1), WOOD_PLANK_LINE)
	var outer := AREA_BOX.grow(3)
	canvas.draw_rect(outer, WOOD_DARK)
	canvas.draw_rect(outer.grow(-1), WOOD_LIGHT)
	canvas.draw_rect(outer.grow(-2), WOOD_DARK)
	# Tabs
	_tab_chip(canvas, font, Rect2(6, 4, 26, 12), "Park", false)
	_tab_chip(canvas, font, Rect2(34, 2, 36, 14), "Area", true)
	# Title plaque
	var title := Park.get_hub(_hub_here).display_name
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var plaque := Rect2(floorf((SCREEN.x - width) / 2.0) - 8.0, 0, width + 16.0, 14)
	canvas.draw_rect(plaque, WOOD_DARK)
	canvas.draw_rect(Rect2(plaque.position + Vector2(1, 0), plaque.size - Vector2(2, 1)), WOOD_MID)
	canvas.draw_rect(Rect2(plaque.position + Vector2(1, 0), Vector2(plaque.size.x - 2, 1)), WOOD_LIGHT)
	canvas.draw_string_outline(font, Vector2(plaque.position.x + 8, 11), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 2, WOOD_DARK)
	canvas.draw_string(font, Vector2(plaque.position.x + 8, 11), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fff3cf"))
	# Footer panel
	var footer := Rect2(6, 244, 468, 24)
	canvas.draw_rect(footer.grow(1), WOOD_DARK)
	canvas.draw_rect(footer, Color("4a2f17"))


func _tab_chip(canvas: Control, font: Font, rect: Rect2, text: String, active: bool) -> void:
	canvas.draw_rect(rect, WOOD_DARK)
	canvas.draw_rect(Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 1)), PARCHMENT if active else Color("5b3a1d"))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	canvas.draw_string(font, rect.position + Vector2(floorf((rect.size.x - width) / 2.0), rect.size.y - 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, BROWN if active else Color("e9d3a0"))


func _text(canvas: Control, font: Font, at: Vector2, text: String, color: Color) -> void:
	canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, INK)
	canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func _load_area_map() -> void:
	var path := "res://assets/map/areas/%s.png" % _hub_here
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_area_rect.texture = texture
	_load_view()
	_sign_at.clear()
	if texture == null:
		return
	var size := texture.get_size()
	_area_scale = maxi(1, floori(minf(AREA_BOX.size.x / size.x, AREA_BOX.size.y / size.y)))
	var shown := size * _area_scale
	_area_rect.position = (AREA_BOX.position + (AREA_BOX.size - shown) / 2.0).floor()
	_area_rect.size = shown
	_area_canvas.position = _area_rect.position
	_area_canvas.size = shown
	_area_footer.position = Vector2(9, 245) if not _view.is_empty() else Vector2(8, 250)
	_place_signs()


## Reads the illustrated map's data, if this hub has one (<hub>_view.json).
func _load_view() -> void:
	_view = {}
	_relief = null
	_points = []
	var path := "res://assets/map/areas/%s_view.json" % _hub_here
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Could not read %s" % path)
		return
	_view = data
	_points = _view.get("points", [])
	var relief: Texture2D = load(str(_view.relief)) if ResourceLoader.exists(str(_view.relief)) else null
	_relief = relief.get_image() if relief else null


# ---------------------------------------------------------------- layout

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.05, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	_park_view = Control.new()
	_park_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_park_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_park_view)
	var map := TextureRect.new()
	map.texture = PARK_MAP
	map.position = MAP_POS
	map.size = PARK_MAP.get_size()
	_park_view.add_child(map)
	_park_canvas = Control.new()
	_park_canvas.position = MAP_POS
	_park_canvas.size = PARK_MAP.get_size()
	_park_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_park_canvas.draw.connect(_draw_park)
	_park_view.add_child(_park_canvas)

	var panel := PanelContainer.new()
	panel.position = INFO_RECT.position
	panel.size = INFO_RECT.size
	_park_view.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	_name_label = _label(box)
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", GOLD)
	_sub_label = _label(box)
	_sub_label.add_theme_color_override("font_color", SUBHEAD)
	_desc_label = _label(box)
	_acts_label = _label(box)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_route_label = _label(box)
	_hint_label = _label(box)
	_hint_label.modulate = DIM

	_area_view = Control.new()
	_area_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_area_view)
	_area_frame = Control.new()
	_area_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area_frame.draw.connect(_draw_area_frame)
	_area_view.add_child(_area_frame)
	_area_title = _label(_area_view)
	_area_title.position = Vector2(8, 3)
	_area_title.add_theme_color_override("font_color", GOLD)
	_area_rect = TextureRect.new()
	_area_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_area_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_area_view.add_child(_area_rect)
	_area_canvas = Control.new()
	_area_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area_canvas.draw.connect(_draw_area)
	_area_view.add_child(_area_canvas)
	_area_footer = _label(_area_view)
	_area_footer.position = Vector2(8, 245)
	_area_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_area_footer.custom_minimum_size.x = 462
	_area_footer.size.x = 462
	_area_footer.add_theme_font_size_override("font_size", 8)
	_area_hint = _label(_area_view)
	_area_hint.position = Vector2(290, 4)
	_area_hint.size = Vector2(184, 12)
	_area_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_area_hint.modulate = DIM
	_area_hint.visible = true


## Labels in the info panel wrap to its width; others stay on one line.
func _label(parent: Control) -> Label:
	var label := Label.new()
	if parent is VBoxContainer:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = INFO_RECT.size.x - 14
	parent.add_child(label)
	return label
