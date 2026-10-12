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
const PARCHMENT_LIGHT := Color("fff6dc")
const SIGN_GOLD_LIGHT := Color("ffe58a")
const SLATE_LIGHT := Color("3d4868")
## Width of the wooden frame around a picture, in pixels.
const FRAME_WIDTH := 4.0
const WOOD_BEVEL := Color("a86d38")
const WOOD_SHADE := Color("6b4322")

## The gamepad's name for each keyboard control the map's hints mention.
const GAMEPAD_BUTTONS := {"Arrows": "D-pad", "E": "A", "Esc": "B", "M": "Back", "Tab": "LB/RB"}

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
## Read-only caches, so the map opens quickly after the first time: each
## hub's view data and relief image (by path), and its sign layout (by hub).
var _view_cache: Dictionary = {}
var _sign_cache: Dictionary = {}
var _cursor := -1
## Name of the shuttle stop the player is riding from, while choosing where to go.
var _shuttle_from := ""
var _routes: Dictionary = {}
var _park_frame: Control
var _park_marker: Control
var _area_marker: Control
## The bob-and-pulse step of the "you are here" pin, the only thing redrawn every frame.
var _pin_phase := 0
var _note_box: StyleBox
## The slim strip under the area map: the panels' dark board and gold edge,
## without the wood frame, which is too deep for it.
var _strip_box: StyleBoxFlat

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
## The travel map's description panel (for tests: its text must fit).
var _info_panel: PanelContainer


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
	if not visible:
		return
	# The maps are only redrawn on change. The "you are here" pin bobs and pulses,
	# so only its small overlays redraw, and only when the animation steps.
	var phase := int(Time.get_ticks_msec() / 160) % 4
	if phase != _pin_phase:
		_pin_phase = phase
		_park_marker.queue_redraw()
		_area_marker.queue_redraw()


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
	elif MenuInput.pressed(event, "move_left") or MenuInput.pressed(event, "move_up"):
		_cycle(-1)
	elif MenuInput.pressed(event, "move_right") or MenuInput.pressed(event, "move_down"):
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
	if MenuInput.pressed(event, "move_left"):
		dir = Vector2.LEFT
	elif MenuInput.pressed(event, "move_right"):
		dir = Vector2.RIGHT
	elif MenuInput.pressed(event, "move_up"):
		dir = Vector2.UP
	elif MenuInput.pressed(event, "move_down"):
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
	_acts_label.text = "\n".join(Array(hub.activities).map(func(a: String) -> String: return "• " + a))
	_route_label.text = _route_text(hub)
	_route_label.modulate = GOLD if _legs.has(_selected) and _legs[_selected].open else (TEXT if _selected == _hub_here else CLOSED)
	var tab_hint := "[%s] Area" % _button("Tab")
	if _travel:
		_hint_label.text = "[%s] Choose   [%s] Travel   [%s] Close   %s" % [_button("Arrows"), _button("E"), _button("Esc"), tab_hint]
	else:
		_hint_label.text = "Travel from a map kiosk or a road out of the area.\n[%s] Choose   [%s] Close   %s" % [_button("Arrows"), _button("M"), tab_hint]
	_area_title.text = "" if not _view.is_empty() else "%s area map" % Park.get_hub(_hub_here).display_name
	_fit_info()
	_refresh_area_text()
	_park_frame.queue_redraw()
	_park_canvas.queue_redraw()
	_park_marker.queue_redraw()
	_area_frame.queue_redraw()
	_area_canvas.queue_redraw()
	_area_marker.queue_redraw()


## The name of a keyboard control on the current device, like the HUD's prompts.
## Steps the description's type down a size at a time until the hub's whole
## note fits its panel (the longest notes, or a wider font, need it).
func _fit_info() -> void:
	for size in [9, 8, 7]:
		_desc_label.add_theme_font_size_override("font_size", size)
		_acts_label.add_theme_font_size_override("font_size", size)
		if _info_panel.get_combined_minimum_size().y <= INFO_RECT.size.y:
			return


