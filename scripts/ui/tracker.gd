class_name Tracker
extends Control
## A gold pin sign that leads the way to whatever you track on the park map
## (MapFog.tracked): a stamp, an area, a hub, a trailhead, or the story's
## next step.
##
## In the same area it points straight at the spot, with how far it is, and
## when the spot is on screen the pin bobs over it. In another area it points
## at the way out that leads nearest to it ("via Ledge Trail"), since the
## areas are joined by trails and roads, not laid edge to edge. Reaching a
## tracked area or hub stops tracking it.
##
## The HUD adds one. It follows the Signposts setting (Settings.wayfinding)
## and hides under menus and conversations like the rest of the HUD.

## Seconds between working out where the sign goes.
const REFRESH := 0.15
## Nearer than this (meters), a stamp counts as reached.
const HERE := 20.0
const INSET := Rect2(Vector2(10, 22), UiScale.SCREEN - Vector2(20, 44))
const FONT_SIZE := 8
const CARD := Color(0.165, 0.106, 0.078, 0.82)
const GOLD := Color("f1cf6a")
const GOLD_SHADE := Color("d8a63b")
const INK := Color("f5eee0")
const DIM := Color(0.96, 0.91, 0.8, 0.75)
const RIM := Color(0.1, 0.06, 0.04, 0.9)

## {text, via, dir (screen), at (UI px, the arrow or pin), on_screen}, or {}.
var _sign: Dictionary = {}
var _goal := Vector2.ZERO
var _wait := 0.0
var _alpha := 0.0
var _phase := 0
var _hud: Node
var _world: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not is_instance_valid(_hud):
		_hud = get_tree().get_first_node_in_group("hud")
	if not is_instance_valid(_world):
		_world = get_tree().get_first_node_in_group("world")
	var shown: bool = Settings.wayfinding and _world != null and _hud != null and not _hud.is_covered() \
			and not MapFog.tracked.is_empty() and Wayfinding._outdoors(_world)
	var prev := _alpha
	_alpha = move_toward(_alpha, 1.0 if shown and not _sign.is_empty() else 0.0, delta * 4.0)
	_wait -= delta
	if shown and _wait <= 0.0:
		_wait = REFRESH
		_sign = point(_world)
	elif not shown and _alpha <= 0.0:
		_sign = {}
	var dirty := prev != _alpha
	if not _sign.is_empty():
		var at: Vector2 = _sign.get("at", _goal)
		var goal: Vector2 = _sign.goal
		if at.distance_squared_to(goal) > 0.01:
			_sign.at = at.lerp(goal, clampf(delta * 8.0, 0.0, 1.0))
			dirty = true
	var phase := int(Time.get_ticks_msec() / 200) % 4
	if phase != _phase:
		_phase = phase
		dirty = true
	if dirty:
		queue_redraw()


## Where the sign goes now, for the player in [param world]: a Dictionary
## {text, via, dir, goal, on_screen}, or {} for no sign. Public for tests.
func point(world: Node) -> Dictionary:
	var region: Region = world.region
	var player: Node2D = world.player
	var target := MapFog.tracked
	if region == null or player == null or target.is_empty():
		return {}
	var at := region.to_local(player.global_position)
	var here := Wayfinding.lonlat_of(region, at)
	var goal_lonlat := MapFog._v2(target.lonlat)
	var goal_region := str(target.get("region", ""))
	var kind := str(target.get("kind", ""))
	var label := str(target.get("label", ""))
	# where the target is in this area, if it's in it
	var spot := Vector2.INF
	if goal_region == region.region_id:
		if kind in ["area", "hub"]:
			MapFog.untrack()
			if _hud and _hud.has_method("show_message"):
				_hud.show_message("You've reached %s." % label)
			return {}
		if kind == "quest":
			spot = _quest_spot(region, str(target.id))
			if spot == Vector2.INF:
				return {}
		else:
			spot = local_of(region, goal_lonlat)
	elif goal_region == "":
		var local := local_of(region, goal_lonlat)
		if region.get_bounds().has_point(local):
			spot = local
	var old: Dictionary = _sign
	var out: Dictionary
	if spot != Vector2.INF:
		var meters := Wayfinding.meters_between(here, goal_lonlat).length() if kind != "quest" else (spot - at).length() * Wayfinding.METERS_PER_PIXEL
		out = {"text": label, "via": "here" if meters < HERE else distance_text(meters), "world": region.to_global(spot)}
	else:
		var exit := best_exit(region, goal_lonlat, goal_region)
		if exit.is_empty():
			return {}
		out = {"text": label, "via": "via %s" % exit.label, "world": exit.global}
	return _place(out, player, old)


