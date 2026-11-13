extends Node
## Achievements and the collection log (autoload "Achievements"), shown on
## the Journal's Logbook tab (L).
##
## The collection log keeps your records: every summit you've stood on, every
## route you've sent (how often, cleanest, fastest), and every fish you've
## landed (how many, the biggest, the trophies). The wildlife itself lives in
## the field log (FieldLog); achievements read it through count()/total().
##
## Achievements are just for the record: unlike Perks, none of them changes
## how the game plays. Each one has an "unlock" that [method progress]
## understands, and a line on how to earn it. They're checked whenever
## something they count changes, and a new one shows a message on the HUD
## once it's free (queued, like a new perk's).
##
## Hooks, one line each at the call site:
##   A route topped out   climb_start.gd climb()   sent()
##   A fish landed        fishing.gd land()        caught()
## Summits come from the tick list and Half Dome's unlock (QuestLog).

signal unlocked(achievement: Dictionary)
signal changed
## Sent when a fish is landed, after it's logged (Friendship tells people).
signal landed(one: Dictionary)

## The park's summits you can stand on, highest first: by a climb's tick
## ("route"), or by a QuestLog unlock ("unlock"). Either way up Half Dome
## (the cables or Snake Dike) sets its unlock (SummitMoment).
const SUMMITS: Array[Dictionary] = [
	{"id": "cathedral_peak", "name": "Cathedral Peak", "feet": 10911, "route": "cathedral_peak",
		"how": "Climb Cathedral Peak's southeast buttress, in the high country.",
		"note": "A summit block the size of a kitchen table. John Muir climbed it alone in 1869, in his hobnailed boots."},
	{"id": "half_dome", "name": "Half Dome", "feet": 8842, "unlock": Backcountry.SUMMIT,
		"how": "Up the cables from Little Yosemite Valley, or climb Snake Dike.",
		"note": "George Anderson drilled his way up the back of it in 1875, the first person known to stand on top."},
	{"id": "el_capitan", "name": "El Capitan", "feet": 7573, "route": "the_nose",
		"how": "Climb the Nose.",
		"note": "Three thousand feet of granite. From the top, the meadow where you started is a green thumbprint."},
	{"id": "sentinel_rock", "name": "Sentinel Rock", "feet": 7038, "route": "steck_salathe",
		"how": "Climb the Steck-Salathé up its north face.",
		"note": "Across the Valley from Yosemite Falls. Its long north face was first climbed in 1950, in five days."},
	{"id": "higher_cathedral_spire", "name": "Higher Cathedral Spire", "feet": 6114, "route": "higher_cathedral_spire",
		"how": "Climb Higher Cathedral Spire.",
		"note": "In 1934 the Sierra Club's climbers reached its top with ropes, pitons and a lot of nerve: the start of Valley rock climbing."},
]