func _button(keyboard: String) -> String:
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud and not hud.device_changed.is_connected(_on_device_changed):
		hud.device_changed.connect(_on_device_changed)
	return hud.prompt(keyboard, GAMEPAD_BUTTONS.get(keyboard, keyboard)) if hud else keyboard


func _on_device_changed() -> void:
	if visible:
		_refresh()


func _refresh_area_text() -> void:
	if _view.is_empty():
		_area_footer.text = "You are at %s.   [%s] Park map   [%s] Close" % [_here_name, _button("Tab"), _button("M")]
		_area_hint.text = ""
		return
	var selected: Dictionary = _points[_cursor] if _cursor >= 0 else {}
	var lines := ""
	if not selected.is_empty():
		lines = "%s. %s" % [selected.name, selected.blurb]
		var stop_name: String = selected.get("stop", "")
		if _shuttle_from != "" and stop_name != "" and stop_name != _shuttle_from:
			lines += "  [%s] Ride here, free, %d min." % [_button("E"), ShuttleStop.RIDE_MINUTES]
		elif _shuttle_from != "" and stop_name == _shuttle_from:
			lines += "  You are at this stop."
		elif stop_name != "":
			lines += " Valley shuttle stop."
	else:
		lines = "You are at %s." % _here_name
	_area_footer.text = lines
	if _shuttle_from != "":
		_area_hint.text = "[%s] Stop   [%s] Ride   [%s] Stay" % [_button("Arrows"), _button("E"), _button("Esc")]
	else:
		_area_hint.text = "[%s] Look   [%s] Park map   [%s] Close" % [_button("Arrows"), _button("Tab"), _button("M")]


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
		var selected: bool = hub.id == _selected
		var r := 3.0 if selected else 2.0
		# The selected hub gets a square highlight ring around its marker.
		if selected:
			canvas.draw_rect(Rect2(p - Vector2(r + 4, r + 4), Vector2(r * 2 + 9, r * 2 + 9)), INK, false, 1.0)
			canvas.draw_rect(Rect2(p - Vector2(r + 3, r + 3), Vector2(r * 2 + 7, r * 2 + 7)), GOLD, false, 1.0)
		canvas.draw_rect(Rect2(p - Vector2(r + 1, r + 1) + Vector2(1, 1), Vector2(r * 2 + 3, r * 2 + 3)), Color(INK, 0.5))
		canvas.draw_rect(Rect2(p - Vector2(r + 1, r + 1), Vector2(r * 2 + 3, r * 2 + 3)), INK)
		canvas.draw_rect(Rect2(p - Vector2(r, r), Vector2(r * 2 + 1, r * 2 + 1)), GOLD if selected else fill)
		markers.append(Rect2(p - Vector2(r + 1, r + 1), Vector2(r * 2 + 3, r * 2 + 3)))
	var taken: Array[Rect2] = []
	for hub in ParkAtlas.HUBS:
		var p := _map_point(Vector2(hub.longitude, hub.latitude))
		var width := font.get_string_size(hub.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var at := _park_label_at(p, Vector2(width, FONT_SIZE), LABEL_SIDE.get(hub.id, Vector2(1, 0)), points, markers, taken)
		taken.append(Rect2(at - Vector2(0, FONT_SIZE - 1), Vector2(width, FONT_SIZE + 2)))
		# The name sits on a parchment plaque, gold when it is the selected hub.
		var is_selected: bool = hub.id == _selected
		_plaque(canvas, at + Vector2(-3, -8), Vector2(ceilf(width) + 6.0, 11.0), GOLD if is_selected else PARCHMENT, SIGN_GOLD_SHADE if is_selected else PARCHMENT_SHADE, SIGN_GOLD_LIGHT if is_selected else PARCHMENT_LIGHT, 1.0)
		canvas.draw_string(font, at, hub.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, BROWN)


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
		_draw_marker_dot(canvas, p, 1.0, false)
		var size := font.get_string_size(place.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		for offset: Vector2 in [Vector2(6, 3), Vector2(-6 - size.x, 3), Vector2(-size.x / 2, -6), Vector2(-size.x / 2, 11)]:
			var sign_rect := Rect2(p + offset - Vector2(3, 8), Vector2(size.x + 6, 11))
			if not taken.any(func(other: Rect2) -> bool: return other.intersects(sign_rect.grow(1))) and Rect2(Vector2.ZERO, _area_canvas.size).encloses(sign_rect):
				taken.append(sign_rect)
				_plaque(canvas, sign_rect.position, sign_rect.size, PARCHMENT, PARCHMENT_SHADE, PARCHMENT_LIGHT, 1.0)
				canvas.draw_string(font, p + offset, place.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, BROWN)
				break


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
			var dot := (_v2(point.anchor) * s).floor()
			if point.has("stop"):
				rects.append(Rect2(dot - Vector2(3, 3), Vector2(7, 7)))
			else:
				rects.append(Rect2(dot - Vector2(2, 2), Vector2(5, 5)))
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
	var light := PARCHMENT_LIGHT
	var ink := BROWN
	if ribbon:
		fill = SLATE
		shade = SLATE_SHADE
		light = SLATE_LIGHT
		ink = CREAM
	elif tier == "home":
		fill = SIGN_GOLD
		shade = SIGN_GOLD_SHADE
		light = SIGN_GOLD_LIGHT
	if selected:
		fill = SIGN_GOLD
		shade = SIGN_GOLD_SHADE
		light = SIGN_GOLD_LIGHT
		ink = BROWN
		# A highlight ring around the selected sign: cream inside, dark outside.
		canvas.draw_rect(Rect2(pos - Vector2(2, 2), size + Vector2(4, 4)), TEXT, false, 1.0)
		canvas.draw_rect(Rect2(pos - Vector2(3, 3), size + Vector2(6, 6)), INK, false, 1.0)
	var alpha := 0.55 if dimmed else 1.0
	_plaque(canvas, pos, size, fill, shade, light, alpha)
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


## Places sit on a marker where they actually are: a shuttle stop gets its bus
## sign, other places a plain dot. Drawn before the signs.
func _draw_dot(canvas: Control, point: Dictionary) -> void:
	if point.tier == "landmark" or point.tier == "fall" or point.tier == "home":
		return
	var dot := (_v2(point.anchor) * float(_area_scale)).floor()
	if point.has("stop"):
		_draw_stop(canvas, dot, 1.0)
	else:
		_draw_marker_dot(canvas, dot, 1.0, false)


func _draw_kiosk(canvas: Control, at: Vector2) -> void:
	var o := (at - Vector2(4, 8)).floor()
	canvas.draw_rect(Rect2(o + Vector2(1, 1), Vector2(9, 6)), Color(INK, 0.5))
	canvas.draw_rect(Rect2(o, Vector2(9, 6)), INK)
	canvas.draw_rect(Rect2(o + Vector2(1, 1), Vector2(7, 4)), WOOD_MID)
	canvas.draw_rect(Rect2(o + Vector2(2, 2), Vector2(5, 2)), KIOSK_GREEN)
	canvas.draw_rect(Rect2(o + Vector2(2, 2), Vector2(2, 1)), Color("e8f7c8"))
	canvas.draw_rect(Rect2(o + Vector2(2, 6), Vector2(1, 2)), INK)
	canvas.draw_rect(Rect2(o + Vector2(6, 6), Vector2(1, 2)), INK)


## A climb: a diamond, gold when the gear is in hand and gray until then.
func _draw_climb(canvas: Control, at: Vector2, ready: bool) -> void:
	var c := at.floor()
	canvas.draw_colored_polygon(_diamond(c + Vector2(1, 1), 5.0), Color(INK, 0.5))
	canvas.draw_colored_polygon(_diamond(c, 5.0), INK)
	canvas.draw_colored_polygon(_diamond(c, 3.5), SIGN_GOLD if ready else GEAR_LOCKED)
	canvas.draw_rect(Rect2(c + Vector2(-2, -1), Vector2(1, 1)), SIGN_GOLD_LIGHT if ready else Color("b9b3a6"))
	if ready:
		canvas.draw_rect(Rect2(c + Vector2(0, -2), Vector2(1, 4)), BROWN)
	else:
		canvas.draw_rect(Rect2(c + Vector2(-1, 0), Vector2(3, 2)), Color("e9e3d0"))
		canvas.draw_rect(Rect2(c + Vector2(0, -1), Vector2(1, 1)), Color("e9e3d0"))


func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


## The "you are here" pin: a red head on a point. It bobs and its ground ring
## pulses, one step per phase of the animation.
func _draw_pin(canvas: Control, at: Vector2) -> void:
	var bob: float = [0.0, -1.0, -2.0, -1.0][_pin_phase]
	var base := at.floor()
	var shadow_w := int(4.0 + bob)
	canvas.draw_rect(Rect2(base + Vector2(-(shadow_w / 2), -1), Vector2(shadow_w, 2)), Color(INK, 0.5))
	canvas.draw_arc(base, 4.0 + float(_pin_phase), 0.0, TAU, 16, Color(HERE_RED, 0.6 - 0.1 * float(_pin_phase)), 1.0)
	var tip := base + Vector2(0, bob)
	var head := tip + Vector2(0, -6)
	canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 1), head + Vector2(-4, 0), head + Vector2(4, 0)]), INK)
	canvas.draw_circle(head, 4.0, INK)
	canvas.draw_colored_polygon(PackedVector2Array([tip, head + Vector2(-3, 0.5), head + Vector2(3, 0.5)]), HERE_RED)
	canvas.draw_circle(head, 3.0, HERE_RED)
	canvas.draw_rect(Rect2(head + Vector2(-2, -2), Vector2(1, 1)), Color(1, 1, 1, 0.85))