## Turns a spot in the world into the sign's place on screen: over the spot
## when it's in view, else on the edge toward it.
func _place(out: Dictionary, player: Node2D, old: Dictionary) -> Dictionary:
	var camera := player.get_node_or_null("Camera") as Camera2D
	var world_at: Vector2 = out.world
	var screen := Vector2.ZERO
	var on_screen := false
	var dir := Vector2.RIGHT
	if camera:
		var view_size := get_viewport_rect().size / camera.zoom
		var view := Rect2(camera.get_screen_center_position() - view_size / 2.0, view_size)
		var ui := (world_at - view.position) / view.size * UiScale.SCREEN
		on_screen = INSET.has_point(ui)
		var middle := INSET.get_center()
		dir = (ui - middle).normalized() if ui != middle else Vector2.DOWN
		screen = ui if on_screen else Wayfinding._edge_spot(dir).clamp(INSET.position, INSET.end)
	out.dir = dir
	out.on_screen = on_screen
	out.goal = screen.round()
	out.at = old.get("at", out.goal) if bool(old.get("on_screen", false)) == on_screen else out.goal
	return out


## The way out of [param region] that leads nearest to [param goal]: the
## exit straight into [param goal_region] if there is one, else the one whose
## far side is nearest. {label, global} or {}.
static func best_exit(region: Region, goal: Vector2, goal_region: String) -> Dictionary:
	var best: Dictionary = {}
	var best_far := INF
	var exits: Array[Node] = region.find_children("*", "RegionExit", true, false)
	exits.append_array(region.find_children("*", "RegionDoor", true, false))
	for exit: Node in exits:
		var to := str(exit.get("target_region"))
		var lands := Vector2.INF
		if to != "":
			if bool(MapFog.region_data(to).get("indoors", false)) and to != goal_region:
				continue
			lands = MapFog.region_lonlat(to)
		else:
			var hub_id := str(exit.get("travel_to")) if exit.get("travel_to") else str(exit.get("drive_to")) if exit.get("drive_to") else ""
			var hub := Park.get_hub(hub_id)
			if hub:
				to = hub.id
				lands = Vector2(hub.longitude, hub.latitude)
		if lands == Vector2.INF:
			continue
		var far := 0.0 if to == goal_region else Wayfinding.meters_between(lands, goal).length()
		if far < best_far:
			best_far = far
			var label := str(exit.get("label"))
			best = {"label": short_label(label if label != "" else MapFog.region_name(to)), "global": (exit as Node2D).global_position, "to": to}
	return best


## "Ledge Trail, down to Curry Village" -> "Ledge Trail".
static func short_label(label: String) -> String:
	var cut := label.find(",")
	return label.substr(0, cut) if cut > 0 else label


## "120 m", "0.4 km", "3 km".
static func distance_text(meters: float) -> String:
	if meters < 1000.0:
		return "%d m" % (roundi(meters / 10.0) * 10)
	if meters < 10000.0:
		return "%.1f km" % (meters / 1000.0)
	return "%d km" % roundi(meters / 1000.0)


## The pixel in [param region] for a longitude/latitude: the inverse of
## Wayfinding.lonlat_of.
static func local_of(region: Region, lonlat: Vector2) -> Vector2:
	if region.map:
		return region.map.lonlat_to_position(lonlat)
	var anchor := region.geo_anchor
	var per_lon := Wayfinding.METERS_PER_DEGREE_LAT * cos(deg_to_rad(anchor.y))
	var meters := Vector2((lonlat.x - anchor.x) * per_lon, -(lonlat.y - anchor.y) * Wayfinding.METERS_PER_DEGREE_LAT)
	return region.get_bounds().get_center() + meters / Wayfinding.METERS_PER_PIXEL


## Where the person a tracked quest sends you to stands in this area, or
## Vector2.INF.
static func _quest_spot(region: Region, quest_id: String) -> Vector2:
	var quest := QuestLog.get_quest(quest_id)
	if quest == null:
		return Vector2.INF
	var who: String = quest.giver
	var step := QuestLog.current_step(quest)
	if not step.is_empty() and str(step.get("type", "")) == "talk":
		who = str(step.target)
	for npc in region.find_children("*", "NPC", true, false):
		var character: CharacterData = npc.get("character")
		if character and character.id == who and (npc as CanvasItem).is_visible_in_tree():
			return region.to_local((npc as Node2D).global_position)
	return Vector2.INF