## Every achievement. "unlock" is how it's earned, as {"type": ..., more}:
##   summits n        stand on n summits ("all" for every one)
##   summit id        stand on that summit
##   ticks n          tick n routes in the guidebook ("all" for every one)
##   sends n          top out n times, repeats too
##   clean            send a led route (not top rope or a boulder) with no falls
##   wall_night       send a route with a night on the wall
##   grade g          send a route of YDS grade g or harder (Guidebook.yds)
##   route id         send that route
##   both_ways        Half Dome by the cables and by Snake Dike
##   fish n           land n fish
##   species          land every kind of fish
##   trophy           land a trophy fish
##   length id n      land that fish n inches or longer
##   animals n        n animals in the field log ("all" for every one)
##   group g          every animal of that group ("bird", "mammal"...) in the field log
##   unlock id        that QuestLog unlock (a first, like a night out)
##   stat id n        n of a counted Perks stat
##   medal            a gold medal on any slackline
##   pressed n        n plants in the press book
##   hearts           a friend at full hearts
##   photos n         take n photographs (Photos)
##   photo_stars n    make a photograph with n stars
##   shot_list n      n pictures on Ansel's shot list ("all" for every one)
const ACHIEVEMENTS: Array[Dictionary] = [
	# Summits
	{"id": "first_summit", "name": "Top of the World", "group": "Summits",
		"unlock": {"type": "summits", "count": 1}, "how": "Stand on top of any summit."},
	{"id": "half_dome", "name": "The Dome", "group": "Summits",
		"unlock": {"type": "summit", "id": "half_dome"}, "how": "Stand on top of Half Dome."},
	{"id": "both_ways", "name": "Both Ways Up", "group": "Summits",
		"unlock": {"type": "both_ways"}, "how": "Go up Half Dome's cables, and climb Snake Dike."},
	{"id": "el_cap_summit", "name": "On Top of El Cap", "group": "Summits",
		"unlock": {"type": "summit", "id": "el_capitan"}, "how": "Top out on El Capitan."},
	{"id": "every_summit", "name": "Peak Bagger", "group": "Summits",
		"unlock": {"type": "summits", "count": "all"}, "how": "Stand on every summit in the logbook."},
	# Climbing
	{"id": "first_tick", "name": "First Tick", "group": "Climbing",
		"unlock": {"type": "ticks", "count": 1}, "how": "Tick a route in the guidebook."},
	{"id": "clean_send", "name": "Clean Send", "group": "Climbing",
		"unlock": {"type": "clean"}, "how": "Lead a route top to bottom without a fall (top rope and boulders don't count)."},
	{"id": "high_ball", "name": "Nobody Does the Mantel", "group": "Climbing",
		"unlock": {"type": "route", "id": "midnight_lightning"}, "how": "Send Midnight Lightning at Camp 4."},
	{"id": "wall_night", "name": "Sleeping on the Wall", "group": "Climbing",
		"unlock": {"type": "wall_night"}, "how": "Send a route with a night on the wall."},
	{"id": "into_the_tens", "name": "Into the Tens", "group": "Climbing",
		"unlock": {"type": "grade", "yds": 10.0}, "how": "Send a 5.10."},
	{"id": "five_twelve", "name": "Five-Twelve", "group": "Climbing",
		"unlock": {"type": "grade", "yds": 12.0}, "how": "Send a 5.12."},
	{"id": "sends_20", "name": "Camp 4 Regular", "group": "Climbing",
		"unlock": {"type": "sends", "count": 20}, "how": "Top out 20 times (repeats count)."},
	{"id": "every_tick", "name": "The Whole Guidebook", "group": "Climbing",
		"unlock": {"type": "ticks", "count": "all"}, "how": "Tick every route in the guidebook."},
	# Fishing
	{"id": "first_fish", "name": "First Rise", "group": "Fishing",
		"unlock": {"type": "fish", "count": 1}, "how": "Land a fish on the fly."},
	{"id": "trophy", "name": "Trophy", "group": "Fishing",
		"unlock": {"type": "trophy"}, "how": "Land a trophy, a fish near the top of its size."},
	{"id": "two_footer", "name": "Two-Footer", "group": "Fishing",
		"unlock": {"type": "length", "id": "brown_trout", "inches": 22}, "how": "Land a brown trout of 22 inches or more. The big ones lie deep in the holes."},
	{"id": "fish_25", "name": "A River Runs Through It", "group": "Fishing",
		"unlock": {"type": "fish", "count": 25}, "how": "Land 25 fish."},
	{"id": "every_fish", "name": "Every Fish in the Park", "group": "Fishing",
		"unlock": {"type": "species"}, "how": "Land every kind of fish in the park."},
	# Wildlife
	{"id": "animals_5", "name": "Field Notes", "group": "Wildlife",
		"unlock": {"type": "animals", "count": 5}, "how": "Log 5 animals in your field log."},
	{"id": "every_bird", "name": "Birder", "group": "Wildlife",
		"unlock": {"type": "group", "id": "bird"}, "how": "See or hear every bird in the field log."},
	{"id": "every_animal", "name": "Naturalist", "group": "Wildlife",
		"unlock": {"type": "animals", "count": "all"}, "how": "Fill in the whole field log."},
	# Valley life
	{"id": "wanderer", "name": "Wanderer", "group": "Valley life",
		"unlock": {"type": "places", "count": 25}, "how": "Discover 25 places in the park."},
	{"id": "every_corner", "name": "Every Corner", "group": "Valley life",
		"unlock": {"type": "places", "count": "all"}, "how": "Discover every place in the park."},
	{"id": "night_out", "name": "Under the Stars", "group": "Valley life",
		"unlock": {"type": "unlock", "id": Backcountry.NIGHT_OUT}, "how": "Spend a night in the backcountry with your food in a bear canister."},
	{"id": "slackline_gold", "name": "Gold on the Line", "group": "Valley life",
		"unlock": {"type": "medal"}, "how": "Win a gold medal walking a Camp 4 slackline."},
	{"id": "pressed_20", "name": "Pressed for Time", "group": "Valley life",
		"unlock": {"type": "pressed", "count": 20}, "how": "Press 20 plants in your press book."},
	{"id": "rescues_10", "name": "Yellow Shirt", "group": "Valley life",
		"unlock": {"type": "stat", "id": "rescues", "count": 10}, "how": "Answer 10 rescue calls from the Camp 4 rescue site."},
	{"id": "best_friend", "name": "Best of Friends", "group": "Valley life",
		"unlock": {"type": "hearts"}, "how": "Fill every heart with a friend."},
	# Photography
	{"id": "first_print", "name": "First Exposure", "group": "Photography",
		"unlock": {"type": "photos", "count": 1}, "how": "Take a photograph with the camera Ansel Adams lends you."},
	{"id": "three_stars", "name": "Worth the Wait", "group": "Photography",
		"unlock": {"type": "photo_stars", "count": 3}, "how": "Make a three-star photograph: the right subject in the right light."},
	{"id": "portfolio", "name": "A Portfolio", "group": "Photography",
		"unlock": {"type": "shot_list", "count": 8}, "how": "Photograph 8 of the pictures on Ansel's list."},
	{"id": "whole_valley", "name": "The Whole Valley on Paper", "group": "Photography",
		"unlock": {"type": "shot_list", "count": "all"}, "how": "Photograph every picture on Ansel's list."},
]