## The "you are here" pin on the park map.
func _draw_park_marker() -> void:
	_draw_pin(_park_marker, _map_point(_here))


## The "you are here" pin on the area map, where the player stands.
func _draw_area_marker() -> void:
	if not _view.is_empty():
		_draw_pin(_area_marker, _view_point(_here) * float(_area_scale))
		return
	var hub := Park.get_hub(_hub_here)
	if _area_rect.texture == null or hub == null:
		return
	_draw_pin(_area_marker, _area_point(hub, _here))


## The plank backdrop behind both maps.
func _draw_planks(canvas: Control) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, SCREEN), WOOD_PLANK)
	for y in range(0, int(SCREEN.y), 15):
		canvas.draw_rect(Rect2(0, y + 14, SCREEN.x, 1), WOOD_PLANK_LINE)


## A wooden frame pinned around [param picture]: a lit top-left bevel, a shaded
## bottom-right, a dark lip where it meets the picture, brass studs at the
## corners, and a soft shadow cast down and to the right.
func _draw_frame(canvas: Control, picture: Rect2) -> void:
	var outer := picture.grow(FRAME_WIDTH)
	var inner := outer.grow(-1)
	canvas.draw_rect(Rect2(outer.position + Vector2(2, 3), outer.size), Color(0, 0, 0, 0.16))
	canvas.draw_rect(Rect2(outer.position + Vector2(1, 2), outer.size), Color(0, 0, 0, 0.3))
	canvas.draw_rect(outer, WOOD_DARK)
	canvas.draw_rect(inner, WOOD_MID)
	canvas.draw_rect(Rect2(outer.position, Vector2(outer.size.x, 1)), WOOD_LIGHT)
	canvas.draw_rect(Rect2(outer.position, Vector2(1, outer.size.y)), WOOD_LIGHT)
	canvas.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), WOOD_BEVEL)
	canvas.draw_rect(Rect2(inner.position, Vector2(1, inner.size.y)), WOOD_BEVEL)
	canvas.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 1), Vector2(inner.size.x, 1)), WOOD_SHADE)
	canvas.draw_rect(Rect2(inner.position + Vector2(inner.size.x - 1, 0), Vector2(1, inner.size.y)), WOOD_SHADE)
	canvas.draw_rect(picture.grow(1), WOOD_DARK)
	var corners := [outer.position, outer.position + Vector2(outer.size.x - 3, 0), outer.position + Vector2(0, outer.size.y - 3), outer.end - Vector2(3, 3)]
	for corner: Vector2 in corners:
		canvas.draw_rect(Rect2(corner, Vector2(3, 3)), WOOD_DARK)
		canvas.draw_rect(Rect2(corner + Vector2(1, 1), Vector2(1, 1)), SIGN_GOLD)


