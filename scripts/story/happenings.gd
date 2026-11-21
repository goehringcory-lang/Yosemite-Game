extends Node
## Happenings around the park (autoload "Happenings"): small things going
## on out in the park that no quest sends you to. A painter at Tunnel View
## waiting for a storm to clear, a fisherman at Happy Isles who dropped his
## fly box, a hiker on Glacier Point who came up without breakfast, a crowd
## at Curry Village hushing for the Firefall. Each is someone standing in
## one area at one time of day, in some seasons and some weather, and only
## some of them are out on any day, so the day is yours to plan: where to
## go, and what to leave for another time.
##
## Each morning a few are rolled (PER_DAY, at most one an area) from those
## whose season, weather and sky fit the day, at least two of them at the
## same hours so you can't be everywhere. Two are heard about ahead (the
## Journal's "Heard around the park"); the rest you find by wandering. Each
## lasts its hours of that one day: missed, it costs nothing, and it may
## come round again on another day.
##
## The kinds (HAPPENINGS "kind"):
##   "witness"  be there, and stay a while if you like: a moment to watch
##   "give"     they need one thing, any of a few ("wants"), from your pack
##   "find"     they lost something nearby: find it ("thing") and bring it
##   "ask"      they ask the way, or about the park: pick the right answer
## The Logbook keeps which you've seen, area by area. The people are
## invented visitors (their looks are visitor sprites), not historical
## figures; nobody here is from the Native cast.
##
## HappeningField (World adds one) stands them in the area you're in.

signal changed

## Most happenings out on one day, and how many are heard about ahead.
const PER_DAY := 4
const RUMORS := 2
const VISITOR_DIR := "res://data/characters/visitors/%s.tres"
## Every store food: what someone hungry will take ("trail_food" in "wants").
const TRAIL_FOOD := ["trail_mix", "dried_apples", "pilot_bread", "cheddar_wedge", "dried_apricots", "beef_jerky", "chocolate_bar"]
const BERRIES := ["wild_strawberry", "blue_elderberries", "california_blackberry", "thimbleberry", "whitebark_raspberry",
	"sierra_gooseberry", "sierra_bilberry", "manzanita_berries", "toyon_berries", "chokecherry"]
const WILDFLOWERS := ["yerba_buena", "coyote_mint", "miners_lettuce", "cow_clover", "sierra_onion", "blue_dicks_corm", "yampah"]
const ITEM_SETS := {"trail_food": TRAIL_FOOD, "berries": BERRIES, "wildflowers": WILDFLOWERS}