## The order the Logbook lists the groups in.
const GROUPS := ["Summits", "Climbing", "Fishing", "Wildlife", "Valley life", "Photography"]
## How long the HUD must be free before an achievement shows, and the time
## between two queued ones (as Perks).
const TOAST_DELAY := 2.0
const TOAST_GAP := 3.6

## Achievement id -> the day (Friendship.today()) it was earned.
var earned: Dictionary = {}
## Summit id -> {"day"} the first time you stood on it (day -1: before the
## logbook was kept).
var summits: Dictionary = {}
## Route id -> {"count", "first_day", "falls" (fewest in a send), "minutes"
## (fastest send, game minutes on the wall), "clean" (a send with no falls)}.
var sends: Dictionary = {}
## Fish id -> {"count", "biggest" (inches, 0 if unknown), "trophies",
## "first_day", "where"}.
var fish: Dictionary = {}

var _by_id: Dictionary = {}
var _toasts: PackedStringArray = []
var _toast_wait := TOAST_DELAY
## Set by start_new_game() and load_data(), so settle() knows whether this
## game's records were loaded or are left over from another.
var _fresh_state := false


func _ready() -> void:
	add_to_group("persist")
	for achievement: Dictionary in ACHIEVEMENTS:
		_by_id[achievement.id] = achievement
	QuestLog.changed.connect(_on_progress)
	FieldLog.changed.connect(_on_progress)
	Discoveries.changed.connect(_on_progress)
	Perks.changed.connect(_on_progress)
	Herbarium.changed.connect(_on_progress)
	Rescues.changed.connect(_on_progress)
	Friendship.changed.connect(_on_progress)


func start_new_game() -> void:
	_clear()
	_fresh_state = true
	changed.emit()


func _clear() -> void:
	earned = {}
	summits = {}
	sends = {}
	fish = {}
	_toasts = []


## After a game starts or loads (World): a save from before the logbook has
## no records of its own, so they're rebuilt from what it does have (ticks,
## Half Dome, the field log's fish), and everything already earned is
## earned quietly.
func settle() -> void:
	if not _fresh_state:
		_clear()
	_fresh_state = false
	for route_id: String in QuestLog.climbed:
		if not sends.has(route_id):
			sends[route_id] = {"count": 1, "first_day": -1, "falls": -1, "minutes": 0, "clean": false}
	for entry: Dictionary in Fishing.FISH:
		if FieldLog.has(entry.id) and not fish.has(entry.id):
			var seen: Dictionary = FieldLog.seen[entry.id]
			fish[entry.id] = {"count": 1, "biggest": 0, "trophies": 0, "first_day": int(seen.get("day", -1)), "where": str(seen.get("where", ""))}
	_note_summits(-1)
	check(false)
	changed.emit()


func get_achievement(id: String) -> Dictionary:
	return _by_id.get(id, {})


func get_summit(id: String) -> Dictionary:
	for summit: Dictionary in SUMMITS:
		if summit.id == id:
			return summit
	return {}


func has(id: String) -> bool:
	return earned.has(id)


func count() -> int:
	return earned.size()


func total() -> int:
	return ACHIEVEMENTS.size()


# ---------------------------------------------------------------- the records

