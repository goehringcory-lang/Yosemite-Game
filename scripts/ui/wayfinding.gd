class_name Wayfinding
extends Control
## Small signs at the edge of the screen on the Valley floor that point the
## way to what's out of sight: the great landmarks (Half Dome, El Capitan,
## Yosemite Falls, Glacier Point) while they're a long walk off, and a "?"
## toward a part of the Valley you haven't walked into yet, or a named place
## nearby you haven't found (see Discoveries). They make the separate areas
## read as one valley you can head across, and give a reason to walk on.
##
## The HUD adds one. Settings.wayfinding turns them off. They hide under
## menus and conversations, like the rest of the HUD.

## Landmark -> real longitude/latitude (x/y), roughly the summit or the
## brink of the fall.
## "over" lists the areas it towers straight over, where it gets no sign.
const LANDMARKS := [
	{"name": "Half Dome", "at": Vector2(-119.5332, 37.7459), "over": ["mirror_lake"]},
	{"name": "El Capitan", "at": Vector2(-119.6377, 37.7340), "over": ["el_capitan_meadow"]},
	{"name": "Yosemite Falls", "at": Vector2(-119.5966, 37.7566), "over": []},
	{"name": "Glacier Point", "at": Vector2(-119.5735, 37.7302), "over": ["curry_village", "lamon_homestead"]},
]
## A landmark gets a sign only between these distances, in meters: nearer,
## its wall fills the view already; further, it's out of the Valley.
const LANDMARK_NEAR := 1500.0
const LANDMARK_FAR := 12000.0
## At most this many landmark signs, and this many "?" signs, at once.
const MOST_LANDMARKS := 3
const MOST_UNKNOWN := 2
## An undiscovered place gets a "?" when it's off screen but this close, in
## pixels; an unwalked area off the edge, when its seam is this close.
const UNKNOWN_NEAR := 1600.0
## Roughly how many meters one pixel of a hand-made Valley area covers,
## measured from the distance between neighboring areas' geo anchors.
const METERS_PER_PIXEL := 0.46
const METERS_PER_DEGREE_LAT := 111320.0
## Where the arrows sit, in the HUD's 480x270 UI pixels (see UiScale): a
## little in from the screen's edges. Cards keep clear of the clock and the
## status bar (see _draw).
const INSET := Rect2(Vector2(8, 8), UiScale.SCREEN - Vector2(16, 16))
## Seconds between working out where the signs go (they glide in between).
const REFRESH := 0.1

const CARD := Color(0.165, 0.106, 0.078, 0.72)
const EDGE := Color(0.573, 0.412, 0.239, 0.9)
const INK := Color(0.96, 0.91, 0.8)
const UNKNOWN_INK := Color(1.0, 0.86, 0.47)
const FONT_SIZE := 8

## Signs now: {key, text, unknown, dir (unit, screen), at (screen)}.
var _signs: Dictionary = {}
var _wait := 0.0
var _alpha := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	var world := get_tree().get_first_node_in_group("world")
	var shown: bool = Settings.wayfinding and world != null and hud != null and not hud.is_covered() \
			and _in_valley(world) and not _hud_talking(hud)
	_alpha = move_toward(_alpha, 1.0 if shown else 0.0, delta * 3.0)
	if _alpha <= 0.0:
		if not _signs.is_empty():
			_signs.clear()
			queue_redraw()
		return
	_wait -= delta
	if _wait <= 0.0 and shown:
		_wait = REFRESH
		_place_signs(world)
	# glide toward where each sign belongs
	var eased := clampf(delta * 8.0, 0.0, 1.0)
	for sign: Dictionary in _signs.values():
		sign.at = (sign.at as Vector2).lerp(sign.goal, eased)
	queue_redraw()


## The place name, a card or a message is up: the signs step back so the
## screen doesn't fill with words, and come back once it's quiet.
static func _hud_talking(hud: Node) -> bool:
	return hud.location_panel.modulate.a > 0.05 or hud.toasts.count() > 0 \
			or (hud.message_label.visible and hud.message_label.modulate.a > 0.05)