## The park map's frame and plank backdrop; the picture sits at MAP_POS.
func _draw_park_frame() -> void:
	_draw_planks(_park_frame)
	_draw_frame(_park_frame, Rect2(MAP_POS, PARK_MAP.get_size()))


func _route_ready(route_id: String) -> bool:
	if not _routes.has(route_id):
		var path := "res://data/routes/%s.tres" % route_id
		_routes[route_id] = load(path) if ResourceLoader.exists(path) else null
	var route: RouteData = _routes[route_id]
	return route != null and Gear.has_all(route.required_gear)


## Planks behind the area map, the wood frame around its picture, the title
## plaque (illustrated maps only), and the footer panel for the note.
func _draw_area_frame() -> void:
	var canvas := _area_frame
	var font := canvas.get_theme_default_font()
	_draw_planks(canvas)
	if _area_rect.texture != null:
		_draw_frame(canvas, _area_rect.get_rect())
	if not _view.is_empty():
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
	# Footer strip: the panels' board and gold edge, slim enough for one line.
	canvas.draw_style_box(_strip_box, Rect2(6, 246, 468, 22))


func _tab_chip(canvas: Control, font: Font, rect: Rect2, text: String, active: bool) -> void:
	canvas.draw_rect(rect, WOOD_DARK)
	canvas.draw_rect(Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 1)), PARCHMENT if active else Color("5b3a1d"))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	canvas.draw_string(font, rect.position + Vector2(floorf((rect.size.x - width) / 2.0), rect.size.y - 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, BROWN if active else Color("e9d3a0"))


## A small flat sign: a 1 px dark outline, a lit top edge, a shaded bottom
## edge, and a 2 px drop shadow down and to the right.
func _plaque(canvas: Control, pos: Vector2, size: Vector2, fill: Color, shade: Color, light: Color, alpha: float) -> void:
	canvas.draw_rect(Rect2(pos + Vector2(1, 2), size + Vector2(1, 0)), Color(INK, 0.55 * alpha))
	canvas.draw_rect(Rect2(pos, size), Color(INK, alpha))
	canvas.draw_rect(Rect2(pos + Vector2(1, 1), size - Vector2(2, 2)), Color(fill, alpha))
	canvas.draw_rect(Rect2(pos + Vector2(1, 1), Vector2(size.x - 2, 1)), Color(light, alpha))
	canvas.draw_rect(Rect2(pos + Vector2(1, size.y - 3), Vector2(size.x - 2, 2)), Color(shade, alpha))


## A plain place's marker: a small cream dot in a dark outline.
func _draw_marker_dot(canvas: Control, at: Vector2, alpha: float, selected: bool) -> void:
	var o := (at - Vector2(2, 2)).floor()
	canvas.draw_rect(Rect2(o + Vector2(1, 1), Vector2(5, 5)), Color(INK, 0.5 * alpha))
	canvas.draw_rect(Rect2(o, Vector2(5, 5)), Color(INK, alpha))
	canvas.draw_rect(Rect2(o + Vector2(1, 1), Vector2(3, 3)), Color(GOLD if selected else TEXT, alpha))


## A shuttle stop's marker: a small bus sign, cream with a slate header band.
func _draw_stop(canvas: Control, at: Vector2, alpha: float) -> void:
	var o := (at - Vector2(3, 3)).floor()
	canvas.draw_rect(Rect2(o + Vector2(1, 1), Vector2(7, 7)), Color(INK, 0.5 * alpha))
	canvas.draw_rect(Rect2(o, Vector2(7, 7)), Color(INK, alpha))
	canvas.draw_rect(Rect2(o + Vector2(1, 1), Vector2(5, 5)), Color(CREAM, alpha))
	canvas.draw_rect(Rect2(o + Vector2(1, 1), Vector2(5, 2)), Color(SLATE, alpha))


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
	_area_footer.position = Vector2(10, 247)
	# Where the signs go depends only on the hub's picture and data, so the
	# search runs once per hub.
	if _sign_cache.has(_hub_here):
		_sign_at = _sign_cache[_hub_here].duplicate()
	else:
		_place_signs()
		_sign_cache[_hub_here] = _sign_at.duplicate()


## Reads the illustrated map's data, if this hub has one (<hub>_view.json).
func _load_view() -> void:
	_view = {}
	_relief = null
	_points = []
	var path := "res://assets/map/areas/%s_view.json" % _hub_here
	if _view_cache.has(path):
		_view = _view_cache[path].view
		_relief = _view_cache[path].relief
		_points = _view.get("points", [])
		return
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
	_view_cache[path] = {"view": _view, "relief": _relief}


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
	_note_box = _make_note_box()
	_strip_box = StyleBoxFlat.new()
	_strip_box.bg_color = Color("3a2a1e")
	_strip_box.border_color = Color("c8a060")
	_strip_box.set_border_width_all(1)
	_strip_box.shadow_color = Color(0, 0, 0, 0.4)
	_strip_box.shadow_size = 2
	_park_frame = _overlay(_park_view, _draw_park_frame)
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
	_park_marker = _overlay(_park_canvas, _draw_park_marker)

	var panel := PanelContainer.new()
	panel.position = INFO_RECT.position
	panel.size = INFO_RECT.size
	panel.add_theme_stylebox_override("panel", _note_box)
	_park_view.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	# The panel is a fixed size; the longest hub's text has to fit it whole.
	panel.clip_contents = true
	_info_panel = panel
	_name_label = _label(box)
	_name_label.add_theme_font_size_override("font_size", 17)
	_name_label.add_theme_color_override("font_color", GOLD)
	_sub_label = _label(box)
	_sub_label.add_theme_font_size_override("font_size", 9)
	_sub_label.add_theme_color_override("font_color", SUBHEAD)
	_desc_label = _label(box)
	_desc_label.add_theme_font_size_override("font_size", 9)
	_acts_label = _label(box)
	_acts_label.add_theme_font_size_override("font_size", 9)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_route_label = _label(box)
	_hint_label = _label(box)
	_hint_label.modulate = DIM
	_hint_label.add_theme_font_size_override("font_size", 8)

	_area_view = Control.new()
	_area_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_area_view)
	_area_frame = _overlay(_area_view, _draw_area_frame)
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
	_area_marker = _overlay(_area_canvas, _draw_area_marker)
	_area_footer = _label(_area_view)
	_area_footer.position = Vector2(10, 245)
	_area_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_area_footer.custom_minimum_size.x = 454
	_area_footer.size.x = 454
	_area_footer.add_theme_font_size_override("font_size", 8)
	_area_hint = _label(_area_view)
	_area_hint.position = Vector2(290, 4)
	_area_hint.size = Vector2(184, 12)
	_area_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_area_hint.add_theme_font_size_override("font_size", 8)
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


## A full-size child of [param parent] that draws [param on_draw], so the
## parts that never change are drawn once and the animated part on its own.
func _overlay(parent: Control, on_draw: Callable) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(on_draw)
	parent.add_child(overlay)
	return overlay


## The tidy panel behind the notes: dark wood with a thin edge and a soft shadow.
## The game's own wood-and-gold panel, as on every other screen.
func _make_note_box() -> StyleBox:
	var box := ThemeDB.get_project_theme().get_stylebox("panel", "PanelContainer").duplicate() as StyleBox
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box