## A route topped out (ClimbStart). [param state] is the finished ClimbState.
func sent(route: RouteData, state: ClimbState) -> void:
	var entry: Dictionary = sends.get(route.id, {"count": 0, "first_day": Friendship.today(), "falls": -1, "minutes": 0, "clean": false})
	entry.count = int(entry.count) + 1
	if int(entry.falls) < 0 or state.falls < int(entry.falls):
		entry.falls = state.falls
	if state.minutes > 0 and (int(entry.minutes) <= 0 or state.minutes < int(entry.minutes)):
		entry.minutes = state.minutes
	if state.falls == 0:
		entry.clean = true
	sends[route.id] = entry
	_on_progress()


## A fish on the bank (Fishing.land()), as Fishing.hooked() made it.
func caught(one: Dictionary) -> void:
	var id: String = one.get("id", "")
	if id == "":
		return
	var entry: Dictionary = fish.get(id, {"count": 0, "biggest": 0, "trophies": 0, "first_day": Friendship.today(), "where": _place()})
	entry.count = int(entry.count) + 1
	entry.biggest = maxi(int(entry.biggest), int(one.get("length", 0)))
	if one.get("trophy", false):
		entry.trophies = int(entry.trophies) + 1
	fish[id] = entry
	_on_progress()
	landed.emit(one)


func fish_count() -> int:
	var n := 0
	for id: String in fish:
		n += int(fish[id].count)
	return n


func send_count() -> int:
	var n := 0
	for id: String in sends:
		n += int(sends[id].count)
	return n


func summit_count() -> int:
	return summits.size()


## True if you've stood on top of [param id] (a SUMMITS id).
func on_summit(id: String) -> bool:
	return summits.has(id)


## Writes down any summit newly reached, on [param day].
func _note_summits(day: int) -> void:
	for summit: Dictionary in SUMMITS:
		if summits.has(summit.id):
			continue
		var reached: bool = QuestLog.has_climbed(summit.route) if summit.has("route") else QuestLog.is_unlocked(summit.unlock)
		if reached:
			summits[summit.id] = {"day": day}


# ---------------------------------------------------------------- achievements

## [have, need] toward an achievement.
func progress(achievement: Dictionary) -> Array[int]:
	var unlock: Dictionary = achievement.unlock
	var have := 0
	var need := 1
	match str(unlock.type):
		"summits":
			have = summit_count()
			need = SUMMITS.size() if str(unlock.count) == "all" else int(unlock.count)
		"summit":
			have = 1 if on_summit(unlock.id) else 0
		"both_ways":
			have = int(QuestLog.is_unlocked(Backcountry.CABLES)) + int(QuestLog.has_climbed("snake_dike"))
			need = 2
		"ticks":
			have = QuestLog.climbed.size()
			need = Guidebook.routes().size() if str(unlock.count) == "all" else int(unlock.count)
		"sends":
			have = send_count()
			need = int(unlock.count)
		"clean":
			have = 1 if _any_clean_lead() else 0
		"wall_night":
			for route in Guidebook.routes():
				if route.nights > 0 and sends.has(route.id):
					have = 1
		"grade":
			for route in Guidebook.routes():
				if sends.has(route.id) and Guidebook.yds(route.grade) >= float(unlock.yds):
					have = 1
		"route":
			have = 1 if sends.has(unlock.id) or QuestLog.has_climbed(unlock.id) else 0
		"fish":
			have = fish_count()
			need = int(unlock.count)
		"species":
			have = fish.size()
			need = Fishing.FISH.size()
		"trophy":
			for id: String in fish:
				if int(fish[id].trophies) > 0:
					have = 1
		"length":
			have = 1 if int(fish.get(unlock.id, {}).get("biggest", 0)) >= int(unlock.inches) else 0
		"places":
			have = Discoveries.count()
			need = Discoveries.total() if str(unlock.count) == "all" else int(unlock.count)
		"animals":
			have = FieldLog.count()
			need = FieldLog.total() if str(unlock.count) == "all" else int(unlock.count)
		"group":
			need = 0
			for animal: Dictionary in FieldLog.ANIMALS:
				if animal.get("group", "") == unlock.id:
					need += 1
					have += int(FieldLog.has(animal.id))
		"unlock":
			have = 1 if QuestLog.is_unlocked(unlock.id) else 0
		"stat":
			have = Perks.stat(unlock.id)
			need = int(unlock.count)
		"medal":
			# a Camp 4 line, as for the first gold: not the travel line you rig anywhere
			for key: String in Perks.stats:
				if key.begins_with("slackline_medal_") and key != "slackline_medal_" + SlacklineState.TRAVEL and int(Perks.stats[key]) >= 3:
					have = 1
		"pressed":
			have = Herbarium.count()
			need = int(unlock.count)
		"hearts":
			for id: String in Friendship.points:
				if Friendship.hearts(id) >= Friendship.MAX_HEARTS:
					have = 1
		"photos":
			have = Photos.total
			need = int(unlock.count)
		"photo_stars":
			have = 1 if Photos.best_ever >= int(unlock.count) else 0
		"shot_list":
			have = Photos.listed_count()
			need = Photos.SHOT_LIST.size() if str(unlock.count) == "all" else int(unlock.count)
	return [mini(have, need), need]