## Outdoors on the Valley floor, walking about.
static func _in_valley(world: Node) -> bool:
	var region: Region = world.region
	return region != null and not region.indoors and region.hub_id == "yosemite_valley" \
			and world.player != null and world.player.can_act


## Where the signs go this time: a direction from the middle of the screen
## for each thing to point at.
func _place_signs(world: Node) -> void:
	var region: Region = world.region
	var player: Player = world.player
	var camera := player.get_node_or_null("Camera") as Camera2D
	if camera == null:
		return
	var view_size := get_viewport_rect().size / camera.zoom
	var view := Rect2(camera.get_screen_center_position() - view_size / 2.0, view_size)
	var at := region.to_local(player.global_position)
	var wanted: Array[Dictionary] = []
	wanted.append_array(_landmarks(region, at))
	wanted.append_array(_unknowns(world, region, at, view))
	var keep: Dictionary = {}
	for want in wanted:
		var goal := _edge_spot(want.dir)
		var sign: Dictionary = _signs.get(want.key, {"at": goal})
		sign.merge(want, true)
		sign.goal = goal
		keep[want.key] = sign
	_signs = keep


## The landmarks a long walk off, nearest first, as directions on screen.
func _landmarks(region: Region, at: Vector2) -> Array[Dictionary]:
	var here := lonlat_of(region, at)
	var found: Array[Dictionary] = []
	for landmark: Dictionary in LANDMARKS:
		if region.region_id in landmark.over:
			continue
		var away := meters_between(here, landmark.at)
		var meters := away.length()
		if meters < LANDMARK_NEAR or meters > LANDMARK_FAR:
			continue
		found.append({"key": landmark.name, "text": landmark.name, "unknown": false, "dir": away.normalized(), "far": meters})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.far < b.far)
	return found.slice(0, MOST_LANDMARKS)


## "?" signs: toward the nearest areas off this one's edges you haven't
## walked into, and the nearest places you haven't found that are off
## screen, here or across the seam laid out now.
func _unknowns(world: Node, region: Region, at: Vector2, view: Rect2) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen_targets := {}
	for exit in Seam.candidates(region) if not region.has_meta("seam_exits") else region.get_meta("seam_exits"):
		var target: String = exit.target_region
		if seen_targets.has(target):
			continue
		seen_targets[target] = true
		var key := Discoveries.key_for(target, _region_name(target))
		if Discoveries.is_found(key) or not _listed(key):
			continue
		var spot := region.to_local(exit.global_position)
		var gap := spot.distance_to(at)
		if gap < UNKNOWN_NEAR and not view.has_point(region.to_global(spot)):
			found.append({"key": "?" + key, "text": "?", "unknown": true, "dir": (spot - at).normalized(), "far": gap, "area": true})
	var seam: Seam = world.seam
	var places: Array = []
	for place in region.get_places():
		places.append([region, place])
	if seam and is_instance_valid(seam.neighbor) and seam.neighbor.is_inside_tree():
		for place in seam.neighbor.get_places():
			places.append([seam.neighbor, place])
	for pair: Array in places:
		var r: Region = pair[0]
		var place: Place = pair[1]
		if place.radius <= 0.0 or place.display_name == r.display_name:
			continue
		var key := Discoveries.key_for(r.region_id, place.display_name)
		if Discoveries.is_found(key) or not _listed(key):
			continue
		var spot := region.to_local(place.global_position)
		var gap := spot.distance_to(at)
		if gap < UNKNOWN_NEAR and gap > place.radius and not view.has_point(place.global_position):
			found.append({"key": "?" + key, "text": "?", "unknown": true, "dir": (spot - at).normalized(), "far": gap, "area": false})
	# a whole area not yet walked into comes before a spot in this one
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.far < b.far if a.area == b.area else a.area)
	return found.slice(0, MOST_UNKNOWN)


static func _listed(key: String) -> bool:
	for entry: Dictionary in Discoveries.places():
		if entry.key == key:
			return true
	return false


