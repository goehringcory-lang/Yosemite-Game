class_name QuestTarget
extends RefCounted
## Where the story's next step is, for the map (ParkMap): the region, its
## hub, and a place on the Valley's illustrated map to stick a flag in.
##
## The main story's next step comes first, then the press book's. A step
## that's a climb points at the route; one that sends you to someone points
## at them; anything else points at whoever gave the quest, since that's who
## you'll be turning it in to. The Lost Guardian points at the gap in the
## talus under the Royal Arches.
##
## Where people and routes are comes from the story overlays
## (scenes/story/content/<region>.tscn), read once.

const CONTENT_DIR := "res://scenes/story/content/"

## Regions with no point of their own on the Valley's illustrated map, and
## the point they sit nearest.
const VALLEY_POINTS := {
	"the_ahwahnee": "ahwahnee", "ahwahnee_meadow": "ahwahnee", "ahwahnee_trail": "ahwahnee",
	"housekeeping_camp": "curry_village", "upper_pines": "curry_village", "leidig_meadow": "cooks_meadow",
	"four_mile_trailhead": "sentinel_rock", "bridalveil_fall": "bridalveil_fall", "guardian_cave": "royal_arches",
}

## character id -> Array of {"region", "stays"} (NPC.stays: 0 always, 1 early
## home, 2 later home); route id -> region id.
static var _people: Dictionary = {}
static var _routes: Dictionary = {}
static var _hubs: Dictionary = {}
static var _read := false


## The main story's next step, or the press book's when there's no main one:
## {"quest", "region", "hub", "point" (illustrated map point id, may be ""),
## "route" (may be ""), "what" ("main" or "press")}, or {}.
static func current() -> Dictionary:
	var main := QuestLog.main_objective()
	if not main.is_empty():
		var target := for_quest(main.quest)
		if not target.is_empty():
			target["what"] = "main"
			return target
	var press := QuestLog.press_objective()
	if not press.is_empty():
		var target := for_quest(press.quest)
		if not target.is_empty():
			target["what"] = "press"
			return target
	return {}


## Every target worth a flag: the main story's and the press book's.
static func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for objective: Dictionary in [QuestLog.main_objective(), QuestLog.press_objective()]:
		if objective.is_empty():
			continue
		var target := for_quest(objective.quest)
		if not target.is_empty():
			target["what"] = "main" if objective.quest.main_line else "press"
			out.append(target)
	return out


## Where [param quest]'s next step happens.
static func for_quest(quest: QuestData) -> Dictionary:
	_read_overlays()
	var region := ""
	var route := ""
	if quest.id == QuestLog.FINALE_QUEST and QuestLog.active.has(quest.id):
		region = "the_ahwahnee"
		return _target(quest, region, "", "royal_arches")
	var step := QuestLog.current_step(quest)
	if not step.is_empty() and not QuestLog.is_step_done(step):
		match step.get("type", ""):
			"climbed":
				route = step.route
				region = _routes.get(route, "")
			"talk":
				region = region_of(step.target)
	if region == "":
		region = region_of(quest.giver)
	if region == "":
		return {}
	return _target(quest, region, route)


static func _target(quest: QuestData, region: String, route: String, point := "") -> Dictionary:
	if point == "":
		point = VALLEY_POINTS.get(region, region)
	return {"quest": quest, "region": region, "hub": hub_of(region), "point": point, "route": route}


## The region someone stands in now, from the story overlays.
static func region_of(character_id: String) -> String:
	_read_overlays()
	var places: Array = _people.get(character_id, [])
	if places.is_empty():
		return ""
	var character := QuestLog.get_character(character_id)
	var early := character != null and character.early_home != "" and character.at_early_home(QuestLog.is_completed)
	for place: Dictionary in places:
		if place.stays == 0 or (place.stays == 1 and early) or (place.stays == 2 and not early):
			return place.region
	return places[0].region


## The hub a region belongs to (its scene's hub_id).
static func hub_of(region_id: String) -> String:
	if _hubs.has(region_id):
		return _hubs[region_id]
	var hub := ""
	var path := "res://scenes/regions/%s.tscn" % region_id
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		# hub_id sits near the top, on the root node
		for i in 400:
			if file.eof_reached():
				break
			var line := file.get_line()
			if line.begins_with("hub_id = "):
				hub = line.trim_prefix("hub_id = ").trim_prefix("\"").trim_suffix("\"")
				break
	_hubs[region_id] = hub
	return hub


## Reads who and which climbs each story overlay puts in its region.
static func _read_overlays() -> void:
	if _read:
		return
	_read = true
	var dir := DirAccess.open(CONTENT_DIR)
	if dir == null:
		return
	var resource := RegEx.create_from_string('\\[ext_resource [^\\]]*path="res://data/(characters(?:/staff)?|routes)/([a-z0-9_]+)\\.tres" id="([^"]+)"\\]')
	var uses := RegEx.create_from_string('^(character|route) = ExtResource\\("([^"]+)"\\)')
	var stays := RegEx.create_from_string('^stays = (\\d)')
	for file_name in dir.get_files():
		if not file_name.ends_with(".tscn"):
			continue
		var region := file_name.get_basename()
		var text := FileAccess.get_file_as_string(CONTENT_DIR + file_name)
		var ids := {}
		for found in resource.search_all(text):
			ids[found.get_string(3)] = found.get_string(2)
		# walk the nodes, remembering the last character's entry for its stays
		var last: Dictionary = {}
		for line in text.split("\n"):
			if line.begins_with("[node"):
				last = {}
				continue
			var use := uses.search(line)
			if use:
				var id: String = ids.get(use.get_string(2), "")
				if id == "":
					continue
				if use.get_string(1) == "character":
					last = {"region": region, "stays": 0}
					if not _people.has(id):
						_people[id] = []
					_people[id].append(last)
				elif not _routes.has(id):
					_routes[id] = region
				continue
			var stay := stays.search(line)
			if stay and not last.is_empty():
				last.stays = int(stay.get_string(1))