func _draw() -> void:
	if _sign.is_empty() or _alpha <= 0.0:
		return
	var font := get_theme_default_font()
	var at: Vector2 = (_sign.at as Vector2).round()
	var on_screen: bool = _sign.on_screen
	var dir: Vector2 = _sign.dir
	var text: String = _sign.text
	var via: String = _sign.via
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var via_w := font.get_string_size(via, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 1).x
	var box_size := Vector2(ceilf(maxf(text_w, via_w)) + 16.0, 20.0)
	var box: Rect2
	var bob: float = [0.0, -1.0, -2.0, -1.0][_phase]
	if on_screen:
		box = Rect2(at + Vector2(-box_size.x / 2.0, -box_size.y - 14.0 + bob), box_size)
	else:
		box = Rect2(at - box_size / 2.0 - dir * Vector2(box_size.x / 2.0 + 5.0, box_size.y / 2.0 + 5.0), box_size)
	box.position = box.position.clamp(Vector2(2, 2), UiScale.SCREEN - box_size - Vector2(2, 2))
	# stay off the HUD's own panels (the place name, the clock, the goal card)
	for other in _keep_clear():
		if other.intersects(box):
			box.position.y = other.end.y + 2.0 if box.get_center().y < UiScale.SCREEN.y / 2.0 else other.position.y - box.size.y - 2.0
	box.position = box.position.clamp(Vector2(2, 2), UiScale.SCREEN - box_size - Vector2(2, 2)).round()
	var a := _alpha
	draw_rect(Rect2(box.position + Vector2(1, 1), box.size), Color(0.05, 0.03, 0.02, 0.35 * a))
	draw_rect(box.grow(1.0), Color(RIM, RIM.a * a))
	draw_rect(box, Color(CARD, CARD.a * a))
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1)), Color(GOLD, a))
	draw_rect(Rect2(box.position + Vector2(0, box.size.y - 1), Vector2(box.size.x, 1)), Color(GOLD_SHADE, a))
	_draw_pin_icon(box.position + Vector2(5, 7), a)
	draw_string(font, box.position + Vector2(12, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(INK, a))
	draw_string(font, box.position + Vector2(12, 17), via, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 1, Color(DIM, DIM.a * a))
	if on_screen:
		# a pin bobbing over the spot itself
		var tip := at + Vector2(0, bob)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(0, 1), tip + Vector2(-4, -6), tip + Vector2(4, -6)]), Color(RIM, a))
		draw_circle(tip + Vector2(0, -7), 4.0, Color(RIM, a))
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-3, -6), tip + Vector2(3, -6)]), Color(GOLD, a))
		draw_circle(tip + Vector2(0, -7), 3.0, Color(GOLD, a))
		draw_rect(Rect2(tip + Vector2(-1, -9), Vector2(1, 1)), Color(INK, a))
	else:
		var side := Vector2(-dir.y, dir.x)
		var tip := at + dir * 4.0
		draw_colored_polygon(PackedVector2Array([tip + dir, at - dir * 3.0 + side * 4.0, at - dir * 3.0 - side * 4.0]), Color(RIM, a))
		draw_colored_polygon(PackedVector2Array([tip, at - dir * 2.0 + side * 3.0, at - dir * 2.0 - side * 3.0]), Color(GOLD, a))


## The HUD's panels showing now, in UI pixels.
func _keep_clear() -> Array[Rect2]:
	var clear: Array[Rect2] = []
	if not is_instance_valid(_hud):
		return clear
	for panel in _hud.find_children("*", "PanelContainer", true, false):
		var control := panel as Control
		if control.is_visible_in_tree() and control.modulate.a > 0.05 and control.get_global_rect().size.x < UiScale.SCREEN.x * 0.6:
			clear.append(control.get_global_rect().grow(2.0))
	return clear


func _draw_pin_icon(at: Vector2, alpha: float) -> void:
	draw_circle(at, 3.0, Color(RIM, alpha))
	draw_circle(at, 2.0, Color(GOLD, alpha))
	draw_rect(Rect2(at + Vector2(-0.5, 2), Vector2(1, 3)), Color(GOLD, alpha))