## A region's own entry on the list of places is the first one listed for
## it (list_places writes the area before the spots inside it).
static func _region_name(id: String) -> String:
	for entry: Dictionary in Discoveries.places():
		if entry.region == id:
			return entry.name
	return ""


## About where [param at] (pixels in [param region]) is on the Earth: the
## region's geo anchor at the middle of its map, and METERS_PER_PIXEL out
## from there. Generated maps know exactly.
static func lonlat_of(region: Region, at: Vector2) -> Vector2:
	if region.map:
		return region.to_lonlat(at)
	var from_middle := (at - region.get_bounds().get_center()) * METERS_PER_PIXEL
	var anchor := region.geo_anchor
	var per_lon := METERS_PER_DEGREE_LAT * cos(deg_to_rad(anchor.y))
	return anchor + Vector2(from_middle.x / per_lon, -from_middle.y / METERS_PER_DEGREE_LAT)


## Meters from [param a] to [param b] (longitude/latitude), east and south
## positive, as on screen.
static func meters_between(a: Vector2, b: Vector2) -> Vector2:
	var per_lon := METERS_PER_DEGREE_LAT * cos(deg_to_rad(a.y))
	return Vector2((b.x - a.x) * per_lon, -(b.y - a.y) * METERS_PER_DEGREE_LAT)


## Where a sign pointing [param dir] sits: on the INSET rectangle's edge,
## straight out from the middle of the screen.
static func _edge_spot(dir: Vector2) -> Vector2:
	var middle := INSET.get_center()
	var half := INSET.size / 2.0
	var scale := INF
	if absf(dir.x) > 0.0001:
		scale = minf(scale, half.x / absf(dir.x))
	if absf(dir.y) > 0.0001:
		scale = minf(scale, half.y / absf(dir.y))
	return middle + dir * scale


func _draw() -> void:
	if _signs.is_empty():
		return
	var font := get_theme_default_font()
	var placed: Array[Rect2] = []
	for sign: Dictionary in _signs.values():
		var text: String = sign.text
		var at: Vector2 = sign.at
		var dir: Vector2 = sign.dir
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		var box_size := Vector2(size.x + 6.0, 11.0)
		# the card sits inward of the arrow, so it never runs off screen
		var box := Rect2(at - box_size / 2.0 - dir * Vector2(box_size.x / 2.0 + 4.0, box_size.y / 2.0 + 4.0), box_size)
		box.position = box.position.clamp(Vector2(2, 2), UiScale.SCREEN - box_size - Vector2(2, 2))
		# don't sit on the clock or the status bar, or stack two cards
		for other in _keep_clear() + placed:
			if other.intersects(box):
				# move off it toward the middle of the screen
				box.position.y = other.end.y + 1.0 if box.get_center().y < UiScale.SCREEN.y / 2.0 else other.position.y - box.size.y - 1.0
		placed.append(box)
		box.position = box.position.round()
		var ink: Color = UNKNOWN_INK if sign.unknown else INK
		var card := CARD
		card.a *= _alpha
		var edge := EDGE
		edge.a *= _alpha
		ink.a *= _alpha
		draw_rect(box, card)
		draw_rect(box, edge, false, 1.0)
		draw_string(font, Vector2(box.position.x + 3.0, box.position.y + 8.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, ink)
		_draw_arrow(at.round(), dir, edge)


## The HUD's own panels that are showing, in UI pixels.
func _keep_clear() -> Array[Rect2]:
	var clear: Array[Rect2] = []
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return clear
	for panel: Control in [hud.clock_panel, hud.status_bar]:
		if panel and panel.is_visible_in_tree() and panel.modulate.a > 0.05:
			clear.append(panel.get_global_rect().grow(2.0))
	return clear


## A small pointed arrow at [param at] aimed along [param dir].
func _draw_arrow(at: Vector2, dir: Vector2, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var tip := at + dir * 3.0
	var points := PackedVector2Array([tip, at - dir * 2.0 + side * 2.5, at - dir * 2.0 - side * 2.5])
	draw_colored_polygon(points, col)
