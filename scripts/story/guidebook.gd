class_name Guidebook
extends RefCounted
## The climbing guidebook and its tick list.
##
## The Curry Village Mountain Shop hands the guidebook over in the first quest
## (the "guidebook" unlock). It lists every route with its grade and the gear
## it needs, and a route is ticked when the player tops it out (QuestLog.climbed).
## Main-line quests end on a climb, so ticking routes is how the story moves.

const ROUTE_DIR := "res://data/routes/"
const ABILITY := "guidebook"

static var _routes: Array[RouteData] = []


static func has_book() -> bool:
	return QuestLog.is_unlocked(ABILITY)


## Every route, in guidebook order.
static func routes() -> Array[RouteData]:
	if _routes.is_empty():
		for file in DirAccess.get_files_at(ROUTE_DIR):
			var name := file.trim_suffix(".remap")
			if name.ends_with(".tres"):
				_routes.append(load(ROUTE_DIR + name))
		_routes.sort_custom(func(a: RouteData, b: RouteData) -> bool:
			return a.guide_order < b.guide_order or (a.guide_order == b.guide_order and a.id < b.id))
	return _routes


## One row per route: route, ticked, ready (you own the gear), missing (gear
## still needed), and main (a main-line quest is waiting on this route).
static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for route in routes():
		var missing := Gear.missing(route.required_gear)
		result.append({
			"route": route,
			"ticked": QuestLog.has_climbed(route.id),
			"ready": missing.is_empty(),
			"missing": missing,
			"main": main_quest_for(route.id) != null,
		})
	return result


static func ticked_count() -> int:
	var n := 0
	for route in routes():
		if QuestLog.has_climbed(route.id):
			n += 1
	return n


## The main-line quest whose climb step is this route, or null.
static func main_quest_for(route_id: String) -> QuestData:
	for quest: QuestData in QuestLog.QUESTS:
		if not quest.main_line:
			continue
		for step: Dictionary in quest.steps:
			if step.get("type") == "climbed" and step.route == route_id:
				return quest
	return null


## A grade's number on the Yosemite Decimal System, for comparing routes:
## "5.5" -> 5.0, "5.10b" -> 10.25, "5.11+" -> 11.9, "VI 5.13" -> 13.0.
## Grades off the scale (glaciers, "easy") return 0.
static func yds(grade: String) -> float:
	var regex := RegEx.create_from_string("5\\.(\\d+)([abcd])?(\\+)?")
	var found := regex.search(grade)
	if found == null:
		return 0.0
	var value := float(found.get_string(1))
	var letter := found.get_string(2)
	if letter != "":
		value += "abcd".find(letter) * 0.25
	elif found.get_string(3) != "":
		value += 0.9
	return value


## Just the decimal part of a grade: "V 5.10b" -> "5.10b".
static func yds_label(grade: String) -> String:
	var found := RegEx.create_from_string("5\\.\\d+[abcd+]?").search(grade)
	return found.get_string() if found else grade


## The ticked route with the highest decimal grade, or null.
static func hardest_tick() -> RouteData:
	var best: RouteData = null
	for route in routes():
		if QuestLog.has_climbed(route.id) and yds(route.grade) > 0.0 and (best == null or yds(route.grade) > yds(best.grade)):
			best = route
	return best


## "Swan Slab, easy" with the gear it needs, for the tick list.
static func gear_text(route: RouteData) -> String:
	if route.required_gear.is_empty():
		return "no gear needed"
	var parts := PackedStringArray()
	for id: String in route.required_gear:
		var gear := Gear.get_gear(id)
		var n := int(route.required_gear[id])
		var name := gear.display_name if gear else id
		parts.append(name if n == 1 else "%d %s" % [n, name])
	return ", ".join(parts)