## Every happening: where ("region", and "near" a marker there, standing
## "offset" from it), when ("hours" [from, to] in hours of the day, past
## 24 for after midnight; "seasons" as GameClock.Season), the day it needs
## ("weather": "dry", "wet", "snow", or "clearing": dry after a day of rain
## or snow; "sky": "moonbow", "firefall" or "horsetail", on the days those
## can happen), and "hub": the travel hub that has to be open. "who" and
## "look" are the person and their visitor sprite; "rumor" is what's heard
## ahead; "lines" what they say. Then by kind: "watch" (what you see if you
## stay, and "minutes" it takes), "wants" (item ids, or an ITEM_SETS name)
## and "wants_text", "thing" ({"name", "icon" (an item whose icon it
## borrows), "near", "offset"}) and "found_lines", "question", "options" (the
## right one first: they're shuffled when asked) and "wrong". "thanks" is
## said when it's done, and "reward" is what you're handed (item ids and
## counts; kept small, and all in one place for retuning).
const HAPPENINGS: Array[Dictionary] = [
	{"id": "tunnel_view_storm", "title": "A storm clearing at Tunnel View", "kind": "witness",
		"region": "tunnel_view", "near": "overlook", "offset": Vector2(70, 36), "hours": [13, 18],
		"seasons": [0, 1, 2, 3], "weather": "clearing", "hub": "yosemite_valley",
		"who": "Ada Whitcomb", "look": "visitor_painter",
		"rumor": "A painter drove up to Tunnel View this afternoon. She says the storm's about to break.",
		"lines": ["I've waited three days for this. The clouds are lifting off El Capitan like a curtain going up.",
			"Stand here with me. Don't talk. Just watch the light come down the Valley."],
		"watch": "The cloud tears open over Half Dome, and light pours down Bridalveil's spray. Ada paints fast, saying nothing at all.",
		"minutes": 30, "thanks": "There. I'll never get it on canvas, but I was here for it. So were you.",
		"reward": {"dried_apples": 1}},
	{"id": "el_cap_spotting", "title": "Spotting climbers on El Capitan", "kind": "ask",
		"region": "el_capitan_meadow", "near": "meadow", "offset": Vector2(-90, -40), "hours": [10, 16],
		"seasons": [0, 1, 2], "weather": "dry", "hub": "yosemite_valley",
		"who": "Harold Pease", "look": "visitor_tourist",
		"rumor": "There's a man in El Capitan Meadow with binoculars, asking everybody where the climbers are.",
		"lines": ["My wife says there are people up on that cliff right now. I've looked for an hour. I see rock."],
		"question": "Where should he look?",
		"options": ["Up the prow, by the long crack halfway up: the Nose", "Right at the very top, waving", "On the far end of the meadow, by the road"],
		"wrong": "He looks, and lowers the binoculars. \"Nope. Just rock. Are you sure?\"",
		"thanks": "There! Two of them, tiny as ants! On a ledge! Martha! MARTHA, COME LOOK!",
		"reward": {"chocolate_bar": 1}},
	{"id": "horsetail_wait", "title": "Waiting for the firefall on Horsetail", "kind": "give",
		"region": "el_capitan_meadow", "near": "meadow", "offset": Vector2(110, -30), "hours": [15.5, 17.9],
		"seasons": [3], "sky": "horsetail", "hub": "yosemite_valley",
		"who": "Dot Kimura", "look": "visitor_photographer",
		"rumor": "Photographers have their tripods out in El Capitan Meadow for the sunset on Horsetail Fall.",
		"lines": ["Twenty minutes of light a year, if the sky's clear and the fall's running. I've been standing in the snow since two.",
			"I forgot to bring anything to eat. Don't suppose you have something?"],
		"wants": "trail_food", "wants_text": "something from the store to eat",
		"thanks": "You're a saint. Now watch the east edge of El Cap, just as the sun goes. It glows like it's on fire.",
		"reward": {"trail_mix": 1}},
	{"id": "moonbow", "title": "A moonbow at Lower Yosemite Fall", "kind": "witness",
		"region": "yosemite_village", "near": "lower_yosemite_fall", "offset": Vector2(90, 110), "hours": [21, 25.5],
		"seasons": [0], "sky": "moonbow", "hub": "yosemite_valley",
		"who": "Milo Brandt", "look": "visitor_photographer",
		"rumor": "Somebody at the store says the full moon tonight makes a rainbow in the spray of Lower Yosemite Fall.",
		"lines": ["Full moon, spring flood, clear night. Everything has to line up, and tonight it does.",
			"Let your eyes get used to the dark. It's pale at first, then you can't stop seeing it."],
		"watch": "A pale arch rises out of the spray, silver and faintly colored at the edges. The fall roars on underneath it.",
		"minutes": 30, "thanks": "A rainbow at midnight. Nobody back home will believe us.",
		"reward": {"pilot_bread": 1}},
	{"id": "firefall_crowd", "title": "The Firefall from Camp Curry", "kind": "witness",
		"region": "curry_village", "near": "plaza", "offset": Vector2(-130, 70), "hours": [20, 21.4],
		"seasons": [1], "sky": "firefall", "hub": "yosemite_valley",
		"who": "The Novaks", "look": "visitor_camper",
		"rumor": "Families at Curry Village are saving spots on the lawn for the Firefall tonight.",
		"lines": ["We drove from Fresno for this. Nine o'clock sharp, they call up to Glacier Point.",
			"Sit with us. The kids are pretending they're not excited."],
		"watch": "\"Let the fire fall!\" A glowing ribbon pours off the rim, three thousand feet up, and the whole camp goes quiet.",
		"minutes": 20, "thanks": "Every summer. Every single summer, it gets me.",
		"reward": {"chocolate_bar": 1}},
	{"id": "glacier_breakfast", "title": "No breakfast at Glacier Point", "kind": "give",
		"region": "glacier_point", "near": "amphitheater", "offset": Vector2(-70, 44), "hours": [6, 9.5],
		"seasons": [1, 2], "weather": "dry", "hub": "glacier_point",
		"who": "Sam Ortega", "look": "visitor_backpacker",
		"rumor": "A hiker walked up the Four Mile Trail in the dark for sunrise at Glacier Point. I bet he forgot breakfast.",
		"lines": ["Watched the sun come up on Half Dome. Best thing I've ever seen.",
			"Worst thing I've ever done: walk up four miles of switchbacks with no breakfast."],
		"wants": "trail_food", "wants_text": "something to eat",
		"thanks": "Thank you. Here, I picked these on the way up. I was saving them, but you've earned them.",
		"reward": {"sierra_bilberry": 2}},
	{"id": "happy_isles_fly_box", "title": "A fly box lost at Happy Isles", "kind": "find",
		"region": "happy_isles", "near": "isles", "offset": Vector2(-70, 60), "hours": [7, 13],
		"seasons": [0, 1], "hub": "yosemite_valley",
		"who": "Walt Fenner", "look": "visitor_angler",
		"rumor": "An old fisherman at Happy Isles is hunting up and down the bank for something he dropped.",
		"lines": ["Forty years of flies in that box. I set it down to change my leader and the river took my attention.",
			"It'll be somewhere along this bank. Green tin. Keep an eye out?"],
		"thing": {"name": "Walt's fly box", "icon": "greg_fly_box", "near": "isles", "offset": Vector2(230, 70)},
		"found_lines": ["A green tin wedged between two rocks at the water's edge. It rattles with flies."],
		"thanks": "That's it! Oh, thank you. Here, I caught more than I can eat this morning anyway.",
		"reward": {"brook_trout": 1}},
	{"id": "mirror_lake_reflection", "title": "Morning on Mirror Lake", "kind": "witness",
		"region": "mirror_lake", "near": "lakeshore", "offset": Vector2(150, 30), "hours": [6, 9],
		"seasons": [0], "weather": "dry", "hub": "yosemite_valley",
		"who": "Clara Bishop", "look": "visitor_painter",
		"rumor": "A painter goes up to Mirror Lake at dawn while the water's still. By nine the wind ruins it, she says.",
		"lines": ["Before the breeze comes up the canyon, the lake's a sheet of glass. Mount Watkins upside down, perfect.",
			"Stay a few minutes. It doesn't last."],
		"watch": "Not a ripple. Mount Watkins hangs in the water, every crack in it. Then a breath of wind, and it shivers away.",
		"minutes": 20, "thanks": "Gone. That's why I come every morning.",
		"reward": {"miners_lettuce": 2}},
	{"id": "mirror_lake_gone", "title": "Where did Mirror Lake go?", "kind": "ask",
		"region": "mirror_lake", "near": "lakeshore", "offset": Vector2(-140, 50), "hours": [10, 16],
		"seasons": [2], "hub": "yosemite_valley",
		"who": "Edna Fry", "look": "visitor_tourist",
		"rumor": "A visitor at Mirror Lake is very upset. She says somebody's taken the lake.",
		"lines": ["The postcard says Mirror Lake. I see a meadow and a puddle. Did they drain it?"],
		"question": "What happened to the lake?",
		"options": ["Nothing: it fills with snowmelt in spring and dries back to meadow by fall", "The hotel drained it for the dining room", "A beaver dam broke"],
		"wrong": "Edna frowns. \"That doesn't sound right at all.\"",
		"thanks": "So it comes back every spring? Well. I'll just have to come back too.",
		"reward": {"dried_apricots": 1}},
	{"id": "meadow_rut", "title": "The rut in Ahwahnee Meadow", "kind": "witness",
		"region": "ahwahnee_meadow", "near": "meadow", "offset": Vector2(110, -50), "hours": [16.5, 19.5],
		"seasons": [2], "hub": "yosemite_valley",
		"who": "Ranger Ellis", "look": "visitor_ranger",
		"rumor": "A ranger's keeping people back in Ahwahnee Meadow at dusk. The bucks are in rut.",
		"lines": ["Bucks are in rut this time of year. They look sweet. They are not sweet.",
			"Stand back here with me, a good bus-length off, and you'll see something."],
		"watch": "Two bucks lower their heads at the edge of the oaks. A crack of antlers, a shove, and one trots off into the grass.",
		"minutes": 20, "thanks": "That's how you watch wildlife: from far enough off that they don't care you're there.",
		"reward": {"trail_mix": 1}},
	{"id": "leidig_evening_talk", "title": "The evening talk at Leidig Meadow", "kind": "give",
		"region": "leidig_meadow", "near": "picnic", "offset": Vector2(80, 40), "hours": [17, 20.5],
		"seasons": [0, 1], "hub": "yosemite_valley",
		"who": "Naturalist Pruitt", "look": "visitor_ranger",
		"rumor": "The naturalist giving the evening talk at Leidig Meadow wants a wildflower to show the campers.",
		"lines": ["Evening talk in half an hour, and I came out without anything to show them.",
			"Have you picked any wild plants today? Mint, clover, miner's lettuce, anything that grows here."],
		"wants": "wildflowers", "wants_text": "a wild plant from the meadows",
		"thanks": "Perfect. They'll pass it round and smell it, and that's the whole talk, really. Thank you.",
		"reward": {"dried_apricots": 1}},
	{"id": "housekeeping_sandal", "title": "A sandal lost on the river beach", "kind": "find",
		"region": "housekeeping_camp", "near": "beach", "offset": Vector2(-90, 0), "hours": [12, 17.5],
		"seasons": [1], "weather": "dry", "hub": "yosemite_valley",
		"who": "Lifeguard", "look": "visitor_lifeguard",
		"rumor": "A little kid at Housekeeping Camp lost a sandal in the river. The lifeguard's been looking all afternoon.",
		"lines": ["One kid, one sandal, one very big river. It went downstream a little way, I think.",
			"I can't leave the swimmers. Would you have a look along the beach?"],
		"thing": {"name": "a small sandal", "icon": "rental_shoes", "near": "beach", "offset": Vector2(250, 50)},
		"found_lines": ["A small sandal, caught on a snag in the shallows."],
		"thanks": "You found it! Somebody's going to stop crying now. Here, from the snack bag.",
		"reward": {"chocolate_bar": 1}},
	{"id": "bridalveil_soaked", "title": "Soaked at Bridalveil Fall", "kind": "give",
		"region": "bridalveil_fall", "near": "fall_base", "offset": Vector2(110, 150), "hours": [12, 17],
		"seasons": [0], "weather": "dry", "hub": "yosemite_valley",
		"who": "Mr. Abernathy", "look": "visitor_motorist",
		"rumor": "A man drove all the way from the coast to see Bridalveil Fall in flood. He got closer than he meant to.",
		"lines": ["I walked up for a closer look and the fall blew sideways. Every stitch I own is wet.",
			"There's a rainbow in the spray, though. Look at it. Worth it.",
			"I'm famished. You wouldn't have any berries, would you?"],
		"wants": "berries", "wants_text": "a handful of berries",
		"thanks": "Thank you. Here, take this from my picnic basket. It's the only dry thing I've got.",
		"reward": {"cheddar_wedge": 1}},
	{"id": "tuolumne_dome", "title": "A climb before the storms", "kind": "ask",
		"region": "tuolumne_meadows", "near": "meadow", "offset": Vector2(-70, 50), "hours": [9, 13],
		"seasons": [1], "hub": "tuolumne_meadows",
		"who": "Kit Lawson", "look": "visitor_backpacker",
		"rumor": "A hiker in Tuolumne Meadows wants to scramble up Lembert Dome, and keeps asking when to go.",
		"lines": ["See those little clouds over Cathedral Peak? Pretty, aren't they? I want to be on top of Lembert Dome this afternoon."],
		"question": "What do you tell him?",
		"options": ["Go now, and be off the granite by early afternoon: summer storms build after lunch", "Wait for the clouds, it's cooler then", "Go at sunset for the view"],
		"wrong": "He shrugs. \"Really? The ranger said something different.\"",
		"thanks": "Off the top by one. Got it. Lightning and bare granite. I'll go now.",
		"reward": {"whitebark_pine_nuts": 2}},
	{"id": "wawona_letter", "title": "A letter blown off at Wawona", "kind": "find",
		"region": "wawona", "near": "covered_bridge", "offset": Vector2(-60, 70), "hours": [8, 13],
		"seasons": [2], "hub": "wawona",
		"who": "Mrs. Calloway", "look": "visitor_stage_lady",
		"rumor": "A lady off the stage at Wawona lost a letter to the wind, out by the covered bridge.",
		"lines": ["A gust took it right out of my hand. It's from my sister, and I haven't read it yet!",
			"It went toward the river, I think. Oh, do look."],
		"thing": {"name": "a letter", "icon": "hiker_postcard", "near": "covered_bridge", "offset": Vector2(-240, 90)},
		"found_lines": ["An envelope in the dry grass, stuck against a fence post."],
		"thanks": "Oh, you're a dear. Plums from the hotel orchard. Take a few, I can't eat them all.",
		"reward": {"sierra_plum": 2}},
	{"id": "el_portal_which_way", "title": "Which way to the Valley?", "kind": "ask",
		"region": "el_portal", "near": "railroad", "offset": Vector2(90, 24), "hours": [8, 12],
		"seasons": [0, 3], "hub": "el_portal",
		"who": "Rail passenger", "look": "visitor_rail_passenger",
		"rumor": "Someone off the morning train at El Portal is lost already. You can't miss them, they've got a lot of bags.",
		"lines": ["The railroad stops here? I thought it went to Yosemite. Which way is the Valley?"],
		"question": "Which way do you send them?",
		"options": ["Up the Merced canyon road, past Arch Rock", "Over Tioga Pass", "South through Wawona"],
		"wrong": "They look at their ticket, and back at you. \"That seems a very long way round.\"",
		"thanks": "Up the river, past the big rock. Thank you! Here, I packed far too much food.",
		"reward": {"pilot_bread": 1}},
	{"id": "big_oak_chains", "title": "Chains on at Big Oak Flat", "kind": "give",
		"region": "big_oak_flat_junction", "near": "arrival", "offset": Vector2(110, 60), "hours": [9, 15],
		"seasons": [3], "weather": "snow", "hub": "yosemite_valley",
		"who": "Motorist", "look": "visitor_motorist",
		"rumor": "Somebody's been putting chains on at the Big Oak Flat junction since breakfast. In the snow.",
		"lines": ["Chains on, chains off, chains on. My fingers have stopped talking to me.",
			"Have you got anything to eat? I'd trade you my whole spare tire."],
		"wants": "trail_food", "wants_text": "something to eat",
		"thanks": "Bless you. Here, I won't need this. Don't tell the tire.",
		"reward": {"beef_jerky": 1}},
]