## True if the achievement's condition is met. One with nothing to count yet
## (a field log group with no animals in it) can't be earned.
func is_ready(achievement: Dictionary) -> bool:
	var p := progress(achievement)
	return p[1] > 0 and p[0] >= p[1]


## Earns every achievement whose condition is met. [param announce] queues a
## HUD message for each (catching up on a loaded save is quiet).
func check(announce := true) -> void:
	var any := false
	for achievement: Dictionary in ACHIEVEMENTS:
		if has(achievement.id) or not is_ready(achievement):
			continue
		earned[achievement.id] = Friendship.today() if announce else -1
		any = true
		if announce:
			_toasts.append("Achievement: %s. %s It's in your logbook (L)." % [achievement.name, achievement.how])
		unlocked.emit(achievement)
	if any:
		changed.emit()


## Messages not shown yet (tests read this).
func pending_toasts() -> PackedStringArray:
	return _toasts


func _on_progress() -> void:
	_note_summits(Friendship.today())
	check()
	changed.emit()


func _any_clean_lead() -> bool:
	for route in Guidebook.routes():
		if not route.top_rope and not route.boulder and bool(sends.get(route.id, {}).get("clean", false)):
			return true
	return false


func _process(delta: float) -> void:
	if _toasts.is_empty():
		return
	if Perks._hud_busy() or not Perks.pending_toasts().is_empty():
		_toast_wait = maxf(_toast_wait, TOAST_DELAY)
		return
	_toast_wait -= delta
	if _toast_wait > 0.0:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	hud.show_message(_toasts[0])
	Sound.play("slack_medal", -8.0, 0.0)
	_toasts.remove_at(0)
	_toast_wait = TOAST_GAP


func _place() -> String:
	var world := get_tree().get_first_node_in_group("world")
	var region: Region = world.region if world and "region" in world else null
	if region == null:
		return ""
	return region.display_name if region.display_name != "" else region.region_id.capitalize()


## "Spring 12, year 1", or "" for a day before the logbook.
static func day_text(day: int) -> String:
	if day < 0:
		return ""
	var per_year := 4 * GameClock.DAYS_PER_SEASON
	var n := maxi(day - 1, 0)
	var season: int = (n % per_year) / GameClock.DAYS_PER_SEASON
	return "%s %d, year %d" % [GameClock.SEASON_NAMES[season], n % GameClock.DAYS_PER_SEASON + 1, n / per_year + 1]


## "3 h 20 min" for a climb's game minutes.
static func time_text(minutes: int) -> String:
	if minutes <= 0:
		return ""
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %02d min" % [minutes / 60, minutes % 60] if minutes % 60 != 0 else "%d h" % (minutes / 60)


func save_data() -> Dictionary:
	return {"earned": earned, "summits": summits, "sends": sends, "fish": fish}


func load_data(data: Dictionary) -> void:
	_clear()
	_fresh_state = true
	var saved: Dictionary = data.get("earned", {})
	for key in saved:
		if _by_id.has(str(key)):
			earned[str(key)] = int(saved[key])
	saved = data.get("summits", {})
	for key in saved:
		if not get_summit(str(key)).is_empty():
			var entry = saved[key]
			summits[str(key)] = {"day": int(entry.get("day", -1)) if entry is Dictionary else -1}
	saved = data.get("sends", {})
	for key in saved:
		var entry = saved[key]
		if entry is Dictionary:
			sends[str(key)] = {"count": int(entry.get("count", 1)), "first_day": int(entry.get("first_day", -1)),
				"falls": int(entry.get("falls", -1)), "minutes": int(entry.get("minutes", 0)), "clean": bool(entry.get("clean", false))}
	saved = data.get("fish", {})
	for key in saved:
		var entry = saved[key]
		if entry is Dictionary:
			fish[str(key)] = {"count": int(entry.get("count", 1)), "biggest": int(entry.get("biggest", 0)),
				"trophies": int(entry.get("trophies", 0)), "first_day": int(entry.get("first_day", -1)), "where": str(entry.get("where", ""))}
	changed.emit()