## Every happening seen through (done), by id: how many times.
var seen: Dictionary = {}
## Today's: the day they were rolled for (Friendship.today), the ids out,
## those done, the "find" ones asked about, and the things found.
var day_of := -1
var out_today: PackedStringArray = []
var done_today: PackedStringArray = []
var asked_today: PackedStringArray = []
var found_today: PackedStringArray = []

var _by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	for happening: Dictionary in HAPPENINGS:
		_by_id[happening.id] = happening
	GameClock.day_started.connect(_on_day_started.unbind(3))


func start_new_game() -> void:
	seen = {}
	day_of = -1
	out_today = []
	done_today = []
	asked_today = []
	found_today = []
	changed.emit()


func get_happening(id: String) -> Dictionary:
	return _by_id.get(id, {})


func total() -> int:
	return HAPPENINGS.size()


## How many different happenings you've seen through.
func count() -> int:
	return seen.size()


func has_seen(id: String) -> bool:
	return seen.has(id)


## True if [param happening] can be out on the day [param date] ({year,
## season, day}), from its season, the weather, the sky and the hub.
static func fits_day(happening: Dictionary, year: int, season: int, day: int) -> bool:
	if not season in happening.get("seasons", [0, 1, 2, 3]):
		return false
	var hub: String = happening.get("hub", "")
	if hub != "" and hub != "yosemite_valley" and not Park.is_hub_unlocked(hub):
		return false
	var weather := Weather.on_day(year, season, day)
	var wet: bool = weather.rain > 0.0 or weather.snow > 0.0
	match happening.get("weather", ""):
		"dry":
			if wet:
				return false
		"wet":
			if not wet:
				return false
		"snow":
			if weather.snow <= 0.0:
				return false
		"clearing":
			if wet:
				return false
			var before := _day_before(year, season, day)
			var then := Weather.on_day(before.x, before.y, before.z)
			if then.rain <= 0.0 and then.snow <= 0.0:
				return false
	match happening.get("sky", ""):
		"moonbow":
			if season != GameClock.Season.SPRING or absi(day - GameClock.FULL_MOON_DAY) > 1:
				return false
		"firefall":
			if season != GameClock.Season.SUMMER:
				return false
		"horsetail":
			if season != GameClock.Season.WINTER or day < GameClock.HORSETAIL_DAYS.x or day > GameClock.HORSETAIL_DAYS.y:
				return false
			if wet or weather.clouds > 0.7:
				return false
	return true


static func _day_before(year: int, season: int, day: int) -> Vector3i:
	if day > 1:
		return Vector3i(year, season, day - 1)
	if season > 0:
		return Vector3i(year, season - 1, GameClock.DAYS_PER_SEASON)
	return Vector3i(maxi(year - 1, 1), 3, GameClock.DAYS_PER_SEASON)


## The happenings that could be out on that day.
static func candidates(year: int, season: int, day: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for happening: Dictionary in HAPPENINGS:
		if fits_day(happening, year, season, day):
			out.append(happening)
	return out


## Which happenings are out on that day: up to PER_DAY, one an area at
## most, the rare sky ones first (they only come on their nights), the rest
## by a roll from the date. Never on the very first morning.
static func roll(year: int, season: int, day: int) -> PackedStringArray:
	var picked := PackedStringArray()
	if year == 1 and season == 0 and day == 1:
		return picked
	var pool := candidates(year, season, day)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("happenings:%d:%d:%d" % [year, season, day])
	# shuffle by the date's roll, then the sky ones to the front
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var keep: Dictionary = pool[i]
		pool[i] = pool[j]
		pool[j] = keep
	var sky := pool.filter(func(h: Dictionary) -> bool: return h.has("sky"))
	var rest := pool.filter(func(h: Dictionary) -> bool: return not h.has("sky"))
	var regions := {}
	for happening: Dictionary in sky + rest:
		if picked.size() >= PER_DAY or regions.has(happening.region):
			continue
		regions[happening.region] = true
		picked.append(happening.id)
	return picked


## Makes sure today's happenings are rolled.
func refresh() -> void:
	var today := Friendship.today()
	if day_of == today:
		return
	day_of = today
	out_today = roll(GameClock.year, GameClock.season, GameClock.day)
	done_today = []
	asked_today = []
	found_today = []
	changed.emit()


## Today's happenings, in the order rolled.
func today() -> Array[Dictionary]:
	refresh()
	var out: Array[Dictionary] = []
	for id: String in out_today:
		if _by_id.has(id):
			out.append(_by_id[id])
	return out


## The ones heard about ahead today (the Journal): the first RUMORS rolled.
func rumors() -> Array[Dictionary]:
	var out := today()
	return out.slice(0, RUMORS)


## True while [param happening]'s hours are on (by the minutes, so after
## midnight is still tonight).
static func in_hours(happening: Dictionary, minutes: int) -> bool:
	var hours: Array = happening.hours
	return minutes >= int(float(hours[0]) * 60.0) and minutes < int(float(hours[1]) * 60.0)


## True if [param id] is out today, and now.
func is_on(id: String) -> bool:
	return id in today().map(func(h: Dictionary) -> String: return h.id) and in_hours(_by_id[id], GameClock.minutes)


func is_done(id: String) -> bool:
	refresh()
	return id in done_today


## The happenings to stand in [param region_id] now: out today, in their
## hours, and not where a rescue's going on.
func here_now(region_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rescue: Dictionary = Rescues.active_call()
	for happening: Dictionary in today():
		if happening.region != region_id or not in_hours(happening, GameClock.minutes):
			continue
		if rescue.get("region", "") == region_id:
			continue
		out.append(happening)
	return out


## "1 PM to 6 PM": a happening's hours.
static func hours_text(happening: Dictionary) -> String:
	return "%s to %s" % [_time_text(float(happening.hours[0])), _time_text(float(happening.hours[1]))]


static func _time_text(hours: float) -> String:
	var h := int(hours) % 24
	var m := int(roundf((hours - floorf(hours)) * 60.0))
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return ("%d" % h12 if m == 0 else "%d:%02d" % [h12, m]) + (" AM" if h < 12 else " PM")


## The items [param happening] would take, as ids.
static func wanted(happening: Dictionary) -> Array:
	var wants = happening.get("wants", [])
	if wants is String:
		return ITEM_SETS.get(wants, [])
	return wants


## The first thing in your pack [param happening] would take, or "".
static func have_wanted(happening: Dictionary) -> String:
	for id: String in wanted(happening):
		if Inventory.count(id) > 0:
			return id
	return ""


## The "find" thing has been picked up.
func pick_up(id: String) -> void:
	if not id in found_today:
		found_today.append(id)
		changed.emit()


func has_found(id: String) -> bool:
	return id in found_today


func has_asked(id: String) -> bool:
	return id in asked_today


## Talking to the person at [param id]'s happening: what they say, the
## choice if any, and what comes of it. Plays it in [param box].
func talk(box: DialogueBox, id: String) -> void:
	var happening := get_happening(id)
	var who: String = happening.who
	if is_done(id):
		await box.say([{"speaker": who, "text": happening.thanks}])
		return
	match happening.kind:
		"witness":
			await box.say(_lines(happening, who))
			var choice := await box.choose("Stay and watch with them?", ["Stay a while", "Not now"])
			if choice != 0:
				return
			GameClock.advance_minutes(int(happening.get("minutes", 20)))
			await box.say([{"speaker": "", "text": happening.watch},
				{"speaker": who, "text": happening.thanks, "mood": "happy"},
				{"speaker": "", "text": _finish(happening)}])
		"give":
			await box.say(_lines(happening, who))
			var have := have_wanted(happening)
			if have == "":
				await box.say([{"speaker": "", "text": "You have nothing to give: they'd like %s." % happening.wants_text}])
				return
			var item := ItemDB.get_item(have)
			var item_name := item.display_name if item else have
			var choice := await box.choose("Give them 1 %s?" % item_name, ["Give it", "Not now"])
			if choice != 0:
				return
			Inventory.remove(have, 1)
			await box.say([{"speaker": who, "text": happening.thanks, "mood": "happy"},
				{"speaker": "", "text": _finish(happening)}])
		"find":
			if has_found(id):
				await box.say([{"speaker": who, "text": happening.thanks, "mood": "happy"},
					{"speaker": "", "text": _finish(happening)}])
				return
			await box.say(_lines(happening, who))
			if not has_asked(id):
				asked_today.append(id)
				changed.emit()
			await box.say([{"speaker": "", "text": "Look nearby for %s." % happening.thing.name}])
		"ask":
			await box.say(_lines(happening, who))
			var options: Array = happening.options.duplicate()
			var right: String = options[0]
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(id + str(day_of))
			for i in range(options.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var keep = options[i]
				options[i] = options[j]
				options[j] = keep
			var choice := await box.choose(happening.question, options)
			if choice < 0:
				return
			if options[choice] != right:
				await box.say([{"speaker": "", "text": happening.wrong}])
				return
			await box.say([{"speaker": who, "text": happening.thanks, "mood": "happy"},
				{"speaker": "", "text": _finish(happening)}])


func _lines(happening: Dictionary, who: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for text: String in happening.lines:
		lines.append({"speaker": who, "text": text})
	return lines


## Marks [param happening] done today and seen, and hands over the reward.
## Returns the line saying so.
func _finish(happening: Dictionary) -> String:
	done_today.append(happening.id)
	var first := not seen.has(happening.id)
	seen[happening.id] = int(seen.get(happening.id, 0)) + 1
	var got := PackedStringArray()
	var reward: Dictionary = happening.get("reward", {})
	for item_id: String in reward:
		Inventory.add(item_id, int(reward[item_id]))
		var item := ItemDB.get_item(item_id)
		got.append(ItemDB.count_name(int(reward[item_id]), item.display_name if item else item_id))
	changed.emit()
	var head := "%s: %s" % ["New in the Logbook" if first else "Happening", happening.title]
	return head + (". Received %s." % ", ".join(got) if not got.is_empty() else ".")


func _on_day_started() -> void:
	refresh()
	if rumors().is_empty():
		return
	# after the night's page and any festival note
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(7.0).timeout
	tree.call_group("hud", "show_message", "Heard around the park: %s" % rumors()[0].rumor)


func save_data() -> Dictionary:
	return {"seen": seen, "day": day_of, "out": out_today, "done": done_today, "asked": asked_today, "found": found_today}


func load_data(data: Dictionary) -> void:
	seen = {}
	var saved: Dictionary = data.get("seen", {})
	for key in saved:
		if _by_id.has(str(key)):
			seen[str(key)] = int(saved[key])
	day_of = int(data.get("day", -1))
	out_today = PackedStringArray(Array(data.get("out", [])).filter(func(id) -> bool: return _by_id.has(str(id))))
	done_today = PackedStringArray(data.get("done", []))
	asked_today = PackedStringArray(data.get("asked", []))
	found_today = PackedStringArray(data.get("found", []))
	changed.emit()
